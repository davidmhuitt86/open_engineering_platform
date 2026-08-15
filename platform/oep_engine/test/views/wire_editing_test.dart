import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('WireEditing', () {
    test('insertVertex inserts a point right after the given index', () {
      const points = [Point2D(0, 0), Point2D(100, 0)];
      final result = WireEditing.insertVertex(points, 0, const Point2D(50, 0));
      expect(result, [const Point2D(0, 0), const Point2D(50, 0), const Point2D(100, 0)]);
    });

    test('insertVertex is a no-op for an out-of-range index', () {
      const points = [Point2D(0, 0), Point2D(100, 0)];
      expect(WireEditing.insertVertex(points, 5, const Point2D(50, 0)), points);
      expect(WireEditing.insertVertex(points, -1, const Point2D(50, 0)), points);
    });

    test('removeVertex removes an interior point but never an anchor', () {
      const points = [Point2D(0, 0), Point2D(50, 0), Point2D(50, 100), Point2D(100, 100)];
      final removed = WireEditing.removeVertex(points, 1);
      expect(removed, [const Point2D(0, 0), const Point2D(50, 100), const Point2D(100, 100)]);

      // Anchors (index 0 and last) are never removed.
      expect(WireEditing.removeVertex(points, 0), points);
      expect(WireEditing.removeVertex(points, 3), points);
    });

    test('removeVertex never drops below 2 points', () {
      const points = [Point2D(0, 0), Point2D(100, 0)];
      expect(WireEditing.removeVertex(points, 0), points);
    });

    test('dragSegment on an interior segment only shifts the perpendicular axis', () {
      // a: (0,0) -> b: (50,0) -> c: (50,100) [vertical, interior] -> d: (100,100)
      const points = [
        Point2D(0, 0),
        Point2D(50, 0),
        Point2D(50, 100),
        Point2D(100, 100),
      ];
      // Segment 1 (index 1, between b and c) is vertical and touches
      // neither anchor. Its perpendicular axis is x, so only delta.dx
      // has any effect.
      final dragged = WireEditing.dragSegment(points, 1, const Point2D(20, 0));
      expect(dragged, [
        const Point2D(0, 0),
        const Point2D(70, 0),
        const Point2D(70, 100),
        const Point2D(100, 100),
      ]);
    });

    test('dragSegment touching the start anchor inserts a connector vertex, anchor unmoved', () {
      const points = [Point2D(0, 0), Point2D(100, 0), Point2D(100, 100)];
      final dragged = WireEditing.dragSegment(points, 0, const Point2D(0, 30));
      // horizontal segment 0 dragged down by 30: anchor (0,0) stays, a new
      // connector vertex (0,30) is inserted, and the far endpoint (100,0)
      // moves to (100,30).
      expect(dragged, [
        const Point2D(0, 0),
        const Point2D(0, 30),
        const Point2D(100, 30),
        const Point2D(100, 100),
      ]);
    });

    test('dragSegment on a 2-point wire brackets both fixed anchors with new vertices', () {
      const points = [Point2D(0, 0), Point2D(100, 0)];
      final dragged = WireEditing.dragSegment(points, 0, const Point2D(0, 40));
      expect(dragged, [
        const Point2D(0, 0),
        const Point2D(0, 40),
        const Point2D(100, 40),
        const Point2D(100, 0),
      ]);
    });

    test('dragSegment rejects a drag that collapses a segment below the minimum length', () {
      const points = [Point2D(0, 0), Point2D(100, 0), Point2D(100, 100)];
      // Dragging segment 0 by a tiny amount would make the new connector
      // segment (length 1) shorter than the minimum.
      final dragged =
          WireEditing.dragSegment(points, 0, const Point2D(0, 1), minimumWireLength: 8);
      expect(dragged, points);
    });

    test('dragCorner on an interior vertex propagates exactly one hop to each neighbor', () {
      // a(0,0) -> b(50,0) -> c(50,50) -> d(100,50) -> e(100,100)
      const points = [
        Point2D(0, 0),
        Point2D(50, 0),
        Point2D(50, 50),
        Point2D(100, 50),
        Point2D(100, 100),
      ];
      // Drag corner c (index 2) to (70, 70).
      final dragged = WireEditing.dragCorner(points, 2, const Point2D(70, 70));
      // b-c was vertical (shared dx=50) -> b's dx follows to 70.
      // c-d was horizontal (shared dy=50) -> d's dy follows to 70.
      expect(dragged[1], const Point2D(70, 0));
      expect(dragged[2], const Point2D(70, 70));
      expect(dragged[3], const Point2D(100, 70));
      expect(dragged.first, points.first, reason: 'anchor untouched');
      expect(dragged.last, points.last, reason: 'anchor untouched');
    });

    test('dragCorner next to a start anchor clamps the shared coordinate to the anchor', () {
      // a(0,0) [anchor] -> b(0,50) -> c(50,50) -> d(50,100) [anchor]
      const points = [Point2D(0, 0), Point2D(0, 50), Point2D(50, 50), Point2D(50, 100)];
      // b (index 1) neighbors the start anchor via a vertical segment
      // (shared dx=0) — dragging b can only slide it along dy; dx must
      // stay 0 to keep that segment attached to the anchor.
      final dragged = WireEditing.dragCorner(points, 1, const Point2D(30, 80));
      expect(dragged[0], points[0], reason: 'anchor never moves');
      expect(dragged[1].dx, 0, reason: 'clamped to the anchor axis');
      expect(dragged[1].dy, 80);
    });

    test('dragCorner refuses to move an anchor itself', () {
      const points = [Point2D(0, 0), Point2D(50, 0), Point2D(50, 50)];
      expect(WireEditing.dragCorner(points, 0, const Point2D(99, 99)), points);
      expect(WireEditing.dragCorner(points, 2, const Point2D(99, 99)), points);
    });

    test('cleanupCorners removes a redundant collinear vertex', () {
      // b sits exactly between a and c on the same horizontal line.
      const points = [Point2D(0, 0), Point2D(50, 0), Point2D(100, 0)];
      final cleaned = WireEditing.cleanupCorners(points);
      expect(cleaned, [const Point2D(0, 0), const Point2D(100, 0)]);
    });

    test('cleanupCorners keeps a genuine corner', () {
      const points = [Point2D(0, 0), Point2D(50, 0), Point2D(50, 100)];
      expect(WireEditing.cleanupCorners(points), points);
    });

    test('dragCorner and dragSegment are pure and deterministic', () {
      const points = [Point2D(0, 0), Point2D(50, 0), Point2D(50, 50), Point2D(100, 50)];
      final first = WireEditing.dragCorner(points, 2, const Point2D(80, 80));
      final second = WireEditing.dragCorner(points, 2, const Point2D(80, 80));
      expect(first, second);
      // The original input list is never mutated in place.
      expect(points, [
        const Point2D(0, 0),
        const Point2D(50, 0),
        const Point2D(50, 50),
        const Point2D(100, 50),
      ]);
    });
  });
}
