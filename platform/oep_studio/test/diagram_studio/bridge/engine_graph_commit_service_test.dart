import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
import 'package:engineering_engine/core/events/engine_event_bus.dart';

import 'package:oep_studio/diagram_studio/bridge/engine_graph_commit_service.dart';

/// A fake [FoundationBridgePort] — no Foundation/FFI involved at all —
/// for testing [EngineGraphCommitService]'s own write-back logic in
/// isolation from `StudioFoundationBridgePort`'s commit logic (already
/// covered by `studio_foundation_bridge_port_test.dart`).
class _FakeFoundationBridgePort implements FoundationBridgePort {
  _FakeFoundationBridgePort({this.resultToReturn, this.shouldThrow = false});

  final GraphCommitResult? resultToReturn;
  final bool shouldThrow;
  Map<String, Object?>? lastSubmittedGraph;

  @override
  Future<String> runtimeState() async => 'repositoryOpen';

  @override
  Future<GraphCommitResult> commitGraph(Map<String, Object?> serializedGraph) async {
    lastSubmittedGraph = serializedGraph;
    if (shouldThrow) throw StateError('simulated Foundation failure');
    return resultToReturn!;
  }

  @override
  Future<Map<String, Object?>> loadCommittedGraph(String repositoryObjectId) async => {};
}

void main() {
  late GraphService graphService;

  setUp(() {
    final serialization = JsonFileSerializationProvider();
    graphService = GraphService(
      provider: InMemoryGraphProvider(serialization: serialization),
      validation: ValidationService(symbols: SymbolLibrary(symbolsDirectory: 'assets/symbols')),
      events: EngineEventBus(),
    );
  });

  group('EngineGraphCommitService.commit', () {
    test('successful commit writes repositoryObjectId/repositoryRelationshipId back onto the graph', () async {
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {
          'n1': const EngineeringNode(id: 'n1', category: NodeCategory.component, displayName: 'n1'),
          'n2': const EngineeringNode(id: 'n2', category: NodeCategory.component, displayName: 'n2'),
        },
        relationships: {
          'r1': const EngineeringRelationship(
            id: 'r1',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'n1',
            targetNode: 'n2',
          ),
        },
      );
      final bridge = _FakeFoundationBridgePort(
        resultToReturn: const GraphCommitResult(
          nodeRepositoryIds: {'n1': 'foundation-object-1', 'n2': 'foundation-object-2'},
          relationshipRepositoryIds: {'r1': 'foundation-rel-1'},
        ),
      );

      final outcome = await EngineGraphCommitService.commit(bridge: bridge, graph: graph, graphService: graphService);

      expect(outcome.graph.nodes['n1']!.repositoryObjectId, 'foundation-object-1');
      expect(outcome.graph.nodes['n2']!.repositoryObjectId, 'foundation-object-2');
      expect(outcome.graph.relationships['r1']!.repositoryRelationshipId, 'foundation-rel-1');
      expect(outcome.result.nodeRepositoryIds, {'n1': 'foundation-object-1', 'n2': 'foundation-object-2'});
      // Engine ids are never overwritten or equated with Foundation ids.
      expect(outcome.graph.nodes['n1']!.id, 'n1');
      expect(outcome.graph.nodes['n1']!.id, isNot(outcome.graph.nodes['n1']!.repositoryObjectId));
    });

    test('failed commit leaves the graph completely untouched', () async {
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'n1': const EngineeringNode(id: 'n1', category: NodeCategory.component, displayName: 'n1')},
      );
      final bridge = _FakeFoundationBridgePort(shouldThrow: true);

      await expectLater(
        EngineGraphCommitService.commit(bridge: bridge, graph: graph, graphService: graphService),
        throwsA(isA<StateError>()),
      );
      // The caller's original `graph` object is unmodified (immutable
      // model) — nothing was ever written back for a failed commit.
      expect(graph.nodes['n1']!.repositoryObjectId, isNull);
    });

    test('a GraphCommitResult referencing an id not in the submitted graph is ignored, not fabricated', () async {
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'n1': const EngineeringNode(id: 'n1', category: NodeCategory.component, displayName: 'n1')},
      );
      final bridge = _FakeFoundationBridgePort(
        resultToReturn: const GraphCommitResult(
          nodeRepositoryIds: {'not-in-graph': 'foundation-object-1'},
          relationshipRepositoryIds: {},
        ),
      );

      final outcome = await EngineGraphCommitService.commit(bridge: bridge, graph: graph, graphService: graphService);

      expect(outcome.graph.nodes['n1']!.repositoryObjectId, isNull);
      expect(outcome.graph.nodes.containsKey('not-in-graph'), isFalse);
    });
  });
}
