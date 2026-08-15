import 'auth_result.dart';

/// The authentication abstraction (OEP First Startup UI, Phase 0A).
///
/// **This exists so a future real OEP identity service can replace
/// today's local-only implementation without touching the Login/Create
/// Account UI at all** — the UI depends only on this interface, never
/// on [LocalAuthenticationProvider] directly (mirroring how
/// `CredentialStore` already isolates every caller from the concrete
/// Windows Credential Manager backend behind it). A future
/// `OepIdentityAuthenticationProvider` (real server-backed sign-in,
/// password recovery, account creation) would implement this same
/// interface.
abstract class AuthenticationService {
  /// Whether at least one local account has been created on this
  /// machine — determines whether the Login screen offers "Create
  /// Account" as the only path forward, or a real account to sign into.
  Future<bool> hasAnyAccount();

  /// The username remembered from a previous "Remember Me" sign-in, if
  /// any. Never a password — only the identity to pre-fill/skip Login
  /// with.
  Future<String?> rememberedUsername();

  Future<AuthResult> signIn({
    required String usernameOrEmail,
    required String password,
    bool rememberMe = false,
  });

  Future<AuthResult> createAccount({
    required String username,
    required String password,
  });

  /// Clears the remembered session (Log Out).
  Future<void> signOut();

  /// Password recovery. The local-only implementation has no real
  /// mechanism to deliver this (no email service, no account-recovery
  /// backend) and must say so honestly rather than pretend an email was
  /// sent — see [LocalAuthenticationProvider.requestPasswordReset].
  Future<AuthResult> requestPasswordReset(String usernameOrEmail);
}
