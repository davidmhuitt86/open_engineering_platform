import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification), § 5: "Wire"
/// is one of the six persistent Edit-mode controls the ratified spec
/// calls for. Before this, creating a wire was only possible via an
/// undiscoverable click-drag directly from one port to another (no
/// visible affordance at all). This verifies the real, explicit
/// two-click alternative: toggle Wire mode, click a port, click a
/// second port on a different node -- a real `EngineeringRelationship`
/// is created through the same `ConnectionValidator`/
/// `CreateRelationshipCommand` the drag path already used.
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

  // A plain press+release at a widget's center, with no hover-synthesis
  // beforehand -- `tester.tap()` synthesizes a hover-then-click
  // sequence that, on the toolbar's icon buttons (each wrapped in its
  // own `Tooltip`), can leave a Tooltip overlay entry mounted and not
  // yet dismissed by the time of the next interaction.
  Future<void> press(WidgetTester tester, Finder finder) async {
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await gesture.up();
  }

  testWidgets('Wire mode: two port clicks on different nodes create a real relationship', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);

    final state = tester.state(find.byType(DiagramStudioPage)) as dynamic;

    Future<String> addNode() async {
      final before = Set<String>.from(state.engine.editing.session.graph.nodes.keys as Iterable<String>);
      await press(tester, find.byTooltip('Add node'));
      await tester.pumpAndSettle();
      await press(tester, find.widgetWithText(PopupMenuItem<String>, 'Battery').first);
      await tester.pumpAndSettle();
      await settle(tester);
      Tooltip.dismissAllToolTips();
      await settle(tester);
      return (state.engine.editing.session.graph.nodes.keys as Iterable<String>).firstWhere((id) => !before.contains(id));
    }

    final nodeA = await addNode();
    final nodeB = await addNode();

    // Separate them so their ports/hit regions don't overlap.
    final nodeBFinder = find.byKey(ValueKey('node-$nodeB'));
    final dragGesture = await tester.startGesture(tester.getCenter(nodeBFinder));
    await tester.pump(const Duration(milliseconds: 30));
    for (var step = 1; step <= 6; step++) {
      await dragGesture.moveBy(const Offset(150, 0) / 6);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await dragGesture.up();
    await settle(tester);

    // The drag above leaves nodeB selected, which renders ResizeHandles
    // -- deselect so it doesn't interfere with the port taps below.
    state.engine.registry.selection.deselectAll();
    await settle(tester);

    final relCountBefore = state.engine.editing.session.graph.relationships.length;

    // Toggle Wire mode on FIRST -- a new toolbar icon can shift the
    // toolbar row's wrap/height, which shifts the canvas's on-screen
    // position, so node rects must be measured AFTER this, not before
    // (the same stale-rect-after-layout-change pattern seen in earlier
    // phases' own widget tests).
    await press(tester, find.byTooltip('Wire: click two ports to connect them'));
    await settle(tester);
    Tooltip.dismissAllToolTips();
    await settle(tester);

    // Real, stable per-port Keys (Phase 14) -- lets `tester.getCenter`
    // compute the correct hit point itself instead of manual screen-
    // coordinate math, which proved unreliable against the full
    // canvas's pan/zoom transform.
    await press(tester, find.byKey(ValueKey('port-$nodeA-positive')));
    await settle(tester);
    Tooltip.dismissAllToolTips();
    await settle(tester);
    await press(tester, find.byKey(ValueKey('port-$nodeB-negative')));
    await settle(tester);

    final relCountAfter = state.engine.editing.session.graph.relationships.length;
    expect(relCountAfter, relCountBefore + 1, reason: 'the two-click Wire mode created exactly one real relationship');

    final created = (state.engine.editing.session.graph.relationships.values as Iterable).lastWhere(
      (r) => (r.sourceNode == nodeA && r.targetNode == nodeB) || (r.sourceNode == nodeB && r.targetNode == nodeA),
    );
    expect(created, isNotNull);
  });
}
