import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

class _FakeBridge implements FoundationBridgePort {
  @override
  Future<String> runtimeState() async => 'repositoryOpen';

  @override
  Future<GraphCommitResult> commitGraph(Map<String, Object?> serializedGraph) async {
    return const GraphCommitResult(nodeRepositoryIds: {}, relationshipRepositoryIds: {});
  }

  @override
  Future<Map<String, Object?>> loadCommittedGraph(String repositoryObjectId) async => {};
}

void main() {
  group('EngineRegistry.foundationBridge', () {
    test('is null when no FoundationBridgePort is registered — the Engine must operate with no bridge', () {
      final registry = EngineRegistry();
      expect(registry.foundationBridge, isNull);
    });

    test('resolves the registered FoundationBridgePort', () {
      final registry = EngineRegistry();
      final bridge = _FakeBridge();
      registry.register<FoundationBridgePort>(bridge);

      expect(registry.foundationBridge, same(bridge));
    });
  });

  group('GraphCommitResult', () {
    test('carries per-node/per-relationship ids and unmapped-item lists independently', () {
      const result = GraphCommitResult(
        nodeRepositoryIds: {'engine-node-1': 'foundation-object-1'},
        relationshipRepositoryIds: {'engine-rel-1': 'foundation-rel-1'},
        unmappedNodeIds: ['engine-node-2'],
        unmappedRelationshipIds: ['engine-rel-2'],
      );

      expect(result.nodeRepositoryIds['engine-node-1'], 'foundation-object-1');
      expect(result.relationshipRepositoryIds['engine-rel-1'], 'foundation-rel-1');
      expect(result.unmappedNodeIds, ['engine-node-2']);
      expect(result.unmappedRelationshipIds, ['engine-rel-2']);
      // Engine and Foundation identities are never the same value here —
      // the whole point of this type.
      expect(result.nodeRepositoryIds['engine-node-1'], isNot('engine-node-1'));
    });

    test('empty commit result is valid — nothing to commit is not an error', () {
      const result = GraphCommitResult(nodeRepositoryIds: {}, relationshipRepositoryIds: {});
      expect(result.nodeRepositoryIds, isEmpty);
      expect(result.relationshipRepositoryIds, isEmpty);
    });
  });
}
