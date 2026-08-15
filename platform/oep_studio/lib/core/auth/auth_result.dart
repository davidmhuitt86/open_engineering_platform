/// The outcome of a sign-in, account-creation, or sign-out attempt
/// against an [AuthenticationService] (OEP First Startup UI, Phase 0A).
class AuthResult {
  const AuthResult._({required this.success, this.username, this.errorMessage});

  factory AuthResult.success(String username) => AuthResult._(success: true, username: username);

  factory AuthResult.failure(String message) => AuthResult._(success: false, errorMessage: message);

  final bool success;
  final String? username;
  final String? errorMessage;
}
