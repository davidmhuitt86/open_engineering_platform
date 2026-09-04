import '../graph/models/engineering_graph.dart';
import '../graph/models/engineering_node.dart';
import 'models/electrical_topology.dart';

/// Converts diagram connectivity into electrical topology (AP-EK-020 §11
/// / Phase 5). Extraction is driven entirely by
/// [EngineeringRelationship] connectivity — diagram/layout pixel
/// coordinates are never consulted.
///
/// **Scope, disclosed:** this extractor supports a single-loop series
/// chain (each node has degree ≤ 2, exactly one node is category
/// [NodeCategory.ground]) — the exact shape of the AP-EK-020 acceptance
/// circuit and the smallest topology that proves the architecture.
/// General arbitrary-branching/parallel topology extraction is future
/// work (not required by the first vertical slice; AP-EK-020 §4 non-
/// goals explicitly scope this down). A graph outside this shape raises
/// [TopologyExtractionFailure] rather than silently producing an
/// incorrect result.
class TopologyExtractionFailure implements Exception {
  final String reason;
  final TopologyFailureKind kind;
  const TopologyExtractionFailure(this.kind, this.reason);

  @override
  String toString() => 'TopologyExtractionFailure(${kind.name}): $reason';
}

enum TopologyFailureKind { missingReferenceNode, unsupportedTopology }

class TopologyExtractor {
  const TopologyExtractor();

  /// Deterministic: given the same graph, always produces the same node
  /// ids and ordering, regardless of `Map` iteration order — achieved by
  /// walking the chain from the (unique) non-ground endpoint and always
  /// sorting any ambiguous candidate set by engineering-node id first.
  ElectricalTopology extract(EngineeringGraph graph) {
    final groundNodes =
        graph.nodes.values
            .where((n) => n.category == NodeCategory.ground)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (groundNodes.isEmpty) {
      throw const TopologyExtractionFailure(
        TopologyFailureKind.missingReferenceNode,
        'No node with category "ground" found; a reference node is required.',
      );
    }
    if (groundNodes.length > 1) {
      throw const TopologyExtractionFailure(
        TopologyFailureKind.unsupportedTopology,
        'More than one ground/reference node found; multi-reference topology is unsupported.',
      );
    }
    final groundNode = groundNodes.first;

    // Undirected adjacency over connectedTo-style relationships.
    final adjacency = <String, List<String>>{};
    for (final node in graph.nodes.values) {
      adjacency[node.id] = [];
    }
    final relationshipsSorted = graph.relationships.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final rel in relationshipsSorted) {
      adjacency[rel.sourceNode]?.add(rel.targetNode);
      adjacency[rel.targetNode]?.add(rel.sourceNode);
    }

    for (final entry in adjacency.entries) {
      if (entry.value.length > 2) {
        throw TopologyExtractionFailure(
          TopologyFailureKind.unsupportedTopology,
          'Node "${entry.key}" has degree ${entry.value.length}; branching topology is unsupported '
          'by the first vertical slice\'s series-chain extractor.',
        );
      }
    }

    // Find the chain endpoint that is not the ground node (there must be
    // exactly one, since a series chain has exactly two degree-1 nodes
    // and one of them is required to be ground).
    final endpoints =
        adjacency.entries
            .where((e) => e.value.length <= 1)
            .map((e) => e.key)
            .toList()
          ..sort();
    final nonGroundEndpoints = endpoints
        .where((id) => id != groundNode.id)
        .toList();
    if (nonGroundEndpoints.length != 1) {
      throw TopologyExtractionFailure(
        TopologyFailureKind.unsupportedTopology,
        'Expected exactly one non-ground chain endpoint, found ${nonGroundEndpoints.length}.',
      );
    }
    final startId = nonGroundEndpoints.first;

    // Walk the chain from startId to groundNode.id.
    final orderedNodeIds = <String>[startId];
    String? previous;
    String current = startId;
    while (current != groundNode.id) {
      final neighbors = adjacency[current] ?? const [];
      final next = neighbors.firstWhere((n) => n != previous, orElse: () => '');
      if (next.isEmpty) {
        throw const TopologyExtractionFailure(
          TopologyFailureKind.unsupportedTopology,
          'Chain walk from source did not reach the ground node; graph is disconnected.',
        );
      }
      orderedNodeIds.add(next);
      previous = current;
      current = next;
    }

    // orderedNodeIds: [source, ..., ground]. Assign one ElectricalNode
    // per junction *between* consecutive components, plus the ground
    // node itself as the final (reference) electrical node.
    final electricalNodes = <ElectricalNode>[];
    final terminalConnections = <TerminalConnection>[];
    final components = <ComponentInstance>[];
    final branches = <ElectricalBranch>[];

    // junctionNodeIdFor(i) is the electrical node between orderedNodeIds[i]
    // and orderedNodeIds[i+1]; the last junction (before ground) is the
    // reference node itself.
    final junctionIds = <String>[];
    for (var i = 0; i < orderedNodeIds.length - 1; i++) {
      final isLastJunction = i == orderedNodeIds.length - 2;
      junctionIds.add(isLastJunction ? 'gnd' : 'n${i + 1}');
    }
    electricalNodes.add(
      ElectricalNode(
        id: 'gnd',
        isReference: true,
        sourceObjectId: groundNode.id,
      ),
    );
    for (final id in junctionIds) {
      if (id != 'gnd') {
        electricalNodes.add(ElectricalNode(id: id, isReference: false));
      }
    }

    // In a single-loop series chain, the far (non-ground) end of the
    // chain has no further explicit relationship — there is nowhere else
    // for its current to return except the same 0 V reference the loop
    // is drawn against, so the chain's first component's "before" node
    // is the reference node itself (closing the loop). This is specific
    // to the single-loop series shape this extractor supports, not a
    // general assumption — see the class doc comment.
    for (var i = 0; i < orderedNodeIds.length - 1; i++) {
      final engNodeId = orderedNodeIds[i];
      final engNode = graph.nodes[engNodeId]!;
      final fromNodeId = i == 0 ? 'gnd' : junctionIds[i - 1];
      final toNodeId = junctionIds[i];

      final modelId = engNode.metadata['componentModelId'] as String?;
      final componentId = 'component-instance-$engNodeId';
      components.add(
        ComponentInstance(
          id: componentId,
          sourceObjectId: engNodeId,
          componentModelId: modelId ?? '',
          parameters: const {},
        ),
      );
      branches.add(
        ElectricalBranch(
          id: 'branch-$engNodeId',
          componentInstanceId: componentId,
          fromNodeId: fromNodeId,
          toNodeId: toNodeId,
        ),
      );
      terminalConnections
        ..add(
          TerminalConnection(
            componentInstanceId: componentId,
            terminalId: 't1',
            electricalNodeId: fromNodeId,
          ),
        )
        ..add(
          TerminalConnection(
            componentInstanceId: componentId,
            terminalId: 't2',
            electricalNodeId: toNodeId,
          ),
        );
    }

    return ElectricalTopology(
      nodes: electricalNodes,
      components: components,
      branches: branches,
      terminalConnections: terminalConnections,
      referenceNodeId: 'gnd',
    );
  }
}
