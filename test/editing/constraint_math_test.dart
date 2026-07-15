import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('ConstraintMath', () {
    test('applyOrthogonalLock locks to the axis with the larger delta', () {
      const start = Point2D(0, 0);
      expect(ConstraintMath.applyOrthogonalLock(start, const Point2D(50, 5)),
          const Point2D(50, 0));
      expect(ConstraintMath.applyOrthogonalLock(start, const Point2D(5, 50)),
          const Point2D(0, 50));
    });

    test('lockToAxis locks to exactly the requested axis regardless of delta magnitude', () {
      const start = Point2D(0, 0);
      expect(
        ConstraintMath.lockToAxis(start, const Point2D(5, 50), ConstraintAxis.x),
        const Point2D(5, 0),
      );
      expect(
        ConstraintMath.lockToAxis(start, const Point2D(5, 50), ConstraintAxis.y),
        const Point2D(0, 50),
      );
    });

    test('snapAngle rounds to the nearest increment', () {
      expect(ConstraintMath.snapAngle(22, 15), 15);
      expect(ConstraintMath.snapAngle(23, 15), 30);
      expect(ConstraintMath.snapAngle(37, 0), 37, reason: 'non-positive increment is a no-op');
    });

    test('hasProtectedConnections is true only for nodes with at least one relationship', () {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C')
            ..connect('a', 'b', id: 'r1'))
          .build();
      expect(ConstraintMath.hasProtectedConnections(graph, 'a'), isTrue);
      expect(ConstraintMath.hasProtectedConnections(graph, 'c'), isFalse);
    });

    test('resolveDragPosition applies axis lock before guides before grid', () {
      // Axis lock to x: candidate.dy forced back to start.dy, regardless
      // of what guides/grid would otherwise do to y.
      final resolved = ConstraintMath.resolveDragPosition(
        start: const Point2D(0, 0),
        candidate: const Point2D(23, 23),
        constraints: const EditingConstraints(axisLock: ConstraintAxis.x),
        width: 100,
        height: 100,
        grid: const GridSettings(spacing: 20),
      );
      expect(resolved.dy, 0, reason: 'axis lock wins over grid snap on y');
      expect(resolved.dx, 20, reason: 'grid still snaps the unlocked axis');
    });

    test('resolveDragPosition falls back to grid snap when no constraints apply', () {
      final resolved = ConstraintMath.resolveDragPosition(
        start: const Point2D(0, 0),
        candidate: const Point2D(23, 37),
        constraints: EditingConstraints.defaults,
        width: 100,
        height: 100,
        grid: const GridSettings(spacing: 20),
      );
      expect(resolved, const Point2D(20, 40));
    });
  });
}
