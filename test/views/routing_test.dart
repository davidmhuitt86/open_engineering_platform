import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('OrthogonalRoutingProvider', () {
    test('returns a direct two-point path when already horizontal', () {
      final provider = OrthogonalRoutingProvider();
      final context = RoutingContext();
      final path = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(0, 50),
          target: Point2D(100, 50),
        ),
        context,
      );
      expect(path, [const Point2D(0, 50), const Point2D(100, 50)]);
    });

    test('routes with a 90-degree corner when rows differ', () {
      final provider = OrthogonalRoutingProvider();
      final context = RoutingContext();
      final path = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(0, 0),
          target: Point2D(100, 100),
        ),
        context,
      );
      expect(path.length, 4);
      expect(path.first, const Point2D(0, 0));
      expect(path.last, const Point2D(100, 100));
      // Middle two points share an x (the vertical corner column) and
      // each match one endpoint's y — the defining shape of an
      // orthogonal (horizontal-vertical-horizontal) route.
      expect(path[1].dx, path[2].dx);
      expect(path[1].dy, 0);
      expect(path[2].dy, 100);
    });

    test('allocates distinct lanes for repeated requests at the same column', () {
      final provider = OrthogonalRoutingProvider();
      final context = RoutingContext();
      final request = const RoutingRequest(
        relationshipId: 'r1',
        source: Point2D(0, 0),
        target: Point2D(100, 100),
      );
      final first = provider.route(request, context);
      final second = provider.route(request, context);
      expect(first[1].dx, isNot(second[1].dx));
    });

    test('returns a direct two-point path when already vertical (corner cleanup)', () {
      final provider = OrthogonalRoutingProvider();
      final context = RoutingContext();
      final path = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(50, 0),
          target: Point2D(50, 100),
        ),
        context,
      );
      expect(path, [const Point2D(50, 0), const Point2D(50, 100)]);
    });

    test('shared trunkKey reuses the same column across requests', () {
      final provider = OrthogonalRoutingProvider();
      final context = RoutingContext();
      final first = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(0, 0),
          target: Point2D(100, 50),
          trunkKey: 'shared',
        ),
        context,
      );
      final second = provider.route(
        const RoutingRequest(
          relationshipId: 'r2',
          source: Point2D(0, 0),
          target: Point2D(100, 200),
          trunkKey: 'shared',
        ),
        context,
      );
      // Both requests share a source node (trunkKey) so they must share
      // the same trunk column rather than each getting an offset lane.
      expect(first[1].dx, second[1].dx);
    });

    test('distinct trunkKeys do not share a column', () {
      final provider = OrthogonalRoutingProvider();
      final context = RoutingContext();
      final first = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(0, 0),
          target: Point2D(100, 50),
          trunkKey: 'a',
        ),
        context,
      );
      final second = provider.route(
        const RoutingRequest(
          relationshipId: 'r2',
          source: Point2D(0, 0),
          target: Point2D(100, 50),
          trunkKey: 'b',
        ),
        context,
      );
      expect(first[1].dx, isNot(second[1].dx));
    });

    test('routing is deterministic given identical requests and fresh contexts', () {
      final provider = OrthogonalRoutingProvider();
      const request = RoutingRequest(
        relationshipId: 'r1',
        source: Point2D(0, 0),
        target: Point2D(100, 100),
        trunkKey: 'x',
      );
      final a = provider.route(request, RoutingContext());
      final b = provider.route(request, RoutingContext());
      expect(a, b);
    });
  });

  group('DiagramView with routing + layout', () {
    test('uses tracked layout positions over the auto-layout fallback', () {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..connect('a', 'b', id: 'r1'))
          .build();
      final layout = DiagramLayoutState.empty
          .withPosition('a', const Point2D(10, 10))
          .withPosition('b', const Point2D(200, 200));

      final scene = DiagramView().render(graph, layout: layout);
      final nodeA = scene.nodes.firstWhere((n) => n.nodeId == 'a');
      expect(nodeA.position, const Point2D(10, 10));
    });

    test('passes an explicit GraphSelection through to node visuals', () {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A'))
          .build();
      final scene = DiagramView().render(
        graph,
        selection: const GraphSelection(nodeIds: {'a'}),
      );
      expect(scene.nodes.single.selected, isTrue);
    });

    test('repeated render() calls on unchanged input produce identical wire routes', () {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C')
            ..connect('a', 'b', id: 'r1')
            ..connect('a', 'c', id: 'r2'))
          .build();
      final layout = DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(200, 150))
          .withPosition('c', const Point2D(200, 300));

      List<List<Point2D>> wirePoints() {
        final scene = DiagramView().render(
          graph,
          layout: layout,
          routing: OrthogonalRoutingProvider(),
        );
        final sorted = scene.wires.toList()
          ..sort((a, b) => a.relationshipId.compareTo(b.relationshipId));
        return sorted.map((w) => w.points).toList();
      }

      final first = wirePoints();
      final second = wirePoints();
      expect(first, second);
    });

    test('relationships sharing a source node share a routing trunk column', () {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C')
            ..connect('a', 'b', id: 'r1')
            ..connect('a', 'c', id: 'r2'))
          .build();
      final layout = DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(200, 150))
          .withPosition('c', const Point2D(200, 300));

      final scene = DiagramView().render(
        graph,
        layout: layout,
        routing: OrthogonalRoutingProvider(),
      );
      final r1 = scene.wires.firstWhere((w) => w.relationshipId == 'r1');
      final r2 = scene.wires.firstWhere((w) => w.relationshipId == 'r2');
      // Both wires originate from 'a', so DiagramView passes the same
      // trunkKey (the shared source node id) — they must share a column.
      expect(r1.points[1].dx, r2.points[1].dx);
    });
  });

  group('DiagramHitTesting', () {
    test('nodesInRect finds nodes whose bounds intersect the rectangle', () {
      final scene = DiagramScene(
        nodes: [
          const DiagramNodeVisual(nodeId: 'a', symbolId: null, position: Point2D(0, 0)),
          const DiagramNodeVisual(nodeId: 'b', symbolId: null, position: Point2D(500, 500)),
        ],
        wires: const [],
        contentWidth: 600,
        contentHeight: 600,
      );
      final rect = Rect2D(left: -10, top: -10, right: 110, bottom: 110);
      expect(DiagramHitTesting.nodesInRect(scene, rect), {'a'});
    });
  });
}
