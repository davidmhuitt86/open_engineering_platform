import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/auth/auth_session_storage.dart';
import 'package:oep_studio/core/auth/local_authentication_provider.dart';
import 'package:oep_studio/core/security/credential_models.dart';
import 'package:oep_studio/core/security/credential_store.dart';

/// An in-memory `CredentialStore`, so these tests never touch the real
/// Windows Credential Manager (the real `WindowsCredentialStore` would
/// otherwise leave test-only credentials behind on the machine running
/// `flutter test`).
class _FakeCredentialStore implements CredentialStore {
  final Map<String, String> _secrets = {};

  @override
  Future<void> saveCredential({required String providerId, required String secret}) async {
    _secrets[providerId] = secret;
  }

  @override
  Future<String?> readCredential(String providerId) async => _secrets[providerId];

  @override
  Future<void> deleteCredential(String providerId) async => _secrets.remove(providerId);

  @override
  Future<List<CredentialSummary>> listCredentials() async =>
      [for (final id in _secrets.keys) CredentialSummary(providerId: id)];
}

void main() {
  late _FakeCredentialStore store;
  late LocalAuthenticationProvider auth;

  setUp(() {
    store = _FakeCredentialStore();
    auth = LocalAuthenticationProvider(store: store);
  });

  // `AuthSessionStorage` writes a real (non-secret) file under
  // `%APPDATA%/oep_studio/auth_session.json` -- clean it up after each
  // "Remember Me" test so these tests never leave state behind for a
  // later real launch to read, mirroring this suite's existing
  // discipline for other real-file-backed state.
  tearDown(() async {
    await AuthSessionStorage.setRememberedUsername(null);
  });

  test('hasAnyAccount is false before any account is created', () async {
    expect(await auth.hasAnyAccount(), isFalse);
  });

  test('createAccount succeeds and hasAnyAccount becomes true', () async {
    final result = await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    expect(result.success, isTrue);
    expect(result.username, 'jsmith');
    expect(await auth.hasAnyAccount(), isTrue);
  });

  test('createAccount rejects a password shorter than 8 characters', () async {
    final result = await auth.createAccount(username: 'jsmith', password: 'short');
    expect(result.success, isFalse);
    expect(result.errorMessage, contains('8 characters'));
  });

  test('createAccount rejects a duplicate username', () async {
    await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    final second = await auth.createAccount(username: 'jsmith', password: 'another-password');
    expect(second.success, isFalse);
    expect(second.errorMessage, contains('already exists'));
  });

  test('the stored secret is a salted hash, never the plaintext password', () async {
    await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    final stored = await store.readCredential('local_auth.account.jsmith');
    expect(stored, isNotNull);
    expect(stored, isNot(contains('correct-horse')));
    expect(stored!.split(':'), hasLength(2), reason: 'salt:hash');
  });

  test('signIn succeeds with the correct password', () async {
    await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    final result = await auth.signIn(usernameOrEmail: 'jsmith', password: 'correct-horse');
    expect(result.success, isTrue);
    expect(result.username, 'jsmith');
  });

  test('signIn fails with an incorrect password', () async {
    await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    final result = await auth.signIn(usernameOrEmail: 'jsmith', password: 'wrong-password');
    expect(result.success, isFalse);
    expect(result.errorMessage, 'Incorrect password.');
  });

  test('signIn fails for a username with no account', () async {
    final result = await auth.signIn(usernameOrEmail: 'nobody', password: 'anything');
    expect(result.success, isFalse);
    expect(result.errorMessage, contains('No account found'));
  });

  test('signIn with rememberMe persists a remembered username', () async {
    await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    await auth.signIn(usernameOrEmail: 'jsmith', password: 'correct-horse', rememberMe: true);
    expect(await auth.rememberedUsername(), 'jsmith');
  });

  test('signIn without rememberMe does not persist a remembered username', () async {
    await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    await auth.signIn(usernameOrEmail: 'jsmith', password: 'correct-horse', rememberMe: false);
    expect(await auth.rememberedUsername(), isNull);
  });

  test('signOut clears any remembered username', () async {
    await auth.createAccount(username: 'jsmith', password: 'correct-horse');
    await auth.signIn(usernameOrEmail: 'jsmith', password: 'correct-horse', rememberMe: true);
    await auth.signOut();
    expect(await auth.rememberedUsername(), isNull);
  });

  test('requestPasswordReset is honestly unavailable, never a fabricated success', () async {
    final result = await auth.requestPasswordReset('jsmith');
    expect(result.success, isFalse);
    expect(result.errorMessage, contains('not available'));
  });
}
