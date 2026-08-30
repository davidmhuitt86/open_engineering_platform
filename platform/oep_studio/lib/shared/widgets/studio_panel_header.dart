import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_typography.dart';

/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — the one header strip Studio pages
/// and panels share: an optional leading icon, a title, and an optional
/// trailing action, on the darker `surface` tier with a hairline bottom
/// border — the same "header sits one shade darker than its body,
/// separated by a 1px divider" chrome Diagram Studio's Property
/// Inspector uses for every one of its panels.
///
/// Used both as a full page's own top header (replacing each page's
/// previously hand-rolled `Row`+icon+`Text` header) and as
/// [StudioSectionPanel]'s header strip.
class StudioPanelHeader extends StatelessWidget {
  const StudioPanelHeader({
    required this.title,
    this.icon,
    this.iconColor = StudioColors.textSecondary,
    this.iconBackground,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    super.key,
  });

  final String title;
  final IconData? icon;
  final Color iconColor;

  /// Optional tinted rounded box behind [icon] (e.g. a Dashboard card's
  /// accent color at low alpha) — `null` renders a bare icon with no
  /// box, the plain treatment every non-Dashboard header uses.
  final Color? iconBackground;

  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final iconBg = iconBackground;
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(bottom: BorderSide(color: StudioColors.borderSubtle)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            if (iconBg != null)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor),
              )
            else
              Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(title, style: StudioTypography.pageTitle)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
