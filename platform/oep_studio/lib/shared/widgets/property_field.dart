import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';

/// A single label/value row in a Property Inspector panel (SDD-004),
/// shared by every selection mode the Property Inspector supports
/// (Object, Relationship, and — since Work Package 007 — Proposal and
/// Session).
class PropertyField extends StatelessWidget {
  const PropertyField({required this.label, required this.value, this.monospace = false, super.key});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: monospace
                ? StudioTheme.monoTextStyle
                : const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
