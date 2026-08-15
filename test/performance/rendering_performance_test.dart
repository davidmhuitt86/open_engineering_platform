import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'synthetic_diagram_generator.dart';

/// AP-DS-001B "Rendering Performance" / "Rendering Optimization" /
/// "Large Diagram Testing" benchmark harness.
///
/// ## Methodology (read before interpreting numbers)
///
/// This suite runs under `flutter test`, i.e. headless, no real GPU
/// compositor, no real display refresh loop. Everything reported here is
/// a **CPU-time proxy** for the real thing, obtained with `Stopwatch`
/// around a specific operation, not a live FPS counter:
///
/// - "Frame build time" = wall-clock time for `DiagramView.render()`
///   (Graph -> `DiagramScene`, pure Dart, no Flutter) plus, at a subset
///   of object counts, the time `WidgetTester.pumpWidget`/`pump` spends
///   building `GraphViewPanel`'s widget tree (`Element`/`RenderObject`
///   construction and `CustomPainter.paint()` calls run synchronously
///   under `pumpWidget` even without a real display). This measures build
///   + paint-callback CPU cost, not actual screen-out GPU rasterization
///   time, and not input-to-photon latency.
/// - "Implied FPS" = `1000 / ms-per-frame-proxy`, presented explicitly as
///   an implied/derived number, not a measured one.
/// - Zoom/pan latency = time to compute the resulting `ViewState`
///   (matrix/transform arithmetic), not time to actually re-composite a
///   frame on screen.
/// - Selection latency = time for `DiagramHitTesting.nodesInRect` (the
///   same primitive box-select and click-hit-testing use) to run against
///   a `DiagramScene` of the given size.
/// - Wire-edit latency = time for `WireEditing.dragCorner`/`insertVertex`/
///   `removeVertex` to run against a representative wire at realistic
///   wire counts in the surrounding scene.
/// - Property-update latency = time for
///   `CommandHistory.execute(UpdateNodePropertiesCommand(...))` to run
///   against a graph of the given total node count — this is the number
///   that answers "does a single-node edit scale with total document
///   size."
///
/// ## What this environment cannot measure
///
/// Real GPU-bound frame time, real display-refresh-synced FPS, real
/// input-to-photon latency, and real user-perceived jank (frame time
/// variance/jitter under actual pointer events) all require a live,
/// on-device interactive profiling session (e.g. Flutter DevTools'
/// timeline view attached to a running app) — none of that exists in a
/// `flutter test` process, which never opens a real window or GPU
/// context. The numbers below are a correct and useful *relative*
/// signal (how cost scales with object count, whether an optimization
/// measurably helped) but should not be read as "the app renders at N
/// FPS" in the way a user would experience it.
void main() {
  // Kept modest so the full suite stays fast in CI; large-diagram
  // "does it even complete" coverage lives in the 10k/100k pure-Dart
  // (non-widget) benchmarks below, which don't pay Flutter widget-tree
  // construction cost.
  const objectCounts = [10, 100, 1000, 10000, 100000];

  final results = <int, Map<String, double>>{};

  tearDownAll(() {
    // Print a results table once, after every benchmark has run, so a
    // human (or the Performance Report) can read one consolidated block
    // instead of scattered per-test prints.
    // ignore: avoid_print
    print('\n=== AP-DS-001B Rendering Performance Results (ms; headless CPU-time proxy, see file doc comment) ===');
    // ignore: avoid_print
    print(
      'objects'.padRight(10) +
          'sceneRenderMs'.padRight(16) +
          'impliedFPS'.padRight(12) +
          'zoomMs'.padRight(10) +
          'panMs'.padRight(10) +
          'selectMs'.padRight(12) +
          'wireEditMs'.padRight(12) +
          'propUpdateMs'.padRight(14),
    );
    for (final count in objectCounts) {
      final r = results[count];
      if (r == null) continue;
      final fps = r['sceneRenderMs']! > 0 ? (1000 / r['sceneRenderMs']!) : double.infinity;
      // ignore: avoid_print
      print(
        '$count'.padRight(10) +
            r['sceneRenderMs']!.toStringAsFixed(3).padRight(16) +
            fps.toStringAsFixed(1).padRight(12) +
            r['zoomMs']!.toStringAsFixed(3).padRight(10) +
            r['panMs']!.toStringAsFixed(3).padRight(10) +
            r['selectMs']!.toStringAsFixed(3).padRight(12) +
            r['wireEditMs']!.toStringAsFixed(3).padRight(12) +
            r['propUpdateMs']!.toStringAsFixed(3).padRight(14),
      );
    }
  });

  for (final count in objectCounts) {
    test('benchmark @ $count objects', () {
      final synthetic = SyntheticDiagram.generate(count);
      final view = DiagramView();
      final routing = OrthogonalRoutingProvider();

      // --- Scene render (build/paint proxy) ---
      final renderWatch = Stopwatch()..start();
      final scene = view.render(synthetic.graph, layout: synthetic.layout, routing: routing);
      renderWatch.stop();
      final sceneRenderMs = renderWatch.elapsedMicroseconds / 1000;

      expect(scene.nodes.length, greaterThanOrEqualTo(0));

      // --- Zoom latency: computing the resulting ViewState from a zoom
      // gesture is pure arithmetic, independent of scene content, so this
      // number is expected to be flat across object counts (that's the
      // point of the measurement, not a flaw in it: zoom cost lives in
      // *repainting under the new transform*, captured separately by the
      // widget-pump benchmark below at select counts).
      final baseView = const ViewState().copyWith(
        zoom: 1.0,
        viewportWidth: 1920,
        viewportHeight: 1080,
      );
      final zoomWatch = Stopwatch()..start();
      final zoomed = baseView.copyWith(zoom: (baseView.zoom * 1.1).clamp(0.25, 4.0));
      zoomWatch.stop();
      expect(zoomed.zoom, isNot(equals(baseView.zoom)));
      final zoomMs = zoomWatch.elapsedMicroseconds / 1000;

      // --- Pan latency: same rationale as zoom above.
      final panWatch = Stopwatch()..start();
      final panned = baseView.copyWith(
        pan: baseView.pan.translate(50, 0),
      );
      panWatch.stop();
      expect(panned.pan.dx, isNot(equals(baseView.pan.dx)));
      final panMs = panWatch.elapsedMicroseconds / 1000;

      // --- Selection latency: hit-test a box-select rect covering the
      // upper-left quadrant of the generated content against the full
      // scene, exercising DiagramHitTesting.nodesInRect at this object
      // count.
      final selectWatch = Stopwatch()..start();
      final selected = DiagramHitTesting.nodesInRect(
        scene,
        Rect2D(left: 0, top: 0, right: scene.contentWidth / 2, bottom: scene.contentHeight / 2),
      );
      selectWatch.stop();
      final selectMs = selectWatch.elapsedMicroseconds / 1000;
      expect(selected, isA<Set<String>>());

      // --- Wire edit latency: drag the middle vertex of a representative
      // multi-point wire (or synthesize one if the scene's wires are all
      // 2-point straight lines, since WireEditing needs an interior
      // vertex to drag).
      final sampleWire = scene.wires.isNotEmpty
          ? scene.wires.first.points
          : const [Point2D(0, 0), Point2D(50, 0), Point2D(50, 50)];
      final wireForEdit = sampleWire.length >= 3
          ? sampleWire
          : [
              sampleWire.isNotEmpty ? sampleWire.first : const Point2D(0, 0),
              const Point2D(50, 0),
              sampleWire.length > 1 ? sampleWire.last : const Point2D(50, 50),
            ];
      final wireEditWatch = Stopwatch()..start();
      WireEditing.dragCorner(wireForEdit, 1, const Point2D(60, 10));
      wireEditWatch.stop();
      final wireEditMs = wireEditWatch.elapsedMicroseconds / 1000;

      // --- Property update latency: this is the "does it scale with
      // total document size" measurement. UpdateNodePropertiesCommand
      // only touches one node's properties, but EngineeringGraph.withNode
      // rebuilds the *entire* nodes map via `{...nodes, id: node}` map
      // spread, which is O(total node count) — so this number is
      // expected to grow with `count`, and that growth is the actual
      // finding (see Performance Report "Known limitations").
      if (synthetic.graph.nodes.isNotEmpty) {
        final targetNodeId = synthetic.graph.nodes.keys.first;
        final session = EditingSession(graph: synthetic.graph, layout: synthetic.layout);
        final history = CommandHistory();
        final propWatch = Stopwatch()..start();
        history.execute(
          UpdateNodePropertiesCommand(targetNodeId, {'benchmarkTouch': true}),
          session,
        );
        propWatch.stop();
        final propUpdateMs = propWatch.elapsedMicroseconds / 1000;

        results[count] = {
          'sceneRenderMs': sceneRenderMs,
          'zoomMs': zoomMs,
          'panMs': panMs,
          'selectMs': selectMs,
          'wireEditMs': wireEditMs,
          'propUpdateMs': propUpdateMs,
        };
      } else {
        results[count] = {
          'sceneRenderMs': sceneRenderMs,
          'zoomMs': zoomMs,
          'panMs': panMs,
          'selectMs': selectMs,
          'wireEditMs': wireEditMs,
          'propUpdateMs': 0,
        };
      }
    });
  }

  group('WirePainter.paint() cost (full wire list, no viewport culling)', () {
    // WirePainter (oep_engine/lib/views/widgets/wire_painter.dart) draws
    // every wire in `scene.wires` on every repaint, regardless of the
    // current viewport — unlike nodes/annotations, wires are never culled
    // (see graph_view_panel.dart's doc comment on that decision). This
    // measures whether that unculled full-list paint is actually a
    // meaningful cost at large object counts, using a real `Canvas`
    // (`PictureRecorder`) rather than a widget pump, so it isolates paint
    // cost from widget-tree build cost.
    for (final count in [1000, 10000, 100000]) {
      test('paint @ $count total objects', () {
        final synthetic = SyntheticDiagram.generate(count);
        final scene = DiagramView().render(
          synthetic.graph,
          layout: synthetic.layout,
          routing: OrthogonalRoutingProvider(),
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = WirePainter(scene.wires);
        final watch = Stopwatch()..start();
        painter.paint(canvas, const Size(1920, 1080));
        watch.stop();
        final picture = recorder.endRecording();
        picture.dispose();
        final paintMs = watch.elapsedMicroseconds / 1000;
        // ignore: avoid_print
        print('WirePainter.paint @ $count objects (${scene.wires.length} wires, UNCULLED): ${paintMs.toStringAsFixed(2)}ms');

        // AP-DS-001B fix, "after" measurement: apply the same bounding-box
        // viewport cull GraphViewPanel now applies before constructing
        // WirePainter, for a 1920x1080 viewport at the scene origin, and
        // re-time the paint call — this is the direct before/after proof
        // for the wire-culling optimization added in this phase.
        const viewport = Rect2D(left: 0, top: 0, right: 1920, bottom: 1080);
        const margin = 200.0;
        bool wireVisible(DiagramWireVisual wire) {
          if (wire.points.isEmpty) return false;
          var left = wire.points.first.dx, right = wire.points.first.dx;
          var top = wire.points.first.dy, bottom = wire.points.first.dy;
          for (final point in wire.points) {
            if (point.dx < left) left = point.dx;
            if (point.dx > right) right = point.dx;
            if (point.dy < top) top = point.dy;
            if (point.dy > bottom) bottom = point.dy;
          }
          return left <= viewport.right + margin &&
              right >= viewport.left - margin &&
              top <= viewport.bottom + margin &&
              bottom >= viewport.top - margin;
        }

        final culledWires = scene.wires.where(wireVisible).toList();
        final culledRecorder = ui.PictureRecorder();
        final culledCanvas = Canvas(culledRecorder);
        final culledPainter = WirePainter(culledWires);
        final culledWatch = Stopwatch()..start();
        culledPainter.paint(culledCanvas, const Size(1920, 1080));
        culledWatch.stop();
        culledRecorder.endRecording().dispose();
        final culledPaintMs = culledWatch.elapsedMicroseconds / 1000;
        // ignore: avoid_print
        print('WirePainter.paint @ $count objects (${culledWires.length} wires, CULLED): ${culledPaintMs.toStringAsFixed(2)}ms');
      });
    }
  });

  group('GraphViewPanel widget build/paint proxy (viewport-culled)', () {
    // Only run the widget-pump proxy at a subset of counts: pumping a
    // real Flutter widget tree (even a culled one) has meaningfully
    // higher fixed overhead than the pure-Dart benchmarks above, and the
    // whole point of viewport culling is that build cost should stay
    // roughly flat once the viewport, not the document, bounds it — so
    // 1,000/10,000/100,000 is exactly the comparison that matters
    // (10/100 would trivially show "everything is on screen, nothing to
    // cull").
    for (final count in [1000, 10000, 100000]) {
      testWidgets('pump @ $count total objects (1920x1080 viewport)', (tester) async {
        final synthetic = SyntheticDiagram.generate(count);
        final view = DiagramView();
        final viewState = const ViewState().copyWith(
          zoom: 1.0,
          viewportWidth: 1920,
          viewportHeight: 1080,
        );
        final scene = view.render(synthetic.graph, layout: synthetic.layout);
        final symbols = SymbolLibrary();
        final transformController = TransformationController();
        final annotations = synthetic.layout.annotations.values.toList();

        void noop() {}
        void noopOffset(Offset _) {}

        final watch = Stopwatch()..start();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1920,
                height: 1080,
                child: GraphViewPanel(
                  scene: scene,
                  viewState: viewState,
                  symbols: symbols,
                  guides: const [],
                  boxSelectRect: null,
                  transformController: transformController,
                  connectionPreviewFrom: null,
                  connectionPreviewTo: null,
                  connectionPreviewValid: true,
                  reconnectingWire: null,
                  annotations: annotations,
                  selectedAnnotationIds: const {},
                  onAnnotationTap: (_) {},
                  onAnnotationDragStart: (_) {},
                  onAnnotationDragUpdate: noopOffset,
                  onAnnotationDragEnd: noop,
                  onAnnotationEditRequested: (_) {},
                  editingWirePoints: null,
                  editingWireSelectedVertex: null,
                  onWireVertexTap: (_) {},
                  onWireCornerDragStart: (_) {},
                  onWireCornerDragUpdate: noopOffset,
                  onWireCornerDragEnd: noop,
                  onWireSegmentDragStart: (_) {},
                  onWireSegmentDragUpdate: noopOffset,
                  onWireSegmentDragEnd: noop,
                  onNodeTap: (_) {},
                  onNodeDragStart: (_) {},
                  onNodeDragUpdate: noopOffset,
                  onNodeDragEnd: noop,
                  onBackgroundTap: (_) {},
                  onBackgroundPanStart: (_) {},
                  onBackgroundPanUpdate: (_, __) {},
                  onBackgroundPanEnd: noop,
                  onHover: (_) {},
                  onPortHoverEnter: (_) {},
                  onPortHoverExit: noop,
                  onPortDragStart: (_) {},
                  onPortDragUpdate: noopOffset,
                  onPortDragEnd: noop,
                  onReconnectDragStart: (_) {},
                  onReconnectDragUpdate: noopOffset,
                  onReconnectDragEnd: noop,
                  onInteractionEnd: noop,
                  onNodeResizeStart: (_, __) {},
                  onNodeResizeUpdate: noopOffset,
                  onNodeResizeEnd: noop,
                ),
              ),
            ),
          ),
        );
        watch.stop();
        final initialBuildMs = watch.elapsedMicroseconds / 1000;

        // A second pump (no state change) measures steady-state repaint
        // cost separately from first-build cost.
        final rebuildWatch = Stopwatch()..start();
        await tester.pump();
        rebuildWatch.stop();
        final rebuildMs = rebuildWatch.elapsedMicroseconds / 1000;

        // ignore: avoid_print
        print(
          'GraphViewPanel pump @ $count objects: initialBuild=${initialBuildMs.toStringAsFixed(1)}ms '
          'rebuild=${rebuildMs.toStringAsFixed(1)}ms visibleNodes=${scene.nodes.where((n) => n.position.dx <= 1920 + 200 && n.position.dy <= 1080 + 200).length}/${scene.nodes.length}',
        );

        expect(find.byType(GraphViewPanel), findsOneWidget);
      });
    }
  });
}
