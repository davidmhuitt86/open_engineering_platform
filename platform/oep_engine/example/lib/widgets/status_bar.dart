import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Status bar with engine diagnostics, selection count, undo/redo
/// availability, zoom %, and a cursor coordinate readout
/// (WORK_PACKAGE_022, ENGINE-TASK-000096: "Coordinate Readout",
/// "Status Indicators"). Extended in WORK_PACKAGE_023, ENGINE-TASK-000106
/// with layer count, active constraints, and search match count.
class DemoStatusBar extends StatelessWidget {
  final EngineeringEngine engine;
  final GraphSelection selection;
  final ViewState viewState;
  final Point2D? cursorScenePosition;
  final int layerCount;
  final int searchResultCount;

  const DemoStatusBar({
    super.key,
    required this.engine,
    required this.selection,
    required this.viewState,
    required this.cursorScenePosition,
    required this.layerCount,
    required this.searchResultCount,
  });

  @override
  Widget build(BuildContext context) {
    final diagnostics = engine.diagnostics();
    final cursor = cursorScenePosition;
    final constraints = viewState.constraints;
    final activeConstraints = <String>[
      if (constraints.orthogonalMovement) 'Ortho',
      if (constraints.axisLock != null) 'Axis:${constraints.axisLock!.name}',
      if (constraints.angleConstraintDegrees != null)
        'Angle:${constraints.angleConstraintDegrees}°',
    ];
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('Engine: ${diagnostics.state.name}'),
            const SizedBox(width: 16),
            Text('v${diagnostics.version}'),
            const SizedBox(width: 16),
            Text('Symbols: ${diagnostics.registeredSymbolCount}'),
            const SizedBox(width: 16),
            Text('Selected: ${selection.length}'),
            const SizedBox(width: 16),
            Text('Undo: ${engine.editing.canUndo ? engine.editing.nextUndoDescription : "—"}'),
            const SizedBox(width: 16),
            Text('Redo: ${engine.editing.canRedo ? engine.editing.nextRedoDescription : "—"}'),
            const SizedBox(width: 16),
            Text('Zoom: ${(viewState.zoom * 100).round()}%'),
            const SizedBox(width: 16),
            Text(cursor == null
                ? 'X: — Y: —'
                : 'X: ${cursor.dx.round()} Y: ${cursor.dy.round()}'),
            const SizedBox(width: 16),
            Text('Layers: $layerCount'),
            const SizedBox(width: 16),
            Text('Constraints: ${activeConstraints.isEmpty ? "—" : activeConstraints.join(", ")}'),
            const SizedBox(width: 16),
            Text('Search: $searchResultCount'),
          ],
        ),
      ),
    );
  }
}
