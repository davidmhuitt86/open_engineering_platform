import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/foundation/foundation_bridge_exception.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/exchange/services/exchange_install_bridge.dart';

/// Exercises `ExchangeInstallBridge`'s own checksum-verification and
/// Foundation-error-classification logic against a fake [PackageInstaller]
/// -- WP-EXC-013's own architecture makes this possible without a real
/// Foundation runtime; the fact that a real one exists and works is
/// proven separately (`docs/tasks/WP-EXC-013.md` §11's Foundation
/// integration test, and Foundation's own, unmodified `tests/runtime/`
/// suite). This file proves the bridge invokes whatever installer it is
/// given correctly, and classifies whatever that installer reports
/// correctly -- not that Foundation itself works.
void main() {
  final archiveBytes = Uint8List.fromList(List.generate(64, (i) => i));
  final correctSha256 = sha256.convert(archiveBytes).toString();

  group('ExchangeInstallBridge checksum verification', () {
    test('rejects a mismatched checksum before ever calling the installer', () async {
      var installerCalled = false;
      final bridge = ExchangeInstallBridge(installer: (path) {
        installerCalled = true;
        throw StateError('should never be called');
      });

      final outcome = await bridge.install(
        archiveBytes: archiveBytes,
        expectedSha256Hex: '0000000000000000000000000000000000000000000000000000000000000000',
        packageId: 'com.example.demo',
      );

      expect(installerCalled, isFalse);
      expect(outcome.success, isFalse);
      expect(outcome.failureCategory, InstallFailureCategory.checksumMismatch);
      expect(outcome.diagnosticMessage, contains('does not match the checksum'));
    });

    test('is case-insensitive when comparing the checksum', () async {
      final bridge = ExchangeInstallBridge(
        installer: (path) =>
            const PackageInstallResult(packageId: 'p', version: '1.0.0', objectsCreated: 0, relationshipsCreated: 0),
      );

      final outcome = await bridge.install(
        archiveBytes: archiveBytes,
        expectedSha256Hex: correctSha256.toUpperCase(),
        packageId: 'com.example.demo',
      );

      expect(outcome.success, isTrue);
    });
  });

  group('ExchangeInstallBridge installer invocation', () {
    test('writes the archive to a temp file and passes its path to the installer', () async {
      String? capturedPath;
      final bridge = ExchangeInstallBridge(installer: (path) {
        capturedPath = path;
        expect(File(path).readAsBytesSync(), archiveBytes);
        return const PackageInstallResult(
          packageId: 'com.example.demo',
          version: '1.0.0',
          objectsCreated: 2,
          relationshipsCreated: 1,
        );
      });

      final outcome = await bridge.install(
        archiveBytes: archiveBytes,
        expectedSha256Hex: correctSha256,
        packageId: 'com.example.demo',
      );

      expect(capturedPath, isNotNull);
      expect(outcome.success, isTrue);
      expect(outcome.result!.packageId, 'com.example.demo');
      expect(outcome.result!.objectsCreated, 2);
      expect(outcome.result!.relationshipsCreated, 1);
      // The temp archive is a working file, not a persisted artifact --
      // it must not survive the call.
      expect(File(capturedPath!).existsSync(), isFalse);
    });

    test('removes the temp archive even when the installer throws', () async {
      String? capturedPath;
      final bridge = ExchangeInstallBridge(installer: (path) {
        capturedPath = path;
        throw FoundationBridgeException.fromResult(
          code: FoundationErrorCode.operationFailed,
          category: FoundationErrorCategory.io,
          technicalDetail: 'could not extract package: not a valid ZIP archive',
        );
      });

      await bridge.install(archiveBytes: archiveBytes, expectedSha256Hex: correctSha256, packageId: 'com.example.demo');

      expect(File(capturedPath!).existsSync(), isFalse);
    });
  });

  group('ExchangeInstallBridge Foundation error classification (WP-EXC-013 §8/§9)', () {
    Future<InstallOutcome> installWithDetail(String technicalDetail) {
      final bridge = ExchangeInstallBridge(
        installer: (path) => throw FoundationBridgeException.fromResult(
          code: FoundationErrorCode.operationFailed,
          category: FoundationErrorCategory.io,
          technicalDetail: technicalDetail,
        ),
      );
      return bridge.install(archiveBytes: archiveBytes, expectedSha256Hex: correctSha256, packageId: 'com.example.demo');
    }

    test('"already installed" is classified as alreadyInstalled', () async {
      final outcome = await installWithDetail("package 'com.example.demo' is already installed");
      expect(outcome.failureCategory, InstallFailureCategory.alreadyInstalled);
      expect(outcome.diagnosticMessage, contains('already installed'));
    });

    test('a corrupt/unreadable archive is classified as installFailure', () async {
      final outcome = await installWithDetail('could not extract package: not a valid ZIP archive');
      expect(outcome.failureCategory, InstallFailureCategory.installFailure);
      expect(outcome.diagnosticMessage, contains('could not extract package'));
    });

    test('a rejected trust state is classified as trustFailure', () async {
      final outcome =
          await installWithDetail("package trust verification failed (InvalidSignature): signature check failed");
      expect(outcome.failureCategory, InstallFailureCategory.trustFailure);
    });

    test('an unreadable trust store is classified as trustFailure', () async {
      final outcome = await installWithDetail('could not verify package trust: trust store unreadable');
      expect(outcome.failureCategory, InstallFailureCategory.trustFailure);
    });

    test('a signature-required policy rejection is classified as trustFailure', () async {
      final outcome = await installWithDetail(
        "this repository's trust policy requires signed packages, and 'com.example.demo' is unsigned",
      );
      expect(outcome.failureCategory, InstallFailureCategory.trustFailure);
    });

    test('an unrelated Foundation failure is classified as installFailure', () async {
      final outcome = await installWithDetail('cannot install a package: no repository is currently open');
      expect(outcome.failureCategory, InstallFailureCategory.installFailure);
    });
  });
}
