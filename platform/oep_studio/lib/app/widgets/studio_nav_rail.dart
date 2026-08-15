import 'package:flutter/material.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/routing/studio_registry.dart';
import '../../core/theme/studio_colors.dart';

/// The permanent left Navigation Rail (SDD-003 Primary Navigation).
///
/// Only one destination is ever selected — selecting one changes the
/// active Primary Workspace (SDD-004); it never opens a floating window.
/// Renders [StudioRegistry.defaultRegistry]'s destinations (WP-STUDIO-021)
/// rather than `StudioDestination.values` directly — same order, same
/// 13 entries, now sourced from the one place routing/settings/search
/// also read from.
class StudioNavRail extends StatelessWidget {
  const StudioNavRail({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final StudioDestination selected;
  final ValueChanged<StudioDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(right: BorderSide(color: StudioColors.border)),
      ),
      child: Column(
        children: [
          const _BrandHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final destination in StudioRegistry.defaultRegistry.destinations)
                  _NavRailItem(
                    destination: destination,
                    selected: destination == selected,
                    onTap: () => onSelect(destination),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: StudioColors.selection,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Text(
              'O',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'OEP Studio',
                  style: TextStyle(
                    color: StudioColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Open Engineering Platform',
                  style: TextStyle(color: StudioColors.textSecondary, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRailItem extends StatelessWidget {
  const _NavRailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final StudioDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? StudioColors.selection.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 18,
                  color: selected ? StudioColors.selection : StudioColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? StudioColors.textPrimary : StudioColors.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
