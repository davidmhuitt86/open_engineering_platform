import 'engineering_group.dart';
import 'engineering_node.dart';
import 'engineering_relationship.dart';

/// The canonical runtime representation of engineering knowledge (SDD-024,
/// SDD-025, SDD-027).
///
/// Immutable value container — [GraphService] and [GraphBuilder] produce
/// new instances rather than mutating in place, which keeps
/// [EngineEventBus] notifications and undo/redo (future) simple to reason
/// about. Contains no visual layout information; that belongs to a View.
class EngineeringGraph {
  final String id;
  final Map<String, EngineeringNode> nodes;
  final Map<String, EngineeringRelationship> relationships;
  final Map<String, EngineeringGroup> groups;
  final Map<String, Object?> metadata;

  const EngineeringGraph({
    required this.id,
    this.nodes = const {},
    this.relationships = const {},
    this.groups = const {},
    this.metadata = const {},
  });

  factory EngineeringGraph.empty(String id) => EngineeringGraph(id: id);

  EngineeringGraph copyWith({
    Map<String, EngineeringNode>? nodes,
    Map<String, EngineeringRelationship>? relationships,
    Map<String, EngineeringGroup>? groups,
    Map<String, Object?>? metadata,
  }) {
    return EngineeringGraph(
      id: id,
      nodes: nodes ?? this.nodes,
      relationships: relationships ?? this.relationships,
      groups: groups ?? this.groups,
      metadata: metadata ?? this.metadata,
    );
  }

  EngineeringGraph withNode(EngineeringNode node) {
    return copyWith(nodes: {...nodes, node.id: node});
  }

  EngineeringGraph withoutNode(String nodeId) {
    final remainingNodes = {...nodes}..remove(nodeId);
    final remainingRelationships = Map<String, EngineeringRelationship>.from(
      relationships,
    )..removeWhere((_, r) => r.sourceNode == nodeId || r.targetNode == nodeId);
    final remainingGroups = groups.map(
      (id, g) => MapEntry(
        id,
        g.copyWith(
          memberNodeIds: g.memberNodeIds.where((m) => m != nodeId).toList(),
        ),
      ),
    );
    return copyWith(
      nodes: remainingNodes,
      relationships: remainingRelationships,
      groups: remainingGroups,
    );
  }

  EngineeringGraph withRelationship(EngineeringRelationship relationship) {
    return copyWith(relationships: {...relationships, relationship.id: relationship});
  }

  EngineeringGraph withoutRelationship(String relationshipId) {
    final remaining = {...relationships}..remove(relationshipId);
    return copyWith(relationships: remaining);
  }

  EngineeringGraph withGroup(EngineeringGroup group) {
    return copyWith(groups: {...groups, group.id: group});
  }

  List<EngineeringRelationship> relationshipsForNode(String nodeId) {
    return relationships.values
        .where((r) => r.sourceNode == nodeId || r.targetNode == nodeId)
        .toList();
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'nodes': nodes.values.map((n) => n.toJson()).toList(),
        'relationships': relationships.values.map((r) => r.toJson()).toList(),
        'groups': groups.values.map((g) => g.toJson()).toList(),
        'metadata': metadata,
      };

  factory EngineeringGraph.fromJson(Map<String, Object?> json) {
    final nodeList = (json['nodes'] as List? ?? const [])
        .map((n) => EngineeringNode.fromJson(Map<String, Object?>.from(n as Map)))
        .toList();
    final relationshipList = (json['relationships'] as List? ?? const [])
        .map((r) =>
            EngineeringRelationship.fromJson(Map<String, Object?>.from(r as Map)))
        .toList();
    final groupList = (json['groups'] as List? ?? const [])
        .map((g) => EngineeringGroup.fromJson(Map<String, Object?>.from(g as Map)))
        .toList();
    return EngineeringGraph(
      id: json['id'] as String,
      nodes: {for (final n in nodeList) n.id: n},
      relationships: {for (final r in relationshipList) r.id: r},
      groups: {for (final g in groupList) g.id: g},
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
    );
  }
}
