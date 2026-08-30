import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_typography.dart';
import 'studio_type_swatch.dart';

/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — the `.fpr`/`.fpk`/`.fpv` idiom from
/// Diagram Studio's Property Inspector: one horizontal row, a
/// fixed-min-width uppercase micro-label, then a bold value, with an
/// optional leading [StudioTypeSwatch].
///
/// Deliberately separate from `PropertyField` (`lib/shared/widgets/
/// property_field.dart`), which stacks label over value for the
/// Knowledge/Object/Relationship inspector modes — that shape stays
/// unchanged (out of this pass's scope); this widget is for pages that
/// want the legacy inspector's horizontal row instead.
class StudioDetailRow extends StatelessWidget {
  const StudioDetailRow({
    required this.label,
    required this.value,
    this.swatchColor,
    this.monospace = false,
    this.labelWidth = 76,
    super.key,
  });

  final String label;
  final String value;
  final Color? swatchColor;
  final bool monospace;

  /// Fixed label-column width — the default (76) fits short labels
  /// ("Name", "Wire", "Runtime"); a caller with longer labels ("Objects
  /// / Relationships") can widen it rather than let the label wrap.
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final swatch = swatchColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(width: labelWidth, child: Text(label, style: StudioTypography.fieldLabel)),
          const SizedBox(width: 6),
          if (swatch != null) ...[
            StudioTypeSwatch(color: swatch, size: 10),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              value,
              style: monospace
                  ? const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: StudioColors.textPrimary, fontWeight: FontWeight.w600)
                  : StudioTypography.fieldValue,
            ),
          ),
        ],
      ),
    );
  }
}
