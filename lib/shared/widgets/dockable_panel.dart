import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import 'panel_dock_slot.dart';

/// A panel with a permanent slot in the window (user-requested: "they
/// just need a permanent place to sit in the window with the ability
/// to move that panel to another place as well as resize") -- fills
/// whatever space its host layout gives it (a fixed-size slot the host
/// page manages, see `diagram_studio_page.dart`'s `_slotSize`), never a
/// freely-positioned overlay. "Move" is a title-bar menu that reassigns
/// [slot] via [onSlotChanged], not a drag gesture -- picking a new slot
/// changes the actual layout structure (which `Row`/`Column` the panel
/// lives in), so there's no intermediate "floating between slots" state
/// and no risk of a panel ending up on top of canvas content the way
/// free dragging did.
class DockablePanel extends StatelessWidget {
  const DockablePanel({
    super.key,
    required this.title,
    required this.child,
    required this.slot,
    required this.onSlotChanged,
    this.icon,
    this.onClose,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final PanelDockSlot slot;
  final ValueChanged<PanelDockSlot> onSlotChanged;
  final VoidCallback? onClose;

  static const double titleBarHeight = 24;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(top: BorderSide(color: StudioColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: titleBarHeight,
            color: StudioColors.surfaceRaised,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: StudioColors.textSecondary),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: StudioColors.textSecondary,
                    ),
                  ),
                ),
                PopupMenuButton<PanelDockSlot>(
                  tooltip: 'Move panel',
                  icon: const Icon(Icons.dock_outlined, size: 13, color: StudioColors.textSecondary),
                  padding: EdgeInsets.zero,
                  onSelected: onSlotChanged,
                  itemBuilder: (context) => [
                    for (final target in PanelDockSlot.values)
                      PopupMenuItem(
                        value: target,
                        enabled: target != slot,
                        child: Text('Move to ${target.label}'),
                      ),
                  ],
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 2),
                  InkWell(
                    onTap: onClose,
                    child: const Icon(Icons.close, size: 13, color: StudioColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
