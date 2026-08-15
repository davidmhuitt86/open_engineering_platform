import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// OEP Diagram Studio -- Phase 4: acceptance tests for the expanded
/// contextual-target hit-testing added this phase (relationship/wire,
/// port, annotation), at the widget layer (Part 12/13's "pointer
/// location -> CursorTarget" boundary). Resolver-side behavior for
/// these targets is covered separately in
/// `test/core/context/contextual_command_resolver_test.dart` -- this
/// file only proves *which real entity* a right-click at a given
/// screen point resolves to.
///
/// **Right-click budget**: Phase 3A documented a `flutter_test`-harness
/// limitation where the 5th `kSecondaryButton` synthetic gesture in a
/// single test process is silently dropped. This file stays at 3 real
/// right-clicks (wire, port, annotation) to stay well clear of that
/// ceiling; a second file
/// (`diagram_hit_testing_transform_test.dart`) covers zoom/pan in its
/// own fresh process/budget.
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
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(tester.element(find.byType(SnackBar).first));
      messenger?.hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  }

  Future<void> rightClick(WidgetTester tester, Offset point) async {
    final gesture = await tester.startGesture(point, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('Diagram Studio contextual targeting: wire, port, and annotation hit-testing', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await bootstrap(tester);
    expect(find.byTooltip('Add node'), findsOneWidget, reason: 'Engine bootstrap must complete before any hit-testing scenario runs');

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

    // --- Part 3/8 setup: two real, spatially-SEPARATED nodes so the
    // real relationship's rendered wire crosses genuine empty canvas
    // (`_addNode`'s spawn formula places new nodes only 40px apart
    // while each is 100px, so they must be dragged apart first, exactly
    // as Phase 3's own equivalent test does).
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

    // A real relationship, created through the same public
    // `EngineeringEditingSession.execute`/`CreateRelationshipCommand`
    // API `_addNode`'s own toolbar action uses under the hood -- not a
    // fabricated wire.
    const relationshipId = 'r_hittest_1';
    state.engine.editing.execute(CreateRelationshipCommand(
      EngineeringRelationship(
        id: relationshipId,
        relationshipType: RelationshipType.connectedTo,
        sourceNode: nodeA,
        targetNode: nodeB,
      ),
    ));
    await settle(tester);

    // --- Test C (Part 12): right-click the real wire ---------------------
    final nodeARect = tester.getRect(nodeAFinder);
    final nodeBRect = tester.getRect(nodeBFinder);
    final wireMidpoint = Offset.lerp(nodeARect.center, nodeBRect.center, 0.5)!;

    // Part 9: right-click must not disturb an existing multi-selection.
    state.engine.registry.selection.selectNode(nodeA);
    state.engine.registry.selection.selectNode(nodeB, additive: true);
    await settle(tester);
    expect(state.engine.registry.selection.current.nodeIds, {nodeA, nodeB});

    await rightClick(tester, wireMidpoint);
    expect(find.textContaining('connectedTo'), findsOneWidget,
        reason: 'the menu header must identify the real relationship, using the same label convention '
            'diagram_prompt_context.dart already established');
    expect(
      state.engine.registry.selection.current.nodeIds,
      {nodeA, nodeB},
      reason: 'a right-click contextual target must not destroy the persistent multi-selection',
    );
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    // --- Test D (Part 12): right-click a real port ------------------------
    // Battery's "positive" port is at normalized (0.0, 0.5) -- real
    // symbol data (assets/symbols/battery.json), not invented -- so its
    // marker center is at the node's left-edge, vertical middle. Read
    // straight off the port marker's own key rather than deriving it
    // from `nodeARect`'s edges: `node-$nodeA`'s `Positioned` is
    // inflated by `kNodeHitMargin` on every side (an edge-exit port's
    // marker, centered exactly on the card boundary, needs that extra
    // room to stay hit-testable), so its `.left` no longer lines up
    // with the card's actual left edge.
    final positivePortPoint = tester.getCenter(find.byKey(ValueKey('port-$nodeA-positive')));
    await rightClick(tester, positivePortPoint);
    expect(find.textContaining('Positive'), findsOneWidget,
        reason: 'the menu header must show the real port displayName from the symbol definition');
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    final multimeter = ProviderScope.containerOf(tester.element(find.byType(DiagramStudioPage)), listen: false)
        .read(multimeterRuntimeServiceProvider)!;
    expect(multimeter.probeA, isNull);
    await rightClick(tester, positivePortPoint);
    await tester.tap(find.widgetWithText(PopupMenuItem<Object>, 'Place DMM Probe +'));
    await settle(tester);
    expect(multimeter.probeA, isNotNull,
        reason: 'Phase 4 Part 11 -- probe placement must now work for a port target, using its real owning node');
    expect(multimeter.probeA!.nodeId, nodeA, reason: 'the real owning node, from CursorTarget.ownerNodeId, not fabricated');
    expect(multimeter.probeA!.portId, 'positive');

    // --- Test E (Part 12) + Part 7 (target priority) ---------------------
    // A real annotation, placed at nodeA's own content-space position so
    // its rendered widget overlaps nodeA's body -- proving the real,
    // observed Z-order priority (Annotations are later `Stack` children
    // than Nodes in `graph_view_panel.dart`, so they paint on top and
    // are hit-tested first) rather than an invented ordering.
    final nodeAPosition = state.engine.editing.session.layout.positionOf(nodeA)!;
    state.engine.editing.execute(CreateAnnotationCommand(
      DiagramAnnotation(
        id: 'annotation_hittest_1',
        type: AnnotationType.freeText,
        text: 'Hit-test annotation',
        position: nodeAPosition,
      ),
    ));
    await settle(tester);

    // `nodeARect.topLeft` is the (margin-inflated) `Positioned`'s
    // corner, not the card's -- offset back in by `kNodeHitMargin` to
    // land inside the card's actual painted body.
    final overlapPoint = nodeARect.topLeft + const Offset(kNodeHitMargin + 4, kNodeHitMargin + 4);
    await rightClick(tester, overlapPoint);
    expect(find.text('Hit-test annotation'), findsWidgets,
        reason: 'the annotation, rendered on top of the node it overlaps, must win the contextual target -- '
            'proving the real, discovered Stack paint-order priority (Annotation > Node/Port > Wire/Canvas)');
  });
}
