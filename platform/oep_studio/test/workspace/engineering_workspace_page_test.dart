import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workspace/engineering_workspace_page.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

/// AP-OEP-WORKSPACE-SHELL-001 — widget-level coverage for the "+" menu,
/// tab activation, and tab close, per this task's own Phase 14. Does
/// not exercise the real Diagram/V2 tab (that requires a real WebView2
/// control, unreliable under `flutter test` — the same reasoning
/// `app_router.dart`'s own standing comment already documents, and
/// which `test/core/surfaces/surface_registry_test.dart`/
/// `test/workspace/workspace_tabs_controller_test.dart` already cover
/// for the Diagram-tab *model* behavior instead).
void main() {
  Widget harness() => const ProviderScope(
        child: MaterialApp(home: Scaffold(body: EngineeringWorkspacePage())),
      );

  testWidgets('starts with no tabs open and shows the empty state', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('No tabs open — press "+" to open a Surface'), findsOneWidget);
  });

  testWidgets('the "+" menu lists every SurfaceRegistry surface plus Diagram Studio', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Diagram Studio'), findsOneWidget);
    for (final surface in SurfaceRegistry.all) {
      expect(find.text(surface.title), findsWidgets, reason: '"+" menu missing ${surface.title}');
    }
  });

  testWidgets('selecting a Surface from "+" opens it as an active, closable tab', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final surface = SurfaceRegistry.all.first;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    expect(find.text('No tabs open — press "+" to open a Surface'), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('opening two different Surfaces creates two tabs; the second is active', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final a = SurfaceRegistry.all[0];
    final b = SurfaceRegistry.all[1];

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(a.title).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(b.title).last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('opening the same Surface twice focuses the existing tab instead of duplicating', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final surface = SurfaceRegistry.all.first;

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'reuse-if-open, not a duplicate tab');
  });

  testWidgets('closing the only open tab returns to the empty state', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final surface = SurfaceRegistry.all.first;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(surface.title).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('No tabs open — press "+" to open a Surface'), findsOneWidget);
  });

  group('split view (AP-OEP-WORKSPACE-SPLIT-VIEW-001)', () {
    // Drives `splitWith` directly through the real, shared
    // `WorkspaceTabsController` rather than simulating the tab chip's
    // right-click context menu — this exercises the exact same
    // production rendering path (`_WorkspaceContent`) the menu action
    // calls into, without coupling the test to a gesture sequence.
    WorkspaceTabsController controllerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(Scaffold)), listen: false).read(workspaceTabsControllerProvider);

    // A wide viewport: several `SurfaceRegistry` pages (e.g.
    // `ProjectExplorerPage`) already need close to a full 800px-wide
    // default test viewport in *single* mode — halving that for a split
    // pane would overflow their own, pre-existing internal layout, a
    // fact about those pages' fixed-width rows, not about the split
    // mechanism itself. A wide viewport keeps each half-pane comfortably
    // above what those pages already require today.
    void useWideViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(2400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('splitting two Surfaces shows both simultaneously', (tester) async {
      useWideViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();
      final controller = controllerOf(tester);
      final a = SurfaceRegistry.all[0];
      final b = SurfaceRegistry.all[1];
      final aId = controller.openSurface(a.id);
      controller.openSurface(b.id);
      await tester.pumpAndSettle();

      controller.splitWith(aId);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.close), findsNWidgets(2), reason: 'both tab chips remain');
      expect(find.byType(VerticalDivider), findsOneWidget, reason: 'the split divider is rendered between the two panes');
    });

    testWidgets('closing a paned tab collapses the split back to a single visible tab', (tester) async {
      useWideViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();
      final controller = controllerOf(tester);
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      final bId = controller.openSurface(SurfaceRegistry.all[1].id);
      controller.splitWith(aId);
      await tester.pumpAndSettle();
      expect(find.byType(VerticalDivider), findsOneWidget);

      controller.close(aId);
      await tester.pumpAndSettle();

      expect(find.byType(VerticalDivider), findsNothing, reason: 'split collapsed to a single visible tab');
      expect(controller.secondTabId, isNull);
      expect(controller.tabs.single.id, bId);
    });

    testWidgets('a third open tab (in neither pane) stays open across a split toggle, not silently closed', (tester) async {
      useWideViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();
      final controller = controllerOf(tester);
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);
      final bId = controller.openSurface(SurfaceRegistry.all[1].id);
      final cId = controller.openSurface(SurfaceRegistry.all[2].id);
      controller.activate(aId);
      controller.splitWith(bId);
      await tester.pumpAndSettle();

      expect(controller.tabs.map((t) => t.id).toSet(), {aId, bId, cId}, reason: 'C is still open, just not in a pane');

      controller.closeSplit();
      controller.activate(cId);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNWidgets(3), reason: 'all three tab chips are still present after the split toggled off');
    });

    testWidgets(
        'splitting/unsplitting preserves a tab\'s live widget State (not just its provider state) — the correctness gap GlobalObjectKey exists to close',
        (tester) async {
      useWideViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();
      final controller = controllerOf(tester);
      final search = SurfaceRegistry.all.firstWhere((s) => s.title == 'Search');
      final other = SurfaceRegistry.all.firstWhere((s) => s.id != search.id);
      final searchId = controller.openSurface(search.id);
      controller.openSurface(other.id);
      controller.activate(searchId);
      await tester.pumpAndSettle();

      // Typed directly into the Search Surface's own local
      // `TextEditingController` — if the framework disposes and
      // recreates this tab's `Element`/`State` merely because it moved
      // between `IndexedStack` and a split `Row`/hidden holder (the
      // real bug `GlobalObjectKey` exists to prevent, § `_keyedTabContent`'s
      // own doc comment), this text would be lost even though nothing
      // about the underlying data changed.
      await tester.enterText(find.byType(TextField), 'preserve me');
      await tester.pump();
      expect(find.text('preserve me'), findsOneWidget);

      controller.splitWith(other.id);
      await tester.pumpAndSettle();
      expect(find.text('preserve me'), findsOneWidget, reason: 'entering split must not reset the tab\'s own widget State');

      controller.closeSplit();
      await tester.pumpAndSettle();
      expect(find.text('preserve me'), findsOneWidget, reason: 'leaving split must not reset the tab\'s own widget State either');
    });

    testWidgets('splitting a tab with itself falls back to single-view rendering without crashing', (tester) async {
      useWideViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();
      final controller = controllerOf(tester);
      final aId = controller.openSurface(SurfaceRegistry.all[0].id);

      controller.splitWith(aId); // secondTabId == activeId
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(VerticalDivider), findsNothing, reason: 'no duplicate-mount split is attempted for the same tab');
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
