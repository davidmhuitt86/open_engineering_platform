import '../../graph/models/engineering_node.dart';
import '../../shared/ids.dart';
import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Duplicates a single node — category/displayName/symbolId/properties/
/// ports are copied; evidence links are not (a duplicate isn't evidenced
/// by the original's source material) (ENGINE-TASK-000079).
///
/// For duplicating a whole selection (with its internal relationships
/// preserved), see `DuplicateSelectionCommand` (ENGINE-TASK-000083).
class DuplicateNodeCommand implements EditingCommand {
  final String sourceNodeId;
  final Point2D offset;

  String? _newNodeId;

  DuplicateNodeCommand(this.sourceNodeId, {this.offset = const Point2D(24, 24)});

  @override
  String get description => 'Duplicate node';

  @override
  EditingSession apply(EditingSession session) {
    final source = session.graph.nodes[sourceNodeId];
    if (source == null) return session;
    final newId = _newNodeId ??= EngineIds.generate('node');
    final copy = EngineeringNode(
      id: newId,
      category: source.category,
      displayName: '${source.displayName} (copy)',
      symbolId: source.symbolId,
      metadata: source.metadata,
      properties: source.properties,
      ports: source.ports,
    );
    final graph = session.graph.withNode(copy);
    final sourcePosition = session.layout.positionOf(sourceNodeId);
    final layout = sourcePosition == null
        ? session.layout
        : session.layout.withPosition(
            newId,
            sourcePosition.translate(offset.dx, offset.dy),
          );
    return session.copyWith(graph: graph, layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    final newId = _newNodeId;
    if (newId == null) return session;
    return session.copyWith(
      graph: session.graph.withoutNode(newId),
      layout: session.layout.withoutPosition(newId),
    );
  }
}
