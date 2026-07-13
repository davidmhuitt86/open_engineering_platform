import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Status bar with engine diagnostics, selection count, undo/redo
/// availability, zoom %, and a cursor coordinate readout
/// (WORK_PACKAGE_022, ENGINE-TASK-000096: "Coordinate Readout",
/// "Status Indicators").
class DemoStatusBar extends StatelessWidget {
  final EngineeringEngine engine;
  final GraphSelection selection;
  final ViewState viewState;
  final Point2D? cursorScenePosition;

  const DemoStatusBar({
    super.key,
    required this.engine,
    required this.selection,
    required this.viewState,
    required this.cursorScenePosition,
  });

  @override
  Widget build(BuildContext context) {
    final diagnostics = engine.diagnostics();
    final cursor = cursorScenePosition;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        ],
      ),
    );
  }
}
