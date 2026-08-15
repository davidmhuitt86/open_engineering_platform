import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Context & Capability Service — Phase 3: acceptance tests for the
/// Diagram Studio right-click contextual menu, mirroring the governing
/// spec's Part 23 (Tests A-J). All scenarios run inside one
/// `testWidgets` for the same reason `diagram_studio_interaction_test.dart`
/// does — `EngineHost.create()`'s real asset-load bootstrap only
/// reliably completes for the first `DiagramStudioPage` mounted per
/// test process.
///
/// **Known limitation (documented, not worked around)**: this suite
/// currently covers Tests A (empty canvas), B (real node target), and C
/// (real DMM probe placement through the menu). Tests D-J (measurement,
/// fault injection, unsupported-fault absence, knowledge, AI, stale-
/// command revalidation, multi-selection) are not yet included.
/// Investigation found that the *fifth* synthetic `kSecondaryButton`
/// gesture dispatched via `WidgetTester.startGesture` in this test
/// process silently fails to reach any gesture handler at all (neither
/// `GraphViewPanel`'s background `onSecondaryTapUp` nor
/// `SymbolNodeWidget`'s per-node `onSecondaryTapUp`) -- confirmed
/// reproducible regardless of click target (a previously-successful
/// point or a fresh one), regardless of how the preceding menu was
/// dismissed (barrier tap vs. item selection), regardless of an
/// intervening real `async` gap (`DiagramSimulationService.createSession`,
/// tried both awaited directly and wrapped in `tester.runAsync`),
/// regardless of pointer device kind (mouse vs. default touch), and
/// regardless of using explicit distinct pointer ids per gesture. Every
/// other diagnostic at the failure point was clean: no leftover
/// `PopupMenuItem`s, a stable (non-growing) `ModalBarrier`/
/// `FadeTransition` count identical before and after several successful
/// menu cycles, and correct capability/menu content on every gesture
/// that *did* land. This points to a `flutter_test`-harness-level
/// limitation specific to repeated secondary-button gesture simulation
/// in a single test process, not a bug in the Contextual Menu
/// architecture itself -- Tests A-C already exercise the real
/// end-to-end pipeline (hit-testing -> `EngineeringInteractionContext`
/// -> `ContextualCommandResolver` -> `MenuDescriptor` -> real
/// `MultimeterController` mutation), so the architecture is proven; the
/// remaining scenarios need either a fixed/updated Flutter SDK, a
/// different gesture-simulation strategy, or splitting across multiple
/// `testWidgets` (blocked today by the single-bootstrap-per-process
/// constraint noted above) to complete.
void main() {
  Widget harness() {
    return ProviderScope(
      child: MaterialApp(
        theme: StudioTheme.dark,
        home: const Scaffold(body: DiagramStudioPage()),
      ),
    );
  }

  Future<void> bootstrap(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.byTooltip('Add node').evaluate().isNotEmpty) return;
      }
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  /// Simulates a real secondary-button (right-click) tap at [point] --
  /// the first use of `kSecondaryButton` in this test suite (confirmed
  /// no prior precedent existed before this phase).
  Future<void> rightClick(WidgetTester tester, Offset point) async {
    final gesture = await tester.startGesture(point, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('Diagram Studio contextual menu: right-click target detection, resolution, and real execution', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);
    expect(find.byTooltip('Add node'), findsOneWidget, reason: 'Engine bootstrap must complete before any menu test runs');

    final state = tester.state(find.byType(DiagramStudioPage)) as dynamic;
    final container = ProviderScope.containerOf(tester.element(find.byType(DiagramStudioPage)), listen: false);

    Future<String> addNode() async {
      final before = Set<String>.from(state.engine.editing.session.graph.nodes.keys as Iterable<String>);
      await tester.tap(find.byTooltip('Add node'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Battery'));
      await tester.pumpAndSettle();
      await settle(tester);
      return (state.engine.editing.session.graph.nodes.keys as Iterable<String>).firstWhere((id) => !before.contains(id));
    }

    // --- Add real nodes first ------------------------------------------
    // `DiagramScene`'s content area is sized from actual node
    // positions (`maxColumn + DiagramLayout.cellWidth` /
    // `maxRow + DiagramLayout.cellHeight`) -- for a genuinely empty
    // diagram this content area can be far smaller than the viewport,
    // meaning "safe-looking" viewport-relative coordinates chosen before
    // any node exists may fall outside the actual interactive/pannable
    // content and never reach any of `GraphViewPanel`'s gesture
    // handlers. Placing real nodes first establishes a real, sized
    // content area to click within.
    //
    // `_addNode`'s spawn formula places nodes only 40px apart (`_nodeSpawnStep`)
    // while each node is 100px wide/tall (`_nodeSize`) -- adjacent spawned
    // nodes visually overlap, so the midpoint between their centers is
    // NOT empty canvas. Instead, derive the real screen-space affine
    // transform (uniform scale + translate) from the two nodes' known
    // content-space positions (40,40) and (80,40) versus their actual
    // rendered rects, then map a content-space point known to be
    // outside both node boxes but inside the real content bounds
    // (`maxColumn(80) + cellWidth(160) = 240` wide,
    // `maxRow(40) + cellHeight(140) = 180` tall) to real screen
    // coordinates for the empty-canvas click.
    final nodeA = await addNode();
    final nodeCenter = tester.getCenter(find.byKey(ValueKey('node-$nodeA')));
    final rectA = tester.getRect(find.byKey(ValueKey('node-$nodeA')));
    final nodeB = await addNode();
    final rectB = tester.getRect(find.byKey(ValueKey('node-$nodeB')));

    // --- Test A: empty canvas ------------------------------------------
    // nodeA is at content (40,40), nodeB at content (80,40) (see
    // `_addNode`'s spawn formula, `_nodeSpawnStep = 40`).
    final scale = (rectB.left - rectA.left) / (80 - 40);
    final originX = rectA.left - scale * 40;
    final originY = rectA.top - scale * 40;
    // Content point (210,160): past both nodes' boxes (40..180 x,
    // 40..140 y) but still inside the real content bounds (240x180).
    final emptyPoint = Offset(originX + scale * 210, originY + scale * 160);
    // `_addNode` auto-selects the node it creates -- `effectiveTarget`
    // correctly falls back to the current selection when the cursor
    // target itself is "none" (Contract spec's own fallback rule), so
    // a genuinely empty-canvas right-click test must start from no
    // selection, matching what "right-click on truly empty canvas"
    // means.
    state.engine.registry.selection.deselectAll();
    await settle(tester);
    await rightClick(tester, emptyPoint);
    expect(find.text('Canvas'), findsOneWidget, reason: 'the menu header must identify the empty-canvas target');
    // No object-specific command groups (Inspect/Test/Diagnose) exist
    // for an untargeted canvas in this initial command set.
    expect(find.text('INSPECT'), findsNothing);
    expect(find.text('TEST'), findsNothing);
    // Dismiss.
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // nodeA and nodeB were spawned only 40px apart while each is 100px
    // wide/tall, so they visually overlap -- right-clicking nodeA's
    // center would actually hit whichever node is topmost in the
    // `Stack`. Drag nodeB away (the same stepped-gesture drag pattern
    // `diagram_studio_interaction_test.dart` already established) so
    // every subsequent per-node right-click lands unambiguously.
    final nodeBFinder = find.byKey(ValueKey('node-$nodeB'));
    const separationDelta = Offset(320, 260);
    final separateDragGesture = await tester.startGesture(tester.getCenter(nodeBFinder));
    await tester.pump(const Duration(milliseconds: 30));
    for (var step = 1; step <= 6; step++) {
      await separateDragGesture.moveBy(separationDelta / 6);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await separateDragGesture.up();
    await settle(tester);
    final nodeBCenter = tester.getCenter(nodeBFinder);

    // --- Test B: real node ----------------------------------------------
    final nodeDisplayName = state.engine.editing.session.graph.nodes[nodeA].displayName as String;
    await rightClick(tester, nodeCenter);
    expect(find.text(nodeDisplayName), findsWidgets, reason: 'the menu header must show the real node identity');
    expect(find.text('INSPECT'), findsOneWidget);
    final inspectObject = find.widgetWithText(PopupMenuItem<Object>, 'Inspect Object');
    expect(inspectObject, findsOneWidget);
    // "Place DMM Probe +/-" (`CommandGroup.test`, `RequireSelectedTarget`
    // only) are applicable as soon as a node is targeted -- they are how
    // probes get placed in the first place. "Measure" is a separate,
    // `RequireBothProbesPlaced`-gated submenu (target-shaped -> hidden,
    // not merely disabled) and must not appear until both probes exist.
    expect(find.text('TEST'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<Object>, 'Place DMM Probe +'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<Object>, 'Measure'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // --- Test C: probe placement -----------------------------------------
    final multimeter = container.read(multimeterRuntimeServiceProvider)!;
    expect(multimeter.probeA, isNull);
    await rightClick(tester, nodeCenter);
    await tester.tap(find.widgetWithText(PopupMenuItem<Object>, 'Place DMM Probe +'));
    await settle(tester);
    expect(multimeter.probeA, isNotNull, reason: 'the real, shared MultimeterController must reflect the placement');
    expect(multimeter.probeA!.nodeId, nodeA);

    await rightClick(tester, nodeBCenter);
    await tester.tap(find.widgetWithText(PopupMenuItem<Object>, 'Place DMM Probe -'));
    await settle(tester);
    expect(multimeter.probeB, isNotNull);
    expect(multimeter.probeB!.nodeId, nodeB);

    // Tests D-J are not implemented in this pass -- see the class-level
    // doc comment above for the discovered, still-unresolved test-
    // harness limitation blocking them (a 5th `kSecondaryButton`
    // synthetic gesture per test process is silently dropped before
    // reaching any handler).
  });
}
