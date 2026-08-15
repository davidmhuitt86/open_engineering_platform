import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../security/credential_service.dart';
import '../security/credential_store.dart';
import 'auth_result.dart';
import 'auth_session_storage.dart';
import 'authentication_service.dart';

/// The local-development [AuthenticationService] implementation (OEP
/// First Startup UI, Phase 0A). No cloud account, no OEP identity
/// server, no network call anywhere in this file -- exactly the "local
/// development authentication mechanism" the phase brief calls for,
/// isolated behind [AuthenticationService] so a future real identity
/// service is a drop-in replacement.
///
/// Passwords are never stored. Only a salted SHA-256 hash is persisted,
/// through the same [CredentialStore] every other secret in this app
/// already goes through (Windows Credential Manager on this platform)
/// -- not a new, weaker, Studio-specific secret store.
class LocalAuthenticationProvider implements AuthenticationService {
  LocalAuthenticationProvider({CredentialStore? store}) : _store = store ?? CredentialService.instance;

  static const _accountPrefix = 'local_auth.account.';

  final CredentialStore _store;

  String _keyFor(String username) => '$_accountPrefix${username.trim().toLowerCase()}';

  Future<bool> _accountExists(String username) async {
    final credentials = await _store.listCredentials();
    return credentials.any((c) => c.providerId == _keyFor(username));
  }

  @override
  Future<bool> hasAnyAccount() async {
    final credentials = await _store.listCredentials();
    return credentials.any((c) => c.providerId.startsWith(_accountPrefix));
  }

  @override
  Future<String?> rememberedUsername() => AuthSessionStorage.readRememberedUsername();

  @override
  Future<AuthResult> signIn({
    required String usernameOrEmail,
    required String password,
    bool rememberMe = false,
  }) async {
    final username = usernameOrEmail.trim();
    if (username.isEmpty) return AuthResult.failure('Enter your username or email.');
    if (password.isEmpty) return AuthResult.failure('Enter your password.');

    final stored = await _store.readCredential(_keyFor(username));
    if (stored == null) {
      return AuthResult.failure('No account found for "$username" on this machine.');
    }

    final separator = stored.indexOf(':');
    if (separator < 0) {
      return AuthResult.failure('The stored credential for "$username" is corrupted.');
    }
    final salt = stored.substring(0, separator);
    final expectedHash = stored.substring(separator + 1);
    if (_hash(password, salt) != expectedHash) {
      return AuthResult.failure('Incorrect password.');
    }

    await AuthSessionStorage.setRememberedUsername(rememberMe ? username : null);
    return AuthResult.success(username);
  }

  @override
  Future<AuthResult> createAccount({required String username, required String password}) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) return AuthResult.failure('Choose a username.');
    if (trimmedUsername.contains(RegExp(r'\s'))) return AuthResult.failure('Usernames cannot contain spaces.');
    if (password.length < 8) return AuthResult.failure('Password must be at least 8 characters.');
    if (await _accountExists(trimmedUsername)) {
      return AuthResult.failure('An account named "$trimmedUsername" already exists on this machine.');
    }

    final salt = _generateSalt();
    await _store.saveCredential(providerId: _keyFor(trimmedUsername), secret: '$salt:${_hash(password, salt)}');
    return AuthResult.success(trimmedUsername);
  }

  @override
  Future<void> signOut() => AuthSessionStorage.setRememberedUsername(null);

  @override
  Future<AuthResult> requestPasswordReset(String usernameOrEmail) async {
    // No email service, no account-recovery backend exists anywhere in
    // this codebase -- disclosed honestly rather than pretending an
    // email was sent (this phase's own explicit instruction).
    return AuthResult.failure(
      'Password recovery is not available until OEP account services are connected. '
      'This local development build has no way to deliver a reset link.',
    );
  }

  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String password, String salt) {
    // A poor-man's iterated hash (10,000 rounds of SHA-256 over
    // salt+password+previous-round) using only the `crypto` package
    // already in `pubspec.yaml` -- no new dependency for a real PBKDF2/
    // bcrypt/argon2 implementation, which would be the right call for
    // an actual production identity service but is more than this
    // local-development-only mechanism needs.
    List<int> digest = utf8.encode('$salt:$password');
    for (var round = 0; round < 10000; round++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }
}
