import '../models/engineering_graph.dart';
import '../models/engineering_node.dart';
import '../models/engineering_relationship.dart';
import 'graph_traversal.dart';

/// Read-only query surface over an [EngineeringGraph].
///
/// Deliberately has no mutation methods — [GraphBuilder] and [GraphService]
/// own edits. Conceptually parallel to the reference implementation's
/// `QueryEngine` (a read-only wrapper distinct from its mutating editor),
/// reimplemented from scratch in Dart.
class GraphQuery {
  final EngineeringGraph graph;

  const GraphQuery(this.graph);

  List<EngineeringNode> nodesByCategory(NodeCategory category) =>
      graph.nodes.values.where((n) => n.category == category).toList();

  List<EngineeringNode> nodesBySymbol(String symbolId) =>
      graph.nodes.values.where((n) => n.symbolId == symbolId).toList();

  List<EngineeringRelationship> relationshipsBetween(
    String nodeIdA,
    String nodeIdB,
  ) {
    return graph.relationships.values
        .where((r) =>
            (r.sourceNode == nodeIdA && r.targetNode == nodeIdB) ||
            (r.sourceNode == nodeIdB && r.targetNode == nodeIdA))
        .toList();
  }

  List<String> neighborsOf(String nodeId) => GraphTraversal.neighbors(graph, nodeId);

  Set<String> reachableFrom(String nodeId, {int maxDepth = 1000}) =>
      GraphTraversal.reachableFrom(graph, nodeId, maxDepth: maxDepth);

  List<String>? findPath(String sourceId, String targetId) =>
      GraphTraversal.findPath(graph, sourceId, targetId);

  List<EngineeringNode> isolatedNodes() {
    final ids = GraphTraversal.isolatedNodes(graph).toSet();
    return graph.nodes.values.where((n) => ids.contains(n.id)).toList();
  }

  List<EngineeringNode> membersOf(String groupId) {
    final group = graph.groups[groupId];
    if (group == null) return const [];
    return group.memberNodeIds
        .map((id) => graph.nodes[id])
        .whereType<EngineeringNode>()
        .toList();
  }
}
