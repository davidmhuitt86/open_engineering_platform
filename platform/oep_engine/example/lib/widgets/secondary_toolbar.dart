import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Second toolbar row grouping the WORK_PACKAGE_023 professional-editing
/// tool groups (ENGINE-TASK-000106: Layer Panel entry point, Search Panel
/// entry point, Annotation Tools, Wire Editing Toolbar, Placement
/// Toolbar, Constraint Toolbar). Still a single flat row — "basic
/// implementation only, do NOT introduce docking frameworks" (carried
/// over from WORK_PACKAGE_022, ENGINE-TASK-000097).
class SecondaryToolbar extends StatelessWidget {
  final VoidCallback onOpenLayers;
  final VoidCallback onOpenSearch;

  final void Function(AnnotationType type) onAddAnnotation;

  final bool wireEditModeActive;
  final VoidCallback? onToggleWireEditMode;
  final VoidCallback? onInsertVertex;
  final VoidCallback? onRemoveVertex;
  final VoidCallback? onRestoreAutomaticRouting;

  final VoidCallback? onRotate90;
  final VoidCallback? onRotate180;
  final void Function(double degrees)? onRotateArbitrary;
  final VoidCallback? onMirrorHorizontal;
  final VoidCallback? onMirrorVertical;
  final VoidCallback? onArrayPlace;
  final void Function(String symbolId)? onReplaceSymbol;
  final List<String> symbolChoices;
  final String Function(String symbolId) resolveSymbolName;

  final EditingConstraints constraints;
  final void Function(EditingConstraints) onConstraintsChanged;

  final List<String> recentDescriptions;

  const SecondaryToolbar({
    super.key,
    required this.onOpenLayers,
    required this.onOpenSearch,
    required this.onAddAnnotation,
    required this.wireEditModeActive,
    required this.onToggleWireEditMode,
    required this.onInsertVertex,
    required this.onRemoveVertex,
    required this.onRestoreAutomaticRouting,
    required this.onRotate90,
    required this.onRotate180,
    required this.onRotateArbitrary,
    required this.onMirrorHorizontal,
    required this.onMirrorVertical,
    required this.onArrayPlace,
    required this.onReplaceSymbol,
    required this.symbolChoices,
    required this.resolveSymbolName,
    required this.constraints,
    required this.onConstraintsChanged,
    required this.recentDescriptions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            onPressed: onOpenLayers,
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Layers',
          ),
          IconButton(
            onPressed: onOpenSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          const VerticalDivider(),
          PopupMenuButton<AnnotationType>(
            tooltip: 'Add annotation',
            onSelected: onAddAnnotation,
            itemBuilder: (context) => AnnotationType.values
                .map((t) => PopupMenuItem(value: t, child: Text(_labelFor(t))))
                .toList(),
            child: const _Label(icon: Icons.sticky_note_2_outlined, label: 'Annotate'),
          ),
          const VerticalDivider(),
          IconButton(
            onPressed: onToggleWireEditMode,
            icon: Icon(wireEditModeActive ? Icons.polyline : Icons.polyline_outlined),
            tooltip: 'Edit Route',
            color: wireEditModeActive ? Colors.deepPurple : null,
          ),
          IconButton(
            onPressed: onInsertVertex,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Insert vertex',
          ),
          IconButton(
            onPressed: onRemoveVertex,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Remove vertex',
          ),
          IconButton(
            onPressed: onRestoreAutomaticRouting,
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Restore automatic routing',
          ),
          const VerticalDivider(),
          IconButton(
            onPressed: onRotate90,
            icon: const Icon(Icons.rotate_90_degrees_ccw),
            tooltip: 'Rotate 90°',
          ),
          IconButton(
            onPressed: onRotate180,
            icon: const Icon(Icons.rotate_left),
            tooltip: 'Rotate 180°',
          ),
          IconButton(
            onPressed: onRotateArbitrary == null ? null : () => _promptAngle(context),
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Rotate arbitrary angle...',
          ),
          IconButton(
            onPressed: onMirrorHorizontal,
            icon: const Icon(Icons.flip),
            tooltip: 'Mirror horizontal',
          ),
          IconButton(
            onPressed: onMirrorVertical,
            icon: const RotatedBox(quarterTurns: 1, child: Icon(Icons.flip)),
            tooltip: 'Mirror vertical',
          ),
          IconButton(
            onPressed: onArrayPlace,
            icon: const Icon(Icons.grid_on),
            tooltip: 'Array placement...',
          ),
          PopupMenuButton<String>(
            tooltip: 'Replace symbol',
            enabled: onReplaceSymbol != null,
            onSelected: onReplaceSymbol,
            itemBuilder: (context) => symbolChoices
                .map((id) => PopupMenuItem(value: id, child: Text(resolveSymbolName(id))))
                .toList(),
            child: const _Label(icon: Icons.find_replace, label: 'Replace'),
          ),
          const VerticalDivider(),
          _ConstraintControls(constraints: constraints, onChanged: onConstraintsChanged),
          const VerticalDivider(),
          PopupMenuButton<String>(
            tooltip: 'Recent commands',
            enabled: recentDescriptions.isNotEmpty,
            itemBuilder: (context) => [
              for (final description in recentDescriptions.take(10))
                PopupMenuItem(enabled: false, child: Text(description)),
            ],
            child: const _Label(icon: Icons.history, label: 'Recent'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAngle(BuildContext context) async {
    final controller = TextEditingController(text: '15');
    final degrees = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rotate by angle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Degrees'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
    if (degrees != null) onRotateArbitrary?.call(degrees);
  }

  static String _labelFor(AnnotationType type) {
    switch (type) {
      case AnnotationType.textLabel:
        return 'Text Label';
      case AnnotationType.leaderNote:
        return 'Leader Note';
      case AnnotationType.callout:
        return 'Callout';
      case AnnotationType.wireLabel:
        return 'Wire Label';
      case AnnotationType.componentLabel:
        return 'Component Label';
      case AnnotationType.freeText:
        return 'Free Text';
      case AnnotationType.revisionNote:
        return 'Revision Note';
      case AnnotationType.portLabel:
        return 'Pin Label';
    }
  }
}

class _ConstraintControls extends StatelessWidget {
  final EditingConstraints constraints;
  final void Function(EditingConstraints) onChanged;

  const _ConstraintControls({required this.constraints, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: 'Orthogonal movement',
          child: Checkbox(
            value: constraints.orthogonalMovement,
            onChanged: (v) =>
                onChanged(constraints.copyWith(orthogonalMovement: v ?? false)),
          ),
        ),
        const Text('Ortho', style: TextStyle(fontSize: 12)),
        DropdownButton<ConstraintAxis?>(
          value: constraints.axisLock,
          hint: const Text('Axis lock'),
          items: const [
            DropdownMenuItem(value: null, child: Text('No axis lock')),
            DropdownMenuItem(value: ConstraintAxis.x, child: Text('Lock X')),
            DropdownMenuItem(value: ConstraintAxis.y, child: Text('Lock Y')),
          ],
          onChanged: (axis) => onChanged(
            axis == null
                ? constraints.copyWith(clearAxisLock: true)
                : constraints.copyWith(axisLock: axis),
          ),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            decoration: const InputDecoration(labelText: 'Min wire len'),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: constraints.minimumWireLength.toString()),
            onSubmitted: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) onChanged(constraints.copyWith(minimumWireLength: parsed));
            },
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Label({required this.icon, required this.label});

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
