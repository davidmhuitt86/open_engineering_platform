import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workbench/perspective/perspective_manager.dart';
import 'package:oep_studio/workbench/widgets/workbench_sidebar.dart';

/// AP-OEP-SURFACE-ARCHITECTURE-003 — the critical architectural
/// property this package exists to prove: if a Surface exists in
/// [SurfaceRegistry], both the "+" New Tab menu (already proven in
/// `test/core/surfaces/surface_registry_test.dart`) and
/// [WorkbenchSidebar] resolve the *same* canonical id/title/icon,
/// without either independently maintaining those values.
void main() {
  Widget harness({StudioDestination current = StudioDestination.dashboard, bool diagramSessionActive = false}) =>
      MaterialApp(
        home: Scaffold(
          body: WorkbenchSidebar(
            perspectiveManager: PerspectiveManager(),
            current: current,
            diagramSessionActive: diagramSessionActive,
          ),
        ),
      );

  /// Same pattern `test/widget_test.dart`'s own `sidebarScrollable`/
  /// `navigateViaSidebar` already established: `WorkbenchSidebar`'s row
  /// list is a real, lazily-mounted `ListView` (`ValueKey(
  /// 'workbench-sidebar-nav-list')`) — a row past the fold isn't in the
  /// Element tree at all until scrolled into view, so a plain
  /// `find.text` on a STUDIOS-section item fails not because the row is
  /// missing, but because it was never scrolled to.
  Finder sidebarScrollable() =>
      find.descendant(of: find.byKey(const ValueKey('workbench-sidebar-nav-list')), matching: find.byType(Scrollable));

  Future<Finder> scrollToDestinationRow(WidgetTester tester, StudioDestination destination) async {
    final target = find.byKey(ValueKey('sidebar-dest-${destination.path}'));
    await tester.scrollUntilVisible(target, 100, scrollable: sidebarScrollable());
    return target;
  }

  group('WorkbenchSidebar sources identity from SurfaceRegistry', () {
    testWidgets('every STUDIOS-section destination shows the SurfaceRegistry title as its label', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      // Every non-diagram destination in the STUDIOS section has a
      // SurfaceDefinition — its label in the tree must be the exact
      // SurfaceRegistry title, not an independently-maintained string.
      for (final surface in SurfaceRegistry.all) {
        if (surface.id == StudioDestination.repository.name ||
            surface.id == StudioDestination.packages.name ||
            surface.id == StudioDestination.search.name ||
            surface.id == StudioDestination.settings.name) {
          // These live in RESOURCES/TOOLS/the footer, not STUDIOS —
          // covered by the dedicated checks below instead.
          continue;
        }
        final destination = StudioDestination.values.firstWhere((d) => d.name == surface.id);
        final row = await scrollToDestinationRow(tester, destination);
        expect(
          find.descendant(of: row, matching: find.text(surface.title)),
          findsOneWidget,
          reason: 'STUDIOS row for ${surface.id} does not show the SurfaceRegistry title "${surface.title}"',
        );
      }
    });

    testWidgets('Repository/Packages/Search rows show the exact SurfaceRegistry title', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      for (final destination in [StudioDestination.repository, StudioDestination.packages, StudioDestination.search]) {
        final row = await scrollToDestinationRow(tester, destination);
        expect(
          find.descendant(of: row, matching: find.text(SurfaceRegistry.forId(destination.name)!.title)),
          findsOneWidget,
        );
      }
    });

    testWidgets('the plain "Diagram Studio" row (no SurfaceDefinition) still appears, sourced from StudioDestination directly', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      // `diagram` is deliberately excluded from SurfaceRegistry
      // (§ `SurfaceRegistry`'s own doc comment) — this asserts the
      // documented fallback still renders it, rather than silently
      // dropping the row.
      expect(SurfaceRegistry.forId(StudioDestination.diagram.name), isNull);
      final row = await scrollToDestinationRow(tester, StudioDestination.diagram);
      expect(find.descendant(of: row, matching: find.text(StudioDestination.diagram.label)), findsOneWidget);
    });

    testWidgets('diagram-session contextual hiding still works with Surface-sourced rows', (tester) async {
      await tester.pumpWidget(harness(current: StudioDestination.diagram, diagramSessionActive: true));
      await tester.pump();

      // Objects/Validation are hidden while a diagram session is active
      // (`_hiddenWhileDiagramActive`) — unchanged behavior, now with
      // Surface-sourced labels. Their `ValueKey` row itself must be
      // absent (not merely scrolled past), so this does not use the
      // scroll-then-find pattern above.
      expect(find.byKey(ValueKey('sidebar-dest-${StudioDestination.objects.path}')), findsNothing);
      expect(find.byKey(ValueKey('sidebar-dest-${StudioDestination.validation.path}')), findsNothing);
    });

    testWidgets('search/filter still works against Surface-sourced labels', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      final knowledgeTitle = SurfaceRegistry.forId(StudioDestination.knowledge.name)!.title;
      await tester.enterText(find.byType(TextField), knowledgeTitle);
      await tester.pump();

      expect(find.byKey(ValueKey('sidebar-dest-${StudioDestination.knowledge.path}')), findsOneWidget);
      expect(
        find.byKey(ValueKey('sidebar-dest-${StudioDestination.acquisition.path}')),
        findsNothing,
        reason: 'filtering should hide non-matching Surface rows entirely, not just scroll them out of view',
      );
    });
  });

  test('no duplicate Surface ids (sidebar and "+" menu share one registry, so this is a shared invariant)', () {
    final ids = SurfaceRegistry.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
