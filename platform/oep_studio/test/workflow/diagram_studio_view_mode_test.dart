import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Diagram Studio -- Phase 6: widget-layer acceptance tests for
/// View/Inspect mode's actual chrome -- Tests A, B, C, D, J, K from
/// Part 25. DMM/simulation-preservation/Knowledge/AI (Tests F/G/H/I)
/// are covered at the resolver layer in
/// `test/core/context/contextual_command_resolver_test.dart` (Part
/// 13's "use the lowest appropriate testing layer" -- no reason to
/// re-drive those through real widget gestures here).
///
/// Stays at 3 real right-clicks (node, wire, port) in this one
/// process, matching the documented `kSecondaryButton` harness ceiling
/// from Phase 3A/4's own test files.
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

  Future<void> rightClick(WidgetTester tester, Offset point) async {
    final gesture = await tester.startGesture(point, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('Diagram Studio View mode: quiet chrome, real contextual targeting, panel toggles', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);
    expect(find.byTooltip('Add node'), findsOneWidget);

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

    // A real, non-trivial diagram to inspect: two separated nodes plus
    // a real wire between them (same construction Phase 4's own
    // hit-testing tests use).
    final nodeA = await addNode();
    final nodeAFinder = find.byKey(ValueKey('node-$nodeA'));
    final nodeB = await addNode();
    final nodeBFinder = find.byKey(ValueKey('node-$nodeB'));
    const separationDelta = Offset(500, 0);
    final dragGesture = await tester.startGesture(tester.getCenter(nodeBFinder));
    await tester.pump(const Duration(milliseconds: 30));
    for (var step = 1; step <= 6; step++) {
      await dragGesture.moveBy(separationDelta / 6);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await dragGesture.up();
    await settle(tester);
    state.engine.editing.execute(CreateRelationshipCommand(
      EngineeringRelationship(
        id: 'r_view_mode_test',
        relationshipType: RelationshipType.connectedTo,
        sourceNode: nodeA,
        targetNode: nodeB,
      ),
    ));
    await settle(tester);

    // --- Test A: View mode entry -----------------------------------------
    // Edit mode's default panels (Object Explorer, Layers, Search,
    // Annotations, Recent Commands) are all visible before switching --
    // establishes the "before" state Test K's own comparison needs.
    expect(find.text('Object Explorer'), findsOneWidget);
    expect(find.text('Layers'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diagram-mode-view')));
    await settle(tester);

    expect(find.byTooltip('Add node'), findsNothing, reason: 'construction toolset must be hidden in View mode');
    expect(find.byType(GraphViewPanel), findsOneWidget, reason: 'the diagram itself must remain visible and dominant');

    // --- Test K: no clutter by default -------------------------------------
    expect(find.text('Object Explorer'), findsNothing, reason: 'View mode must default to a sparse workspace');
    expect(find.text('Layers'), findsNothing);
    expect(find.text('Search'), findsNothing);
    expect(find.text('Annotations'), findsNothing);
    expect(find.text('Recent Commands'), findsNothing);

    // --- Test B: right-click a real node in View mode ----------------------
    final nodeDisplayName = state.engine.editing.session.graph.nodes[nodeA].displayName as String;
    final nodeARect = tester.getRect(nodeAFinder);
    await rightClick(tester, nodeARect.center);
    expect(find.text(nodeDisplayName), findsWidgets, reason: 'the menu must still show the real node identity in View mode');
    expect(find.text('INSPECT'), findsOneWidget, reason: 'Inspect commands remain available in View mode');
    // Edit-only commands (from Edit-mode-gated descriptors) must not
    // leak into View mode's menu -- proven at the resolver layer
    // exhaustively; here just confirm the one real example
    // (`diagram.annotate.add`, gated Edit-only) does not appear.
    expect(find.text('Add Annotation'), findsNothing, reason: 'Edit-only commands must not appear in View mode');
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // --- Test C: right-click the real wire in View mode --------------------
    final nodeBRect = tester.getRect(nodeBFinder);
    final wireMidpoint = Offset.lerp(nodeARect.center, nodeBRect.center, 0.5)!;
    await rightClick(tester, wireMidpoint);
    expect(find.textContaining('connectedTo'), findsOneWidget, reason: 'the wire must still resolve to its real relationship identity');
    // No editing commands (e.g. a fault-injection entry, gated out of
    // View mode this phase) leak in either.
    expect(find.text('Inject Fault'), findsNothing, reason: 'Part 10: View mode is inspect/measure, not manipulate/diagnose');
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // --- Test D: right-click a real port in View mode; DMM still works ----
    final multimeter = container.read(multimeterRuntimeServiceProvider)!;
    expect(multimeter.probeA, isNull);
    // Battery's real "positive" port (assets/symbols/battery.json,
    // x=0.0, y=0.5) -- same real geometry Phase 4's own port test uses.
    // Read straight off the port marker's own key rather than deriving
    // it from `nodeARect.left`: `node-$nodeA`'s `Positioned` is
    // inflated by `kNodeHitMargin` on every side (an edge-exit port's
    // marker, centered exactly on the card boundary, needs that extra
    // room to stay hit-testable), so its `.left` no longer lines up
    // with the card's actual left edge.
    final positivePortPoint = tester.getCenter(find.byKey(ValueKey('port-$nodeA-positive')));
    await rightClick(tester, positivePortPoint);
    expect(find.textContaining('Positive'), findsOneWidget, reason: 'the port must still resolve to its real identity in View mode');
    await tester.tap(find.widgetWithText(PopupMenuItem<Object>, 'Place DMM Probe +'));
    await settle(tester);
    expect(multimeter.probeA, isNotNull, reason: 'Part 8: DMM is a legitimate View-mode capability, through the real runtime');
    expect(multimeter.probeA!.nodeId, nodeA);

    // --- Test J: panel visibility toggles still work in View mode ---------
    expect(find.text('Object Explorer'), findsNothing);
    await tester.tap(find.byTooltip('Toggle Object Explorer'));
    await settle(tester);
    expect(find.text('Object Explorer'), findsOneWidget, reason: 'the user can still deliberately open a panel in View mode');
    await tester.tap(find.byTooltip('Toggle Object Explorer'));
    await settle(tester);
    expect(find.text('Object Explorer'), findsNothing);

    // --- Test A (continued): mode is visually identifiable, and
    // returning to Edit restores its own defaults ---------------------------
    await tester.tap(find.byKey(const ValueKey('diagram-mode-edit')));
    await settle(tester);
    expect(find.byTooltip('Add node'), findsOneWidget, reason: 'Edit mode restores the construction toolset');
    expect(find.text('Object Explorer'), findsOneWidget, reason: 'Edit mode restores its own pre-Phase-6 panel defaults');
  });
}
