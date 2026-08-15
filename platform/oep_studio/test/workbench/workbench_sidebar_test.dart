import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/workbench/perspective/perspective.dart';
import 'package:oep_studio/workbench/perspective/perspective_manager.dart';
import 'package:oep_studio/workbench/widgets/workbench_sidebar.dart';
import 'package:oep_studio/workbench/widgets/workbench_sidebar_state.dart';

/// WP-DS-006: `WorkbenchSidebar` — the left sidebar navigation that
/// replaced the earlier horizontal `PerspectiveSelector`. Real
/// `PerspectiveManager`/`WorkbenchSidebarState` (in-memory, no file
/// injected — persistence itself is already covered by
/// `perspective_manager_test.dart`), small fixture Perspectives.
void main() {
  List<PerspectiveSidebarItem> alphaSubItems(BuildContext context) => [
        PerspectiveSidebarItem(label: 'Alpha Item One', onTap: () {}, active: true),
        PerspectiveSidebarItem(label: 'Alpha Item Two', onTap: () {}),
      ];

  List<Perspective> fixtures() => [
        Perspective(
          id: 'alpha',
          title: 'Alpha',
          icon: Icons.circle,
          centerBuilder: (context) => const SizedBox(),
          sidebarSubItemsProvider: alphaSubItems,
        ),
        Perspective(id: 'beta', title: 'Beta', icon: Icons.square, centerBuilder: (context) => const SizedBox()),
      ];

  Widget harness(PerspectiveManager manager) => MaterialApp(
        home: Scaffold(body: WorkbenchSidebar(perspectiveManager: manager)),
      );

  testWidgets('renders every registered perspective under WORKBENCH, with the active one highlighted', (tester) async {
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('alpha');

    await tester.pumpWidget(harness(manager));
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('WORKBENCH'), findsOneWidget);
  });

  testWidgets('tapping a perspective row activates it via PerspectiveManager', (tester) async {
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('alpha');

    await tester.pumpWidget(harness(manager));
    await tester.pump();

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(manager.active?.id, 'beta');
  });

  testWidgets('the active perspective with sub-items shows an expand chevron; tapping it reveals real sub-items', (tester) async {
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('alpha');

    await tester.pumpWidget(harness(manager));
    await tester.pump();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.text('Alpha Item One'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();

    expect(find.text('Alpha Item One'), findsOneWidget);
    expect(find.text('Alpha Item Two'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('Beta (no sidebarSubItemsProvider) never shows an expand chevron even when active', (tester) async {
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('beta');

    await tester.pumpWidget(harness(manager));
    await tester.pump();

    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('typing in the filter box narrows WORKBENCH to matching perspective titles only', (tester) async {
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('alpha');

    await tester.pumpWidget(harness(manager));
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bet');
    await tester.pump();

    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('RESOURCES and TOOLS sections render with real, honestly-scoped rows', (tester) async {
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('alpha');

    await tester.pumpWidget(harness(manager));
    await tester.pump();

    expect(find.text('RESOURCES'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Repository'), findsOneWidget);
    expect(find.text('Packages'), findsOneWidget);
    expect(find.text('TOOLS'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Tasks & Jobs'), findsOneWidget);
    // Reports is honestly disabled -- no such feature exists yet.
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('tapping Library activates the library Perspective by id', (tester) async {
    final manager = PerspectiveManager()
      ..registerAll([
        ...fixtures(),
        Perspective(id: 'library', title: 'Library (placeholder)', icon: Icons.folder, centerBuilder: (context) => const SizedBox()),
      ]);
    manager.activate('alpha');

    await tester.pumpWidget(harness(manager));
    await tester.pump();

    await tester.tap(find.text('Library'));
    await tester.pump();

    expect(manager.active?.id, 'library');
  });

  testWidgets('tapping Search navigates to the Search Workspace destination', (tester) async {
    // Search now navigates to `StudioDestination.search` (matching the
    // classic `StudioNavRail`'s own behavior, since this sidebar replaced
    // it as the app's single left nav) rather than opening the Command
    // Palette -- a real `GoRouter` (not this file's plain `harness()`) is
    // needed to observe that navigation.
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('alpha');

    late String currentPath;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            currentPath = state.uri.path;
            return Scaffold(body: WorkbenchSidebar(perspectiveManager: manager));
          },
        ),
        GoRoute(
          path: StudioDestination.search.path,
          builder: (context, state) {
            currentPath = state.uri.path;
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(currentPath, StudioDestination.search.path);
  });

  testWidgets('the collapse toggle switches to an icon-only rail and back', (tester) async {
    final manager = PerspectiveManager()..registerAll(fixtures());
    manager.activate('alpha');
    final sidebarState = WorkbenchSidebarState();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: WorkbenchSidebar(perspectiveManager: manager, sidebarState: sidebarState))),
    );
    await tester.pump();

    expect(find.text('WORKBENCH'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(find.text('WORKBENCH'), findsNothing);
    expect(sidebarState.collapsed, isTrue);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(find.text('WORKBENCH'), findsOneWidget);
    expect(sidebarState.collapsed, isFalse);
  });

  group('Phase 14 -- Left Sidebar minimization while Diagram Studio is active', () {
    // The nav list is a real Sliver-backed `ListView` -- rows past the
    // realized viewport are not mounted into the Element tree until
    // scrolled into view (same real constraint `widget_test.dart`'s own
    // `sidebarScrollable()`/`navigateViaSidebar` helpers already work
    // around). `scrollUntilVisible` throwing (rather than finding
    // nothing) is itself the "still present, just needs a scroll"
    // signal; a `tester.scrollUntilVisible` call that instead runs to
    // completion without ever finding [target] throws its own
    // `TestFailure`, which is exactly the assertion this helper wants
    // for the "must be findable" case. For the "must NOT be present at
    // all" case, exhausting the scroll without throwing (this sidebar's
    // list has a finite extent) and then finding nothing is the real
    // signal an item was truly excluded, not merely off-screen -- see
    // [_expectAbsentAfterFullScroll].
    Finder navList() => find.byKey(const ValueKey('workbench-sidebar-nav-list'));
    Finder navScrollable() => find.descendant(of: navList(), matching: find.byType(Scrollable));

    Future<void> expectVisible(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(target, 200, scrollable: navScrollable());
      expect(target, findsOneWidget);
    }

    Future<void> expectAbsentAfterFullScroll(WidgetTester tester, Finder target) async {
      // Drag the list to its end (a large, deliberately excessive
      // offset) so every row that exists gets a chance to mount, then
      // assert [target] is still nowhere in the tree.
      await tester.drag(navScrollable(), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(target, findsNothing);
    }

    testWidgets('diagramSessionActive=false on the Diagram destination shows every destination (default, unchanged behavior)', (tester) async {
      final manager = PerspectiveManager()..registerAll(fixtures());
      manager.activate('alpha');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WorkbenchSidebar(perspectiveManager: manager, current: StudioDestination.diagram),
        ),
      ));
      await tester.pump();

      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.repository.path}')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.packages.path}')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.validation.path}')));
    });

    testWidgets('diagramSessionActive=true on the Diagram destination hides capability/service destinations, keeps global ones', (tester) async {
      final manager = PerspectiveManager()..registerAll(fixtures());
      manager.activate('alpha');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WorkbenchSidebar(
            perspectiveManager: manager,
            current: StudioDestination.diagram,
            diagramSessionActive: true,
          ),
        ),
      ));
      await tester.pump();

      // Hidden while a diagram is actively open.
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.repository.path}')));
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.packages.path}')));
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.validation.path}')));
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.objects.path}')));
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.relationships.path}')));
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.graph.path}')));
      await expectAbsentAfterFullScroll(
          tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.engineeringIntelligence.path}')));
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.acquisition.path}')));
      await expectAbsentAfterFullScroll(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.projectExplorer.path}')));

      // Still reachable -- global functions, not DS-specific.
      await expectVisible(tester, find.byKey(const ValueKey('sidebar-perspective-library')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.dashboard.path}')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.knowledge.path}')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.exchange.path}')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.copilot.path}')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.search.path}')));
    });

    testWidgets('diagramSessionActive=true on a NON-diagram destination does not minimize the sidebar', (tester) async {
      final manager = PerspectiveManager()..registerAll(fixtures());
      manager.activate('alpha');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WorkbenchSidebar(
            perspectiveManager: manager,
            current: StudioDestination.repository,
            diagramSessionActive: true,
          ),
        ),
      ));
      await tester.pump();

      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.repository.path}')));
      await expectVisible(tester, find.byKey(ValueKey('sidebar-dest-${StudioDestination.packages.path}')));
    });
  });
}
