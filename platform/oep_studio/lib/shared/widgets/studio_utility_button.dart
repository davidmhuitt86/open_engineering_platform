import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — the `.fp-act`/`.fp-kb` idiom from
/// Diagram Studio's Property Inspector: a small bordered chip button
/// for filters/mode-toggles/secondary actions (not primary actions,
/// which stay `ElevatedButton`). `selected: true` inverts to a solid
/// accent background, matching the legacy panel's `.active` state.
class StudioUtilityButton extends StatefulWidget {
  const StudioUtilityButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<StudioUtilityButton> createState() => _StudioUtilityButtonState();
}

class _StudioUtilityButtonState extends State<StudioUtilityButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? StudioColors.selection
        : (_hovered ? StudioColors.surfaceHover : StudioColors.surfaceSunken);
    final fg = widget.selected
        ? Colors.white
        : (_hovered ? StudioColors.textPrimary : StudioColors.textSecondary);
    final border = widget.selected ? StudioColors.selection : StudioColors.border;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: widget.onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: border)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
