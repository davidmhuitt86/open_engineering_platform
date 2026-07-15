import '../../views/diagram/diagram_geometry.dart';
import '../../views/diagram/diagram_layout.dart';
import '../../views/diagram/node_transform.dart';
import '../editing_command.dart';
import '../editing_session.dart';
import '../placement_math.dart';

/// Rotates the selection by [angleDeltaDegrees] (WORK_PACKAGE_023,
/// ENGINE-TASK-000102: "Rotate 90°", "Rotate 180°", "Rotate Arbitrary
/// Angle" are all just different deltas). Positions rotate around the
/// selection's bounding-box center (`PlacementMath.rotatedPositions`);
/// each node's own `NodeTransform.rotation` advances by the same delta.
class RotateNodesCommand implements EditingCommand {
  final Set<String> nodeIds;
  final double angleDeltaDegrees;

  Map<String, Point2D> _previousPositions = const {};
  Map<String, NodeTransform> _previousTransforms = const {};

  RotateNodesCommand(this.nodeIds, this.angleDeltaDegrees);

  @override
  String get description => 'Rotate';

  @override
  EditingSession apply(EditingSession session) {
    if (nodeIds.isEmpty) return session;
    // Resolves each node's *effective* position (tracked, or the same
    // auto-layout fallback DiagramView renders with) — a node that has
    // never been explicitly moved must still rotate correctly.
    final positions = <String, Point2D>{
      for (final id in nodeIds)
        if (session.graph.nodes.containsKey(id))
          id: DiagramLayout.resolvePosition(session.graph, session.layout, id),
    };
    if (positions.isEmpty) return session;

    _previousPositions = positions;
    _previousTransforms = {for (final id in positions.keys) id: session.layout.transformOf(id)};

    final rotated = PlacementMath.rotatedPositions(positions, angleDeltaDegrees);
    var layout = session.layout.withPositions(rotated);
    for (final id in positions.keys) {
      final current = _previousTransforms[id]!;
      layout = layout.withTransform(
        id,
        current.copyWith(rotation: (current.rotation + angleDeltaDegrees) % 360),
      );
    }
    return session.copyWith(layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    if (_previousPositions.isEmpty) return session;
    var layout = session.layout.withPositions(_previousPositions);
    for (final entry in _previousTransforms.entries) {
      layout = layout.withTransform(entry.key, entry.value);
    }
    return session.copyWith(layout: layout);
  }
}
