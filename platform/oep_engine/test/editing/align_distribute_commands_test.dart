import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  late EditingSession session;

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
          ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
          ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C'))
        .build();
    session = EditingSession.initial(graph).copyWith(
      layout: DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(50, 80))
          .withPosition('c', const Point2D(200, 40)),
    );
  });

  group('AlignNodesCommand', () {
    test('left alignment moves all nodes to the minimum left edge', () {
      final command = AlignNodesCommand({'a', 'b', 'c'}, AlignmentMode.left);
      final after = command.apply(session);
      expect(after.layout.positionOf('a')!.dx, 0);
      expect(after.layout.positionOf('b')!.dx, 0);
      expect(after.layout.positionOf('c')!.dx, 0);
    });

    test('revert restores original positions', () {
      final command = AlignNodesCommand({'a', 'b', 'c'}, AlignmentMode.top);
      final after = command.apply(session);
      final reverted = command.revert(after);
      expect(reverted.layout.positionOf('a'), const Point2D(0, 0));
      expect(reverted.layout.positionOf('b'), const Point2D(50, 80));
      expect(reverted.layout.positionOf('c'), const Point2D(200, 40));
    });

    test('middle alignment aligns y-centers to the bounding-box center', () {
      final command = AlignNodesCommand({'a', 'c'}, AlignmentMode.middle);
      final after = command.apply(session);
      final aCenter = after.layout.positionOf('a')!.dy + 50;
      final cCenter = after.layout.positionOf('c')!.dy + 50;
      expect(aCenter, closeTo(cCenter, 0.01));
    });

    test('is a no-op with fewer than 2 nodes', () {
      final command = AlignNodesCommand({'a'}, AlignmentMode.left);
      final after = command.apply(session);
      expect(after.layout.positionOf('a'), const Point2D(0, 0));
    });
  });

  group('DistributeNodesCommand', () {
    test('spaces nodes evenly along the horizontal axis, keeping ends fixed', () {
      final command = DistributeNodesCommand({'a', 'b', 'c'}, DistributionAxis.horizontal);
      final after = command.apply(session);
      // sorted by x: a(0), b(50), c(200) -> a and c stay, b becomes the midpoint
      expect(after.layout.positionOf('a')!.dx, 0);
      expect(after.layout.positionOf('c')!.dx, 200);
      expect(after.layout.positionOf('b')!.dx, closeTo(100, 0.01));
    });

    test('revert restores original positions', () {
      final command = DistributeNodesCommand({'a', 'b', 'c'}, DistributionAxis.horizontal);
      final after = command.apply(session);
      final reverted = command.revert(after);
      expect(reverted.layout.positionOf('b'), const Point2D(50, 80));
    });

    test('is a no-op with fewer than 3 nodes', () {
      final command = DistributeNodesCommand({'a', 'b'}, DistributionAxis.horizontal);
      final after = command.apply(session);
      expect(after.layout.positionOf('b'), const Point2D(50, 80));
    });
  });

  group('Never-moved nodes (WORK_PACKAGE_023 regression)', () {
    // A freshly-created graph has no tracked layout positions at all —
    // DiagramView falls back to DiagramLayout.compute for rendering.
    // Align/Distribute must resolve that same fallback rather than
    // silently skipping nodes with no explicit position.
    late EditingSession freshSession;

    setUp(() {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C'))
          .build();
      freshSession = EditingSession.initial(graph); // layout is DiagramLayoutState.empty
    });

    test('AlignNodesCommand aligns nodes that have never been moved', () {
      final command = AlignNodesCommand({'a', 'b', 'c'}, AlignmentMode.top);
      final after = command.apply(freshSession);
      final y = after.layout.positionOf('a')!.dy;
      expect(after.layout.positionOf('b')!.dy, y);
      expect(after.layout.positionOf('c')!.dy, y);
    });

    test('DistributeNodesCommand distributes nodes that have never been moved', () {
      final command = DistributeNodesCommand({'a', 'b', 'c'}, DistributionAxis.horizontal);
      final after = command.apply(freshSession);
      // DiagramLayout.compute places a/b/c at columns 0/1/2 (160px apart);
      // distributing horizontally should leave them evenly spaced.
      final xa = after.layout.positionOf('a')!.dx;
      final xb = after.layout.positionOf('b')!.dx;
      final xc = after.layout.positionOf('c')!.dx;
      expect(xb - xa, closeTo(xc - xb, 0.01));
    });
  });
}
