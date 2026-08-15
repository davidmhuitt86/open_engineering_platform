import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/authentication_provider.dart';
import '../../core/theme/studio_colors.dart';
import '../../settings/services/settings_service.dart';

/// The Splash screen (OEP First Startup UI, Phase 0A; approved render
/// `01_First_Launch_Onboarding.png`, panel 1).
///
/// Runs real initialization work -- `SettingsService.load()` (the
/// actual User Configuration file read) and
/// `AuthenticationService.hasAnyAccount()` (a real Windows Credential
/// Manager enumeration) -- rather than a fabricated progress
/// percentage. Neither step reports granular sub-progress today, so
/// this shows a plain indeterminate indicator while they run, not an
/// invented number.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({required this.onInitialized, super.key});

  final VoidCallback onInitialized;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final stopwatch = Stopwatch()..start();

    // Real initialization work, not a simulated delay.
    await SettingsService.load();
    await ref.read(authenticationServiceProvider).hasAnyAccount();

    // A brief minimum display time so the splash doesn't flash by
    // unreadably fast on a machine where the above completes in a few
    // milliseconds -- the wait itself is real UI settling time, not a
    // fabricated progress animation.
    const minimumDisplay = Duration(milliseconds: 900);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minimumDisplay) {
      await Future.delayed(minimumDisplay - elapsed);
    }

    if (mounted) widget.onInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StudioColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [StudioColors.selection.withValues(alpha: 0.25), Colors.transparent],
                ),
              ),
              child: const Icon(Icons.hexagon_outlined, size: 96, color: StudioColors.selection),
            ),
            const SizedBox(height: 32),
            const Text(
              'OEP',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            const Text(
              'OPEN ENGINEERING PLATFORM',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 13, letterSpacing: 2),
            ),
            const SizedBox(height: 36),
            const Text(
              'ENGINEERING KNOWLEDGE ENGINE (EKE)',
              style: TextStyle(color: StudioColors.textDisabled, fontSize: 11, letterSpacing: 1.5),
            ),
            const SizedBox(height: 4),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: StudioColors.textDisabled, fontSize: 11),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: StudioColors.borderSubtle,
                color: StudioColors.selection,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Initializing Engine…',
              style: TextStyle(color: StudioColors.textDisabled, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
