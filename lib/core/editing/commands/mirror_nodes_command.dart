import '../../views/diagram/diagram_geometry.dart';
import '../../views/diagram/diagram_layout.dart';
import '../../views/diagram/node_transform.dart';
import '../editing_command.dart';
import '../editing_session.dart';
import '../placement_math.dart';

/// Mirrors the selection horizontally or vertically (WORK_PACKAGE_023,
/// ENGINE-TASK-000102: "Mirror Horizontal", "Mirror Vertical") — reflects
/// positions around the selection's bounding-box center
/// (`PlacementMath.mirroredPositions`, the same bounding-box math
/// `AlignNodesCommand` uses) and flips each node's corresponding
/// `NodeTransform` flag, so a future renderer can mirror the symbol
/// glyph itself.
class MirrorNodesCommand implements EditingCommand {
  final Set<String> nodeIds;
  final MirrorAxis axis;

  Map<String, Point2D> _previousPositions = const {};
  Map<String, NodeTransform> _previousTransforms = const {};

  MirrorNodesCommand(this.nodeIds, this.axis);

  @override
  String get description => 'Mirror ${axis.name}';

  @override
  EditingSession apply(EditingSession session) {
    if (nodeIds.isEmpty) return session;
    // See RotateNodesCommand: resolve each node's *effective* position so
    // a never-moved node still mirrors correctly.
    final positions = <String, Point2D>{
      for (final id in nodeIds)
        if (session.graph.nodes.containsKey(id))
          id: DiagramLayout.resolvePosition(session.graph, session.layout, id),
    };
    if (positions.isEmpty) return session;

    _previousPositions = positions;
    _previousTransforms = {for (final id in positions.keys) id: session.layout.transformOf(id)};

    final mirrored = PlacementMath.mirroredPositions(positions, axis);
    var layout = session.layout.withPositions(mirrored);
    for (final id in positions.keys) {
      final current = _previousTransforms[id]!;
      layout = layout.withTransform(
        id,
        axis == MirrorAxis.horizontal
            ? current.copyWith(flipHorizontal: !current.flipHorizontal)
            : current.copyWith(flipVertical: !current.flipVertical),
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
