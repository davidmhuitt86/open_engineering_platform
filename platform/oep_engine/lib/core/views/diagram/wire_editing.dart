import 'diagram_geometry.dart';

/// Pure geometry for manual wire editing (WORK_PACKAGE_023,
/// ENGINE-TASK-000099: "Insert Vertex", "Remove Vertex", "Drag Segment",
/// "Drag Corner", "Preserve Orthogonality", "Automatic Corner Cleanup").
///
/// Every function here takes and returns a plain `List<Point2D>` — the
/// same shape `RoutingProvider.route()` produces and `SetWireRouteCommand`
/// stores as a manual override (see docs/WIRE_EDITING.md). No engine
/// state, no Flutter — the Demonstration Host calls these to compute a
/// new point list, then commits it with one `SetWireRouteCommand`.
///
/// **Fixed anchors**: `points.first`/`points.last` are the wire's port
/// anchors and are never moved by [dragSegment] or [dragCorner] — dragging
/// a segment or corner that touches an anchor inserts a new intermediate
/// vertex instead, so the anchor itself stays exactly where the port is.
class WireEditing {
  WireEditing._();

  static bool _isHorizontal(Point2D a, Point2D b) => (a.dy - b.dy).abs() < 0.5;
  static bool _isVertical(Point2D a, Point2D b) => (a.dx - b.dx).abs() < 0.5;

  static bool _violatesMinimumLength(List<Point2D> points, double minimumWireLength) {
    final minSquared = minimumWireLength * minimumWireLength;
    for (var i = 0; i < points.length - 1; i++) {
      final dx = points[i].dx - points[i + 1].dx;
      final dy = points[i].dy - points[i + 1].dy;
      if (dx * dx + dy * dy < minSquared) return true;
    }
    return false;
  }

  /// Inserts [point] right after [afterIndex]. The caller is responsible
  /// for choosing a [point] that preserves orthogonality (e.g. snapping it
  /// to share an axis with one of its new neighbors) — this primitive
  /// performs the structural insert only, the same scoping [dragSegment]/
  /// [dragCorner] apply to their own orthogonality guarantees.
  static List<Point2D> insertVertex(List<Point2D> points, int afterIndex, Point2D point) {
    if (afterIndex < 0 || afterIndex >= points.length - 1) return points;
    final result = List<Point2D>.from(points)..insert(afterIndex + 1, point);
    return result;
  }

  /// Removes the vertex at [index]. Anchors ([index] `0` or the last
  /// index) are never removed, and a wire always keeps at least 2 points.
  static List<Point2D> removeVertex(List<Point2D> points, int index) {
    if (points.length <= 2 || index <= 0 || index >= points.length - 1) {
      return points;
    }
    return List<Point2D>.from(points)..removeAt(index);
  }

  /// Drags the segment between `points[segmentIndex]` and
  /// `points[segmentIndex + 1]` by [delta], preserving orthogonality: only
  /// the component of [delta] perpendicular to the segment's own
  /// orientation is applied (a horizontal segment only moves in y, a
  /// vertical segment only in x). If the segment touches a fixed anchor,
  /// that anchor is left untouched and a new connector vertex is inserted
  /// in its place instead — this one rule (see class doc) also correctly
  /// handles a 2-point wire (both ends anchors): both ends stay fixed and
  /// two new vertices bracket the newly offset middle segment.
  static List<Point2D> dragSegment(
    List<Point2D> points,
    int segmentIndex,
    Point2D delta, {
    double minimumWireLength = 8,
  }) {
    if (points.length < 2 || segmentIndex < 0 || segmentIndex >= points.length - 1) {
      return points;
    }
    final left = points[segmentIndex];
    final right = points[segmentIndex + 1];
    final horizontal = _isHorizontal(left, right);
    final vertical = _isVertical(left, right);
    if (!horizontal && !vertical) return points;

    Point2D shiftPerp(Point2D p) =>
        horizontal ? Point2D(p.dx, p.dy + delta.dy) : Point2D(p.dx + delta.dx, p.dy);

    final result = <Point2D>[];
    for (var i = 0; i < points.length; i++) {
      if (i == segmentIndex) {
        if (i == 0) {
          result.add(points[i]);
          result.add(shiftPerp(points[i]));
        } else {
          result.add(shiftPerp(points[i]));
        }
      } else if (i == segmentIndex + 1) {
        if (i == points.length - 1) {
          result.add(shiftPerp(points[i]));
          result.add(points[i]);
        } else {
          result.add(shiftPerp(points[i]));
        }
      } else {
        result.add(points[i]);
      }
    }
    return _violatesMinimumLength(result, minimumWireLength) ? points : result;
  }

  /// Drags the interior vertex at [cornerIndex] to [newPosition], keeping
  /// both adjacent segments orthogonal. A neighbor that is itself a fixed
  /// anchor clamps the shared coordinate (the corner can only slide along
  /// that anchor's segment axis); a neighbor that is another interior
  /// vertex is nudged to follow (propagated exactly one hop, which is
  /// always sufficient — see docs/WIRE_EDITING.md). Anchors themselves
  /// ([cornerIndex] `0` or the last index) are never draggable this way.
  static List<Point2D> dragCorner(
    List<Point2D> points,
    int cornerIndex,
    Point2D newPosition, {
    double minimumWireLength = 8,
  }) {
    if (points.length < 3 || cornerIndex <= 0 || cornerIndex >= points.length - 1) {
      return points;
    }
    final result = List<Point2D>.from(points);
    final prev = result[cornerIndex - 1];
    final next = result[cornerIndex + 1];
    final prevHorizontal = _isHorizontal(prev, result[cornerIndex]);
    final nextHorizontal = _isHorizontal(result[cornerIndex], next);

    var candidate = newPosition;
    if (cornerIndex - 1 == 0) {
      candidate = prevHorizontal ? Point2D(candidate.dx, prev.dy) : Point2D(prev.dx, candidate.dy);
    }
    if (cornerIndex + 1 == result.length - 1) {
      candidate = nextHorizontal ? Point2D(candidate.dx, next.dy) : Point2D(next.dx, candidate.dy);
    }
    result[cornerIndex] = candidate;

    if (cornerIndex - 1 != 0) {
      result[cornerIndex - 1] =
          prevHorizontal ? Point2D(prev.dx, candidate.dy) : Point2D(candidate.dx, prev.dy);
    }
    if (cornerIndex + 1 != result.length - 1) {
      result[cornerIndex + 1] =
          nextHorizontal ? Point2D(next.dx, candidate.dy) : Point2D(candidate.dx, next.dy);
    }

    return _violatesMinimumLength(result, minimumWireLength) ? points : result;
  }

  /// Automatic Corner Cleanup: removes interior vertices that don't
  /// actually change direction (three consecutive collinear points),
  /// which [dragSegment]/[dragCorner] can produce after repeated edits.
  static List<Point2D> cleanupCorners(List<Point2D> points) {
    if (points.length <= 2) return points;
    final result = <Point2D>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final prev = result.last;
      final curr = points[i];
      final next = points[i + 1];
      final collinearHorizontal =
          (prev.dy - curr.dy).abs() < 0.5 && (curr.dy - next.dy).abs() < 0.5;
      final collinearVertical =
          (prev.dx - curr.dx).abs() < 0.5 && (curr.dx - next.dx).abs() < 0.5;
      if (collinearHorizontal || collinearVertical) continue;
      result.add(curr);
    }
    result.add(points.last);
    return result;
  }
}
