import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../models/installation.dart';
import 'exchange_api_client.dart' show DownloadedArtifact;

/// WP-EXC-013 (Exchange -> Repository Install Bridge). The one place an
/// Exchange-downloaded package archive is actually installed -- by
/// calling Foundation's existing, authoritative `oep_package_install`
/// (via the already-established `FoundationBridge.installPackage` FFI
/// path, exactly as `package_manager_page.dart` already does for a
/// manually-selected local file). This class introduces no new
/// installation mechanism: it only (1) verifies the downloaded bytes
/// against the checksum Exchange's own download response already
/// supplies, (2) writes them to a temporary file (Foundation's installer
/// takes a filesystem path, not a byte buffer), and (3) calls the real
/// installer and classifies whatever it reports.
///
/// The installer call itself is injectable ([PackageInstaller]) so this
/// bridge's checksum/classification logic can be unit-tested without a
/// real Foundation runtime — the default, [FoundationBridge.installPackage],
/// is what production code actually uses.
typedef PackageInstaller = PackageInstallResult Function(String archivePath);

/// The categories WP-EXC-013 §9 requires this bridge to distinguish.
/// Deliberately not more granular than Foundation itself can establish —
/// e.g. a corrupt/unreadable archive and a dependency-resolution failure
/// are both [installFailure], because `oep_package_install` reports
/// neither with its own distinct error code (see
/// `docs/tasks/WP-EXC-013.md` §8 for the exact message substrings this
/// bridge classifies against); [diagnosticMessage] always preserves
/// Foundation's own specific text regardless of which bucket it falls in.
enum InstallFailureCategory {
  /// The downloaded bytes' SHA-256 did not match the checksum Exchange's
  /// own download response reported — rejected before Foundation is ever
  /// invoked (WP-EXC-013 §6/§8: "Exchange rejects before Foundation
  /// installation").
  checksumMismatch,

  /// Foundation's own Ed25519 trust verification (WP-REP-004) rejected
  /// the package (Tampered / InvalidSignature / UnknownPublisher /
  /// ExpiredCertificate / RevokedCertificate), or the repository's trust
  /// policy requires a signature the package doesn't have.
  trustFailure,

  /// Foundation's Package Registry already has this `packageId` recorded
  /// as installed (`oep_package_install`'s own "already installed"
  /// outcome, not invented here).
  alreadyInstalled,

  /// Any other `oep_package_install` failure — corrupt/unreadable
  /// archive, no repository open, Engineering Object/Relationship
  /// creation failure, dependency resolution failure, etc. — each
  /// already distinguishable from [diagnosticMessage]'s own text if a
  /// caller needs finer detail than this bridge's four categories.
  installFailure,
}

/// The result of one [ExchangeInstallBridge.install] call.
class InstallOutcome {
  const InstallOutcome.success(this.result)
      : failureCategory = null,
        diagnosticMessage = null;

  const InstallOutcome.failure(this.failureCategory, this.diagnosticMessage) : result = null;

  /// Non-null iff Foundation genuinely installed the package —
  /// `packageId`/`version` are Foundation's own Package Registry
  /// identity (WP-EXC-013 §12: distinct from, and authoritative over,
  /// Exchange's own catalog `packageId`/`version` strings, even though
  /// they are expected to carry the same values for a well-formed
  /// package); `objectsCreated`/`relationshipsCreated` are exactly what
  /// `oep_package_install` reports.
  final PackageInstallResult? result;

  final InstallFailureCategory? failureCategory;

  /// Foundation's own error text (`FoundationBridgeException.technicalDetail`)
  /// for a Foundation-side failure, or this bridge's own message for a
  /// checksum mismatch. Never a generic, information-losing string.
  final String? diagnosticMessage;

  bool get success => result != null;
}

class ExchangeInstallBridge {
  ExchangeInstallBridge({required PackageInstaller installer, Directory? tempDirectoryOverride})
      : _installer = installer,
        _tempDirectoryOverride = tempDirectoryOverride;

  final PackageInstaller _installer;
  final Directory? _tempDirectoryOverride;

  /// Verifies [archiveBytes] against [expectedSha256Hex], writes them to a
  /// temporary file, calls the real Foundation installer, and classifies
  /// the outcome. The temporary file is always removed afterward,
  /// regardless of outcome — Foundation's own Package Registry, not this
  /// bridge, is where an installed package's data actually lives.
  Future<InstallOutcome> install({
    required Uint8List archiveBytes,
    required String expectedSha256Hex,
    required String packageId,
  }) async {
    final actualSha256 = sha256.convert(archiveBytes).toString();
    if (actualSha256.toLowerCase() != expectedSha256Hex.toLowerCase()) {
      return InstallOutcome.failure(
        InstallFailureCategory.checksumMismatch,
        'Downloaded archive for "$packageId" does not match the checksum Exchange reported '
        '(expected $expectedSha256Hex, got $actualSha256). The archive was not installed.',
      );
    }

    final tempDir = _tempDirectoryOverride ?? Directory.systemTemp.createTempSync('oep_exchange_install_');
    // A sanitized, deterministic-enough file name -- the path itself is
    // never persisted or shown to the user; only Foundation's own
    // Package Registry identity (in the returned result) is.
    final safeName = packageId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final archiveFile = File('${tempDir.path}${Platform.pathSeparator}$safeName.oep');

    try {
      await archiveFile.writeAsBytes(archiveBytes, flush: true);
      final result = _installer(archiveFile.path);
      return InstallOutcome.success(result);
    } on FoundationBridgeException catch (error) {
      return InstallOutcome.failure(_classify(error), error.technicalDetail);
    } finally {
      if (archiveFile.existsSync()) {
        archiveFile.deleteSync();
      }
      if (_tempDirectoryOverride == null && tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  }

  /// Classifies a real `FoundationRuntime::install_package` failure by its
  /// own `technicalDetail` text — the exact substrings that function
  /// produces (`platform/oep_foundation/platform/runtime/src/foundation_runtime.cpp`),
  /// not invented here. See `docs/tasks/WP-EXC-013.md` §8 for the full,
  /// evidenced mapping.
  InstallFailureCategory _classify(FoundationBridgeException error) {
    final detail = error.technicalDetail;
    if (detail.contains('is already installed')) {
      return InstallFailureCategory.alreadyInstalled;
    }
    if (detail.contains('could not verify package trust') ||
        detail.contains('package trust verification failed') ||
        detail.contains('trust policy requires signed packages')) {
      return InstallFailureCategory.trustFailure;
    }
    return InstallFailureCategory.installFailure;
  }
}

/// [ExchangeRuntimeNotifier.installPackage]'s own WP-EXC-013 orchestration
/// step, factored out as a standalone function so it is testable with
/// plain fakes — no Riverpod `ProviderContainer`, no real Foundation
/// runtime, and no real HTTP call required — rather than only reachable
/// through the full notifier. [installer] is `null` when Foundation has
/// no repository open yet (`FoundationRuntimeNotifier.bridge` itself is
/// nullable for exactly that reason); every other parameter mirrors
/// [ExchangeInstallBridge.install]'s own inputs. Returns [installation]
/// corrected to reflect what actually happened — never trusts Exchange's
/// own `completed` status as proof the package reached the Repository.
Future<Installation> applyFoundationInstall({
  required Installation installation,
  required String packageId,
  required String? version,
  required Future<DownloadedArtifact> Function(String packageId, {String? version}) downloadArtifact,
  required PackageInstaller? installer,
  Directory? tempDirectoryOverride,
}) async {
  if (installer == null) {
    return installation.copyWith(
      status: 'failed',
      errorMessage: 'No OEP Repository is currently open, so "$packageId" could not be installed locally.',
    );
  }

  final artifact = await downloadArtifact(packageId, version: version);
  final bridge = ExchangeInstallBridge(installer: installer, tempDirectoryOverride: tempDirectoryOverride);
  final outcome = await bridge.install(
    archiveBytes: Uint8List.fromList(artifact.bytes),
    expectedSha256Hex: artifact.sha256,
    packageId: packageId,
  );

  if (outcome.success) {
    final result = outcome.result!;
    return installation.copyWith(
      status: 'completed',
      clearErrorMessage: true,
      repositoryPackageId: '${result.packageId}@${result.version}',
    );
  }
  return installation.copyWith(status: 'failed', errorMessage: outcome.diagnosticMessage);
}
