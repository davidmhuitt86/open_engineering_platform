import '../../graph/models/engineering_group.dart';
import '../../graph/models/engineering_node.dart';
import '../../graph/models/engineering_relationship.dart';
import '../../views/diagram/diagram_annotation.dart';
import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Deletes a batch of nodes/relationships/groups/annotations as one
/// undoable step (used by Cut and multi-selection Delete). Snapshots the
/// full `graph.groups` map before mutating (node deletion cascades into
/// every surviving group's `memberNodeIds`, not just the explicitly
/// deleted ones — see `DeleteNodeCommand`) so revert is exact.
/// [annotationIds] (WORK_PACKAGE_023) is a Diagram Layout deletion,
/// captured and restored the same way removed positions are.
class DeleteManyCommand implements EditingCommand {
  final Set<String> nodeIds;
  final Set<String> relationshipIds;
  final Set<String> groupIds;
  final Set<String> annotationIds;

  Map<String, EngineeringNode> _removedNodes = const {};
  Map<String, EngineeringRelationship> _removedRelationships = const {};
  Map<String, EngineeringGroup>? _groupsSnapshot;
  Map<String, Point2D> _removedPositions = const {};
  Map<String, DiagramAnnotation> _removedAnnotations = const {};

  DeleteManyCommand({
    this.nodeIds = const {},
    this.relationshipIds = const {},
    this.groupIds = const {},
    this.annotationIds = const {},
  });

  @override
  String get description => 'Delete selection';

  @override
  EditingSession apply(EditingSession session) {
    var graph = session.graph;
    var layout = session.layout;

    _groupsSnapshot = graph.groups;
    _removedNodes = {for (final id in nodeIds) if (graph.nodes[id] != null) id: graph.nodes[id]!};
    final cascadedRelationships = <String, EngineeringRelationship>{};
    for (final id in nodeIds) {
      for (final relationship in graph.relationshipsForNode(id)) {
        cascadedRelationships[relationship.id] = relationship;
      }
    }
    for (final id in relationshipIds) {
      final relationship = graph.relationships[id];
      if (relationship != null) cascadedRelationships[id] = relationship;
    }
    _removedRelationships = cascadedRelationships;
    _removedPositions = {
      for (final id in nodeIds)
        if (layout.positionOf(id) != null) id: layout.positionOf(id)!,
    };

    for (final id in nodeIds) {
      graph = graph.withoutNode(id);
      layout = layout.withoutPosition(id);
    }
    for (final id in relationshipIds) {
      graph = graph.withoutRelationship(id);
    }
    for (final id in groupIds) {
      graph = graph.withoutGroup(id);
    }

    _removedAnnotations = {
      for (final id in annotationIds)
        if (layout.annotationOf(id) != null) id: layout.annotationOf(id)!,
    };
    for (final id in annotationIds) {
      layout = layout.withoutAnnotation(id);
    }

    return session.copyWith(graph: graph, layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    final groupsSnapshot = _groupsSnapshot;
    if (groupsSnapshot == null) return session;

    var graph = session.graph;
    for (final node in _removedNodes.values) {
      graph = graph.withNode(node);
    }
    for (final relationship in _removedRelationships.values) {
      graph = graph.withRelationship(relationship);
    }
    graph = graph.copyWith(groups: groupsSnapshot);

    var layout = session.layout;
    for (final entry in _removedPositions.entries) {
      layout = layout.withPosition(entry.key, entry.value);
    }
    for (final annotation in _removedAnnotations.values) {
      layout = layout.withAnnotation(annotation);
    }

    return session.copyWith(graph: graph, layout: layout);
  }
}
