import '../../views/diagram/diagram_geometry.dart';
import '../../views/diagram/diagram_layout.dart';
import '../../views/diagram/rect2d.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Edge/center alignment modes (WORK_PACKAGE_022, ENGINE-TASK-000091).
enum AlignmentMode { left, right, top, bottom, center, middle }

/// Aligns two or more nodes to a common edge or center/middle line,
/// computed from the selection's overall bounding box. Layout-only
/// mutation (SDD-024 Rule 5) — undoable, like every other move.
class AlignNodesCommand implements EditingCommand {
  final Set<String> nodeIds;
  final AlignmentMode mode;

  Map<String, Point2D> _previousPositions = const {};

  AlignNodesCommand(this.nodeIds, this.mode);

  @override
  String get description => 'Align ${mode.name}';

  @override
  EditingSession apply(EditingSession session) {
    if (nodeIds.length < 2) return session;
    const size = DiagramLayout.nodeSize;

    final bounds = <String, Rect2D>{};
    for (final id in nodeIds) {
      if (!session.graph.nodes.containsKey(id)) continue;
      // Resolves the effective position (tracked, or the same
      // auto-layout fallback DiagramView renders with) so aligning a
      // never-moved node still works (WORK_PACKAGE_023 finding).
      final position = DiagramLayout.resolvePosition(session.graph, session.layout, id);
      bounds[id] = Rect2D(
        left: position.dx,
        top: position.dy,
        right: position.dx + size,
        bottom: position.dy + size,
      );
    }
    if (bounds.length < 2) return session;

    final minLeft = bounds.values.map((b) => b.left).reduce((a, b) => a < b ? a : b);
    final maxRight = bounds.values.map((b) => b.right).reduce((a, b) => a > b ? a : b);
    final minTop = bounds.values.map((b) => b.top).reduce((a, b) => a < b ? a : b);
    final maxBottom = bounds.values.map((b) => b.bottom).reduce((a, b) => a > b ? a : b);
    final centerX = (minLeft + maxRight) / 2;
    final centerY = (minTop + maxBottom) / 2;

    _previousPositions = {
      for (final id in bounds.keys)
        id: DiagramLayout.resolvePosition(session.graph, session.layout, id),
    };

    final newPositions = <String, Point2D>{};
    for (final entry in bounds.entries) {
      final b = entry.value;
      final width = b.right - b.left;
      final height = b.bottom - b.top;
      double x = b.left;
      double y = b.top;
      switch (mode) {
        case AlignmentMode.left:
          x = minLeft;
        case AlignmentMode.right:
          x = maxRight - width;
        case AlignmentMode.top:
          y = minTop;
        case AlignmentMode.bottom:
          y = maxBottom - height;
        case AlignmentMode.center:
          x = centerX - width / 2;
        case AlignmentMode.middle:
          y = centerY - height / 2;
      }
      newPositions[entry.key] = Point2D(x, y);
    }
    return session.copyWith(layout: session.layout.withPositions(newPositions));
  }

  @override
  EditingSession revert(EditingSession session) {
    if (_previousPositions.isEmpty) return session;
    return session.copyWith(layout: session.layout.withPositions(_previousPositions));
  }
}
