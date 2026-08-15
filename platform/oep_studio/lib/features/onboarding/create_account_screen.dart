import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/authentication_provider.dart';
import '../../core/theme/studio_colors.dart';

/// First-run account creation (OEP First Startup UI, Phase 0A).
///
/// Creates a real local account via [AuthenticationService] (salted
/// SHA-256 hash in Windows Credential Manager, never a plaintext
/// password) -- no cloud account, no server call.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({required this.onCreated, required this.onCancel, super.key});

  final void Function(String username) onCreated;
  final VoidCallback onCancel;

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final result = await ref.read(authenticationServiceProvider).createAccount(
          username: _usernameController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.success) {
      widget.onCreated(result.username!);
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
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
                'Create Local Account',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'No account exists on this machine yet -- create a local development account to continue. '
                'This does not create a cloud/OEP account.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 24),
              const Text('Username', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('create-username-field'),
                controller: _usernameController,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 16),
              const Text('Password', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('create-password-field'),
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(isDense: true, helperText: 'At least 8 characters.'),
              ),
              const SizedBox(height: 16),
              const Text('Confirm Password', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                key: const Key('create-confirm-password-field'),
                controller: _confirmController,
                obscureText: true,
                onSubmitted: (_) => _create(),
                decoration: const InputDecoration(isDense: true),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: widget.onCancel, child: const Text('Back to Sign In')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _create,
                      child: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create Account'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
