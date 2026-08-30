import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workspace/engineering_workspace_page.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-LIFECYCLE-001 — the empirically-testable parts of
/// this package's own audit: multi-tab switching, duplicate policy,
/// close semantics that don't touch each other, and the Workspace
/// route-transition question (Phase 5/6/7/8). Basic "+"/duplicate/close
/// coverage already exists in `engineering_workspace_page_test.dart`
/// (AP-OEP-WORKSPACE-SHELL-001) — this file adds only what that one
/// doesn't: three-or-more-tab switching, cross-tab close isolation, and
/// the route-away-and-back structural rebuild finding.
///
/// Diagram/V2's own lifecycle is not exercised here — real WebView2
/// controls are unreliable under `flutter test` (the same reasoning
/// `app_router.dart`'s own standing comment documents). Diagram/V2's
/// lifecycle claims in this package's final report are backed by direct
/// source inspection instead (`legacy_v2_webview.dart`'s own
/// `dispose()`, `DiagramStudioController`'s app-wide provider scope).
void main() {
  setUp(useIsolatedSettingsStorage);

  Widget workspaceHarness() => const ProviderScope(
        child: MaterialApp(home: Scaffold(body: EngineeringWorkspacePage())),
      );

  Future<void> openSurface(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip('New tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title).last);
    await tester.pumpAndSettle();
  }

  int indexedStackChildCount(WidgetTester tester) => tester.widget<IndexedStack>(find.byType(IndexedStack)).children.length;

  testWidgets('opening three Surfaces keeps all three mounted in the IndexedStack, not just the active one', (tester) async {
    await tester.pumpWidget(workspaceHarness());
    await tester.pump();

    final a = SurfaceRegistry.all[0];
    final b = SurfaceRegistry.all[1];
    final c = SurfaceRegistry.all[2];

    await openSurface(tester, a.title);
    await openSurface(tester, b.title);
    await openSurface(tester, c.title);

    // IndexedStack keeps every child mounted regardless of which index is
    // showing — this is the actual mechanism "FULLY RETAINED" state
    // depends on. Each tab's content is one `IndexedStack` child (built by
    // `_buildTabContent`, `engineering_workspace_page.dart`) — the
    // `children` list length is the ground truth for how many tabs are
    // actually mounted, not merely how many are showing.
    expect(find.byType(IndexedStack), findsOneWidget);
    expect(indexedStackChildCount(tester), 3);
    expect(find.byIcon(Icons.close), findsNWidgets(3), reason: 'all three tab chips remain in the strip');
  });

  testWidgets('A -> B -> C -> A: switching back to A does not remove or recreate any tab', (tester) async {
    await tester.pumpWidget(workspaceHarness());
    await tester.pump();

    final a = SurfaceRegistry.all[0];
    final b = SurfaceRegistry.all[1];
    final c = SurfaceRegistry.all[2];

    await openSurface(tester, a.title);
    await openSurface(tester, b.title);
    await openSurface(tester, c.title);

    final container = ProviderScope.containerOf(tester.element(find.byType(EngineeringWorkspacePage)), listen: false);
    final controller = container.read(workspaceTabsControllerProvider);
    final tabAId = controller.tabs.firstWhere((t) => t.surfaceId == a.id).id;

    // Activate A again (the "-> A" step) directly through the same
    // authority the tab strip's own tap handler uses.
    controller.activate(tabAId);
    await tester.pumpAndSettle();

    expect(controller.tabs, hasLength(3), reason: 'no tab was dropped by switching');
    expect(controller.active!.id, tabAId);
    expect(indexedStackChildCount(tester), 3, reason: 'no tab was recreated by switching');
  });

  testWidgets('closing the middle tab (C) does not affect A or B', (tester) async {
    await tester.pumpWidget(workspaceHarness());
    await tester.pump();

    final a = SurfaceRegistry.all[0];
    final b = SurfaceRegistry.all[1];
    final c = SurfaceRegistry.all[2];

    await openSurface(tester, a.title);
    await openSurface(tester, b.title);
    await openSurface(tester, c.title);

    final container = ProviderScope.containerOf(tester.element(find.byType(EngineeringWorkspacePage)), listen: false);
    final controller = container.read(workspaceTabsControllerProvider);
    final tabCId = controller.tabs.firstWhere((t) => t.surfaceId == c.id).id;

    controller.close(tabCId);
    await tester.pumpAndSettle();

    expect(controller.tabs, hasLength(2));
    expect(controller.tabs.map((t) => t.surfaceId), [a.id, b.id]);
    expect(indexedStackChildCount(tester), 2);
  });

  testWidgets('closing A afterward does not affect B', (tester) async {
    await tester.pumpWidget(workspaceHarness());
    await tester.pump();

    final a = SurfaceRegistry.all[0];
    final b = SurfaceRegistry.all[1];

    await openSurface(tester, a.title);
    await openSurface(tester, b.title);

    final container = ProviderScope.containerOf(tester.element(find.byType(EngineeringWorkspacePage)), listen: false);
    final controller = container.read(workspaceTabsControllerProvider);
    final tabAId = controller.tabs.firstWhere((t) => t.surfaceId == a.id).id;

    controller.close(tabAId);
    await tester.pumpAndSettle();

    expect(controller.tabs, hasLength(1));
    expect(controller.tabs.single.surfaceId, b.id);
    expect(indexedStackChildCount(tester), 1);
  });

  testWidgets(
    'the underlying Flutter mechanism AP-OEP-WORKSPACE-LIFECYCLE-001 found and '
    'AP-OEP-WORKSPACE-ROUTING-001 fixed: a bare route swap (no persistent host above it) rebuilds '
    'EngineeringWorkspacePage as a new widget instance on return, even though WorkspaceTabsController '
    '(Riverpod-scoped) still reports the same open tabs',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/workspace',
        routes: [
          GoRoute(path: '/workspace', builder: (context, state) => const Scaffold(body: EngineeringWorkspacePage())),
          GoRoute(path: '/other', builder: (context, state) => const Scaffold(body: Text('elsewhere'))),
        ],
      );

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();

      final surface = SurfaceRegistry.all[0];
      await openSurface(tester, surface.title);

      final controller = container.read(workspaceTabsControllerProvider);
      expect(controller.tabs, hasLength(1));
      final firstElement = tester.element(find.byType(EngineeringWorkspacePage));

      router.go('/other');
      await tester.pumpAndSettle();
      expect(find.text('elsewhere'), findsOneWidget);
      expect(find.byType(EngineeringWorkspacePage), findsNothing, reason: 'the page is unmounted while its route is not active');

      router.go('/workspace');
      await tester.pumpAndSettle();

      // The DATA survives — same controller instance, same provider,
      // same open tab.
      expect(container.read(workspaceTabsControllerProvider), same(controller));
      expect(controller.tabs, hasLength(1));
      expect(controller.tabs.single.surfaceId, surface.id);

      // The WIDGET does not, in THIS bare harness — a fresh
      // EngineeringWorkspacePage Element is built on return, because
      // nothing above this route swap keeps a persistent instance alive.
      // This was AP-OEP-WORKSPACE-LIFECYCLE-001's own documented Phase 8
      // finding, and is exactly why AP-OEP-WORKSPACE-ROUTING-001's fix
      // lives in `StudioShell` (which sits *above* every route's `child`
      // and is itself preserved by `ShellRoute` across sibling route
      // changes) rather than in `EngineeringWorkspacePage` itself. That
      // real, StudioShell-wrapped behavior is moot in production now
      // (AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — nothing in the UI ever
      // navigates away from `/workspace` anymore), but this bare-harness
      // finding about `EngineeringWorkspacePage`'s own lifecycle under a
      // plain route swap remains true and worth documenting.
      final secondElement = tester.element(find.byType(EngineeringWorkspacePage));
      expect(identical(firstElement, secondElement), isFalse);
    },
  );
}
