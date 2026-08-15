import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// A single card in the Dashboard grid (SDD-007), per
/// 001-OEP-STUDIO-DASHBOARD-v1.0.png.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor = StudioColors.textSecondary,
    this.iconBackground,
    this.trailing,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color? iconBackground;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBackground ?? StudioColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: StudioColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// "View All" text link used in the header of several Dashboard cards.
class ViewAllLink extends StatelessWidget {
  const ViewAllLink({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'View All',
      style: TextStyle(
        color: StudioColors.selection,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
