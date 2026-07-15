import 'dart:math';

import 'diagram_geometry.dart';
import 'diagram_scene.dart';
import 'rect2d.dart';

/// Box-selection hit-testing (WORK_PACKAGE_021, ENGINE-TASK-000080;
/// extended WORK_PACKAGE_023, ENGINE-TASK-000098).
///
/// Lives in the View layer, not `SelectionService` — selection never
/// needs to know about screen coordinates; only the thing that already
/// has them ([DiagramScene]) does.
class DiagramHitTesting {
  DiagramHitTesting._();

  /// Node ids whose bounds intersect [rect] — "Crossing Selection"
  /// (ENGINE-TASK-000098): a node touched *anywhere* by the rectangle is
  /// included, even if only partially inside it. "Selection Priority"
  /// (ENGINE-TASK-000080) is resolved by the caller choosing which of
  /// nodes/relationships/groups to act on when several are returned —
  /// this helper only reports geometric membership.
  static Set<String> nodesInRect(DiagramScene scene, Rect2D rect) {
    final result = <String>{};
    for (final node in scene.nodes) {
      if (rect.intersects(_boundsOf(node))) {
        result.add(node.nodeId);
      }
    }
    return result;
  }

  /// Node ids whose bounds are *fully contained* within [rect] —
  /// "Window Selection" (ENGINE-TASK-000098), the stricter counterpart
  /// to [nodesInRect]'s "Crossing Selection": a node only partially
  /// inside the rectangle is excluded.
  static Set<String> nodesFullyInRect(DiagramScene scene, Rect2D rect) {
    final result = <String>{};
    for (final node in scene.nodes) {
      final bounds = _boundsOf(node);
      if (bounds.left >= rect.left &&
          bounds.right <= rect.right &&
          bounds.top >= rect.top &&
          bounds.bottom <= rect.bottom) {
        result.add(node.nodeId);
      }
    }
    return result;
  }

  /// Node ids whose center falls inside [polygon] — "Lasso Selection"
  /// (ENGINE-TASK-000098), via the standard ray-casting point-in-polygon
  /// test. [polygon] need not be closed explicitly; the last vertex is
  /// implicitly connected back to the first.
  static Set<String> nodesInPolygon(DiagramScene scene, List<Point2D> polygon) {
    if (polygon.length < 3) return {};
    final result = <String>{};
    for (final node in scene.nodes) {
      final center = Point2D(
        node.position.dx + node.width / 2,
        node.position.dy + node.height / 2,
      );
      if (_pointInPolygon(center, polygon)) {
        result.add(node.nodeId);
      }
    }
    return result;
  }

  /// The id of the relationship whose wire passes within [threshold] scene
  /// units of [point], or `null` if none does — lets a host select a wire
  /// by clicking near it (needed to reach "Edit Route" mode,
  /// WORK_PACKAGE_023 ENGINE-TASK-000099, since a relationship can only
  /// be selected once it's click-reachable on the canvas). Checks
  /// point-to-segment distance across every segment of every wire;
  /// returns the first match, closest-wire-wins is left to the caller if
  /// that refinement is ever needed.
  static String? relationshipAt(DiagramScene scene, Point2D point, {double threshold = 6}) {
    for (final wire in scene.wires) {
      for (var i = 0; i < wire.points.length - 1; i++) {
        if (_distanceToSegment(point, wire.points[i], wire.points[i + 1]) <= threshold) {
          return wire.relationshipId;
        }
      }
    }
    return null;
  }

  static double _distanceToSegment(Point2D p, Point2D a, Point2D b) {
    final abx = b.dx - a.dx;
    final aby = b.dy - a.dy;
    final lengthSquared = abx * abx + aby * aby;
    double t = lengthSquared == 0
        ? 0
        : ((p.dx - a.dx) * abx + (p.dy - a.dy) * aby) / lengthSquared;
    t = t.clamp(0, 1);
    final closestX = a.dx + t * abx;
    final closestY = a.dy + t * aby;
    final dx = p.dx - closestX;
    final dy = p.dy - closestY;
    return sqrt(dx * dx + dy * dy);
  }

  static Rect2D _boundsOf(DiagramNodeVisual node) => Rect2D(
        left: node.position.dx,
        top: node.position.dy,
        right: node.position.dx + node.width,
        bottom: node.position.dy + node.height,
      );

  static bool _pointInPolygon(Point2D point, List<Point2D> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final vi = polygon[i];
      final vj = polygon[j];
      final intersects = ((vi.dy > point.dy) != (vj.dy > point.dy)) &&
          (point.dx <
              (vj.dx - vi.dx) * (point.dy - vi.dy) / (vj.dy - vi.dy) + vi.dx);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}
