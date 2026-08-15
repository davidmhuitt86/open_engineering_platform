import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/studio_app.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';

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

/// Finds the sidebar's own `Scrollable` (`WorkbenchSidebar`, a `ListView`
/// of WORKBENCH/RESOURCES/TOOLS/STUDIOS rows), by the stable
/// `ValueKey('workbench-sidebar-nav-list')` its `ListView` carries. Text
/// anchors (e.g. the 'WORKBENCH' section label) don't work here: once the
/// list is scrolled far enough to reveal a STUDIOS row, that label itself
/// scrolls out of the realized viewport (a plain `ListView`'s children
/// are lazily mounted, like any `Sliver`) and stops being findable.
Finder sidebarScrollable() =>
    find.descendant(of: find.byKey(const ValueKey('workbench-sidebar-nav-list')), matching: find.byType(Scrollable));

/// Navigates via a `StudioDestination`'s row in the Engineering Workbench
/// sidebar (`WorkbenchSidebar`, now `StudioShell`'s single left nav,
/// replacing the classic `StudioNavRail`). Looked up by the stable
/// `ValueKey('sidebar-dest-<path>')` each such row carries -- a plain text
/// finder isn't reliable here since a Studio page kept alive off-route can
/// render the same label its own sidebar row uses. WORKBENCH/RESOURCES/
/// TOOLS/STUDIOS rows sit in a real scrollable `ListView` -- like the old
/// rail before it (see this file's own long-standing comment about
/// 'Packages'/'Settings' below the realized viewport), a row past the
/// fold isn't mounted into the Element tree until scrolled into view.
Future<void> navigateViaSidebar(WidgetTester tester, StudioDestination destination) async {
  final target = find.byKey(ValueKey('sidebar-dest-${destination.path}'));
  await tester.scrollUntilVisible(target, 100, scrollable: sidebarScrollable());
  // `scrollUntilVisible` stops the moment any part of the target overlaps
  // the viewport -- that can leave it clipped at the very edge, where
  // `tester.tap`'s computed center point lands outside the Scrollable's
  // visible region and hits whatever row is actually painted there
  // instead (a real, observed flake). `ensureVisible` scrolls the target
  // fully into view.
  await tester.ensureVisible(target);
  await settle(tester);
  await tester.tap(target);
  await settle(tester);
}

void main() {
  testWidgets('StudioApp launches on the Dashboard and navigates via the rail', (
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

    expect(find.text('Welcome to OEP Studio'), findsOneWidget);
    expect(find.text('Open Repository'), findsWidgets);

    // Settings has no row of its own in `WorkbenchSidebar` (now
    // `StudioShell`'s single left nav, replacing the classic
    // `StudioNavRail` this comment used to describe) -- it's reached via
    // the sidebar footer's gear `IconButton` instead (see
    // `_SidebarFooter`).
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);

    // Work Package 017: Settings is now a real Workspace (General page by
    // default), not a placeholder.
    expect(find.text('Localization'), findsOneWidget);

    // Property Inspector (Work Package 003) is a persistent panel —
    // "No Object Selected" regardless of which page is active.
    expect(find.text('No Object Selected'), findsOneWidget);
    // Status Bar's new Selected Object field.
    expect(find.text('Selected Object: None'), findsOneWidget);
  });

  testWidgets('Repository Explorer shows No Repository Open and returns to the Dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await navigateViaSidebar(tester, StudioDestination.repository);

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

    await navigateViaSidebar(tester, StudioDestination.objects);

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

    await navigateViaSidebar(tester, StudioDestination.relationships);

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

    await navigateViaSidebar(tester, StudioDestination.search);

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

    await navigateViaSidebar(tester, StudioDestination.knowledge);

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

    await navigateViaSidebar(tester, StudioDestination.knowledge);

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
    // Appears in the session header, the Property Inspector's Session
    // mode (no proposal/object/relationship selected yet), and the
    // Breadcrumb Bar's Document-level segment (Phase 2, ODS-S004 § 4
    // Navigation Hierarchy).
    expect(find.text('Timing Chain Manual Import'), findsNWidgets(3));
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

    // Selecting the candidate updates the Property Inspector.
    await tester.tap(find.text('Timing Chain Cover'));
    await settle(tester);
    expect(find.text('Knowledge Candidate ID'), findsOneWidget);

    // Accept it — the status badge (Engineering Review) and the
    // Property Inspector's Knowledge Candidate mode (still showing this
    // same, now-updated candidate) both read "Accepted".
    await tester.tap(find.widgetWithTooltip('Accept'));
    await settle(tester);
    expect(find.text('Accepted'), findsNWidgets(2));
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('Diagram Studio opens to a blank untitled document with its toolbars and panels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    final diagramRow = find.byKey(ValueKey('sidebar-dest-${StudioDestination.diagram.path}'));
    await tester.scrollUntilVisible(diagramRow, 100, scrollable: sidebarScrollable());
    await tester.ensureVisible(diagramRow); // see `navigateViaSidebar`'s own doc comment for why
    await settle(tester);
    await tester.tap(diagramRow);
    await tester.pump();
    await settleDiagramStudioBootstrap(tester);

    // The document bar (WORK_PACKAGE_024, ENGINE-TASK-000111) — a fresh
    // Engine session starts on a blank, unsaved document. Also appears
    // in the Breadcrumb Bar's Document-level segment (Phase 2, ODS-S004
    // § 4 Navigation Hierarchy) AND in the Phase 5 diagram tab bar's own
    // tab chip, hence multiple matches.
    expect(find.text('Untitled Diagram'), findsWidgets);

    // Toolbar groups (ENGINE-TASK-000113) and dockable panels
    // (ENGINE-TASK-000114) rendered. "Validation" also labels the
    // unrelated `/validation` sidebar destination (in the WorkbenchSidebar's
    // STUDIOS section, scrolled further down the same sidebar Scrollable
    // used above), so two matches (sidebar label + panel title) is the
    // correct count here -- scroll its row into view first (by key -- see
    // `navigateViaSidebar`'s own doc comment for why) since a
    // `WorkbenchSidebar` row past the fold isn't mounted until then.
    expect(find.text('Object Explorer'), findsOneWidget);
    expect(find.text('Layers'), findsOneWidget);
    final validationRow = find.byKey(ValueKey('sidebar-dest-${StudioDestination.validation.path}'));
    await tester.scrollUntilVisible(validationRow, 100, scrollable: sidebarScrollable());
    await tester.ensureVisible(validationRow);
    await settle(tester);
    // Only the sidebar's own "Validation" destination row now -- Diagram
    // Studio's own duplicate "Validation" side panel was removed (Phase 3,
    // Objective 6): it read the exact same `ValidationReport` the shared
    // Output Panel's own "Validation" tab already shows.
    expect(find.text('Validation'), findsOneWidget);
    expect(find.text('Annotations'), findsOneWidget);
    expect(find.text('Recent Commands'), findsOneWidget);

    // The shared Property Inspector (docked at the StudioShell level,
    // untouched by Diagram Studio) still shows its own default state.
    expect(find.text('No Object Selected'), findsOneWidget);
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
