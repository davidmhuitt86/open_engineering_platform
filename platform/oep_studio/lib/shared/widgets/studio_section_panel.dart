import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import 'studio_panel_header.dart';

/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — a [StudioPanelHeader] over a
/// `surfaceRaised` body, bordered as one unit. The generic form of what
/// `DashboardCard` already did by hand; `DashboardCard` now delegates
/// here so its own call sites are unaffected.
class StudioSectionPanel extends StatelessWidget {
  const StudioSectionPanel({
    required this.title,
    required this.child,
    this.icon,
    this.iconColor = StudioColors.textSecondary,
    this.iconBackground,
    this.trailing,
    this.bodyPadding = const EdgeInsets.all(16),
    super.key,
  });

  final String title;
  final IconData? icon;
  final Color iconColor;
  final Color? iconBackground;
  final Widget? trailing;
  final EdgeInsetsGeometry bodyPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StudioColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StudioColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          StudioPanelHeader(
            title: title,
            icon: icon,
            iconColor: iconColor,
            iconBackground: iconBackground,
            trailing: trailing,
          ),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}
