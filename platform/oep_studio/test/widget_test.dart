import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/studio_app.dart';
import 'package:oep_studio/core/routing/app_router.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_webview.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import 'support/isolated_settings_storage.dart';

/// A bounded stand-in for `pumpAndSettle()`. The Settings Workspace
/// (Work Package 017/018) shows an indeterminate `CircularProgressIndicator`
/// while its configuration loads from disk — indeterminate progress
/// indicators animate forever by design, so `pumpAndSettle()` (which
/// waits for *no* frame to be scheduled) never converges once one is
/// on screen and reliably times out. A fixed number of bounded pumps
/// gives every real async operation (Settings load, dialog transitions,
/// route animations) ample time to finish without waiting on an
/// animation that never stops on its own.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Like [settle], but for `DiagramStudioPage`'s bootstrap specifically
/// (WORK_PACKAGE_024): `EngineHost.create()` awaits `rootBundle.loadString`
/// for each of the 14 seed symbols. Under `testWidgets`'s fake-async
/// test binding, a plain `tester.pump(duration)` loop advances the fake
/// clock but does not reliably drive forward the real asynchronous
/// gaps those platform-channel asset reads go through — the resulting
/// `Future`s never resolve and the page is left showing its loading
/// spinner forever. `tester.runAsync` bridges into the real event loop
/// for the duration of its callback; interleaving real delays with
/// `tester.pump()` calls inside that one real-async window lets both
/// the pending asset-load Futures and the widget's own frame scheduling
/// progress together.
Future<void> settleDiagramStudioBootstrap(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
  });
}

/// `appRouter` (`core/routing/app_router.dart`) is a top-level singleton
/// constructed once per test *process*, not once per test — its
/// `initialLocation` only ever takes effect the very first time it's
/// built, so a test later in this file can inherit whatever route an
/// earlier test's own navigation left it on (e.g. tapping "Open
/// Repository" navigates to Dashboard). Every test in this file that
/// interacts with the Workspace force-navigates to it first, exactly the
/// same self-healing "explicit absolute navigation as the first real
/// action" robustness the old sidebar-driven tests always had (each of
/// those called `context.go` to its own specific destination up front,
/// regardless of where a previous test may have left the router).
Future<void> ensureOnWorkspace(WidgetTester tester) async {
  appRouter.go(StudioDestination.workspace.path);
  await settle(tester);
}

/// AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — opens [label] as a Workspace tab
/// via the real "+" menu (`_WorkspaceTabStrip` in
/// `engineering_workspace_page.dart`), the app's sole navigation surface
/// now that the old sidebar/nav-rail chrome is gone. [label] must be the
/// exact menu-row label. Only used for entries near the top of that menu
/// (Dashboard, Repository) — real UI coverage of the menu itself; see
/// [openWorkspaceSurfaceById] for entries further down, where the
/// popup's own internal scrolling makes a blind `tester.tap` unreliable
/// (Flutter's real `PopupMenuButton` overlay does not auto-scroll a
/// clipped item into view for a computed-offset tap).
Future<void> openWorkspaceTab(WidgetTester tester, String label) async {
  await ensureOnWorkspace(tester);
  await tester.tap(find.byTooltip('New tab'));
  await settle(tester);
  await tester.tap(find.text(label).last);
  await settle(tester);
}

/// Opens [surfaceId] (a `StudioDestination.name`, or
/// `WorkspaceTab.diagramSurfaceId`) as a Workspace tab directly through
/// `workspaceTabsControllerProvider.openSurface` — the same authority
/// the "+" menu's own `onTap` calls. The "+" menu's own UI is already
/// exercised end-to-end by [openWorkspaceTab] above and by
/// `engineering_workspace_page_test.dart`; these tests care about each
/// Studio's own page content, not re-proving the menu can be scrolled
/// and tapped for every one of its ~20 rows.
Future<void> openWorkspaceSurfaceById(WidgetTester tester, String surfaceId) async {
  await ensureOnWorkspace(tester);
  final container = ProviderScope.containerOf(tester.element(find.byType(StudioApp)), listen: false);
  container.read(workspaceTabsControllerProvider).openSurface(surfaceId);
  await settle(tester);
}

void main() {
  // AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — `flutter_test_config.dart`'s
  // whole-*file* default `SettingsStorage` override means every
  // `testWidgets` below shares one real temp directory unless each test
  // isolates its own: `workspaceTabsControllerProvider` persists opened
  // tabs to disk, so without this, a tab opened in one test would still
  // be there (and already-`.last`, breaking finders) when the next test
  // in this file boots.
  setUp(useIsolatedSettingsStorage);

  testWidgets('StudioApp boots directly into the empty tabbed Workspace', (
    WidgetTester tester,
  ) async {
    // Flutter's default 800x600 test surface is narrower than this app's
    // actual minimum window size (windows/runner/win32_window.cpp,
    // kMinWindowWidth/kMinWindowHeight) — testing below that size isn't
    // representative of anything a real user can produce.
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    // AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — no chrome (menu bar, toolbar,
    // ribbon, breadcrumb bar, sidebar, property inspector, output panel,
    // status bar) surrounds the Workspace; it's the entire screen.
    expect(find.text('No tabs open — press "+" to open a Surface'), findsOneWidget);
    expect(find.byTooltip('New tab'), findsOneWidget);

    await openWorkspaceTab(tester, 'Dashboard');
    expect(find.text('Welcome to OEP Studio'), findsOneWidget);
    expect(find.text('Open Repository'), findsWidgets);
  });

  testWidgets('Settings opens as a Workspace tab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await openWorkspaceSurfaceById(tester, 'settings');

    // Work Package 017: Settings is now a real Workspace (General page by
    // default), not a placeholder.
    expect(find.text('Localization'), findsOneWidget);
  });

  testWidgets('Repository Explorer shows No Repository Open and can jump to the Dashboard tab', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await openWorkspaceTab(tester, 'Repository');

    expect(find.text('No Repository Open'), findsOneWidget);

    await tester.tap(find.text('Open Repository').first);
    await settle(tester);

    expect(find.text('Welcome to OEP Studio'), findsOneWidget);
  });

  testWidgets('Object Explorer prompts for a category when none is selected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await openWorkspaceSurfaceById(tester, 'objects');

    expect(find.text('No Category Selected'), findsOneWidget);

    await tester.tap(find.text('Go to Repository Explorer').first);
    await settle(tester);

    expect(find.text('No Repository Open'), findsOneWidget);
  });

  testWidgets('Relationship Explorer shows No Repository Open when disconnected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await openWorkspaceSurfaceById(tester, 'relationships');

    expect(find.text('No Repository Open'), findsOneWidget);
  });

  testWidgets(
      'Search Workspace stays usable (not blocked) with no repository open '
      'and no diagram loaded yet — WORK_PACKAGE_025 unifies Foundation and '
      'Engine search, so a repository is no longer a hard prerequisite', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await openWorkspaceSurfaceById(tester, 'search');

    expect(find.text('Search across the whole platform'), findsOneWidget);
    expect(
      find.text('No repository open and no diagram loaded yet — search will still work once either is available.'),
      findsOneWidget,
    );
  });

  testWidgets('Knowledge Studio opens with placeholder panels and no active session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await openWorkspaceSurfaceById(tester, 'knowledge');

    expect(find.text('No Knowledge Curation Session'), findsOneWidget);
    expect(find.text('Import Queue'), findsOneWidget);
    expect(find.text('Source Viewer'), findsOneWidget);
    expect(find.text('AI Suggestions'), findsOneWidget);
    expect(find.text('Repository Matches'), findsOneWidget);
    expect(find.text('Engineering Review'), findsOneWidget);
    expect(find.text('Commit Summary'), findsOneWidget);
    // Knowledge Studio is Studio-only — it never requires a live
    // Foundation repository to be open (Work Package 007).
    expect(find.text('No Repository Open'), findsNothing);
  });

  testWidgets('Knowledge Curation Session: create a session, add a candidate, accept it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await openWorkspaceSurfaceById(tester, 'knowledge');

    // Create a session.
    await tester.tap(find.widgetWithText(OutlinedButton, 'New Session'));
    await settle(tester);

    await tester.enterText(findFieldLabeled('Session Name'), 'Timing Chain Manual Import');
    await tester.pump();
    await tester.enterText(findFieldLabeled('Repository'), 'demo-repo');
    await tester.pump();
    await tester.enterText(findFieldLabeled('Author'), 'jsmith');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Session'));
    await settle(tester);

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'the New Session dialog should have closed after a valid submission',
    );
    // Appears in the session header and the Property Inspector's Session
    // mode (no proposal/object/relationship selected yet) — the
    // Breadcrumb Bar's own former Document-level segment is gone along
    // with the rest of the chrome (AP-OEP-WORKSPACE-AS-PRIMARY-UI-001).
    expect(find.text('Timing Chain Manual Import'), findsWidgets);
    expect(find.text('Created'), findsWidgets);
    expect(find.text('No Knowledge Curation Session'), findsNothing);

    // Add a manual Knowledge Candidate.
    await tester.tap(find.widgetWithText(OutlinedButton, 'New Candidate'));
    await settle(tester);

    await tester.enterText(findFieldLabeled('Name'), 'Timing Chain Cover');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Candidate'));
    await settle(tester);

    expect(find.text('Timing Chain Cover'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    // Selecting the candidate (previously also asserted this updated the
    // Property Inspector's Knowledge Candidate mode — that panel was
    // removed by AP-OEP-WORKSPACE-AS-PRIMARY-UI-001, so only the real,
    // still-selectable row itself is asserted here now).
    await tester.tap(find.text('Timing Chain Cover'));
    await settle(tester);
    expect(find.text('Timing Chain Cover'), findsOneWidget);

    // Accept it — the status badge (Engineering Review) reads "Accepted".
    await tester.tap(find.widgetWithTooltip('Accept'));
    await settle(tester);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('Diagram Studio opens as a Workspace tab, blank untitled document with its toolbars and panels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);
    await ensureOnWorkspace(tester);

    await tester.tap(find.byTooltip('New tab'));
    await settle(tester);
    await tester.tap(find.text('Diagram Studio').last);
    await tester.pump();
    await settleDiagramStudioBootstrap(tester);

    // AP-DIAGRAM-V2-BRIDGE-002/010 — the Diagram tab renders
    // `DiagramWithComparePane`, the same real, unmodified Legacy V2
    // embedding `WebSurfacesHostPage`'s own `/diagram` route uses — never
    // the native renderer, which was retired entirely by
    // AP-DIAGRAM-V2-BRIDGE-010.
    expect(find.byType(LegacyV2WebViewPage), findsOneWidget,
        reason: 'Legacy V2 auto-opens as the default tab on the production Diagram Studio route');
  });
}

extension on CommonFinders {
  Finder widgetWithTooltip(String tooltip) =>
      find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == tooltip);
}

/// Finds a `TextField` by its `InputDecoration.labelText`, avoiding
/// positional-index ambiguity across a dialog's several fields.
Finder findFieldLabeled(String label) {
  return find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == label);
}
