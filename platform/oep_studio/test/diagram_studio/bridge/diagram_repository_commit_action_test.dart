import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/models/object_category.dart' as foundation;
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/core/objects/engineering_object_runtime.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';
import 'package:oep_studio/diagram_studio/host/engine_host.dart';
import 'package:oep_studio/diagram_studio/inspector/engineering_node_properties.dart';
import 'package:oep_studio/diagram_studio/inspector/engineering_relationship_properties.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-DIAGRAM-REPOSITORY-001 — the fake used to exercise
/// `commitDiagramToRepository` without a real Foundation DLL. Same fake-
/// at-the-service-boundary approach `studio_foundation_bridge_port_test.dart`
/// already established for the layer below this one — these tests don't
/// re-verify `StudioFoundationBridgePort`'s own id-correspondence/
/// rollback logic (already covered there), only that this UI wires to
/// `EngineGraphCommitService` and reports its result truthfully.
class _FakeFoundationBridgePort implements FoundationBridgePort {
  _FakeFoundationBridgePort({this.resultToReturn, this.shouldThrow = false});

  final GraphCommitResult? resultToReturn;
  final bool shouldThrow;

  @override
  Future<String> runtimeState() async => 'repositoryOpen';

  @override
  Future<GraphCommitResult> commitGraph(Map<String, Object?> serializedGraph) async {
    if (shouldThrow) throw StateError('simulated Foundation failure');
    return resultToReturn!;
  }

  @override
  Future<Map<String, Object?>> loadCommittedGraph(String repositoryObjectId) async => {};
}

class _FakeEngineeringProjectNotifier extends EngineeringProjectNotifier {
  _FakeEngineeringProjectNotifier(this._state);

  final EngineeringProjectState _state;

  @override
  EngineeringProjectState build() => _state;
}

void main() {
  Future<EngineHost> hostWithGraph(WidgetTester tester, EngineeringGraph graph, {FoundationBridgePort? bridge}) async {
    late EngineHost host;
    await tester.runAsync(() async {
      host = await EngineHost.create(foundationBridge: bridge);
      host.engine.beginEditingSession(graph);
    });
    return host;
  }

  Widget harness({required Widget child, required EngineHost host, DiagramDocument? document}) {
    return ProviderScope(
      overrides: [
        engineeringProjectServiceProvider.overrideWith(
          () => _FakeEngineeringProjectNotifier(
            EngineeringProjectState(
              document: document ?? DiagramDocument(),
              engineHost: host,
              session: host.engine.editing.session,
            ),
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  const unsavedNode = EngineeringNode(id: 'n1', category: NodeCategory.component, displayName: 'Battery');
  const savedNode = EngineeringNode(
    id: 'n1',
    category: NodeCategory.component,
    displayName: 'Battery',
    repositoryObjectId: 'foundation-object-1',
  );

  group('1. Repository action is rendered in the selected UI location', () {
    testWidgets('node inspector: unsaved node shows the commit action', (tester) async {
      final host = await hostWithGraph(tester, EngineeringGraph(id: 'g1', nodes: {'n1': unsavedNode}));
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: unsavedNode), host: host));

      expect(find.text('Commit Diagram to Repository'), findsOneWidget);
      expect(find.text('Go to Repository Object'), findsNothing);
    });

    testWidgets('node inspector: already-committed node shows the navigation link instead', (tester) async {
      final host = await hostWithGraph(tester, EngineeringGraph(id: 'g1', nodes: {'n1': savedNode}));
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: savedNode), host: host));

      expect(find.text('Go to Repository Object'), findsOneWidget);
      expect(find.text('Commit Diagram to Repository'), findsNothing);
    });

    testWidgets('relationship inspector: unsaved relationship shows the commit action', (tester) async {
      const relationship = EngineeringRelationship(
        id: 'r1',
        relationshipType: RelationshipType.connectedTo,
        sourceNode: 'n1',
        targetNode: 'n2',
      );
      final host = await hostWithGraph(tester, const EngineeringGraph(id: 'g1'));
      await tester.pumpWidget(harness(
        child: const EngineeringRelationshipProperties(relationship: relationship, sourceNodeName: 'A', targetNodeName: 'B'),
        host: host,
      ));

      expect(find.text('Commit Diagram to Repository'), findsOneWidget);
    });
  });

  group('2/3/4/5. commit action invokes the commit service and propagates ids', () {
    testWidgets('successful commit reports success and propagates node/relationship ids', (tester) async {
      final graph = EngineeringGraph(
        id: 'g1',
        nodes: {'n1': unsavedNode, 'n2': const EngineeringNode(id: 'n2', category: NodeCategory.component, displayName: 'Ground')},
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.connectedTo, sourceNode: 'n1', targetNode: 'n2'),
        },
      );
      final bridge = _FakeFoundationBridgePort(
        resultToReturn: const GraphCommitResult(
          nodeRepositoryIds: {'n1': 'foundation-object-1', 'n2': 'foundation-object-2'},
          relationshipRepositoryIds: {'r1': 'foundation-rel-1'},
        ),
      );
      final host = await hostWithGraph(tester, graph, bridge: bridge);
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: unsavedNode), host: host));

      await tester.tap(find.text('Commit Diagram to Repository'));
      await tester.pump(); // start the async action
      await tester.pump(const Duration(milliseconds: 50)); // let it complete + SnackBar animate in

      expect(find.textContaining('Committed 2 objects, 1 relationship'), findsOneWidget);
      // Node identity propagation (requirement 4).
      expect(host.engine.editing.session.graph.nodes['n1']!.repositoryObjectId, 'foundation-object-1');
      expect(host.engine.editing.session.graph.nodes['n2']!.repositoryObjectId, 'foundation-object-2');
      // Relationship identity propagation (requirement 5).
      expect(host.engine.editing.session.graph.relationships['r1']!.repositoryRelationshipId, 'foundation-rel-1');
      // Engine ids are never overwritten.
      expect(host.engine.editing.session.graph.nodes['n1']!.id, 'n1');
    });
  });

  group('6. already-persisted items are handled per existing service semantics', () {
    testWidgets('a node that already has a repositoryObjectId is not resubmitted', (tester) async {
      const secondNode = EngineeringNode(id: 'n2', category: NodeCategory.component, displayName: 'Ground');
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': savedNode, 'n2': secondNode});
      final bridge = _FakeFoundationBridgePort(
        resultToReturn: const GraphCommitResult(nodeRepositoryIds: {'n2': 'foundation-object-2'}, relationshipRepositoryIds: {}),
      );
      final host = await hostWithGraph(tester, graph, bridge: bridge);
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: secondNode), host: host));

      await tester.tap(find.text('Commit Diagram to Repository'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Committed 1 object, 0 relationships'), findsOneWidget);
      expect(host.engine.editing.session.graph.nodes['n1']!.repositoryObjectId, 'foundation-object-1', reason: 'unchanged');
      expect(host.engine.editing.session.graph.nodes['n2']!.repositoryObjectId, 'foundation-object-2');
    });
  });

  group('7/8. unmapped categories/types are reported, never fabricated', () {
    testWidgets('unmapped node category is reported in the SnackBar and left uncommitted', (tester) async {
      const wireNode = EngineeringNode(id: 'w1', category: NodeCategory.wire, displayName: 'Wire');
      final host = await hostWithGraph(
        tester,
        EngineeringGraph(id: 'g1', nodes: {'w1': wireNode}),
        bridge: _FakeFoundationBridgePort(
          resultToReturn: const GraphCommitResult(nodeRepositoryIds: {}, relationshipRepositoryIds: {}, unmappedNodeIds: ['w1']),
        ),
      );
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: wireNode), host: host));

      await tester.tap(find.text('Commit Diagram to Repository'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('1 node skipped'), findsOneWidget);
      expect(host.engine.editing.session.graph.nodes['w1']!.repositoryObjectId, isNull);
    });

    testWidgets('unmapped relationship type is reported in the SnackBar and left uncommitted', (tester) async {
      const relationship = EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.other, sourceNode: 'n1', targetNode: 'n2');
      final host = await hostWithGraph(
        tester,
        EngineeringGraph(id: 'g1', relationships: {'r1': relationship}),
        bridge: _FakeFoundationBridgePort(
          resultToReturn: const GraphCommitResult(
            nodeRepositoryIds: {},
            relationshipRepositoryIds: {},
            unmappedRelationshipIds: ['r1'],
          ),
        ),
      );
      await tester.pumpWidget(harness(
        child: const EngineeringRelationshipProperties(relationship: relationship, sourceNodeName: 'A', targetNodeName: 'B'),
        host: host,
      ));

      await tester.tap(find.text('Commit Diagram to Repository'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('1 relationship skipped'), findsOneWidget);
      expect(host.engine.editing.session.graph.relationships['r1']!.repositoryRelationshipId, isNull);
    });
  });

  group('9. commit failure reports failure without falsely claiming persistence', () {
    testWidgets('a thrown commit error shows a failure message and writes nothing back', (tester) async {
      final host = await hostWithGraph(
        tester,
        EngineeringGraph(id: 'g1', nodes: {'n1': unsavedNode}),
        bridge: _FakeFoundationBridgePort(shouldThrow: true),
      );
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: unsavedNode), host: host));

      await tester.tap(find.text('Commit Diagram to Repository'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Commit to Repository failed'), findsOneWidget);
      expect(find.textContaining('nothing was persisted'), findsOneWidget);
      expect(host.engine.editing.session.graph.nodes['n1']!.repositoryObjectId, isNull);
    });

    testWidgets('no Foundation repository open shows a truthful message, not a fabricated success', (tester) async {
      final host = await hostWithGraph(tester, EngineeringGraph(id: 'g1', nodes: {'n1': unsavedNode}));
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: unsavedNode), host: host));

      await tester.tap(find.text('Commit Diagram to Repository'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('No Foundation repository is open'), findsOneWidget);
    });
  });

  group('10. existing Repository navigation resolves the resulting Foundation identity', () {
    testWidgets('tapping "Go to Repository Object" resolves via the existing goToObject path', (tester) async {
      // Seed EngineeringObjectRuntime's cache (the same cache goToObject
      // already reads from) with an object matching the committed id —
      // exactly what `refreshRepository()` would populate in production
      // after a real commit.
      addTearDown(() => EngineeringObjectRuntime.instance
          .updateFromFoundationState(const FoundationServiceState(phase: FoundationConnectionPhase.connected)));
      EngineeringObjectRuntime.instance.updateFromFoundationState(
        FoundationServiceState(
          phase: FoundationConnectionPhase.connected,
          runtimeState: FoundationRuntimeState.repositoryOpen,
          objectList: const [
            EngineeringObjectSummary(
              objectId: 'foundation-object-1',
              category: foundation.ObjectCategory.component,
              name: 'Battery',
              author: 'test',
              version: '1',
            ),
          ],
        ),
      );

      final host = await hostWithGraph(tester, EngineeringGraph(id: 'g1', nodes: {'n1': savedNode}));
      final container = ProviderContainer(overrides: [
        engineeringProjectServiceProvider.overrideWith(
          () => _FakeEngineeringProjectNotifier(
            EngineeringProjectState(document: DiagramDocument(), engineHost: host, session: host.engine.editing.session),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: StudioDestination.workspace.path,
        routes: [
          GoRoute(
            path: StudioDestination.workspace.path,
            builder: (context, state) => const Scaffold(body: EngineeringNodeProperties(node: savedNode)),
          ),
          GoRoute(path: StudioDestination.objects.path, builder: (context, state) => const Scaffold(body: Text('standalone-objects'))),
        ],
      );

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
      await tester.pump();

      await tester.tap(find.text('Go to Repository Object'));
      await tester.pumpAndSettle();

      // Same assertion style as `engineering_validation_properties_test.dart`'s
      // own navigation-verification test: the Workspace was active, so
      // `openOrActivateDestination` (inside `goToObject`) opened a real
      // Workspace tab for the Objects surface rather than a bare route
      // swap — proving `goToObject` genuinely resolved the committed id
      // and ran its real navigation path, not a bespoke one.
      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.objects.name);
    });
  });

  group('11/persistence. commit persists the updated DiagramDocument (AP-OEP-DIAGRAM-REPOSITORY-001)', () {
    late Directory tempDir;

    setUp(() {
      useIsolatedSettingsStorage();
      tempDir = Directory.systemTemp.createTempSync('diagram_repository_commit_persistence_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    testWidgets('an already-saved document is re-saved with the committed identities, including diagramRepositoryId',
        (tester) async {
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': unsavedNode});
      late EngineHost host;
      late DiagramDocument document;
      final path = '${tempDir.path}/diagram.json';
      await tester.runAsync(() async {
        document = DiagramDocument();
        await document.saveAs(path, graph, DiagramLayoutState.empty);
        host = await EngineHost.create(
          foundationBridge: _FakeFoundationBridgePort(
            resultToReturn: const GraphCommitResult(
              nodeRepositoryIds: {'n1': 'foundation-object-1'},
              relationshipRepositoryIds: {},
              diagramRepositoryId: 'foundation-diagram-1',
            ),
          ),
        );
        host.engine.beginEditingSession(graph);
      });

      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: unsavedNode), host: host, document: document));
      // The commit action now performs real `dart:io` writes
      // (`persistCommittedGraph`) — `runAsync` lets that real I/O
      // actually complete; plain `pump(Duration)` only advances the
      // fake clock, which real file writes never observe.
      await tester.runAsync(() async {
        await tester.tap(find.text('Commit Diagram to Repository'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      });

      expect(document.isDirty, isFalse, reason: 'the commit\'s own save cleared dirty state');

      late Map<String, Object?> onDisk;
      await tester.runAsync(() async {
        final reopened = await DiagramDocument().open(path);
        onDisk = reopened.graph.toJson();
      });
      final onDiskGraph = EngineeringGraph.fromJson(onDisk);
      expect(onDiskGraph.nodes['n1']!.repositoryObjectId, 'foundation-object-1');
      expect(onDiskGraph.diagramRepositoryId, 'foundation-diagram-1');
    });

    testWidgets('a never-saved document is not implicitly saved by a commit', (tester) async {
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': unsavedNode});
      final host = await hostWithGraph(
        tester,
        graph,
        bridge: _FakeFoundationBridgePort(
          resultToReturn: const GraphCommitResult(nodeRepositoryIds: {'n1': 'foundation-object-1'}, relationshipRepositoryIds: {}),
        ),
      );
      final document = DiagramDocument(); // never saved — path stays null
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: unsavedNode), host: host, document: document));

      await tester.tap(find.text('Commit Diagram to Repository'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The commit itself still succeeded and updated the live session —
      // only the implicit save is skipped (no path to write a first-time
      // Save As to; the identities live on the session until the user's
      // own next save/save-as).
      expect(find.textContaining('Committed 1 object'), findsOneWidget);
      expect(document.path, isNull);
      expect(host.engine.editing.session.graph.nodes['n1']!.repositoryObjectId, 'foundation-object-1');
    });

    testWidgets('full continuity: commit -> persisted save -> reopen recovers diagramRepositoryId, without re-enumerating',
        (tester) async {
      final graph = EngineeringGraph(id: 'g1', nodes: {'n1': unsavedNode});
      late DiagramDocument document;
      final path = '${tempDir.path}/diagram.json';
      late EngineHost host;
      await tester.runAsync(() async {
        document = DiagramDocument();
        await document.saveAs(path, graph, DiagramLayoutState.empty);
        host = await EngineHost.create(
          foundationBridge: _FakeFoundationBridgePort(
            resultToReturn: const GraphCommitResult(
              nodeRepositoryIds: {'n1': 'foundation-object-1'},
              relationshipRepositoryIds: {},
              diagramRepositoryId: 'foundation-diagram-1',
            ),
          ),
        );
        host.engine.beginEditingSession(graph);
      });

      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: unsavedNode), host: host, document: document));
      await tester.runAsync(() async {
        await tester.tap(find.text('Commit Diagram to Repository'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      });

      // Reopen through the same real DiagramDocument.open() path
      // AP-OEP-DIAGRAM-PERSISTENCE-001's restoration relies on.
      late EngineeringGraph reopenedGraph;
      await tester.runAsync(() async {
        final reopened = await DiagramDocument().open(path);
        reopenedGraph = reopened.graph;
      });
      expect(reopenedGraph.diagramRepositoryId, 'foundation-diagram-1');
      expect(reopenedGraph.nodes['n1']!.repositoryObjectId, 'foundation-object-1');
    });
  });
}
