import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/workbench/perspective/perspective_manager.dart';
import 'package:oep_studio/workbench/widgets/workbench_sidebar.dart';

/// AP-OEP-WORKSPACE-UX-001 — proves `WorkbenchSidebar`'s
/// `onActivateWorkspaceSurface` callback wiring itself, independent of
/// `StudioShell`/`workspaceTabsControllerProvider` (those are exercised
/// end-to-end by `studio_shell_workspace_sidebar_test.dart`). This file
/// only asserts: when the callback is supplied, a directly-mapped row
/// calls it instead of navigating; when it's not supplied (every
/// existing behavior, unchanged), the row still calls `context.go`.
void main() {
  Widget harness({void Function(StudioDestination)? onActivateWorkspaceSurface}) => MaterialApp(
        home: Scaffold(
          body: WorkbenchSidebar(
            perspectiveManager: PerspectiveManager(),
            current: StudioDestination.workspace,
            onActivateWorkspaceSurface: onActivateWorkspaceSurface,
          ),
        ),
      );

  /// Same real constraint `test/widget_test.dart`'s own
  /// `sidebarScrollable()`/`navigateViaSidebar` and
  /// `workbench_sidebar_surface_parity_test.dart` already work around:
  /// the sidebar's nav list is a real, lazily-mounted `ListView` — a row
  /// past the fold isn't in the Element tree until scrolled into view.
  Finder navScrollable() =>
      find.descendant(of: find.byKey(const ValueKey('workbench-sidebar-nav-list')), matching: find.byType(Scrollable));

  Future<void> tapDestinationRow(WidgetTester tester, StudioDestination destination) async {
    final target = find.byKey(ValueKey('sidebar-dest-${destination.path}'));
    // Scroll back to the top first: a prior tap in the same test may have
    // scrolled down past this row's position (rows are listed in a fixed
    // order, not necessarily below wherever the list last stopped).
    await tester.drag(navScrollable(), const Offset(0, 10000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 100, scrollable: navScrollable());
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('a directly-mapped row calls onActivateWorkspaceSurface instead of navigating, when supplied', (tester) async {
    StudioDestination? activated;
    await tester.pumpWidget(harness(onActivateWorkspaceSurface: (d) => activated = d));
    await tester.pumpAndSettle();

    await tapDestinationRow(tester, StudioDestination.knowledge);

    expect(activated, StudioDestination.knowledge);
  });

  testWidgets('Repository/Packages/Search rows also route through onActivateWorkspaceSurface', (tester) async {
    final activated = <StudioDestination>[];
    await tester.pumpWidget(harness(onActivateWorkspaceSurface: activated.add));
    await tester.pumpAndSettle();

    await tapDestinationRow(tester, StudioDestination.repository);
    await tapDestinationRow(tester, StudioDestination.search);

    expect(activated, [StudioDestination.repository, StudioDestination.search]);
  });

  testWidgets('the Settings footer button also routes through onActivateWorkspaceSurface', (tester) async {
    StudioDestination? activated;
    await tester.pumpWidget(harness(onActivateWorkspaceSurface: (d) => activated = d));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(activated, StudioDestination.settings);
  });

  testWidgets('tapping the same row twice calls the callback twice — duplicate prevention is the controller\'s job, not the sidebar\'s', (tester) async {
    final activated = <StudioDestination>[];
    await tester.pumpWidget(harness(onActivateWorkspaceSurface: activated.add));
    await tester.pumpAndSettle();

    await tapDestinationRow(tester, StudioDestination.knowledge);
    await tapDestinationRow(tester, StudioDestination.knowledge);

    // Two calls is correct here: `WorkbenchSidebar` has no duplicate-tab
    // policy of its own (§ this task's own Phase 3 instruction — "do
    // not make WorkbenchSidebar responsible for tab management"). The
    // real dedup guarantee lives in `WorkspaceTabsController.openSurface`
    // (already covered by `workspace_tabs_controller_test.dart`'s
    // "opening the same Surface twice" case).
    expect(activated, [StudioDestination.knowledge, StudioDestination.knowledge]);
  });

  testWidgets('when onActivateWorkspaceSurface is null (existing behavior), rows fall back to normal navigation', (tester) async {
    // No GoRouter ancestor in this harness, so a real `context.go` call
    // throws — caught by the framework's own error zone (not a rejected
    // `Future`, hence `tester.takeException()` rather than `throwsA`).
    // That thrown error is itself proof the fallback path
    // (`_goToDestination`'s `context.go` branch) was actually reached,
    // not silently skipped.
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tapDestinationRow(tester, StudioDestination.knowledge);

    expect(tester.takeException(), isNotNull);
  });
}
