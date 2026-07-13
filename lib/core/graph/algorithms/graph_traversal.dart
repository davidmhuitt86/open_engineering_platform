import '../models/engineering_graph.dart';

/// Breadth-first traversal helpers over an [EngineeringGraph].
///
/// Relationship-agnostic and direction-agnostic by default (a relationship
/// connects two nodes; whether that connection should be treated as
/// directed is a question for a specific reasoning module, not the graph
/// itself) — conceptually parallel to the reference implementation's
/// `Graph.reachableFrom` / `Graph.findPath`, reimplemented from scratch.
class GraphTraversal {
  GraphTraversal._();

  static List<String> neighbors(EngineeringGraph graph, String nodeId) {
    final result = <String>{};
    for (final r in graph.relationshipsForNode(nodeId)) {
      if (r.sourceNode == nodeId) result.add(r.targetNode);
      if (r.targetNode == nodeId) result.add(r.sourceNode);
    }
    return result.toList();
  }

  /// All node ids reachable from [startId] within [maxDepth] hops
  /// (inclusive of [startId] at depth 0).
  static Set<String> reachableFrom(
    EngineeringGraph graph,
    String startId, {
    int maxDepth = 1000,
  }) {
    if (!graph.nodes.containsKey(startId)) return {};
    final visited = <String>{startId};
    var frontier = <String>{startId};
    var depth = 0;
    while (frontier.isNotEmpty && depth < maxDepth) {
      final next = <String>{};
      for (final id in frontier) {
        for (final neighbor in neighbors(graph, id)) {
          if (visited.add(neighbor)) next.add(neighbor);
        }
      }
      frontier = next;
      depth++;
    }
    return visited;
  }

  /// Shortest node-id path from [sourceId] to [targetId], or `null` if
  /// unreachable.
  static List<String>? findPath(
    EngineeringGraph graph,
    String sourceId,
    String targetId,
  ) {
    if (sourceId == targetId) return [sourceId];
    if (!graph.nodes.containsKey(sourceId) || !graph.nodes.containsKey(targetId)) {
      return null;
    }
    final visited = <String>{sourceId};
    final queue = <List<String>>[
      [sourceId]
    ];
    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final last = path.last;
      for (final neighbor in neighbors(graph, last)) {
        if (neighbor == targetId) return [...path, neighbor];
        if (visited.add(neighbor)) {
          queue.add([...path, neighbor]);
        }
      }
    }
    return null;
  }

  /// Node ids with no relationships at all.
  static List<String> isolatedNodes(EngineeringGraph graph) {
    return graph.nodes.keys
        .where((id) => graph.relationshipsForNode(id).isEmpty)
        .toList();
  }
}
