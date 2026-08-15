import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

class DemoToolbar extends StatelessWidget {
  final void Function(String symbolId) onAddNode;
  final VoidCallback? onDelete;
  final VoidCallback? onGroup;
  final VoidCallback? onUngroup;
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final VoidCallback? onDuplicate;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final List<String> symbolChoices;
  final String Function(String symbolId) resolveSymbolName;

  final VoidCallback onFitAll;
  final VoidCallback? onFitSelection;
  final VoidCallback? onCenterSelection;
  final VoidCallback? onGoBack;
  final VoidCallback? onGoForward;

  final void Function(AlignmentMode mode)? onAlign;
  final void Function(DistributionAxis axis)? onDistribute;

  final ViewState viewState;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleSnap;
  final VoidCallback onToggleGuides;
  final VoidCallback onOpenGridSettings;
  final VoidCallback onOpenNamedLayouts;

  const DemoToolbar({
    super.key,
    required this.onAddNode,
    required this.onDelete,
    required this.onGroup,
    required this.onUngroup,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onDuplicate,
    required this.onUndo,
    required this.onRedo,
    required this.symbolChoices,
    required this.resolveSymbolName,
    required this.onFitAll,
    required this.onFitSelection,
    required this.onCenterSelection,
    required this.onGoBack,
    required this.onGoForward,
    required this.onAlign,
    required this.onDistribute,
    required this.viewState,
    required this.onToggleGrid,
    required this.onToggleSnap,
    required this.onToggleGuides,
    required this.onOpenGridSettings,
    required this.onOpenNamedLayouts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Add node',
            onSelected: onAddNode,
            itemBuilder: (context) => symbolChoices
                .map((id) => PopupMenuItem(value: id, child: Text(resolveSymbolName(id))))
                .toList(),
            child: const _ToolbarLabel(icon: Icons.add_box, label: 'Add'),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete), tooltip: 'Delete (Del)'),
          IconButton(onPressed: onGroup, icon: const Icon(Icons.group_work), tooltip: 'Group'),
          IconButton(onPressed: onUngroup, icon: const Icon(Icons.group_off), tooltip: 'Ungroup'),
          const VerticalDivider(),
          IconButton(onPressed: onCopy, icon: const Icon(Icons.copy), tooltip: 'Copy (Ctrl+C)'),
          IconButton(onPressed: onCut, icon: const Icon(Icons.cut), tooltip: 'Cut (Ctrl+X)'),
          IconButton(onPressed: onPaste, icon: const Icon(Icons.paste), tooltip: 'Paste (Ctrl+V)'),
          IconButton(
            onPressed: onDuplicate,
            icon: const Icon(Icons.content_copy),
            tooltip: 'Duplicate (Ctrl+D)',
          ),
          const VerticalDivider(),
          IconButton(onPressed: onUndo, icon: const Icon(Icons.undo), tooltip: 'Undo (Ctrl+Z)'),
          IconButton(onPressed: onRedo, icon: const Icon(Icons.redo), tooltip: 'Redo (Ctrl+Y)'),
          const VerticalDivider(),
          PopupMenuButton<AlignmentMode>(
            tooltip: 'Align',
            enabled: onAlign != null,
            onSelected: onAlign,
            itemBuilder: (context) => AlignmentMode.values
                .map((m) => PopupMenuItem(value: m, child: Text('Align ${m.name}')))
                .toList(),
            child: const _ToolbarLabel(icon: Icons.align_horizontal_left, label: 'Align'),
          ),
          PopupMenuButton<DistributionAxis>(
            tooltip: 'Distribute',
            enabled: onDistribute != null,
            onSelected: onDistribute,
            itemBuilder: (context) => DistributionAxis.values
                .map((a) => PopupMenuItem(value: a, child: Text('Distribute ${a.name}')))
                .toList(),
            child: const _ToolbarLabel(icon: Icons.space_bar, label: 'Distribute'),
          ),
          const VerticalDivider(),
          IconButton(onPressed: onFitAll, icon: const Icon(Icons.fit_screen), tooltip: 'Fit All'),
          IconButton(
            onPressed: onFitSelection,
            icon: const Icon(Icons.crop_free),
            tooltip: 'Fit Selection',
          ),
          IconButton(
            onPressed: onCenterSelection,
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Center Selection',
          ),
          IconButton(
            onPressed: onGoBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Navigate back',
          ),
          IconButton(
            onPressed: onGoForward,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Navigate forward',
          ),
          const VerticalDivider(),
          PopupMenuButton<void>(
            tooltip: 'View',
            itemBuilder: (context) => [
              CheckedPopupMenuItem<void>(
                checked: viewState.grid.visible,
                onTap: onToggleGrid,
                child: const Text('Show Grid'),
              ),
              CheckedPopupMenuItem<void>(
                checked: viewState.grid.snapEnabled,
                onTap: onToggleSnap,
                child: const Text('Snap to Grid'),
              ),
              CheckedPopupMenuItem<void>(
                checked: viewState.guidesVisible,
                onTap: onToggleGuides,
                child: const Text('Show Guides'),
              ),
              PopupMenuItem<void>(
                onTap: onOpenGridSettings,
                child: const Text('Grid Settings...'),
              ),
              PopupMenuItem<void>(
                onTap: onOpenNamedLayouts,
                child: const Text('Named Layouts...'),
              ),
            ],
            child: const _ToolbarLabel(icon: Icons.visibility, label: 'View'),
          ),
        ],
      ),
    );
  }
}

class _ToolbarLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ToolbarLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(label),
      ]),
    );
  }
}
