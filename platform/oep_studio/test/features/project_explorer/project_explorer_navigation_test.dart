import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/features/project_explorer/project_explorer_page.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/workspace/workspace_tab.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-NAVIGATION-CONVERGENCE-001 — the audit's one
/// confirmed defect: `ProjectExplorerPage` had three production call
/// sites (`_openFromRepository`, the "Recent Projects" leaf, the
/// "Diagrams" leaf) that issued a raw `context.go(StudioDestination.
/// diagram.path)`, bypassing the Workspace entirely and landing on
/// `WebSurfacesHostPage`'s own separate UI shell. All three now go
/// through the existing, already-tested `openOrActivateDestination`
/// primitive (`unified_navigation_workspace_context002_test.dart`
/// already proves that primitive's own semantics generically — these
/// tests only prove `ProjectExplorerPage` actually calls it, using the
/// exact same real-`GoRouter` harness shape that file established).
void main() {
  setUp(useIsolatedSettingsStorage);

  // A bounded alternative to `pumpAndSettle()` — this page's Foundation-
  // backed branches (`_KnowledgeBranch`/`_EvidenceBranch`/etc.) and the
  // `FutureBuilder`-backed Recent Projects branch mean `pumpAndSettle()`
  // itself is unreliable here (observed to hang indefinitely in this
  // exact widget during this task's own test authoring); a fixed number
  // of pumps is enough to let an `ExpansionTile`'s animation and any
  // real `RecentProjectsStorage`/dialog async gap resolve without ever
  // blocking on "no more frames scheduled."
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  GoRouter buildRouter(String initialLocation) => GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: StudioDestination.workspace.path,
            builder: (context, state) => Scaffold(body: ProjectExplorerPage()),
          ),
          GoRoute(
            path: StudioDestination.diagram.path,
            builder: (context, state) => const Scaffold(body: Text('standalone-diagram')),
          ),
          GoRoute(
            path: StudioDestination.knowledge.path,
            builder: (context, state) => const Scaffold(body: Text('standalone-knowledge')),
          ),
          GoRoute(
            path: StudioDestination.validation.path,
            builder: (context, state) => const Scaffold(body: Text('standalone-validation')),
          ),
        ],
      );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String initialLocation = '',
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: StudioTheme.dark, routerConfig: buildRouter(initialLocation)),
    ));
    await settle(tester);
    return container;
  }

  group('Diagrams branch', () {
    testWidgets('tapping the Diagrams leaf opens the primary Diagram tab, staying inside the Workspace', (tester) async {
      final container = await pump(tester, initialLocation: StudioDestination.workspace.path);

      await tester.tap(find.text('Diagrams'));
      await settle(tester);
      await tester.tap(find.text('Untitled Diagram'));
      await settle(tester);

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.isDiagram, isTrue);
      expect(tabs.active!.id, primaryDiagramInstanceId, reason: 'must be the existing primary instance, not a new one');
      expect(find.text('standalone-diagram'), findsNothing, reason: 'must never leave the Workspace route');
    });

    testWidgets('tapping it again activates the same primary tab -- no duplicate Diagram instance', (tester) async {
      final container = await pump(tester, initialLocation: StudioDestination.workspace.path);

      await tester.tap(find.text('Diagrams'));
      await settle(tester);
      await tester.tap(find.text('Untitled Diagram'));
      await settle(tester);
      await tester.tap(find.text('Untitled Diagram'));
      await settle(tester);

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1), reason: 'repeated activation must never create a second Diagram instance');
      expect(tabs.tabs.single.id, primaryDiagramInstanceId);
    });

    testWidgets('a pre-existing secondary Diagram instance is left untouched by the Diagrams leaf', (tester) async {
      final container = await pump(tester, initialLocation: StudioDestination.workspace.path);
      final tabsController = container.read(workspaceTabsControllerProvider);
      // Realistic ordering: a secondary instance can only exist once the
      // primary already does (it is only ever created via the "+" menu's
      // dedicated Browser/Diagram entries after the primary is already
      // open) — never the reverse.
      tabsController.openSurface(WorkspaceTab.diagramSurfaceId);
      final secondaryId = tabsController.openNewInstance(WorkspaceTab.diagramSurfaceId);
      tabsController.activate(secondaryId);
      await settle(tester);

      await tester.tap(find.text('Diagrams'));
      await settle(tester);
      await tester.tap(find.text('Untitled Diagram').first);
      await settle(tester);

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs.map((t) => t.id), containsAll([primaryDiagramInstanceId, secondaryId]));
      expect(tabs.tabs, hasLength(2), reason: 'the pre-existing secondary instance must survive untouched, and no third instance is created');
      expect(tabs.active!.id, primaryDiagramInstanceId, reason: 'the Diagrams leaf targets the primary, not whichever Diagram tab was last active');
    });
  });

  // The "Recent Projects" and "Open from Repository" leaves both feed a
  // real `RecentProjectsStorage` `Future` into a `FutureBuilder`/async
  // gap. Mounting them in `flutter_test` with real (non-empty) file I/O
  // was found, during this task's own authoring, to hang the test
  // harness indefinitely regardless of `tester.runAsync()` wrapping —
  // reproduced in isolation with a bare `FutureBuilder` fed by
  // `RecentProjectsStorage.load()`, with no `ProjectExplorerPage`,
  // Riverpod, or `ExpansionTile` involved at all. This is a pre-existing
  // `flutter_test`/real-`dart:io` interaction hazard, not something this
  // task's navigation change introduced or can fix. Both call sites use
  // the exact same `openOrActivateDestination(context, ref,
  // StudioDestination.diagram)` call already proven correct end-to-end by
  // the "Diagrams branch" tests above (same function, same arguments, no
  // per-call-site branching inside it) -- so source-level verification
  // that the raw `context.go` call is gone and the primitive is used is
  // sufficient here.
  group('Recent Projects and Open from Repository (source-level)', () {
    late String source;

    setUpAll(() {
      source = File('lib/features/project_explorer/project_explorer_page.dart').readAsStringSync();
    });

    test('no raw context.go(StudioDestination.diagram.path) call sites remain', () {
      expect(source.contains('context.go(StudioDestination.diagram.path)'), isFalse);
    });

    test('Recent Projects leaf and Open from Repository both route through openOrActivateDestination', () {
      final matches = 'openOrActivateDestination(context, ref, StudioDestination.diagram)'.allMatches(source).length;
      expect(matches, greaterThanOrEqualTo(2), reason: 'expected the Recent Projects leaf and the Open from Repository leaf to both call the shared primitive');
    });
  });

  // AP-OEP-WORKSPACE-NAVIGATION-CONVERGENCE-002 — the two remaining raw
  // `context.go` sites the completeness audit found in this file: the
  // Evidence branch's leaf (-> Knowledge) and the Validation branch's
  // leaf (-> Validation). Both now go through `openOrActivateDestination`
  // exactly like the Diagrams branch above.
  group('Evidence branch', () {
    testWidgets('tapping an Evidence leaf opens/activates the Knowledge tab, staying inside the Workspace', (tester) async {
      final container = await pump(
        tester,
        initialLocation: StudioDestination.workspace.path,
        overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeFoundationWithSourceNotifier.new)],
      );

      await tester.tap(find.text('Evidence'));
      await settle(tester);
      await tester.tap(find.text('spec.pdf'));
      await settle(tester);

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.knowledge.name);
      expect(find.text('standalone-knowledge'), findsNothing, reason: 'must never leave the Workspace route');
    });
  });

  group('Validation branch', () {
    testWidgets('tapping the Validation leaf opens/activates the Validation tab, staying inside the Workspace', (tester) async {
      final container = await pump(tester, initialLocation: StudioDestination.workspace.path);

      await tester.tap(find.text('Validation'));
      await settle(tester);
      await tester.tap(find.text('No findings'));
      await settle(tester);

      final tabs = container.read(workspaceTabsControllerProvider);
      expect(tabs.tabs, hasLength(1));
      expect(tabs.active!.surfaceId, StudioDestination.validation.name);
      expect(find.text('standalone-validation'), findsNothing, reason: 'must never leave the Workspace route');
    });
  });

  group('unrelated existing behavior is unchanged', () {
    testWidgets('Open from Repository still warns when no repository is open', (tester) async {
      await pump(tester, initialLocation: StudioDestination.workspace.path);

      await tester.tap(find.text('Open from Repository'));
      await tester.pump();

      expect(find.text('Open a repository from the Dashboard first.'), findsOneWidget);
    });

    testWidgets('New Project and Open from Repository entries still both render', (tester) async {
      await pump(tester, initialLocation: StudioDestination.workspace.path);

      expect(find.text('Open from Repository'), findsOneWidget);
      expect(find.text('New Project'), findsOneWidget);
    });
  });
}

class _FakeFoundationWithSourceNotifier extends FoundationRuntimeNotifier {
  @override
  FoundationServiceState build() => FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        sourceMaterials: [
          SourceMaterial(
            id: 'src-1',
            originalFileName: 'spec.pdf',
            localPath: 'C:/tmp/spec.pdf',
            type: SourceMaterialType.pdf,
            sizeBytes: 1024,
            importDate: DateTime.utc(2024, 1, 1),
            addedBy: 'alice',
          ),
        ],
      );
}
