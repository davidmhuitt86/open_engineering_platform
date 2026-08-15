import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import 'diagram_tab.dart';

/// (OEP Diagram Studio -- Phase 5, Part 2/Part 3.) The browser-style
/// tab bar for OPEN DIAGRAM DOCUMENTS -- not application-level Studio
/// navigation (that remains `StudioShell`'s job, untouched). Each tab
/// represents one real open diagram; switching mode never adds/removes
/// a tab (Part 3).
class DiagramTabBar extends StatelessWidget {
  const DiagramTabBar({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
    required this.onTogglePin,
    required this.onNewTab,
    required this.recentlyClosedCount,
    required this.onShowHistory,
  });

  final List<DiagramTab> tabs;
  final String? activeTabId;
  final void Function(String id) onSelect;
  final void Function(String id) onClose;
  final void Function(String id) onTogglePin;
  final VoidCallback onNewTab;
  final int recentlyClosedCount;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: StudioColors.surface,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final tab in tabs) _TabChip(tab: tab, selected: tab.id == activeTabId, onSelect: onSelect, onClose: onClose, onTogglePin: onTogglePin)],
            ),
          ),
          IconButton(
            tooltip: 'New diagram tab',
            icon: const Icon(Icons.add, size: 18, color: StudioColors.textSecondary),
            onPressed: onNewTab,
          ),
          Tooltip(
            message: 'Recently closed diagrams',
            child: IconButton(
              icon: Badge(
                isLabelVisible: recentlyClosedCount > 0,
                label: Text('$recentlyClosedCount'),
                child: const Icon(Icons.history, size: 18, color: StudioColors.textSecondary),
              ),
              onPressed: onShowHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.tab, required this.selected, required this.onSelect, required this.onClose, required this.onTogglePin});

  final DiagramTab tab;
  final bool selected;
  final void Function(String id) onSelect;
  final void Function(String id) onClose;
  final void Function(String id) onTogglePin;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('diagram-tab-${tab.id}'),
      onTap: () => onSelect(tab.id),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? StudioColors.surfaceRaised : StudioColors.surface,
          border: Border(
            right: const BorderSide(color: StudioColors.borderSubtle),
            bottom: BorderSide(color: selected ? StudioColors.selection : Colors.transparent, width: 2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 14, color: StudioColors.textSecondary),
            const SizedBox(width: 6),
            if (tab.pinned) const Icon(Icons.push_pin, size: 12, color: StudioColors.selection),
            if (tab.pinned) const SizedBox(width: 4),
            Expanded(
              child: Text(
                tab.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: selected ? StudioColors.textPrimary : StudioColors.textSecondary),
              ),
            ),
            InkWell(
              key: ValueKey('diagram-tab-pin-${tab.id}'),
              onTap: () => onTogglePin(tab.id),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(tab.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 13, color: StudioColors.textDisabled),
              ),
            ),
            InkWell(
              key: ValueKey('diagram-tab-close-${tab.id}'),
              onTap: () => onClose(tab.id),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 13, color: StudioColors.textDisabled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
