import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/security/credential_models.dart';
import 'package:oep_studio/core/security/windows_credential_store.dart';

/// Exercises the real Windows Credential Manager via `dart:ffi` — this
/// is plain `advapi32.dll` access, not a Flutter plugin/platform
/// channel, so (unlike `flutter_secure_storage`) it runs for real in a
/// bare `flutter test` process. Uses a disposable, invented test
/// provider id/secret (never a real credential) and deletes everything
/// it writes in `tearDown`, so this suite never leaves anything behind
/// in the real Windows Credential Manager, pass or fail.
void main() {
  const testProviderId = 'oep_studio_test_provider_wp018';
  late WindowsCredentialStore store;

  setUp(() {
    store = WindowsCredentialStore();
  });

  tearDown(() async {
    await store.deleteCredential(testProviderId);
  });

  group('WindowsCredentialStore', () {
    test('readCredential returns null when nothing has been saved', () async {
      final result = await store.readCredential(testProviderId);
      expect(result, isNull);
    });

    test('saveCredential then readCredential round-trips the exact secret', () async {
      await store.saveCredential(providerId: testProviderId, secret: 'test-secret-value-12345');
      final result = await store.readCredential(testProviderId);
      expect(result, 'test-secret-value-12345');
    });

    test('saveCredential overwrites a previous value for the same providerId', () async {
      await store.saveCredential(providerId: testProviderId, secret: 'first-value');
      await store.saveCredential(providerId: testProviderId, secret: 'second-value');
      final result = await store.readCredential(testProviderId);
      expect(result, 'second-value');
    });

    test('deleteCredential removes a stored secret', () async {
      await store.saveCredential(providerId: testProviderId, secret: 'to-be-deleted');
      await store.deleteCredential(testProviderId);
      final result = await store.readCredential(testProviderId);
      expect(result, isNull);
    });

    test('deleteCredential on a non-existent credential is a no-op, not a failure', () async {
      await expectLater(store.deleteCredential('no_such_provider_ever'), completes);
    });

    test('a saved credential appears in listCredentials, scoped to Studio\'s own prefix', () async {
      await store.saveCredential(providerId: testProviderId, secret: 'listed-value');
      final summaries = await store.listCredentials();
      expect(summaries.map((s) => s.providerId), contains(testProviderId));
      // Every returned summary carries only a providerId — never a secret.
      expect(summaries, everyElement(isA<CredentialSummary>()));
    });

    test('round-trips a secret containing non-ASCII characters', () async {
      const secret = 'sk-ant-tëst-🔑-value';
      await store.saveCredential(providerId: testProviderId, secret: secret);
      final result = await store.readCredential(testProviderId);
      expect(result, secret);
    });
  });
}
