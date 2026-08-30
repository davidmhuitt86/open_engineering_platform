import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — the `.fpsw`/category-dot idiom from
/// Diagram Studio's Property Inspector: a small circular color
/// indicator for an object's "kind" (object category, severity, ...),
/// with an optional label beside it.
class StudioTypeSwatch extends StatelessWidget {
  const StudioTypeSwatch({required this.color, this.label, this.size = 10, super.key});

  final Color color;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: StudioColors.borderStrong),
      ),
    );
    if (label == null) return dot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(label!, style: const TextStyle(fontSize: 12.5, color: StudioColors.textPrimary)),
      ],
    );
  }
}
