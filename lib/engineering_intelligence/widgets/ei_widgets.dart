import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// Shared building blocks for the Engineering Intelligence Studio pages
/// (WP-EKE-008). Kept intentionally small and dependency-free — every
/// piece is plain `Container`/`Text`/`Row` composition using
/// [StudioColors], matching the styling convention already established
/// by `ObjectsPage`/`ValidationPage` rather than introducing a new
/// design system.
class EiSectionCard extends StatelessWidget {
  const EiSectionCard({super.key, required this.title, this.icon, this.trailing, required this.child});

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: StudioColors.surfaceRaised,
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: StudioColors.selection),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class EiKeyValueRow extends StatelessWidget {
  const EiKeyValueRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor ?? StudioColors.textPrimary, fontSize: 12, fontFamily: 'Consolas'),
            ),
          ),
        ],
      ),
    );
  }
}

class EiEmptyState extends StatelessWidget {
  const EiEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: StudioColors.textDisabled),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class EiErrorBanner extends StatelessWidget {
  const EiErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.error.withValues(alpha: 0.08),
        border: Border.all(color: StudioColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: StudioColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: StudioColors.error, fontSize: 12))),
        ],
      ),
    );
  }
}

Color severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return StudioColors.error;
    case 'error':
      return StudioColors.error;
    case 'warning':
      return StudioColors.warning;
    default:
      return StudioColors.info;
  }
}

class EiChip extends StatelessWidget {
  const EiChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? StudioColors.selection;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
