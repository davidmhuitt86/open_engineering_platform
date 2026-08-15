import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

// A path is a sequence of orthogonal (horizontal or vertical) segments --
// true for every path `OrthogonalRoutingProvider` produces.
bool segmentIntersectsRect(Point2D a, Point2D b, Rect2D r) {
  if ((a.dy - b.dy).abs() < 0.001) {
    // Horizontal segment at y = a.dy.
    final y = a.dy;
    final left = a.dx < b.dx ? a.dx : b.dx;
    final right = a.dx > b.dx ? a.dx : b.dx;
    return y > r.top && y < r.bottom && right > r.left && left < r.right;
  }
  // Vertical segment at x = a.dx.
  final x = a.dx;
  final top = a.dy < b.dy ? a.dy : b.dy;
  final bottom = a.dy > b.dy ? a.dy : b.dy;
  return x > r.left && x < r.right && bottom > r.top && top < r.bottom;
}

bool pathIntersectsRect(List<Point2D> path, Rect2D r) {
  for (var i = 0; i < path.length - 1; i++) {
    if (segmentIntersectsRect(path[i], path[i + 1], r)) return true;
  }
  return false;
}

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

  group('OrthogonalRoutingProvider obstacle avoidance (user-requested: never cross a component)', () {
    test('exits each port perpendicular to its own node before jogging sideways', () {
      final provider = OrthogonalRoutingProvider();
      final path = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(50, 0),
          target: Point2D(150, 100),
          sourceExitDirection: 'down',
          targetExitDirection: 'up',
        ),
        RoutingContext(),
      );
      expect(path.first, const Point2D(50, 0));
      expect(path.last, const Point2D(150, 100));
      // First leg travels straight down from the source port (same x,
      // increasing y) -- never diagonally toward the target.
      expect(path[1].dx, 50);
      expect(path[1].dy, greaterThan(0));
      // Last leg approaches the target port straight from above (same
      // x, y below the target's).
      final beforeLast = path[path.length - 2];
      expect(beforeLast.dx, 150);
      expect(beforeLast.dy, lessThan(100));
    });

    test('routes around a component sitting directly between two ports instead of through it', () {
      final provider = OrthogonalRoutingProvider();
      // A top-row port (exits down) connecting to a bottom-row port
      // (exits up) one column over, with a third component's card
      // squarely in the corridor between them -- the exact "wire needs
      // to go to the component next to it" scenario described.
      const obstacle = Rect2D(left: 30, top: 40, right: 70, bottom: 60);
      final context = RoutingContext(obstacles: {'blocker': obstacle});

      final path = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(0, 0),
          target: Point2D(100, 100),
          sourceNodeId: 'a',
          targetNodeId: 'b',
          sourceExitDirection: 'down',
          targetExitDirection: 'up',
        ),
        context,
      );

      expect(pathIntersectsRect(path, obstacle), isFalse,
          reason: 'the routed wire must go around the obstacle, never through it');
    });

    test('a component next to (not between) the two ports is left alone', () {
      final provider = OrthogonalRoutingProvider();
      // This obstacle's x-range doesn't overlap the source/target
      // corridor at all, so it must not affect the route.
      const farAway = Rect2D(left: 500, top: 40, right: 540, bottom: 60);
      final context = RoutingContext(obstacles: {'far': farAway});

      final path = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(0, 0),
          target: Point2D(0, 100),
          sourceNodeId: 'a',
          targetNodeId: 'b',
          sourceExitDirection: 'down',
          targetExitDirection: 'up',
        ),
        context,
      );

      expect(pathIntersectsRect(path, farAway), isFalse);
    });

    test('a wire never treats its own source/target node as an obstacle', () {
      final provider = OrthogonalRoutingProvider();
      // The source node's own bounding box necessarily overlaps its own
      // port anchor -- excluded via sourceNodeId, or every route from a
      // real node would be considered "blocked" by itself.
      const ownNode = Rect2D(left: -10, top: -10, right: 10, bottom: 10);
      final context = RoutingContext(obstacles: {'a': ownNode});

      final path = provider.route(
        const RoutingRequest(
          relationshipId: 'r1',
          source: Point2D(0, 0),
          target: Point2D(100, 100),
          sourceNodeId: 'a',
          targetNodeId: 'b',
          sourceExitDirection: 'down',
          targetExitDirection: 'up',
        ),
        context,
      );
      expect(path.first, const Point2D(0, 0));
      expect(path.last, const Point2D(100, 100));
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

    test('a wire between two real nodes routes around a real component next to it (user-requested)', () {
      // Two-row wiring-harness layout: 'a' on the top row (exit down),
      // 'b' on the bottom row (exit up), and 'blocker' sitting in the
      // corridor between them -- the exact scenario described: "if a
      // wire needs to go to the component next to it... never have a
      // wire cross over a component."
      final graph = (GraphBuilder(id: 'g')
            ..addNode(
              id: 'a',
              category: NodeCategory.component,
              displayName: 'A',
              metadata: const {'exit': 'down'},
              ports: const [Port(id: 'out', name: 'Out')],
            )
            ..addNode(
              id: 'b',
              category: NodeCategory.component,
              displayName: 'B',
              metadata: const {'exit': 'up'},
              ports: const [Port(id: 'in', name: 'In')],
            )
            ..addNode(id: 'blocker', category: NodeCategory.component, displayName: 'Blocker')
            ..connect('a', 'b', id: 'r1'))
          .build();
      final layout = DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(150, 300))
          .withPosition('blocker', const Point2D(80, 140));

      final scene = DiagramView().render(
        graph,
        layout: layout,
        routing: OrthogonalRoutingProvider(),
      );

      final blockerNode = scene.nodes.firstWhere((n) => n.nodeId == 'blocker');
      final blockerRect = Rect2D(
        left: blockerNode.position.dx,
        top: blockerNode.position.dy,
        right: blockerNode.position.dx + blockerNode.width,
        bottom: blockerNode.position.dy + blockerNode.height,
      );

      final wire = scene.wires.firstWhere((w) => w.relationshipId == 'r1');
      expect(pathIntersectsRect(wire.points, blockerRect), isFalse,
          reason: 'the wire between a and b must route around blocker, never through it');
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

    test('relationshipAt finds the wire whose segment passes near the point', () {
      final scene = DiagramScene(
        nodes: const [],
        wires: const [
          DiagramWireVisual(relationshipId: 'r1', points: [Point2D(0, 0), Point2D(100, 0)]),
        ],
        contentWidth: 200,
        contentHeight: 200,
      );
      expect(DiagramHitTesting.relationshipAt(scene, const Point2D(50, 2)), 'r1');
      expect(DiagramHitTesting.relationshipAt(scene, const Point2D(50, 50)), isNull);
    });
  });
}
