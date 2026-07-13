import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
// EngineEventBus is internal (SDD-026: "Events remain internal to the
// Engineering Engine") and intentionally not exported from the public
// barrel — tests reach it via its implementation path directly.
import 'package:engineering_engine/core/events/engine_event_bus.dart';

void main() {
  group('GraphService', () {
    late Directory tempDir;
    late GraphService service;
    late SymbolLibrary symbols;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oep_engine_test_');
      symbols = SymbolLibrary(symbolsDirectory: 'assets/symbols');
      await symbols.initialize();
      final serialization = JsonFileSerializationProvider();
      final provider = InMemoryGraphProvider(serialization: serialization);
      service = GraphService(
        provider: provider,
        validation: ValidationService(symbols: symbols),
        events: EngineEventBus(),
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('create produces an empty graph', () async {
      final graph = await service.create(id: 'demo');
      expect(graph.id, 'demo');
      expect(graph.nodes, isEmpty);
    });

    test('addNode / addRelationship / removeNode mutate a new graph copy', () async {
      var graph = await service.create(id: 'demo');
      final node = EngineeringNode(
        id: 'n1',
        category: NodeCategory.component,
        displayName: 'Node 1',
      );
      graph = await service.addNode(graph, node);
      expect(graph.nodes.containsKey('n1'), isTrue);

      final node2 = EngineeringNode(
        id: 'n2',
        category: NodeCategory.component,
        displayName: 'Node 2',
      );
      graph = await service.addNode(graph, node2);
      graph = await service.addRelationship(
        graph,
        const EngineeringRelationship(
          id: 'r1',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'n1',
          targetNode: 'n2',
        ),
      );
      expect(graph.relationships.containsKey('r1'), isTrue);

      graph = await service.removeNode(graph, 'n1');
      expect(graph.nodes.containsKey('n1'), isFalse);
      expect(graph.relationships.containsKey('r1'), isFalse);
    });

    test('validate delegates to the ValidationProvider', () async {
      var graph = await service.create(id: 'demo');
      graph = await service.addNode(
        graph,
        const EngineeringNode(
          id: 'n1',
          category: NodeCategory.component,
          displayName: 'Floating node',
        ),
      );
      final report = service.validate(graph);
      expect(report.findings.any((f) => f.code == 'floating_node'), isTrue);
      expect(report.findings.any((f) => f.code == 'missing_symbol'), isTrue);
    });

    test('save/load round-trips through JSON', () async {
      final path = '${tempDir.path}/graphs/roundtrip.json';
      var graph = await service.create(id: 'demo');
      graph = await service.addNode(
        graph,
        const EngineeringNode(
          id: 'n1',
          category: NodeCategory.component,
          displayName: 'Node 1',
          symbolId: 'battery',
        ),
      );

      final serialization = JsonFileSerializationProvider();
      await serialization.write(graph, path);
      final restored = await serialization.read(path);

      expect(restored.nodes['n1']!.displayName, 'Node 1');
      expect(restored.nodes['n1']!.symbolId, 'battery');
    });
  });
}
