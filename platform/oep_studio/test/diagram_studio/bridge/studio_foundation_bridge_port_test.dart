import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/models/object_category.dart';
import 'package:oep_studio/core/models/relationship_summary.dart';
import 'package:oep_studio/core/models/relationship_type.dart' as foundation;
import 'package:oep_studio/diagram_studio/bridge/foundation_commit_operations.dart';
import 'package:oep_studio/diagram_studio/bridge/studio_foundation_bridge_port.dart';

/// A fake [FoundationCommitOperations] — no native call, no real
/// `FoundationBridge` — for testing `StudioFoundationBridgePort`'s own
/// logic (id correspondence, skip-already-committed, rollback-on-
/// failure) in isolation. Mirrors the `LegacyV2Channel` fake precedent
/// already established in this codebase.
class _FakeFoundationCommitOperations implements FoundationCommitOperations {
  int _nextObjectId = 1;
  int _nextRelationshipId = 1;
  int _nextDiagramId = 1;
  bool _transactionActive = false;

  final List<String> callLog = [];
  final List<String> createdObjectNamesInOrder = [];
  final List<String> createdDiagramNamesInOrder = [];

  /// Set to make the Nth `createDiagram` call (1-indexed) throw.
  int? failCreateDiagramAtCall;

  /// Set to make the Nth `createObjectInDiagram` call (1-indexed) throw.
  int? failCreateObjectAtCall;

  /// Set to make the Nth `createRelationshipInDiagram` call (1-indexed) throw.
  int? failCreateRelationshipAtCall;

  int _createDiagramCalls = 0;
  int _createObjectCalls = 0;
  int _createRelationshipCalls = 0;

  @override
  void beginTransaction() {
    callLog.add('begin');
    _transactionActive = true;
  }

  @override
  void commitTransaction() {
    callLog.add('commit');
    _transactionActive = false;
  }

  @override
  void rollbackTransaction() {
    callLog.add('rollback');
    _transactionActive = false;
  }

  @override
  bool get isTransactionActive => _transactionActive;

  // AP-OEP-FOUNDATION-BRIDGE-002 — per-diagram fixtures for
  // `loadCommittedGraph`'s diagram-scoped load. `knownDiagramIds` models
  // `oep_diagram_get_objects`/`_get_relationships`'s own "invalid
  // diagram_id fails, valid-but-empty succeeds" distinction.
  //
  // AP-OEP-FOUNDATION-BRIDGE-003 — `createDiagram`/`createObjectInDiagram`/
  // `createRelationshipInDiagram` below register directly into these same
  // maps, mirroring real Foundation's own "a created member is
  // immediately visible to a scoped enumeration of its diagram" behavior
  // — this is what makes a commit-then-load round trip test meaningful
  // against this fake, not just against separately-seeded fixtures.
  final Set<String> knownDiagramIds = {};
  final Map<String, List<EngineeringObjectSummary>> objectsByDiagram = {};
  final Map<String, List<RelationshipSummary>> relationshipsByDiagram = {};

  @override
  EngineeringObjectSummary createDiagram({required String name, String description = '', String author = ''}) {
    _createDiagramCalls++;
    if (failCreateDiagramAtCall == _createDiagramCalls) {
      throw StateError('simulated diagram-create failure');
    }
    createdDiagramNamesInOrder.add(name);
    final id = 'foundation-diagram-${_nextDiagramId++}';
    callLog.add('createDiagram($name)->$id');
    knownDiagramIds.add(id);
    objectsByDiagram.putIfAbsent(id, () => []);
    relationshipsByDiagram.putIfAbsent(id, () => []);
    return EngineeringObjectSummary(objectId: id, category: ObjectCategory.diagram, name: name, author: author, version: '1');
  }

  @override
  EngineeringObjectSummary createObjectInDiagram({
    required ObjectCategory category,
    required String name,
    required String diagramId,
    String description = '',
    String author = '',
    List<String> tags = const [],
  }) {
    _createObjectCalls++;
    if (failCreateObjectAtCall == _createObjectCalls) {
      throw StateError('simulated object-create failure');
    }
    if (!knownDiagramIds.contains(diagramId)) {
      throw StateError("invalid diagram_id: no diagram with id '$diagramId'");
    }
    createdObjectNamesInOrder.add(name);
    final id = 'foundation-object-${_nextObjectId++}';
    callLog.add('createObjectInDiagram($name,$diagramId)->$id');
    final summary = EngineeringObjectSummary(objectId: id, category: category, name: name, author: author, version: '1');
    objectsByDiagram.putIfAbsent(diagramId, () => []).add(summary);
    return summary;
  }

  @override
  RelationshipSummary createRelationshipInDiagram({
    required String sourceObjectId,
    required String targetObjectId,
    required foundation.RelationshipType type,
    required String diagramId,
    String author = '',
    String description = '',
    required Map<String, String> objectNamesById,
  }) {
    _createRelationshipCalls++;
    if (failCreateRelationshipAtCall == _createRelationshipCalls) {
      throw StateError('simulated relationship-create failure');
    }
    if (!knownDiagramIds.contains(diagramId)) {
      throw StateError("invalid diagram_id: no diagram with id '$diagramId'");
    }
    final id = 'foundation-rel-${_nextRelationshipId++}';
    callLog.add('createRelationshipInDiagram($sourceObjectId->$targetObjectId,$diagramId)->$id');
    final summary = RelationshipSummary(
      relationshipId: id,
      sourceObjectId: sourceObjectId,
      targetObjectId: targetObjectId,
      sourceObjectName: objectNamesById[sourceObjectId] ?? sourceObjectId,
      targetObjectName: objectNamesById[targetObjectId] ?? targetObjectId,
      type: type,
      author: author,
    );
    relationshipsByDiagram.putIfAbsent(diagramId, () => []).add(summary);
    return summary;
  }

  @override
  List<EngineeringObjectSummary> listObjects() => const [];

  @override
  List<RelationshipSummary> listRelationships({required Map<String, String> objectNamesById}) => const [];

  @override
  List<EngineeringObjectSummary> listObjectsForDiagram(String diagramId) {
    callLog.add('listObjectsForDiagram($diagramId)');
    if (!knownDiagramIds.contains(diagramId)) {
      throw StateError("invalid diagram_id: no diagram with id '$diagramId'");
    }
    return objectsByDiagram[diagramId] ?? const [];
  }

  @override
  List<RelationshipSummary> listRelationshipsForDiagram(
    String diagramId, {
    required Map<String, String> objectNamesById,
  }) {
    callLog.add('listRelationshipsForDiagram($diagramId)');
    if (!knownDiagramIds.contains(diagramId)) {
      throw StateError("invalid diagram_id: no diagram with id '$diagramId'");
    }
    return relationshipsByDiagram[diagramId] ?? const [];
  }
}

EngineeringNode _node(String id, {NodeCategory category = NodeCategory.component, String? repositoryObjectId}) {
  return EngineeringNode(id: id, category: category, displayName: id, repositoryObjectId: repositoryObjectId);
}

EngineeringRelationship _relationship(
  String id, {
  required String source,
  required String target,
  RelationshipType type = RelationshipType.connectedTo,
  String? repositoryRelationshipId,
}) {
  return EngineeringRelationship(
    id: id,
    relationshipType: type,
    sourceNode: source,
    targetNode: target,
    repositoryRelationshipId: repositoryRelationshipId,
  );
}

void main() {
  group('StudioFoundationBridgePort.commitGraph', () {
    test('successful commit returns correct per-node/per-relationship id correspondence', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'n1': _node('n1'), 'n2': _node('n2')},
        relationships: {'r1': _relationship('r1', source: 'n1', target: 'n2')},
      );

      final result = await port.commitGraph(graph.toJson());

      expect(result.nodeRepositoryIds['n1'], 'foundation-object-1');
      expect(result.nodeRepositoryIds['n2'], 'foundation-object-2');
      expect(result.relationshipRepositoryIds['r1'], 'foundation-rel-1');
      // Engine ids are never equated with Foundation ids.
      expect(result.nodeRepositoryIds['n1'], isNot('n1'));
      expect(ops.callLog.first, 'begin');
      expect(ops.callLog.last, 'commit');
    });

    test('input-order correspondence: nodes are created and mapped in submission order', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'a': _node('a'), 'b': _node('b'), 'c': _node('c')},
      );

      final result = await port.commitGraph(graph.toJson());

      expect(ops.createdObjectNamesInOrder, ['a', 'b', 'c']);
      expect(result.nodeRepositoryIds['a'], 'foundation-object-1');
      expect(result.nodeRepositoryIds['b'], 'foundation-object-2');
      expect(result.nodeRepositoryIds['c'], 'foundation-object-3');
    });

    test('object-creation failure rolls back and returns no ids', () async {
      final ops = _FakeFoundationCommitOperations()..failCreateObjectAtCall = 2;
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(id: 'g1', nodes: {'a': _node('a'), 'b': _node('b')});

      await expectLater(port.commitGraph(graph.toJson()), throwsA(isA<StateError>()));
      expect(ops.callLog, contains('rollback'));
    });

    test('relationship-creation failure rolls back and returns no ids', () async {
      final ops = _FakeFoundationCommitOperations()..failCreateRelationshipAtCall = 1;
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'n1': _node('n1'), 'n2': _node('n2')},
        relationships: {'r1': _relationship('r1', source: 'n1', target: 'n2')},
      );

      await expectLater(port.commitGraph(graph.toJson()), throwsA(isA<StateError>()));
      expect(ops.callLog, contains('rollback'));
    });

    test('already-committed nodes/relationships are skipped, not resubmitted (duplicate/retry)', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {
          'n1': _node('n1', repositoryObjectId: 'already-committed-1'),
          'n2': _node('n2'),
        },
      );

      final result = await port.commitGraph(graph.toJson());

      expect(result.nodeRepositoryIds.containsKey('n1'), isFalse);
      expect(result.nodeRepositoryIds['n2'], 'foundation-object-1');
      expect(ops.createdObjectNamesInOrder, ['n2']);
    });

    test('a node whose category has no Foundation mapping is excluded, not fabricated', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'w': _node('w', category: NodeCategory.wire)},
      );

      final result = await port.commitGraph(graph.toJson());

      expect(result.nodeRepositoryIds, isEmpty);
      expect(result.unmappedNodeIds, ['w']);
      expect(ops.callLog, isEmpty); // no transaction even opened for an all-excluded graph
    });

    test('empty graph commits without error and without opening a transaction', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      final result = await port.commitGraph(const EngineeringGraph(id: 'g1').toJson());

      expect(result.nodeRepositoryIds, isEmpty);
      expect(result.relationshipRepositoryIds, isEmpty);
      expect(ops.callLog, isEmpty);
    });

    test('no repository open throws rather than fabricating a result', () async {
      final port = StudioFoundationBridgePort(operationsResolver: () => null, runtimeStateResolver: () => 'initialized');
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': _node('n1')});

      await expectLater(port.commitGraph(graph.toJson()), throwsStateError);
    });
  });

  group('StudioFoundationBridgePort.commitGraph diagram identity (AP-OEP-FOUNDATION-BRIDGE-003)', () {
    test('first commit creates exactly one diagram identity', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': _node('n1')});

      final result = await port.commitGraph(graph.toJson());

      expect(ops.createdDiagramNamesInOrder.length, 1);
      expect(result.diagramRepositoryId, 'foundation-diagram-1');
    });

    test('newly-created objects belong to the established diagram', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': _node('n1'), 'n2': _node('n2')});

      final result = await port.commitGraph(graph.toJson());

      expect(ops.objectsByDiagram[result.diagramRepositoryId]!.map((o) => o.objectId).toSet(),
          {result.nodeRepositoryIds['n1'], result.nodeRepositoryIds['n2']});
    });

    test('newly-created relationships belong to the established diagram', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'n1': _node('n1'), 'n2': _node('n2')},
        relationships: {'r1': _relationship('r1', source: 'n1', target: 'n2')},
      );

      final result = await port.commitGraph(graph.toJson());

      expect(ops.relationshipsByDiagram[result.diagramRepositoryId]!.map((r) => r.relationshipId).toSet(),
          {result.relationshipRepositoryIds['r1']});
    });

    test('commit followed by scoped loadCommittedGraph round-trips correctly', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'n1': _node('n1'), 'n2': _node('n2')},
        relationships: {'r1': _relationship('r1', source: 'n1', target: 'n2')},
      );

      final commitResult = await port.commitGraph(graph.toJson());
      final loaded = EngineeringGraph.fromJson(await port.loadCommittedGraph(commitResult.diagramRepositoryId!));

      expect(loaded.nodes.keys.toSet(), commitResult.nodeRepositoryIds.values.toSet());
      expect(loaded.relationships.keys.toSet(), commitResult.relationshipRepositoryIds.values.toSet());
      for (final node in loaded.nodes.values) {
        expect(node.repositoryObjectId, node.id); // real Foundation id, never fabricated
      }
      for (final relationship in loaded.relationships.values) {
        expect(relationship.repositoryRelationshipId, relationship.id);
      }
    });

    test('two separately committed graphs remain isolated under scoped load', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      final resultA = await port.commitGraph(EngineeringGraph(id: 'gA', nodes: {'a1': _node('a1')}).toJson());
      final resultB = await port.commitGraph(EngineeringGraph(id: 'gB', nodes: {'b1': _node('b1')}).toJson());

      expect(resultA.diagramRepositoryId, isNot(resultB.diagramRepositoryId));
      final loadedA = EngineeringGraph.fromJson(await port.loadCommittedGraph(resultA.diagramRepositoryId!));
      final loadedB = EngineeringGraph.fromJson(await port.loadCommittedGraph(resultB.diagramRepositoryId!));

      expect(loadedA.nodes.keys, [resultA.nodeRepositoryIds['a1']]);
      expect(loadedB.nodes.keys, [resultB.nodeRepositoryIds['b1']]);
    });

    test('recommitting an unchanged, already-fully-committed graph creates no duplicate diagram or members', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': _node('n1')});

      final firstResult = await port.commitGraph(graph.toJson());
      // Simulate `EngineGraphCommitService`'s write-back: the node now
      // carries its repositoryObjectId, and the graph carries its
      // diagramRepositoryId, exactly as a real second call would see it.
      final committedGraph = graph
          .withNode(graph.nodes['n1']!.copyWith(repositoryObjectId: firstResult.nodeRepositoryIds['n1']))
          .copyWith(metadata: {EngineeringGraph.diagramRepositoryIdMetadataKey: firstResult.diagramRepositoryId});

      final secondResult = await port.commitGraph(committedGraph.toJson());

      expect(ops.createdDiagramNamesInOrder.length, 1); // still just the one from the first commit
      expect(ops.createdObjectNamesInOrder.length, 1);
      expect(secondResult.diagramRepositoryId, firstResult.diagramRepositoryId);
      expect(secondResult.nodeRepositoryIds, isEmpty); // nothing new to report
    });

    test('adding a new node after the first commit extends the existing diagram rather than creating another', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': _node('n1')});

      final firstResult = await port.commitGraph(graph.toJson());
      final committedGraph = graph
          .withNode(graph.nodes['n1']!.copyWith(repositoryObjectId: firstResult.nodeRepositoryIds['n1']))
          .copyWith(metadata: {EngineeringGraph.diagramRepositoryIdMetadataKey: firstResult.diagramRepositoryId})
          .withNode(_node('n2'));

      final secondResult = await port.commitGraph(committedGraph.toJson());

      expect(ops.createdDiagramNamesInOrder.length, 1); // no second diagram
      expect(secondResult.diagramRepositoryId, firstResult.diagramRepositoryId);
      expect(secondResult.nodeRepositoryIds.keys, ['n2']);
      expect(ops.objectsByDiagram[firstResult.diagramRepositoryId]!.length, 2); // n1 + n2, same diagram
    });

    test('transaction failure leaves no partially propagated identity', () async {
      final ops = _FakeFoundationCommitOperations()..failCreateObjectAtCall = 2;
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(id: 'g1', nodes: {'a': _node('a'), 'b': _node('b')});

      await expectLater(port.commitGraph(graph.toJson()), throwsA(isA<StateError>()));
      // No GraphCommitResult was ever returned to propagate a diagram id
      // or any node/relationship id onto — the caller sees only the
      // thrown exception, matching the atomic-or-fails contract.
      expect(ops.callLog, contains('rollback'));
    });

    test('empty graph does not create a diagram (existing no-op semantics preserved)', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      final result = await port.commitGraph(const EngineeringGraph(id: 'g1').toJson());

      expect(result.diagramRepositoryId, isNull);
      expect(ops.createdDiagramNamesInOrder, isEmpty);
    });

    test('a graph with only unmapped categories/types does not create a diagram', () async {
      final ops = _FakeFoundationCommitOperations();
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');
      final graph = EngineeringGraph(id: 'g1', nodes: {'w': _node('w', category: NodeCategory.wire)});

      final result = await port.commitGraph(graph.toJson());

      expect(result.diagramRepositoryId, isNull);
      expect(result.unmappedNodeIds, ['w']);
      expect(ops.createdDiagramNamesInOrder, isEmpty);
    });
  });

  group('StudioFoundationBridgePort.loadCommittedGraph (AP-OEP-FOUNDATION-BRIDGE-002)', () {
    EngineeringObjectSummary object(String id, {String name = 'obj'}) =>
        EngineeringObjectSummary(objectId: id, category: ObjectCategory.component, name: name, author: '', version: '1');

    RelationshipSummary relationship(String id, {required String source, required String target}) =>
        RelationshipSummary(
          relationshipId: id,
          sourceObjectId: source,
          targetObjectId: target,
          sourceObjectName: source,
          targetObjectName: target,
          type: foundation.RelationshipType.connectedTo,
          author: '',
        );

    test('uses diagram-scoped object retrieval, never the whole-repository listObjects', () async {
      final ops = _FakeFoundationCommitOperations()..knownDiagramIds.add('diagram-a');
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      await port.loadCommittedGraph('diagram-a');

      expect(ops.callLog, contains('listObjectsForDiagram(diagram-a)'));
      expect(ops.callLog.any((c) => c.startsWith('listObjects(')), isFalse);
      expect(ops.callLog, isNot(contains('listObjects')));
    });

    test('uses diagram-scoped relationship retrieval, never the whole-repository listRelationships', () async {
      final ops = _FakeFoundationCommitOperations()..knownDiagramIds.add('diagram-a');
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      await port.loadCommittedGraph('diagram-a');

      expect(ops.callLog, contains('listRelationshipsForDiagram(diagram-a)'));
    });

    test('diagram A cannot load diagram B\'s objects or relationships; multiple diagrams coexist', () async {
      final ops = _FakeFoundationCommitOperations()
        ..knownDiagramIds.addAll(['diagram-a', 'diagram-b'])
        ..objectsByDiagram['diagram-a'] = [object('a-battery'), object('a-ground')]
        ..objectsByDiagram['diagram-b'] = [object('b-fuse')]
        ..relationshipsByDiagram['diagram-a'] = [relationship('a-wire', source: 'a-battery', target: 'a-ground')]
        ..relationshipsByDiagram['diagram-b'] = [];
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      final graphAJson = await port.loadCommittedGraph('diagram-a');
      final graphA = EngineeringGraph.fromJson(graphAJson);
      final graphBJson = await port.loadCommittedGraph('diagram-b');
      final graphB = EngineeringGraph.fromJson(graphBJson);

      expect(graphA.nodes.keys.toSet(), {'a-battery', 'a-ground'});
      expect(graphA.relationships.keys.toSet(), {'a-wire'});
      expect(graphB.nodes.keys.toSet(), {'b-fuse'});
      expect(graphB.relationships, isEmpty);
      // Cross-diagram leakage in either direction would fail the two lines above.
    });

    test('empty diagram returns an empty graph successfully, not an error', () async {
      final ops = _FakeFoundationCommitOperations()..knownDiagramIds.add('diagram-empty');
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      final graphJson = await port.loadCommittedGraph('diagram-empty');
      final graph = EngineeringGraph.fromJson(graphJson);

      expect(graph.nodes, isEmpty);
      expect(graph.relationships, isEmpty);
    });

    test('Foundation IDs are preserved end-to-end: repositoryObjectId/repositoryRelationshipId equal the Foundation id', () async {
      final ops = _FakeFoundationCommitOperations()
        ..knownDiagramIds.add('diagram-a')
        ..objectsByDiagram['diagram-a'] = [object('foundation-obj-77')]
        ..relationshipsByDiagram['diagram-a'] = [
          relationship('foundation-rel-9', source: 'foundation-obj-77', target: 'foundation-obj-77'),
        ];
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      final graph = EngineeringGraph.fromJson(await port.loadCommittedGraph('diagram-a'));

      final node = graph.nodes['foundation-obj-77']!;
      expect(node.repositoryObjectId, 'foundation-obj-77');
      expect(node.id, 'foundation-obj-77'); // never fabricated or position-derived
      final rel = graph.relationships['foundation-rel-9']!;
      expect(rel.repositoryRelationshipId, 'foundation-rel-9');
    });

    test('invalid/nonexistent diagram id fails rather than returning an empty graph', () async {
      final ops = _FakeFoundationCommitOperations(); // 'bogus-diagram' never registered
      final port = StudioFoundationBridgePort(operationsResolver: () => ops, runtimeStateResolver: () => 'repositoryOpen');

      await expectLater(port.loadCommittedGraph('bogus-diagram'), throwsA(isA<StateError>()));
    });

    test('no repository open throws rather than fabricating a result', () async {
      final port = StudioFoundationBridgePort(operationsResolver: () => null, runtimeStateResolver: () => 'initialized');

      await expectLater(port.loadCommittedGraph('diagram-a'), throwsStateError);
    });
  });
}
