import 'package:flutter/material.dart';

import '../../core/context/engineering_interaction_context.dart';
import '../../core/theme/studio_colors.dart';

/// (OEP Diagram Studio -- Phase 5, Part 4.) A compact, three-way mode
/// selector for the active diagram tab. Uses the existing OEP palette
/// (`StudioColors`) only -- no new colors.
///
/// **Design divergence documented (Part 23)**: the reference render
/// (`DS_Three_Mode_Workspace.png`) places mode switching as a vertical
/// icon rail down the left edge, each icon opening a full labeled
/// panel. This implementation instead uses a compact horizontal
/// segmented control docked above the canvas. No `oep_design_system`
/// specification exists for either layout (grepped -- confirmed
/// absent), and a full rail-with-expanding-panel treatment is a larger
/// visual redesign than this incremental phase's "establish the
/// workspace structure, don't build complete feature sets" scope
/// (Part 24/26) justifies. The three modes, their real content, and
/// mode-as-context are implemented per spec; only the chrome shape
/// differs.
class DiagramModeSwitcher extends StatelessWidget {
  const DiagramModeSwitcher({super.key, required this.mode, required this.onModeChanged});

  final DiagramStudioMode mode;
  final void Function(DiagramStudioMode mode) onModeChanged;

  static const _entries = [
    (mode: DiagramStudioMode.view, icon: Icons.visibility_outlined, label: 'View', subtitle: 'Inspect'),
    (mode: DiagramStudioMode.edit, icon: Icons.edit_outlined, label: 'Edit', subtitle: 'Build'),
    (mode: DiagramStudioMode.simulate, icon: Icons.play_circle_outline, label: 'Simulate', subtitle: 'Diagnose'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StudioColors.surfaceSunken,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StudioColors.border),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final entry in _entries) _ModeButton(entry: entry, selected: entry.mode == mode, onTap: () => onModeChanged(entry.mode))],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.entry, required this.selected, required this.onTap});

  final ({DiagramStudioMode mode, IconData icon, String label, String subtitle}) entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('diagram-mode-${entry.mode.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? StudioColors.selection.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry.icon, size: 15, color: selected ? StudioColors.selection : StudioColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              entry.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? StudioColors.textPrimary : StudioColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
