import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// The Welcome screen (OEP First Startup UI, Phase 0A; approved render
/// `01_First_Launch_Onboarding.png`, panel 3).
///
/// "Take a Tour" has no backing tour system anywhere in this codebase
/// (confirmed by inspection) -- shown as an honest unavailable state
/// rather than a fabricated interactive tour.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onGetStarted, super.key});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 460,
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
                'Welcome to OEP!',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Open Engineering Platform',
                style: TextStyle(color: StudioColors.selection, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'The Engineering Knowledge Engine (EKE) now stands ready to power your work.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              const _WelcomeFeatureRow(
                icon: Icons.hub_outlined,
                title: 'Open Architecture',
                subtitle: 'Built on open standards and open source.',
              ),
              const _WelcomeFeatureRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Engineering Knowledge',
                subtitle: 'Create, verify, and share engineering assets.',
              ),
              const _WelcomeFeatureRow(
                icon: Icons.play_circle_outline,
                title: 'Simulation & Verification',
                subtitle: 'Virtual testing before real-world deployment.',
              ),
              const _WelcomeFeatureRow(
                icon: Icons.storefront_outlined,
                title: 'Engineering Exchange',
                subtitle: 'Discover, acquire, and publish engineering assets.',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'No guided tour system exists yet -- this will connect to a real tour in a future phase.',
                      child: OutlinedButton(onPressed: null, child: const Text('Take a Tour')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('welcome-get-started-button'),
                      onPressed: onGetStarted,
                      child: const Text('Get Started'),
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

class _WelcomeFeatureRow extends StatelessWidget {
  const _WelcomeFeatureRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: StudioColors.selection),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
