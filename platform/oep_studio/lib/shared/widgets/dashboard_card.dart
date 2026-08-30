import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import 'studio_section_panel.dart';

/// A single card in the Dashboard grid (SDD-007), per
/// 001-OEP-STUDIO-DASHBOARD-v1.0.png.
///
/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — now a thin wrapper over the shared
/// [StudioSectionPanel] (same header/body chrome every Studio page uses)
/// rather than its own hand-rolled header `Row`; the public API is
/// unchanged so existing call sites need no edits.
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
    return StudioSectionPanel(
      title: title,
      icon: icon,
      iconColor: iconColor,
      iconBackground: iconBackground,
      trailing: trailing,
      child: child,
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
