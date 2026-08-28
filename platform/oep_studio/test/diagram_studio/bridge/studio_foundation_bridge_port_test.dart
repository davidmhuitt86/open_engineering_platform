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
  bool _transactionActive = false;

  final List<String> callLog = [];
  final List<String> createdObjectNamesInOrder = [];

  /// Set to make the Nth `createObject` call (1-indexed) throw.
  int? failCreateObjectAtCall;

  /// Set to make the Nth `createRelationship` call (1-indexed) throw.
  int? failCreateRelationshipAtCall;

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

  @override
  EngineeringObjectSummary createObject({
    required ObjectCategory category,
    required String name,
    String description = '',
    String author = '',
    List<String> tags = const [],
  }) {
    _createObjectCalls++;
    if (failCreateObjectAtCall == _createObjectCalls) {
      throw StateError('simulated object-create failure');
    }
    createdObjectNamesInOrder.add(name);
    final id = 'foundation-object-${_nextObjectId++}';
    callLog.add('createObject($name)->$id');
    return EngineeringObjectSummary(objectId: id, category: category, name: name, author: author, version: '1');
  }

  @override
  RelationshipSummary createRelationship({
    required String sourceObjectId,
    required String targetObjectId,
    required foundation.RelationshipType type,
    String author = '',
    String description = '',
    required Map<String, String> objectNamesById,
  }) {
    _createRelationshipCalls++;
    if (failCreateRelationshipAtCall == _createRelationshipCalls) {
      throw StateError('simulated relationship-create failure');
    }
    final id = 'foundation-rel-${_nextRelationshipId++}';
    callLog.add('createRelationship($sourceObjectId->$targetObjectId)->$id');
    return RelationshipSummary(
      relationshipId: id,
      sourceObjectId: sourceObjectId,
      targetObjectId: targetObjectId,
      sourceObjectName: objectNamesById[sourceObjectId] ?? sourceObjectId,
      targetObjectName: objectNamesById[targetObjectId] ?? targetObjectId,
      type: type,
      author: author,
    );
  }

  @override
  List<EngineeringObjectSummary> listObjects() => const [];

  @override
  List<RelationshipSummary> listRelationships({required Map<String, String> objectNamesById}) => const [];
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
}
