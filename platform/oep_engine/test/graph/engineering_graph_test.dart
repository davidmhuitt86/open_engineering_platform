import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('GraphBuilder', () {
    test('builds nodes and relationships fluently', () {
      final graph = (GraphBuilder(id: 'g1')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..connect('a', 'b', id: 'r1'))
          .build();

      expect(graph.id, 'g1');
      expect(graph.nodes.length, 2);
      expect(graph.relationships.length, 1);
      expect(graph.relationships['r1']!.sourceNode, 'a');
      expect(graph.relationships['r1']!.targetNode, 'b');
    });
  });

  group('EngineeringGraph', () {
    test('withoutNode cascades relationship removal', () {
      final graph = (GraphBuilder(id: 'g2')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..connect('a', 'b', id: 'r1'))
          .build();

      final updated = graph.withoutNode('a');
      expect(updated.nodes.containsKey('a'), isFalse);
      expect(updated.relationships.containsKey('r1'), isFalse);
    });

    test('round-trips through toJson/fromJson without runtime metadata', () {
      final graph = (GraphBuilder(id: 'g3')
            ..addNode(
              id: 'a',
              category: NodeCategory.component,
              displayName: 'A',
              symbolId: 'battery',
            )
            ..addNode(id: 'b', category: NodeCategory.ground, displayName: 'B')
            ..connect('a', 'b', id: 'r1', type: RelationshipType.grounds))
          .build();

      final json = graph.toJson();
      final restored = EngineeringGraph.fromJson(json);

      expect(restored.id, graph.id);
      expect(restored.nodes['a']!.displayName, 'A');
      expect(restored.nodes['a']!.symbolId, 'battery');
      expect(restored.relationships['r1']!.relationshipType, RelationshipType.grounds);
      // Runtime metadata is never persisted (SDD-027) — always resets to initial.
      expect(restored.nodes['a']!.runtime.selected, isFalse);
    });

    test('diagramRepositoryId reads from metadata and survives toJson/fromJson (AP-OEP-FOUNDATION-BRIDGE-003)', () {
      const graph = EngineeringGraph(
        id: 'g5',
        metadata: {EngineeringGraph.diagramRepositoryIdMetadataKey: 'foundation-diagram-1'},
      );

      expect(graph.diagramRepositoryId, 'foundation-diagram-1');
      expect(EngineeringGraph.fromJson(graph.toJson()).diagramRepositoryId, 'foundation-diagram-1');
    });

    test('diagramRepositoryId is null when never committed, not fabricated', () {
      const graph = EngineeringGraph(id: 'g6');
      expect(graph.diagramRepositoryId, isNull);
    });
  });

  group('GraphTraversal / GraphQuery', () {
    late EngineeringGraph graph;

    setUp(() {
      graph = (GraphBuilder(id: 'g4')
            ..addNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery')
            ..addNode(id: 'switch', category: NodeCategory.switchNode, displayName: 'Switch')
            ..addNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp')
            ..addNode(id: 'isolated', category: NodeCategory.component, displayName: 'Isolated')
            ..connect('battery', 'switch', id: 'r1')
            ..connect('switch', 'lamp', id: 'r2'))
          .build();
    });

    test('findPath returns shortest path', () {
      final path = GraphTraversal.findPath(graph, 'battery', 'lamp');
      expect(path, ['battery', 'switch', 'lamp']);
    });

    test('findPath returns null when unreachable', () {
      final path = GraphTraversal.findPath(graph, 'battery', 'isolated');
      expect(path, isNull);
    });

    test('reachableFrom includes connected nodes only', () {
      final reachable = GraphTraversal.reachableFrom(graph, 'battery');
      expect(reachable, {'battery', 'switch', 'lamp'});
      expect(reachable.contains('isolated'), isFalse);
    });

    test('isolatedNodes finds nodes with no relationships', () {
      expect(GraphTraversal.isolatedNodes(graph), ['isolated']);
    });

    test('GraphQuery.nodesByCategory filters correctly', () {
      final query = GraphQuery(graph);
      final switches = query.nodesByCategory(NodeCategory.switchNode);
      expect(switches.map((n) => n.id), ['switch']);
    });
  });
}
