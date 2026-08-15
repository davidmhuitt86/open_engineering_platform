import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/authentication_provider.dart';
import '../../core/theme/studio_colors.dart';

/// The Login screen (OEP First Startup UI, Phase 0A; approved render
/// `01_First_Launch_Onboarding.png`, panel 2).
///
/// Real sign-in against [AuthenticationService] -- today
/// `LocalAuthenticationProvider` (Windows Credential Manager). SSO and
/// API Key sign-in are shown in the render but have no backing
/// capability anywhere in this codebase, so they are present-but-
/// disabled with a disclosed reason rather than omitted or faked.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    required this.onSignedIn,
    required this.onCreateAccount,
    this.initialUsername,
    super.key,
  });

  final void Function(String username) onSignedIn;
  final VoidCallback onCreateAccount;
  final String? initialUsername;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _usernameController = TextEditingController(text: widget.initialUsername ?? '');
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final result = await ref.read(authenticationServiceProvider).signIn(
          usernameOrEmail: _usernameController.text,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.success) {
      widget.onSignedIn(result.username!);
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _forgotPassword() async {
    final result = await ref.read(authenticationServiceProvider).requestPasswordReset(_usernameController.text);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password'),
        content: Text(result.errorMessage ?? 'Password recovery is not available yet.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: StudioColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: StudioColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome Back',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign in to continue to OEP',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              const Text('Username or Email', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('login-username-field'),
                controller: _usernameController,
                decoration: const InputDecoration(isDense: true, hintText: 'you@example.com'),
              ),
              const SizedBox(height: 16),
              const Text('Password', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('login-password-field'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                onSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (value) => setState(() => _rememberMe = value ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Remember me', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    onPressed: _forgotPassword,
                    child: const Text('Forgot Password?', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _signIn,
                  child: _submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider(color: StudioColors.borderSubtle)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('or continue with', style: TextStyle(color: StudioColors.textDisabled, fontSize: 11)),
                  ),
                  Expanded(child: Divider(color: StudioColors.borderSubtle)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: const Text('SSO'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: 'No OEP identity service is connected yet -- SSO/API Key sign-in are not available.',
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.key_outlined, size: 16),
                        label: const Text('API Key'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text('New to OEP? ', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5)),
                    GestureDetector(
                      onTap: widget.onCreateAccount,
                      child: const Text(
                        'Create Account',
                        style: TextStyle(color: StudioColors.selection, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
