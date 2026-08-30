import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/routing/studio_registry.dart';
import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workbench/perspectives/engineering_perspective.dart';
import 'package:oep_studio/workbench/perspectives/instruments_perspective.dart';
import 'package:oep_studio/workspace/engineering_workspace_page.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-WORKBENCH-PERSPECTIVE-MIGRATION-001 — the two remaining
/// legitimately-reachable Workbench capabilities (Engineering,
/// Instruments) exposed as ordinary Workspace Surfaces. Does not
/// re-test `WorkspaceTabsController`'s own generic open/activate/close
/// semantics (already covered, Surface-agnostically, by
/// `workspace_tabs_controller_test.dart`) — only that Engineering/
/// Instruments are correctly wired into that existing mechanism, and
/// that their real content (§ `engineering_perspective.dart`/
/// `instruments_perspective.dart`) is preserved, not forked.
void main() {
  setUp(useIsolatedSettingsStorage);

  group('registration (Phase 8, items 1-2)', () {
    test('Engineering is registered in StudioRegistry and SurfaceRegistry', () {
      final descriptor = StudioRegistry.defaultRegistry.descriptorFor(StudioDestination.engineeringWorkbench);
      expect(descriptor, isNotNull);

      final surface = SurfaceRegistry.forId(StudioDestination.engineeringWorkbench.name);
      expect(surface, isNotNull);
      expect(surface!.title, StudioDestination.engineeringWorkbench.label);
      expect(surface.icon, StudioDestination.engineeringWorkbench.icon);
    });

    test('Instruments is registered in StudioRegistry and SurfaceRegistry', () {
      final descriptor = StudioRegistry.defaultRegistry.descriptorFor(StudioDestination.instrumentsWorkbench);
      expect(descriptor, isNotNull);

      final surface = SurfaceRegistry.forId(StudioDestination.instrumentsWorkbench.name);
      expect(surface, isNotNull);
      expect(surface!.title, StudioDestination.instrumentsWorkbench.label);
      expect(surface.icon, StudioDestination.instrumentsWorkbench.icon);
    });

    testWidgets('StudioRegistry and SurfaceRegistry construct the same widget classes (no forked implementation)', (tester) async {
      // Same "one throwaway, real, mounted context" pattern
      // `surface_registry_test.dart` already established — a
      // `SurfaceDefinition.build`/`StudioDescriptor.pageBuilder` closure
      // never reads `context` at construction time, only once actually
      // composed into a tree.
      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        capturedContext = context;
        return const SizedBox.shrink();
      })));

      final engineeringSurfaceWidget = SurfaceRegistry.forId(StudioDestination.engineeringWorkbench.name)!.build;
      final instrumentsSurfaceWidget = SurfaceRegistry.forId(StudioDestination.instrumentsWorkbench.name)!.build;
      expect(engineeringSurfaceWidget(capturedContext), isA<EngineeringSurfacePage>());
      expect(instrumentsSurfaceWidget(capturedContext), isA<InstrumentsSurfacePage>());
    });
  });

  group('opening as Workspace tabs (Phase 8, items 3-4, 9)', () {
    test('opening Engineering creates exactly one Workspace tab', () {
      final controller = WorkspaceTabsController();
      final id = controller.openSurface(StudioDestination.engineeringWorkbench.name);

      expect(controller.tabs, hasLength(1));
      expect(controller.activeId, id);
      expect(controller.active!.surfaceId, StudioDestination.engineeringWorkbench.name);
      expect(controller.active!.title, 'Engineering');
    });

    test('opening Instruments creates exactly one Workspace tab', () {
      final controller = WorkspaceTabsController();
      final id = controller.openSurface(StudioDestination.instrumentsWorkbench.name);

      expect(controller.tabs, hasLength(1));
      expect(controller.activeId, id);
      expect(controller.active!.surfaceId, StudioDestination.instrumentsWorkbench.name);
      expect(controller.active!.title, 'Instruments');
    });

    test('Engineering and Instruments coexist as two separate tabs, no duplicate tab authority', () {
      final controller = WorkspaceTabsController();
      controller.openSurface(StudioDestination.engineeringWorkbench.name);
      controller.openSurface(StudioDestination.instrumentsWorkbench.name);

      expect(controller.tabs, hasLength(2));
      expect(controller.active!.surfaceId, StudioDestination.instrumentsWorkbench.name);
    });

    test('re-opening Engineering focuses the existing tab instead of duplicating it', () {
      final controller = WorkspaceTabsController();
      final firstId = controller.openSurface(StudioDestination.engineeringWorkbench.name);
      final secondId = controller.openSurface(StudioDestination.engineeringWorkbench.name);

      expect(secondId, firstId);
      expect(controller.tabs, hasLength(1));
    });
  });

  group('content parity (Phase 8, items 5-7)', () {
    testWidgets('EngineeringSurfacePage renders the same real content the Perspective provides', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EngineeringSurfacePage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Engineering'), findsOneWidget);
      expect(find.text('Engineering Objects'), findsOneWidget);
      expect(find.text('Relationships'), findsOneWidget);
      expect(find.text('Validation'), findsOneWidget);
    });

    testWidgets('InstrumentsSurfacePage renders the same real content the Perspective provides', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InstrumentsSurfacePage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Instruments'), findsOneWidget);
      // The real DockManager/DockPanelClientRegistry plumbing, populated
      // with zero instruments today — same honest empty state
      // `instrumentsPerspective` itself shows, not a fabricated one.
      expect(find.textContaining('No instruments available'), findsOneWidget);
    });

    testWidgets('switching between the two Workspace tabs shows the newly-active one\'s real content each time',
        (tester) async {
      // Drives the actual `EngineeringWorkspacePage` shell (not a
      // reimplementation of it) — the same shell every other Surface
      // already relies on.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: EngineeringWorkspacePage())),
      ));
      await tester.pump();

      final tabsController = container.read(workspaceTabsControllerProvider);
      final engineeringId = tabsController.openSurface(StudioDestination.engineeringWorkbench.name);
      final instrumentsId = tabsController.openSurface(StudioDestination.instrumentsWorkbench.name);
      await tester.pumpAndSettle();

      // Instruments is active (opened last) — its real content renders.
      expect(find.textContaining('No instruments available'), findsOneWidget);

      tabsController.activate(engineeringId);
      await tester.pumpAndSettle();

      // Switching back to Engineering shows its real content again —
      // and crucially, neither tab was closed by the switch (the
      // generic `WorkspaceTabsController.activate` behavior every other
      // Surface already relies on — see
      // `workspace_tabs_controller_test.dart`'s own "activate switches
      // the active tab without closing anything").
      expect(find.text('Engineering Objects'), findsOneWidget);
      expect(tabsController.activeId, engineeringId);
      expect(tabsController.tabs, hasLength(2), reason: 'switching tabs never closes the other one');
      expect(instrumentsId, isNot(engineeringId));
    });
  });

  group('cross-Surface navigation (Phase 8, item 8)', () {
    Future<ProviderContainer> bootstrap(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: StudioDestination.workspace.path,
        routes: [
          GoRoute(path: StudioDestination.workspace.path, builder: (context, state) => const EngineeringSurfacePage()),
          GoRoute(path: StudioDestination.objects.path, builder: (context, state) => const Scaffold(body: Text('standalone-objects'))),
        ],
      );
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      return container;
    }

    testWidgets('tapping "Engineering Objects" while the Workspace is active opens the Objects tab, does not navigate away', (tester) async {
      final container = await bootstrap(tester);

      await tester.tap(find.text('Engineering Objects'));
      await tester.pumpAndSettle();

      final tabsController = container.read(workspaceTabsControllerProvider);
      expect(tabsController.tabs, hasLength(1));
      expect(tabsController.active!.surfaceId, StudioDestination.objects.name);
      expect(find.text('standalone-objects'), findsNothing, reason: 'must not have left the Workspace route');
    });
  });

  group('regression guards (Phase 8, items 10-11)', () {
    test('/diagram remains unaffected', () {
      final descriptor = StudioRegistry.defaultRegistry.descriptorFor(StudioDestination.diagram);
      expect(descriptor, isNotNull);
      expect(SurfaceRegistry.forId(StudioDestination.diagram.name), isNull, reason: 'still deliberately excluded');
    });

    test('/diagram-classic no longer exists (retired by AP-OEP-WORKBENCH-RETIREMENT-001)', () {
      expect(StudioDestination.values.any((d) => d.path == '/diagram-classic'), isFalse);
    });
  });
}
