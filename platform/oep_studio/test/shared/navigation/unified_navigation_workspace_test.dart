import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller.dart';
import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller_provider.dart';
import 'package:oep_studio/shared/navigation/unified_navigation.dart';
import 'package:oep_studio/workspace/workspace_tab.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-CONTEXT-001 — the one implemented cross-Surface
/// workflow: `goToDiagramElement` (already the real, existing mechanism
/// Search/Validation use to select a node/relationship on the shared,
/// Engine-owned `GraphSelection`) now opens/activates the Workspace's
/// own reserved Diagram tab instead of leaving the Workspace outright,
/// whenever the Workspace is the currently active destination. Outside
/// the Workspace, behavior is byte-for-byte unchanged (still
/// `context.go(StudioDestination.diagram.path)`).
///
/// These tests exercise the real `WorkspaceTabsController` provider and
/// a real, bootstrapped `DiagramStudioController`/`EngineeringEngine` —
/// no mocks — via a minimal two-route `GoRouter` standing in for
/// `app_router.dart`'s real route table (only `/workspace` and
/// `/diagram` matter for this workflow; a third, unrelated `/other`
/// route proves the fallback path is untouched).
void main() {
  Future<(DiagramStudioController, ProviderContainer)> bootstrap(WidgetTester tester, {required String initialLocation}) async {
    useIsolatedSettingsStorage();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: StudioDestination.workspace.path, builder: (context, state) => const _TriggerPage()),
        GoRoute(path: StudioDestination.diagram.path, builder: (context, state) => const Scaffold(body: Text('standalone-diagram'))),
        GoRoute(path: '/other', builder: (context, state) => const _TriggerPage()),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));

    late DiagramStudioController controller;
    await tester.runAsync(() async {
      controller = await container.read(diagramStudioControllerProvider.future);
    });
    await tester.pumpAndSettle();
    return (controller, container);
  }

  testWidgets('while the Workspace is active, selecting a diagram node opens the Diagram workspace tab instead of leaving the Workspace', (tester) async {
    final (controller, container) = await bootstrap(tester, initialLocation: StudioDestination.workspace.path);
    controller.addNode('battery', const Point2D(40, 40));
    final nodeId = controller.engine.editing.session.graph.nodes.keys.single;

    expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty, reason: 'source context: nothing open yet');

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    // canonical ID captured on the one shared, Engine-owned authority.
    expect(controller.engine.registry.selection.current.nodeIds, {nodeId});

    // destination Surface opens as a workspace tab, not a route change.
    final tabsController = container.read(workspaceTabsControllerProvider);
    expect(tabsController.tabs, hasLength(1));
    expect(tabsController.active!.isDiagram, isTrue);
    expect(tabsController.active!.surfaceId, WorkspaceTab.diagramSurfaceId);
    expect(find.text('standalone-diagram'), findsNothing, reason: 'must not have navigated away from the Workspace route');
  });

  testWidgets('triggering the same workflow twice activates the one Diagram tab, never a duplicate', (tester) async {
    final (controller, container) = await bootstrap(tester, initialLocation: StudioDestination.workspace.path);
    controller.addNode('battery', const Point2D(40, 40));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(container.read(workspaceTabsControllerProvider).tabs, hasLength(1));
  });

  testWidgets('a pre-existing workspace tab is left intact when the Diagram tab is opened alongside it', (tester) async {
    final (controller, container) = await bootstrap(tester, initialLocation: StudioDestination.workspace.path);
    controller.addNode('battery', const Point2D(40, 40));

    final tabsController = container.read(workspaceTabsControllerProvider);
    tabsController.openSurface('knowledge');

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(tabsController.tabs, hasLength(2), reason: 'source Surface tab must remain intact');
    expect(tabsController.tabs.map((t) => t.surfaceId), containsAll(['knowledge', WorkspaceTab.diagramSurfaceId]));
    expect(tabsController.active!.surfaceId, WorkspaceTab.diagramSurfaceId);

    // switching back to the original tab preserves it — it was never
    // removed, only deactivated.
    tabsController.activate(tabsController.tabs.first.id);
    expect(tabsController.tabs, hasLength(2));
  });

  testWidgets('outside the Workspace, the original context.go(diagram) behavior is unchanged', (tester) async {
    final (controller, container) = await bootstrap(tester, initialLocation: '/other');
    controller.addNode('battery', const Point2D(40, 40));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('standalone-diagram'), findsOneWidget);
    expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty, reason: 'the Workspace was never involved for this navigation');
  });

  testWidgets('an engine that has not started yet fails safely: no tab opens, no crash, no navigation', (tester) async {
    useIsolatedSettingsStorage();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: StudioDestination.workspace.path,
      routes: [
        GoRoute(path: StudioDestination.workspace.path, builder: (context, state) => const _TriggerPage()),
        GoRoute(path: StudioDestination.diagram.path, builder: (context, state) => const Scaffold(body: Text('standalone-diagram'))),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();

    // No `ensureEngineStarted`/controller bootstrap here at all — the
    // real "no engine yet" state `goToDiagramElement` already guards
    // against (`if (engine == null) return;`).
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);
    expect(find.text('standalone-diagram'), findsNothing);
  });
}

class _TriggerPage extends ConsumerWidget {
  const _TriggerPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () {
          final graph = ref.read(engineeringProjectServiceProvider).session?.graph;
          final nodeId = (graph != null && graph.nodes.isNotEmpty) ? graph.nodes.keys.first : 'no-such-node';
          goToDiagramElement(context, ref, nodeId: nodeId);
        },
        child: const Text('trigger'),
      ),
    );
  }
}
