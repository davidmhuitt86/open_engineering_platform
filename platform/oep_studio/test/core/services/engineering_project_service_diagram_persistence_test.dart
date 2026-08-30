import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';
import 'package:oep_studio/diagram_studio/host/engine_host.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-DIAGRAM-PERSISTENCE-001 — a fake `FoundationBridgePort`, same
/// fake-at-the-service-boundary pattern `diagram_repository_commit_action_test.dart`
/// already established, used here to prove `EngineeringProjectNotifier.
/// openDocument`'s new reconnect step calls the existing scoped
/// `loadCommittedGraph` path with exactly the restored `diagramRepositoryId`
/// — never enumerates anything, never re-commits.
class _FakeFoundationBridgePort implements FoundationBridgePort {
  _FakeFoundationBridgePort({this.shouldThrowOnLoad = false});

  final bool shouldThrowOnLoad;
  final List<String> loadCommittedGraphCalls = [];
  int commitGraphCalls = 0;

  @override
  Future<String> runtimeState() async => 'repositoryOpen';

  @override
  Future<GraphCommitResult> commitGraph(Map<String, Object?> serializedGraph) async {
    commitGraphCalls++;
    return const GraphCommitResult(nodeRepositoryIds: {}, relationshipRepositoryIds: {});
  }

  @override
  Future<Map<String, Object?>> loadCommittedGraph(String repositoryObjectId) async {
    loadCommittedGraphCalls.add(repositoryObjectId);
    if (shouldThrowOnLoad) {
      throw StateError("invalid diagram_id: no diagram with id '$repositoryObjectId'");
    }
    return {};
  }
}

class _FakeEngineeringProjectNotifier extends EngineeringProjectNotifier {
  _FakeEngineeringProjectNotifier(this._state);

  final EngineeringProjectState _state;

  @override
  EngineeringProjectState build(String arg) => _state;
}

void main() {
  late Directory tempDir;

  setUp(() {
    useIsolatedSettingsStorage();
    tempDir = Directory.systemTemp.createTempSync('engineering_project_persistence_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const committedNode = EngineeringNode(
    id: 'battery',
    category: NodeCategory.component,
    displayName: 'Battery',
    repositoryObjectId: 'foundation-object-1',
  );

  /// Everything here does real `dart:io` work (file read/write, asset
  /// loads via `EngineHost.create`) — all of it must run inside
  /// `tester.runAsync`, matching `diagram_repository_commit_action_test.dart`'s
  /// own `hostWithGraph` helper, or `testWidgets`'s fake-async zone hangs
  /// forever waiting on real I/O that its fake clock never advances.
  Future<({EngineHost host, ProviderContainer container, EngineeringGraph restored})> openRestored(
    WidgetTester tester,
    EngineeringGraph graphToPersist,
    _FakeFoundationBridgePort? bridge,
  ) async {
    late EngineHost host;
    late ProviderContainer container;
    late EngineeringGraph restored;
    await tester.runAsync(() async {
      final path = '${tempDir.path}/diagram.json';
      await DiagramDocument().saveAs(path, graphToPersist, DiagramLayoutState.empty);

      host = await EngineHost.create(foundationBridge: bridge);
      container = ProviderContainer(overrides: [
        engineeringProjectServiceFamily.overrideWith(
          () => _FakeEngineeringProjectNotifier(
            EngineeringProjectState(document: DiagramDocument(), engineHost: host, session: host.engine.editing.session),
          ),
        ),
      ]);

      await container.read(engineeringProjectServiceProvider.notifier).openDocument(path);
      // Read the live engine session directly, not `state.session` — the
      // fake notifier's pre-built initial state bypasses
      // `ensureEngineStarted()`'s `sessionChanges` subscription (it only
      // runs when `state.engineHost` is null), so `state.session` would
      // otherwise stay pinned to the host's original pre-open session.
      // `diagram_repository_commit_action_test.dart`'s own assertions
      // read `host.engine.editing.session.graph` for the same reason.
      restored = host.engine.editing.session.graph;
    });
    return (host: host, container: container, restored: restored);
  }

  testWidgets('restoring a committed graph uses the scoped loadCommittedGraph path with its diagramRepositoryId',
      (tester) async {
    final graph = EngineeringGraph(id: 'g1', nodes: {'battery': committedNode}, metadata: const {
      EngineeringGraph.diagramRepositoryIdMetadataKey: 'foundation-diagram-1',
    });
    final bridge = _FakeFoundationBridgePort();

    final result = await openRestored(tester, graph, bridge);
    addTearDown(result.container.dispose);

    expect(bridge.loadCommittedGraphCalls, ['foundation-diagram-1']);
    expect(bridge.commitGraphCalls, 0, reason: 'restoration must never re-commit or create a new diagram');
  });

  testWidgets('restoration does not call loadCommittedGraph for an uncommitted graph (no diagramRepositoryId)',
      (tester) async {
    final graph = EngineeringGraph(
      id: 'g1',
      nodes: {'n1': const EngineeringNode(id: 'n1', category: NodeCategory.component, displayName: 'X')},
    );
    final bridge = _FakeFoundationBridgePort();

    final result = await openRestored(tester, graph, bridge);
    addTearDown(result.container.dispose);

    expect(bridge.loadCommittedGraphCalls, isEmpty);
    expect(result.restored.diagramRepositoryId, isNull, reason: 'still uncommitted after restoration');
  });

  testWidgets('restored diagramRepositoryId is retained exactly, unmodified by the reconnect attempt', (tester) async {
    final graph = EngineeringGraph(id: 'g1', nodes: {'battery': committedNode}, metadata: const {
      EngineeringGraph.diagramRepositoryIdMetadataKey: 'foundation-diagram-1',
    });
    final bridge = _FakeFoundationBridgePort();

    final result = await openRestored(tester, graph, bridge);
    addTearDown(result.container.dispose);

    expect(result.restored.diagramRepositoryId, 'foundation-diagram-1');
  });

  testWidgets('an invalid/no-longer-resolving diagramRepositoryId is not replaced, fabricated, or dropped',
      (tester) async {
    final graph = EngineeringGraph(id: 'g1', nodes: {'battery': committedNode}, metadata: const {
      EngineeringGraph.diagramRepositoryIdMetadataKey: 'stale-diagram-id',
    });
    final bridge = _FakeFoundationBridgePort(shouldThrowOnLoad: true);

    // Must not throw out of openDocument — a reconnect failure is
    // swallowed, never surfaced as a crash or an app-level error.
    final result = await openRestored(tester, graph, bridge);
    addTearDown(result.container.dispose);

    expect(bridge.loadCommittedGraphCalls, ['stale-diagram-id']);
    // The id itself is preserved exactly as persisted — never silently
    // cleared or swapped for another value.
    expect(result.restored.diagramRepositoryId, 'stale-diagram-id');
  });

  testWidgets('restored graph content (nodes/relationships) is never overwritten by the reconnect load result',
      (tester) async {
    const relationship = EngineeringRelationship(
      id: 'r1',
      relationshipType: RelationshipType.connectedTo,
      sourceNode: 'battery',
      targetNode: 'ground',
    );
    final graph = EngineeringGraph(
      id: 'g1',
      nodes: {
        'battery': committedNode,
        'ground': const EngineeringNode(
          id: 'ground',
          category: NodeCategory.ground,
          displayName: 'Ground',
          repositoryObjectId: 'foundation-object-2',
        ),
      },
      relationships: {'r1': relationship},
      metadata: const {EngineeringGraph.diagramRepositoryIdMetadataKey: 'foundation-diagram-1'},
    );
    // Bridge's loadCommittedGraph returns `{}` (an empty serialized
    // graph, per the fake above) — if restoration used that result to
    // replace the session, the restored graph would end up empty.
    final bridge = _FakeFoundationBridgePort();

    final result = await openRestored(tester, graph, bridge);
    addTearDown(result.container.dispose);

    expect(result.restored.nodes.keys.toSet(), {'battery', 'ground'});
    expect(result.restored.relationships.keys, ['r1']);
    expect(result.restored.nodes['battery']!.displayName, 'Battery');
  });

  testWidgets('no Foundation bridge registered: restoration still succeeds and preserves the identity', (tester) async {
    final graph = EngineeringGraph(id: 'g1', nodes: {'battery': committedNode}, metadata: const {
      EngineeringGraph.diagramRepositoryIdMetadataKey: 'foundation-diagram-1',
    });

    final result = await openRestored(tester, graph, null); // no bridge at all
    addTearDown(result.container.dispose);

    expect(result.restored.diagramRepositoryId, 'foundation-diagram-1');
  });

  testWidgets('full continuity: commit-shaped result persisted, then restored, recovers the same diagramRepositoryId',
      (tester) async {
    // Simulates the existing commit write-back (EngineGraphCommitService)
    // having already stamped diagramRepositoryId into the graph before
    // it was ever saved — proving the commit -> persist -> restore chain
    // the completion criteria describe, through the real DiagramDocument
    // envelope and the real openDocument path (not a shortcut).
    final committedGraph = EngineeringGraph(
      id: 'g1',
      nodes: {'battery': committedNode},
    ).copyWith(metadata: const {EngineeringGraph.diagramRepositoryIdMetadataKey: 'foundation-diagram-9'});
    final bridge = _FakeFoundationBridgePort();

    final result = await openRestored(tester, committedGraph, bridge);
    addTearDown(result.container.dispose);

    expect(result.restored.diagramRepositoryId, 'foundation-diagram-9');
    expect(bridge.loadCommittedGraphCalls, ['foundation-diagram-9']);
  });
}
