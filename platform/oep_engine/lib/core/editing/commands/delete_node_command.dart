import '../../graph/models/engineering_group.dart';
import '../../graph/models/engineering_node.dart';
import '../../graph/models/engineering_relationship.dart';
import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Deletes a node, cascading relationship removal
/// ([EngineeringGraph.withoutNode] already does this) — captures the
/// removed node, its relationships, its layout position, and a full
/// snapshot of `graph.groups` (since `withoutNode` also strips this node
/// from every surviving group's `memberNodeIds`, not just from groups
/// that get deleted) so [revert] restores everything precisely
/// (ENGINE-TASK-000079).
class DeleteNodeCommand implements EditingCommand {
  final String nodeId;

  EngineeringNode? _removedNode;
  List<EngineeringRelationship> _removedRelationships = const [];
  Map<String, EngineeringGroup>? _groupsSnapshot;
  Point2D? _removedPosition;

  DeleteNodeCommand(this.nodeId);

  @override
  String get description => 'Delete node';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    _removedNode = node;
    _removedRelationships = session.graph.relationshipsForNode(nodeId);
    _groupsSnapshot = session.graph.groups;
    _removedPosition = session.layout.positionOf(nodeId);
    return session.copyWith(
      graph: session.graph.withoutNode(nodeId),
      layout: session.layout.withoutPosition(nodeId),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final removed = _removedNode;
    final groupsSnapshot = _groupsSnapshot;
    if (removed == null || groupsSnapshot == null) return session;
    var graph = session.graph.withNode(removed);
    for (final relationship in _removedRelationships) {
      graph = graph.withRelationship(relationship);
    }
    graph = graph.copyWith(groups: groupsSnapshot);
    var layout = session.layout;
    final position = _removedPosition;
    if (position != null) {
      layout = layout.withPosition(nodeId, position);
    }
    return session.copyWith(graph: graph, layout: layout);
  }
}
