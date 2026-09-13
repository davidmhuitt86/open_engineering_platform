import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/foundation/foundation_bridge_exception.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/exchange/models/installation.dart';
import 'package:oep_studio/exchange/services/exchange_api_client.dart';
import 'package:oep_studio/exchange/services/exchange_install_bridge.dart';

/// Exercises `applyFoundationInstall` -- the exact function
/// `ExchangeRuntimeNotifier.installPackage` (WP-EXC-013) delegates to --
/// with plain fakes for both the download step and the Foundation
/// installer. This is `ExchangeRuntimeNotifier`'s own WP-EXC-013
/// orchestration logic under test, not merely `ExchangeInstallBridge` in
/// isolation (see `exchange_install_bridge_test.dart` for that): it
/// proves the *notifier's* decision of what the corrected `Installation`
/// should look like in each case.
void main() {
  Installation pendingInstallation() => const Installation(
        id: 'install-1',
        packageId: 'com.example.demo',
        version: '1.0.0',
        status: 'completed', // Exchange's own (simulated) success -- must not be trusted as-is.
        repositoryPackageId: 'stub-com.example.demo@1.0.0',
        errorMessage: null,
        requestedAt: '2026-01-01T00:00:00Z',
        completedAt: '2026-01-01T00:00:01Z',
      );

  Future<DownloadedArtifact> Function(String packageId, {String? version}) fakeDownload(
    List<int> bytes,
    String sha256Hex,
  ) =>
      (String packageId, {String? version}) async => DownloadedArtifact(bytes: bytes, sha256: sha256Hex);

  const validBytes = [1, 2, 3, 4, 5];
  // The real SHA-256 of `validBytes`, computed once and pinned here so
  // this test does not depend on `package:crypto` producing the same
  // value it did when this fixture was written.
  const validSha256 = '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0';

  test('reports failure, not fabricated success, when no Foundation repository is open', () async {
    final corrected = await applyFoundationInstall(
      installation: pendingInstallation(),
      packageId: 'com.example.demo',
      version: null,
      downloadArtifact: fakeDownload(validBytes, validSha256),
      installer: null, // FoundationRuntimeNotifier.bridge == null
    );

    expect(corrected.status, 'failed');
    expect(corrected.errorMessage, contains('No OEP Repository is currently open'));
    // The Exchange stub's own fabricated identity must not survive uncorrected.
    expect(corrected.repositoryPackageId, 'stub-com.example.demo@1.0.0');
  });

  test('reports success with Foundation\'s own identity when the install genuinely succeeds', () async {
    final corrected = await applyFoundationInstall(
      installation: pendingInstallation(),
      packageId: 'com.example.demo',
      version: null,
      downloadArtifact: fakeDownload(validBytes, validSha256),
      installer: (path) => const PackageInstallResult(
        packageId: 'com.example.demo',
        version: '1.0.0',
        objectsCreated: 2,
        relationshipsCreated: 1,
      ),
    );

    expect(corrected.status, 'completed');
    expect(corrected.errorMessage, isNull);
    expect(corrected.repositoryPackageId, 'com.example.demo@1.0.0');
  });

  test('reports failure when the checksum does not match, before any installer call', () async {
    var installerCalled = false;
    final corrected = await applyFoundationInstall(
      installation: pendingInstallation(),
      packageId: 'com.example.demo',
      version: null,
      downloadArtifact: fakeDownload(validBytes, '0' * 64),
      installer: (path) {
        installerCalled = true;
        throw StateError('must not be called');
      },
    );

    expect(installerCalled, isFalse);
    expect(corrected.status, 'failed');
    expect(corrected.errorMessage, contains('does not match the checksum'));
  });

  test('reports failure with Foundation\'s own message for an already-installed package', () async {
    final corrected = await applyFoundationInstall(
      installation: pendingInstallation(),
      packageId: 'com.example.demo',
      version: null,
      downloadArtifact: fakeDownload(validBytes, validSha256),
      installer: (path) => throw FoundationBridgeException.fromResult(
        code: FoundationErrorCode.operationFailed,
        category: FoundationErrorCategory.io,
        technicalDetail: "package 'com.example.demo' is already installed",
      ),
    );

    expect(corrected.status, 'failed');
    expect(corrected.errorMessage, contains('already installed'));
  });

  test('reports failure with Foundation\'s own message for a rejected trust state', () async {
    final corrected = await applyFoundationInstall(
      installation: pendingInstallation(),
      packageId: 'com.example.demo',
      version: null,
      downloadArtifact: fakeDownload(validBytes, validSha256),
      installer: (path) => throw FoundationBridgeException.fromResult(
        code: FoundationErrorCode.operationFailed,
        category: FoundationErrorCategory.io,
        technicalDetail: 'package trust verification failed (Tampered): content hash mismatch',
      ),
    );

    expect(corrected.status, 'failed');
    expect(corrected.errorMessage, contains('Tampered'));
  });
}
