import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Diagram Studio -- Phase 4, Part 8: proves right-click target
/// identification stays correct under a non-identity canvas transform
/// (zoomed in AND panned simultaneously), not just at zoom 1.0/no pan.
/// A separate file/process from `diagram_hit_testing_widget_test.dart`
/// for its own fresh right-click budget (see that file's own doc
/// comment on the discovered `kSecondaryButton` harness ceiling).
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

  testWidgets('Diagram Studio contextual targeting stays correct when the canvas is zoomed in and panned', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);
    expect(find.byTooltip('Add node'), findsOneWidget);

    final state = tester.state(find.byType(DiagramStudioPage)) as dynamic;

    Future<String> addNode() async {
      final before = Set<String>.from(state.engine.editing.session.graph.nodes.keys as Iterable<String>);
      await tester.tap(find.byTooltip('Add node'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Battery'));
      await tester.pumpAndSettle();
      await settle(tester);
      return (state.engine.editing.session.graph.nodes.keys as Iterable<String>).firstWhere((id) => !before.contains(id));
    }

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

    const relationshipId = 'r_hittest_zoom_1';
    state.engine.editing.execute(CreateRelationshipCommand(
      EngineeringRelationship(
        id: relationshipId,
        relationshipType: RelationshipType.connectedTo,
        sourceNode: nodeA,
        targetNode: nodeB,
      ),
    ));
    await settle(tester);

    // Apply a real zoom + pan through the same real, public
    // `ViewStateService` the zoom/pan toolbar controls already use --
    // not a fabricated transform.
    final ViewStateService viewState = state.engine.registry.viewState as ViewStateService;
    viewState
      ..setZoom(1.8)
      ..setPan(const Point2D(-120, -60));
    await settle(tester);
    expect(viewState.current.zoom, 1.8, reason: 'the real transform must actually have changed before this test means anything');

    // Re-measure real screen positions -- these now reflect the zoomed
    // + panned transform, exactly as a real user's screen would.
    final nodeARect = tester.getRect(nodeAFinder);
    final nodeBRect = tester.getRect(nodeBFinder);
    final wireMidpoint = Offset.lerp(nodeARect.center, nodeBRect.center, 0.5)!;

    await rightClick(tester, wireMidpoint);
    expect(find.textContaining('connectedTo'), findsOneWidget,
        reason: 'the wire must still resolve to the correct relationship at a zoomed-in, panned transform');
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // Battery's "positive" port (assets/symbols/battery.json, x=0.0,
    // y=0.5) -- real symbol data. Read straight off the port marker's
    // own key (its center reflects the current zoom/pan transform
    // automatically) rather than deriving it from `nodeARect.left`:
    // `node-$nodeA`'s `Positioned` is inflated by `kNodeHitMargin`
    // scene units on every side (an edge-exit port's marker, centered
    // exactly on the card boundary, needs that room to stay
    // hit-testable), which scales with zoom on screen, so a fixed
    // pixel offset from `nodeARect.left` no longer lines up with the
    // card's actual left edge once zoomed.
    final positivePortPoint = tester.getCenter(find.byKey(ValueKey('port-$nodeA-positive')));
    await rightClick(tester, positivePortPoint);
    expect(find.textContaining('Positive'), findsOneWidget,
        reason: 'the port must still resolve to the correct port at a zoomed-in, panned transform');
  });
}
