import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/foundation/foundation_bridge.dart';
import 'package:oep_studio/exchange/services/exchange_install_bridge.dart';

import 'fixtures/oep_package_fixture.dart';

/// WP-EXC-013 §11/§16's Foundation integration test: proves
/// `ExchangeInstallBridge` reaches the REAL, unmodified Foundation
/// runtime through the REAL `oep_foundation_bridge.dll` -- not a fake
/// [PackageInstaller] -- and that a package installed through it is
/// genuinely registered in the Repository Registry and produces real
/// Engineering Objects, exactly the way
/// `platform/oep_foundation/tests/runtime/package_installation_tests.cpp`'s
/// own (unmodified) suite already proves for a direct C++ call. This file
/// does not re-test Foundation's installer logic; it tests that this
/// bridge's own call into it is wired correctly.
///
/// WP-EXC-013A hardened this file's own environment handling: it used to
/// skip unconditionally whenever `FoundationBridge.create()` threw, which
/// let a genuinely stale, tracked `oep_foundation_bridge.dll` masquerade
/// as "Foundation just isn't built here" indefinitely. It now distinguishes
/// the two `dart:ffi` failure shapes that condition actually produces:
///
/// - `DynamicLibrary.open` itself failing ("Failed to load dynamic
///   library ... error code: 126" on Windows) means the DLL is genuinely
///   absent -- a real "not built in this environment" case (e.g. a CI
///   runner with no native Windows toolchain). Skips.
/// - A successful `open` followed by a symbol-lookup failure ("Failed to
///   lookup symbol ... error code: 127") means a DLL exists but is stale
///   or incompatible with the current `oep_api.h` -- exactly the failure
///   mode `tool/sync_foundation_bridge_dll.dart` exists to prevent. This
///   is a real defect in the checked-out repository state, not an
///   unavailable environment, so it now FAILS clearly instead of quietly
///   reporting green. See `docs/tasks/WP-EXC-013A.md` for the full
///   reproduction procedure (`flutter build windows --debug` then `dart
///   run tool/sync_foundation_bridge_dll.dart`).
void main() {
  FoundationBridge? bridge;
  Directory? repoRoot;
  Object? staleOrIncompatibleError;

  setUp(() {
    staleOrIncompatibleError = null;
    try {
      bridge = FoundationBridge.create();
    } catch (error) {
      final message = error.toString();
      if (message.contains('Failed to lookup symbol')) {
        // A DLL loaded, but doesn't export what current oep_api.h
        // requires -- stale/incompatible, not "environment not built".
        staleOrIncompatibleError = error;
      }
      bridge = null;
    }
  });

  tearDown(() {
    try {
      bridge?.closeRepository();
    } catch (_) {}
    bridge?.dispose();
    if (repoRoot != null && repoRoot!.existsSync()) {
      repoRoot!.deleteSync(recursive: true);
    }
  });

  /// `repository.json` per OEP-SPEC-003 / `oep::repository::RepositoryMetadata`
  /// -- the same shape `package_installation_tests.cpp`'s own
  /// `build_repository` helper writes, ported field-for-field (camelCase
  /// JSON keys per `metadata.cpp`'s `save_metadata`).
  Directory createRepository(String foundationVersion) {
    final dir = Directory.systemTemp.createTempSync('oep_exchange_bridge_it_');
    File('${dir.path}${Platform.pathSeparator}repository.json').writeAsStringSync(
      '{"repositoryId":"1b9e1b02-e845-482a-b299-1e15ffe3932b",'
      '"repositoryName":"exchange-install-bridge-it",'
      '"repositoryVersion":"1.0.0",'
      '"foundationVersion":"$foundationVersion",'
      '"templateVersion":"1.0",'
      '"createdUtc":"2026-01-01T00:00:00Z",'
      '"lastModifiedUtc":"2026-01-01T00:00:00Z"}',
    );
    return dir;
  }

  test('a valid package genuinely installs through the real Foundation runtime', () async {
    final foundation = _requireFoundation(bridge, staleOrIncompatibleError);
    if (foundation == null) return;

    repoRoot = createRepository(foundation.foundationVersion);
    foundation.openRepository(repoRoot!.path);

    final installBridge = ExchangeInstallBridge(installer: foundation.installPackage);
    final archiveBytes = buildDemoOepPackage('com.exchange.wp013.valid');
    final checksum = sha256.convert(archiveBytes).toString();

    final outcome = await installBridge.install(
      archiveBytes: archiveBytes,
      expectedSha256Hex: checksum,
      packageId: 'com.exchange.wp013.valid',
    );

    expect(outcome.success, isTrue, reason: outcome.diagnosticMessage);
    expect(outcome.result!.packageId, 'com.exchange.wp013.valid');
    expect(outcome.result!.objectsCreated, 2);
    expect(outcome.result!.relationshipsCreated, 1);

    // Repository registration: the real Repository Registry, read back
    // through the real bridge -- not asserted from the install result alone.
    expect(foundation.getObjectCount(), 2);
    expect(foundation.getRelationshipCount(), 1);
  });

  test('checksum mismatch is rejected before Foundation is ever invoked', () async {
    final foundation = _requireFoundation(bridge, staleOrIncompatibleError);
    if (foundation == null) return;

    repoRoot = createRepository(foundation.foundationVersion);
    foundation.openRepository(repoRoot!.path);

    final installBridge = ExchangeInstallBridge(installer: foundation.installPackage);
    final archiveBytes = buildDemoOepPackage('com.exchange.wp013.checksum');

    final outcome = await installBridge.install(
      archiveBytes: archiveBytes,
      expectedSha256Hex: '0' * 64,
      packageId: 'com.exchange.wp013.checksum',
    );

    expect(outcome.success, isFalse);
    expect(outcome.failureCategory, InstallFailureCategory.checksumMismatch);
    // Never reached Foundation, so nothing was created.
    expect(foundation.getObjectCount(), 0);
  });

  test('a corrupt package is rejected by the real Foundation installer', () async {
    final foundation = _requireFoundation(bridge, staleOrIncompatibleError);
    if (foundation == null) return;

    repoRoot = createRepository(foundation.foundationVersion);
    foundation.openRepository(repoRoot!.path);

    final installBridge = ExchangeInstallBridge(installer: foundation.installPackage);
    final archiveBytes = buildCorruptOepPackage();
    final checksum = sha256.convert(archiveBytes).toString();

    final outcome = await installBridge.install(
      archiveBytes: archiveBytes,
      expectedSha256Hex: checksum,
      packageId: 'com.exchange.wp013.corrupt',
    );

    expect(outcome.success, isFalse);
    expect(outcome.failureCategory, InstallFailureCategory.installFailure);
  });

  test('installing the same package twice reports the real already-installed outcome', () async {
    final foundation = _requireFoundation(bridge, staleOrIncompatibleError);
    if (foundation == null) return;

    repoRoot = createRepository(foundation.foundationVersion);
    foundation.openRepository(repoRoot!.path);

    final installBridge = ExchangeInstallBridge(installer: foundation.installPackage);
    final archiveBytes = buildDemoOepPackage('com.exchange.wp013.duplicate');
    final checksum = sha256.convert(archiveBytes).toString();

    final first = await installBridge.install(
      archiveBytes: archiveBytes,
      expectedSha256Hex: checksum,
      packageId: 'com.exchange.wp013.duplicate',
    );
    expect(first.success, isTrue, reason: first.diagnosticMessage);

    final second = await installBridge.install(
      archiveBytes: archiveBytes,
      expectedSha256Hex: checksum,
      packageId: 'com.exchange.wp013.duplicate',
    );
    expect(second.success, isFalse);
    expect(second.failureCategory, InstallFailureCategory.alreadyInstalled);
  });
}

/// WP-EXC-013A §7: distinguishes "Foundation genuinely isn't built in
/// this environment" (legitimate skip) from "a bridge DLL loaded but is
/// stale/incompatible with the current API" (a real defect -- fails the
/// test with a clear, actionable message instead of masquerading as an
/// unavailable environment). Returns the live [FoundationBridge] to use,
/// or `null` after calling `markTestSkipped` for the legitimate case.
FoundationBridge? _requireFoundation(FoundationBridge? bridge, Object? staleOrIncompatibleError) {
  if (staleOrIncompatibleError != null) {
    fail(
      'oep_foundation_bridge.dll loaded but is stale/incompatible with the current Foundation API '
      '($staleOrIncompatibleError). Run `flutter build windows --debug` then `dart run '
      'tool/sync_foundation_bridge_dll.dart` to synchronize it -- see docs/tasks/WP-EXC-013A.md.',
    );
  }
  if (bridge == null) {
    markTestSkipped(
      'oep_foundation_bridge.dll is not present in this environment (Foundation was not built here).',
    );
    return null;
  }
  return bridge;
}
