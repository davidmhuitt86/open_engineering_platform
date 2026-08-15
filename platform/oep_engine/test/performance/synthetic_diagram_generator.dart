import 'dart:math';

import 'package:engineering_engine/engineering_engine.dart';

/// Synthetic diagram generation for performance benchmarking
/// (AP-DS-001B "Rendering Performance" / "Large Diagram Testing").
///
/// Builds an [EngineeringGraph] + [DiagramLayoutState] with a requested
/// total object count (nodes + relationships + annotations combined),
/// laid out on a deterministic grid so generation is O(n) and repeatable
/// across runs (no `GraphBuilder` incremental `copyWith` chaining here —
/// that pattern is O(n^2) for n nodes since every `withNode` call spreads
/// the whole map; fine for hand-written test fixtures, unusable at
/// 100,000-node benchmark scale, so this generator builds the backing
/// maps directly in one pass).
///
/// Object mix: roughly 40% nodes, 40% relationships (one wire per node
/// pair along a chain plus cross-links), 20% annotations — chosen to
/// resemble a real wiring diagram's ratio of symbols to connections to
/// labels, not to be load-bearing itself; the important thing for a
/// culling/hit-testing benchmark is realistic spatial distribution, not
/// exact proportions.
class SyntheticDiagram {
  final EngineeringGraph graph;
  final DiagramLayoutState layout;
  final int objectCount;

  const SyntheticDiagram({
    required this.graph,
    required this.layout,
    required this.objectCount,
  });

  static const double cellWidth = 160;
  static const double cellHeight = 120;
  static const double nodeSize = 100;

  /// Generates a synthetic diagram with approximately [totalObjects]
  /// combined nodes + relationships + annotations, arranged on a grid
  /// (`ceil(sqrt(nodeCount))` columns) so that spatial queries (viewport
  /// culling, box-select, nearest-wire hit-testing) exercise realistic,
  /// non-degenerate geometry rather than all-objects-at-origin.
  factory SyntheticDiagram.generate(int totalObjects, {int seed = 42}) {
    if (totalObjects <= 0) {
      return SyntheticDiagram(
        graph: EngineeringGraph.empty('synthetic-empty'),
        layout: DiagramLayoutState.empty,
        objectCount: 0,
      );
    }

    // Split the requested total across nodes/relationships/annotations
    // at roughly 40/40/20, with a floor of 1 node so relationships have
    // something to connect.
    final nodeCount = max(1, (totalObjects * 0.4).round());
    final relationshipCount = max(0, (totalObjects * 0.4).round());
    final annotationCount = max(0, totalObjects - nodeCount - relationshipCount);

    final random = Random(seed);
    final columns = sqrt(nodeCount).ceil().clamp(1, 1 << 20);

    final nodes = <String, EngineeringNode>{};
    final nodeIds = List<String>.generate(nodeCount, (i) => 'node-$i', growable: false);
    final positions = <String, Point2D>{};
    final categories = NodeCategory.values;

    for (var i = 0; i < nodeCount; i++) {
      final id = nodeIds[i];
      final column = i % columns;
      final row = i ~/ columns;
      nodes[id] = EngineeringNode(
        id: id,
        category: categories[i % categories.length],
        displayName: 'Node $i',
        properties: {'index': i, 'label': 'N$i'},
      );
      positions[id] = Point2D(column * cellWidth, row * cellHeight);
    }

    // Relationships: a deterministic mix of "chain" links (i -> i+1, always
    // spatially adjacent, like a real bus/harness run) and a smaller set of
    // pseudo-random cross-links (like a real diagram's occasional long
    // jumper), so wire lengths/counts-per-node resemble a real diagram
    // instead of either "all wires are 1 unit long" or "all wires are
    // random noise."
    final relationships = <String, EngineeringRelationship>{};
    for (var i = 0; i < relationshipCount; i++) {
      final id = 'rel-$i';
      final String source;
      final String target;
      if (i % 4 != 0 || nodeCount < 2) {
        final a = i % nodeCount;
        final b = (i + 1) % nodeCount;
        source = nodeIds[a];
        target = nodeIds[b];
      } else {
        final a = random.nextInt(nodeCount);
        var b = random.nextInt(nodeCount);
        if (b == a) b = (b + 1) % nodeCount;
        source = nodeIds[a];
        target = nodeIds[b];
      }
      relationships[id] = EngineeringRelationship(
        id: id,
        relationshipType: RelationshipType.values[i % RelationshipType.values.length],
        sourceNode: source,
        targetNode: target,
      );
    }

    final annotations = <String, DiagramAnnotation>{};
    for (var i = 0; i < annotationCount; i++) {
      final id = 'annotation-$i';
      final column = i % columns;
      final row = i ~/ columns;
      annotations[id] = DiagramAnnotation(
        id: id,
        type: AnnotationType.values[i % AnnotationType.values.length],
        text: 'Note $i',
        position: Point2D(column * cellWidth + cellWidth / 2, row * cellHeight - 40),
      );
    }

    final graph = EngineeringGraph(
      id: 'synthetic-$totalObjects',
      nodes: nodes,
      relationships: relationships,
    );
    final layout = DiagramLayoutState(positions: positions, annotations: annotations);

    return SyntheticDiagram(
      graph: graph,
      layout: layout,
      objectCount: nodeCount + relationshipCount + annotationCount,
    );
  }
}
