import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oep_studio/app/studio_shell.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/knowledge/workspaces/knowledge_studio_page.dart';
import 'package:oep_studio/workspace/engineering_workspace_page.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-ROUTING-001 — proves the fix for
/// AP-OEP-WORKSPACE-LIFECYCLE-001's own documented finding: leaving
/// `/workspace` for another route and returning used to rebuild
/// `EngineeringWorkspacePage` as a brand new widget `Element`
/// (`workspace_lifecycle_test.dart`'s own "Phase 8 finding" test, still
/// present and still passing — it now documents the *old*, no-longer-
/// current behavior of a route shape this package intentionally leaves
/// otherwise unchanged for every non-Workspace destination).
///
/// `StudioShell` now builds `EngineeringWorkspacePage` exactly once (a
/// `late final` field, `_workspaceHost`) and only toggles its
/// `Offstage` visibility — mirroring the same pattern
/// `AP-OEP-DIAGRAM-UX-001` already proved for Diagram Studio's own
/// `_diagramStudioHost`. This file uses a real two-route `GoRouter`
/// with a `ShellRoute` wrapping `StudioShell`, structurally identical to
/// `app_router.dart`'s real route table, so the test exercises the
/// actual mechanism that makes this work (`ShellRoute` keeping its own
/// builder's returned widget's `State` alive across sibling route
/// changes) rather than assuming it.
///
/// Every `find.byType(EngineeringWorkspacePage)` here while another
/// Studio is showing passes `skipOffstage: false` — Flutter's finders
/// default to `skipOffstage: true`, so the *whole point* of this
/// package's fix (kept mounted, merely `Offstage`-hidden) requires
/// disabling that default; the earlier debugging pass that wrote this
/// test found this out the hard way (`debugDumpApp()` — which does not
/// skip offstage — showed the widget the whole time).
void main() {
  GoRouter buildRouter() => GoRouter(
        initialLocation: StudioDestination.workspace.path,
        routes: [
          ShellRoute(
            builder: (context, state, child) => StudioShell(
              selected: StudioDestination.fromPath(state.uri.path),
              onSelect: (d) => context.go(d.path),
              child: child,
            ),
            routes: [
              GoRoute(path: StudioDestination.workspace.path, builder: (c, s) => const EngineeringWorkspacePage()),
              GoRoute(path: StudioDestination.knowledge.path, builder: (c, s) => const KnowledgeStudioPage()),
            ],
          ),
        ],
      );

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    useIsolatedSettingsStorage();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: buildRouter()),
    ));
    await tester.pump();
    return container;
  }

  Finder workspaceFinder() => find.byType(EngineeringWorkspacePage, skipOffstage: false);

  testWidgets('Workspace mounts once at startup', (tester) async {
    await pumpApp(tester);
    expect(workspaceFinder(), findsOneWidget);
  });

  testWidgets(
    'leaving /workspace for another Studio and returning keeps the same EngineeringWorkspacePage '
    'Element mounted — tabs, tab Elements, and active tab all survive',
    (tester) async {
      final container = await pumpApp(tester);

      // Open a real tab so there is state worth losing.
      await tester.tap(find.byTooltip('New tab'));
      await tester.pumpAndSettle();
      final surface = SurfaceRegistry.all[0];
      await tester.tap(find.text(surface.title).last);
      await tester.pumpAndSettle();

      final controller = container.read(workspaceTabsControllerProvider);
      expect(controller.tabs, hasLength(1));
      final openedTabId = controller.tabs.single.id;

      final workspaceElementBefore = tester.element(workspaceFinder());
      final indexedStackBefore = tester.widget<IndexedStack>(find.byType(IndexedStack));

      // -> another Studio.
      GoRouter.of(tester.element(workspaceFinder())).go(StudioDestination.knowledge.path);
      await tester.pumpAndSettle();

      expect(find.byType(KnowledgeStudioPage), findsOneWidget, reason: 'now on the Knowledge route');

      // The Workspace is not gone — merely hidden — while another Studio
      // is showing. This *is* the mechanism: nothing above it is ever
      // unmounted, so nothing inside it (tabs, WebView, local widget
      // State) is disposed either.
      expect(workspaceFinder(), findsOneWidget, reason: 'kept mounted, only Offstage-hidden, unlike before this fix');
      final offstage = tester.widget<Offstage>(
        find.ancestor(of: workspaceFinder(), matching: find.byType(Offstage)).first,
      );
      expect(offstage.offstage, isTrue);

      final workspaceElementWhileAway = tester.element(workspaceFinder());
      expect(identical(workspaceElementBefore, workspaceElementWhileAway), isTrue,
          reason: 'same Element the whole time, never torn down');

      // -> back to /workspace.
      GoRouter.of(tester.element(find.byType(KnowledgeStudioPage))).go(StudioDestination.workspace.path);
      await tester.pumpAndSettle();

      final workspaceElementAfter = tester.element(workspaceFinder());
      expect(identical(workspaceElementBefore, workspaceElementAfter), isTrue,
          reason: 'the fix under test: the SAME EngineeringWorkspacePage Element survives a full route round trip');

      final indexedStackAfter = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(identical(indexedStackBefore, indexedStackAfter), isTrue, reason: 'the tab content host itself was never rebuilt');

      // No duplicate, no loss: the exact same tab, still active.
      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.id, openedTabId);
      expect(controller.active!.id, openedTabId);
      expect(find.byIcon(Icons.close), findsOneWidget, reason: 'still exactly one tab chip, not zero, not two');
    },
  );

  testWidgets('closing a Workspace tab still disposes its Surface Element correctly, even though the Workspace host itself stays mounted', (tester) async {
    final container = await pumpApp(tester);

    await tester.tap(find.byTooltip('New tab'));
    await tester.pumpAndSettle();
    final surface = SurfaceRegistry.all[0];
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    final controller = container.read(workspaceTabsControllerProvider);
    expect(controller.tabs, hasLength(1));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(controller.tabs, isEmpty);
    // The persistent Workspace host itself remains — closing a tab is not
    // the same thing as leaving the Workspace.
    expect(workspaceFinder(), findsOneWidget);
    expect(find.text('No tabs open — press "+" to open a Surface'), findsOneWidget);
  });

  testWidgets('sidebar-driven workspace navigation still works, and still converges on the one persistent host', (tester) async {
    final container = await pumpApp(tester);

    Finder navScrollable() =>
        find.descendant(of: find.byKey(const ValueKey('workbench-sidebar-nav-list')), matching: find.byType(Scrollable));
    final target = find.byKey(ValueKey('sidebar-dest-${StudioDestination.knowledge.path}'));
    await tester.scrollUntilVisible(target, 100, scrollable: navScrollable());
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    final controller = container.read(workspaceTabsControllerProvider);
    expect(controller.tabs, hasLength(1));
    expect(controller.active!.surfaceId, StudioDestination.knowledge.name);
    // Still on /workspace (the whole point of AP-OEP-WORKSPACE-UX-001's
    // sidebar rule) — the fix in this package doesn't change that.
    expect(find.byType(EngineeringWorkspacePage), findsOneWidget);
  });

  testWidgets('non-Workspace route navigation is otherwise unaffected: the Knowledge route still renders KnowledgeStudioPage directly, visibly', (tester) async {
    await pumpApp(tester);

    GoRouter.of(tester.element(workspaceFinder())).go(StudioDestination.knowledge.path);
    await tester.pumpAndSettle();

    // Not `skipOffstage: false` here — this must be the one *visible*
    // KnowledgeStudioPage, not merely present somewhere offstage.
    expect(find.byType(KnowledgeStudioPage), findsOneWidget);
  });
}
