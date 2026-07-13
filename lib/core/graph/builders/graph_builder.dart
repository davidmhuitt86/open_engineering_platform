import '../../shared/ids.dart';
import '../models/engineering_graph.dart';
import '../models/engineering_group.dart';
import '../models/engineering_node.dart';
import '../models/engineering_relationship.dart';
import '../models/evidence_link.dart';
import '../models/port.dart';

/// Fluent, in-memory graph construction.
///
/// Conceptually parallel to the reference implementation's `GraphEditor`
/// (`addComponent` / `connect` / `build()` chaining), reimplemented from
/// scratch in Dart against the SDD-027 object model. Useful for seeding
/// sample graphs and for tests; `GraphService` is the service-layer
/// counterpart that persists and validates.
class GraphBuilder {
  EngineeringGraph _graph;

  GraphBuilder({String? id}) : _graph = EngineeringGraph.empty(id ?? EngineIds.generate('graph'));

  GraphBuilder addNode({
    String? id,
    required NodeCategory category,
    required String displayName,
    String? symbolId,
    Map<String, Object?> metadata = const {},
    Map<String, Object?> properties = const {},
    List<Port> ports = const [],
    List<EvidenceLink> evidenceLinks = const [],
  }) {
    final node = EngineeringNode(
      id: id ?? EngineIds.generate('node'),
      category: category,
      displayName: displayName,
      symbolId: symbolId,
      metadata: metadata,
      properties: properties,
      ports: ports,
      evidenceLinks: evidenceLinks,
    );
    _graph = _graph.withNode(node);
    return this;
  }

  GraphBuilder connect(
    String sourceId,
    String targetId, {
    RelationshipType type = RelationshipType.connectedTo,
    String? id,
    Map<String, Object?> metadata = const {},
  }) {
    final relationship = EngineeringRelationship(
      id: id ?? EngineIds.generate('rel'),
      relationshipType: type,
      sourceNode: sourceId,
      targetNode: targetId,
      metadata: metadata,
    );
    _graph = _graph.withRelationship(relationship);
    return this;
  }

  GraphBuilder addGroup({
    String? id,
    required GroupKind kind,
    required String displayName,
    List<String> memberNodeIds = const [],
  }) {
    final group = EngineeringGroup(
      id: id ?? EngineIds.generate('group'),
      kind: kind,
      displayName: displayName,
      memberNodeIds: memberNodeIds,
    );
    _graph = _graph.withGroup(group);
    return this;
  }

  EngineeringNode? findNode(String id) => _graph.nodes[id];

  EngineeringGraph build() => _graph;
}
