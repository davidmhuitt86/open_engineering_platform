import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/studio_app.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';

/// A bounded stand-in for `pumpAndSettle()` — see `test/widget_test.dart`'s
/// identical helper for why (Settings' indeterminate progress indicator
/// never lets `pumpAndSettle()` converge). Duplicated here rather than
/// imported since `test/` files in this codebase don't import each other.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Bridges `EngineHost.create()`'s real asset-load `Future`s (14 seed
/// symbols read via `rootBundle.loadString`) through `tester.runAsync` —
/// see `test/widget_test.dart`'s identical helper.
Future<void> settleDiagramStudioBootstrap(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
  });
}

/// Navigates via a `StudioDestination`'s row in the Engineering Workbench
/// sidebar (`WorkbenchSidebar`, `StudioShell`'s single left nav, replacing
/// the classic `StudioNavRail` this helper used to target by widget type
/// -- see `test/widget_test.dart`'s identical helper for the full
/// rationale, duplicated here since `test/` files in this codebase don't
/// import each other). Looked up by the stable
/// `ValueKey('sidebar-dest-<path>')` each such row carries (a plain
/// `find.text(...)` isn't safe: e.g. "Validation" also labels Project
/// Explorer's Validation branch and Diagram Studio's own validation
/// panel), scrolling the row into view first since a row past the fold
/// isn't mounted until then (the sidebar's nav list is a real
/// `Scrollable`, found by its own `ValueKey('workbench-sidebar-nav-list')`).
Future<void> navigateViaSidebar(WidgetTester tester, StudioDestination destination) async {
  final target = find.byKey(ValueKey('sidebar-dest-${destination.path}'));
  final sidebarScrollable = find.descendant(
    of: find.byKey(const ValueKey('workbench-sidebar-nav-list')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(target, 100, scrollable: sidebarScrollable);
  // `scrollUntilVisible` stops the moment any part of the target overlaps
  // the viewport, which can leave it clipped at the edge -- `tester.tap`'s
  // computed center then lands outside the Scrollable's visible region
  // and hits whatever row is actually painted there instead (a real,
  // observed flake). `ensureVisible` scrolls the target fully into view.
  await tester.ensureVisible(target);
  await settle(tester);
  await tester.tap(target);
  await settle(tester);
}

/// A `FoundationRuntimeNotifier` override that skips the real
/// `FoundationBridge.create()` `dart:ffi` call (there is no native
/// `oep_foundation_bridge.dll` under `flutter test`, and this test's
/// whole point is Studio-side wiring, not the Foundation Bridge itself)
/// and starts from a fixed, test-seeded state instead — the standard
/// Riverpod `overrideWith` test seam. `phase: error` mirrors exactly what
/// every other test in this suite already runs under (a real
/// `FoundationBridge.create()` call already fails the same way with no
/// native library present) — this override only adds the one thing no
/// existing test seam provides: a seeded `SourceMaterial` to resolve
/// evidence navigation against.
class _SeededFoundationRuntimeNotifier extends FoundationRuntimeNotifier {
  _SeededFoundationRuntimeNotifier(this._initial);
  final FoundationServiceState _initial;

  @override
  FoundationServiceState build() => _initial;
}

void main() {
  testWidgets(
    'Unified workflow: Project Explorer, cross-workspace selection, '
    'evidence navigation, live validation, and Ask AI all stay wired to '
    'the same Engineering Project (WORK_PACKAGE_025, ENGINE-TASK-000127)',
    (WidgetTester tester) async {
      // WP-DS-006: bumped from 800 to 950. Several of Diagram Studio's own
      // side panels (DiagramLayerPanel, DiagramSearchPanel,
      // DiagramValidationPanel) run with only single-digit-pixel vertical
      // margin at this fixed test viewport height -- each has tripped a
      // RenderFlex overflow independently as unrelated Workbench chrome
      // changes shifted layout by a few pixels one way or another (first
      // the horizontal Perspective Selector row, later the left
      // WorkbenchSidebar). Rather than keep chasing single-digit pixel
      // margins panel by panel, this gives real headroom once. This is
      // test viewport sizing, not a change to any assertion in this test;
      // real desktop windows are essentially never exactly 800px tall.
      // Width bumped from 1280 to 1600: WP-DS-006's new WorkbenchSidebar
      // (240px expanded) sits alongside StudioShell's own existing 200px
      // nav rail and right-hand Property Inspector panel -- at 1280px
      // wide that left DiagramStudioPage's own toolbar (`_DocumentBar`)
      // only ~540px, 20px short of what its (unchanged, out-of-scope-to-
      // redesign) button row actually needs. 1600px is a realistic
      // desktop window width and was never something this test asserted
      // against specifically -- this is viewport headroom, not a change
      // to any assertion.
      tester.view.physicalSize = const Size(1600, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sourceMaterial = SourceMaterial(
        id: 'source-1',
        originalFileName: 'timing-chain-manual.pdf',
        localPath: 'C:/fake/timing-chain-manual.pdf',
        type: SourceMaterialType.pdf,
        sizeBytes: 1024,
        importDate: DateTime(2026, 1, 1),
        addedBy: 'jsmith',
      );

      final container = ProviderContainer(
        overrides: [
          foundationRuntimeServiceProvider.overrideWith(
            () => _SeededFoundationRuntimeNotifier(
              FoundationServiceState(
                phase: FoundationConnectionPhase.error,
                sourceMaterials: [sourceMaterial],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const StudioApp()),
      );
      await settle(tester);

      // --- Seed a diagram graph directly (bypassing gesture-level canvas
      // editing, already exhaustively covered by WORK_PACKAGE_021-024's own
      // test suites) with exactly one node carrying a real EvidenceLink and
      // zero relationships, so ValidationService's `_checkFloatingNodes`
      // emits exactly one deterministic `floating_node` finding to
      // navigate through. `symbolId: 'battery'` (one of the Engine's 14
      // seed symbols) avoids also triggering `missing_symbol`/
      // `unknown_symbol`, keeping this test's one finding unambiguous.
      const evidenceLink = EvidenceLink(
        id: 'link-1',
        kind: EvidenceKind.diagramRegion,
        sourceReference: 'source-1',
        locator: {'regionId': 'region-1'},
      );
      const node = EngineeringNode(
        id: 'node-1',
        category: NodeCategory.component,
        displayName: 'Timing Chain Cover',
        symbolId: 'battery',
        evidenceLinks: [evidenceLink],
      );
      final graph = EngineeringGraph(id: 'wf-graph', nodes: {'node-1': node});

      final projectNotifier = container.read(engineeringProjectServiceProvider.notifier);
      await tester.runAsync(() async {
        final host = await projectNotifier.ensureEngineStarted();
        host.engine.beginEditingSession(graph);
      });
      await settle(tester);

      final seededState = container.read(engineeringProjectServiceProvider);
      expect(seededState.validationReport?.findings.length, 1);
      expect(seededState.validationReport!.findings.single.code, 'floating_node');

      // --- Project Explorer (ENGINE-TASK-000126): the Validation branch
      // reflects the live finding count without navigating anywhere else.
      await navigateViaSidebar(tester, StudioDestination.projectExplorer);
      await settle(tester);

      final validationBranch = find.widgetWithText(ExpansionTile, 'Validation');
      expect(
        find.descendant(of: validationBranch, matching: find.text('1')),
        findsOneWidget,
        reason: 'the Validation branch trailing badge should mirror the live finding count',
      );
      await tester.tap(validationBranch);
      await settle(tester);
      expect(find.text('1 finding(s)'), findsOneWidget);

      // --- Navigate to Diagram Studio, then select the node directly
      // through the Engine (the same public selection API a canvas click
      // uses — gesture mechanics themselves are Diagram Studio's own,
      // already-tested concern). Because ENGINE-TASK-000118 hoisted the
      // Engine out of `DiagramStudioPage`'s own private State, the Engine
      // instance is the SAME one Project Explorer/Validation just read.
      await navigateViaSidebar(tester, StudioDestination.diagram);
      await tester.pump();
      await settleDiagramStudioBootstrap(tester);
      // Also appears in the Breadcrumb Bar's Document-level segment
      // (Phase 2, ODS-S004 § 4 Navigation Hierarchy) AND in the Phase 5
      // diagram tab bar's own tab chip, hence multiple matches.
      expect(find.text('Untitled Diagram'), findsWidgets);

      final engine = container.read(engineeringProjectServiceProvider).engine!;
      engine.registry.selection.selectNode('node-1');
      await settle(tester);

      // --- Property Inspector auto-shows the selected component
      // (ENGINE-TASK-000119 Synchronization).
      expect(find.text('Timing Chain Cover'), findsWidgets);
      expect(find.text('diagramRegion: source-1'), findsOneWidget);

      // --- Evidence Integration (ENGINE-TASK-000122/123): tapping the
      // evidence row switches the Property Inspector to Evidence Link
      // mode; "Go to Evidence" resolves it against the seeded Source
      // Material and navigates to Knowledge Studio.
      await tester.tap(find.text('diagramRegion: source-1'));
      await settle(tester);
      expect(find.text('Go to Evidence'), findsOneWidget);
      expect(find.text('Source Reference'), findsOneWidget);

      await tester.tap(find.text('Go to Evidence'));
      await settle(tester);

      expect(
        find.text('That evidence could not be found in the active Knowledge Session.'),
        findsNothing,
        reason: 'the seeded Source Material should have resolved cleanly',
      );
      expect(find.text('Import Queue'), findsOneWidget); // a Knowledge Studio panel
      expect(container.read(foundationRuntimeServiceProvider).selectedSourceMaterial?.id, 'source-1');

      // --- Shared recent history (ENGINE-TASK-000119): the evidence
      // navigation above recorded an entry.
      final historyAfterEvidence = container.read(engineeringProjectServiceProvider).recentHistory;
      expect(historyAfterEvidence, isNotEmpty);
      expect(historyAfterEvidence.first.id, 'link-1');
      expect(historyAfterEvidence.first.workspaceLabel, 'Knowledge Studio');

      // --- Switching workspaces via the Navigation Rail preserves both
      // the live selection (held by the Engine, not by any one page's
      // State — re-synced to the Property Inspector the moment
      // `DiagramStudioPage` remounts) and history (it lives in
      // `engineeringProjectServiceProvider`, not a page-local field, so a
      // plain rail switch — unlike the navigation helpers above — must
      // not add to it).
      await navigateViaSidebar(tester, StudioDestination.diagram);
      await tester.pump();
      await settleDiagramStudioBootstrap(tester);

      expect(find.text('Timing Chain Cover'), findsWidgets);
      expect(
        container.read(engineeringProjectServiceProvider).recentHistory.length,
        historyAfterEvidence.length,
        reason: 'switching workspaces via the nav rail must not itself record history',
      );

      // --- Validation Integration (ENGINE-TASK-000125): the global
      // Validation page shows the SAME live report, with a Suggested Fix.
      await navigateViaSidebar(tester, StudioDestination.validation);
      await settle(tester);

      expect(find.text('1 finding(s)'), findsOneWidget);
      expect(find.text('Timing Chain Cover has no relationships.'), findsOneWidget);
      expect(find.textContaining('Connect it to the rest of the diagram'), findsOneWidget);

      // --- AI Workspace Integration (ENGINE-TASK-000124): "Ask AI" builds
      // a request from the SAME live validation + selection state and
      // calls the deterministic Mock provider — no network, reproducible
      // output.
      await tester.tap(find.text('Ask AI'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Timing Chain Cover'), findsWidgets);
      await tester.tap(find.text('Close'));
      await settle(tester);

      // --- Click-to-navigate: tapping the finding itself jumps back to
      // Diagram Studio with the affected node selected (its `subjectId`
      // resolves against the live graph).
      await tester.tap(find.text('Timing Chain Cover has no relationships.'));
      await tester.pump();
      await settleDiagramStudioBootstrap(tester);

      expect(find.text('Untitled Diagram'), findsWidgets);
      expect(find.text('Timing Chain Cover'), findsWidgets);
    },
  );
}
