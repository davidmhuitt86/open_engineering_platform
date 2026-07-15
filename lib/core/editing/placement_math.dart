import 'dart:math';

import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/diagram_layout.dart';

/// The axis a [MirrorNodesCommand] reflects positions across
/// (WORK_PACKAGE_023, ENGINE-TASK-000102).
enum MirrorAxis { horizontal, vertical }

/// Pure position math backing the placement commands
/// (`RotateNodesCommand`, `MirrorNodesCommand`, `ArrayPlaceCommand`).
///
/// Factored out as static functions — rather than inlined inside each
/// command's `apply()` — specifically so the Demonstration Host can call
/// the same computation to render a live preview *before* committing the
/// command (WORK_PACKAGE_023, ENGINE-TASK-000105: "Multi-step Command
/// Preview"), without duplicating the math or executing an edit early.
class PlacementMath {
  PlacementMath._();

  static double _centerX(Map<String, Point2D> positions, double nodeSize) {
    final minLeft = positions.values.map((p) => p.dx).reduce(min);
    final maxRight = positions.values.map((p) => p.dx + nodeSize).reduce(max);
    return (minLeft + maxRight) / 2;
  }

  static double _centerY(Map<String, Point2D> positions, double nodeSize) {
    final minTop = positions.values.map((p) => p.dy).reduce(min);
    final maxBottom = positions.values.map((p) => p.dy + nodeSize).reduce(max);
    return (minTop + maxBottom) / 2;
  }

  /// Rotates every position in [positions] by [angleDeltaDegrees] around
  /// the selection's overall bounding-box center (90°/180°/arbitrary are
  /// all just different deltas). A single-node selection's bounding-box
  /// center is the node itself, so its position is unaffected — only its
  /// own orientation changes, which `RotateNodesCommand` tracks
  /// separately via `NodeTransform.rotation`.
  static Map<String, Point2D> rotatedPositions(
    Map<String, Point2D> positions,
    double angleDeltaDegrees, {
    double nodeSize = DiagramLayout.nodeSize,
  }) {
    if (positions.length < 2) return positions;
    final centerX = _centerX(positions, nodeSize);
    final centerY = _centerY(positions, nodeSize);
    final radians = angleDeltaDegrees * pi / 180;
    final cosA = cos(radians);
    final sinA = sin(radians);
    return positions.map((id, p) {
      final originX = p.dx + nodeSize / 2 - centerX;
      final originY = p.dy + nodeSize / 2 - centerY;
      final rotatedX = originX * cosA - originY * sinA;
      final rotatedY = originX * sinA + originY * cosA;
      return MapEntry(
        id,
        Point2D(centerX + rotatedX - nodeSize / 2, centerY + rotatedY - nodeSize / 2),
      );
    });
  }

  /// Reflects every position in [positions] across the selection's
  /// bounding-box center line on [axis].
  static Map<String, Point2D> mirroredPositions(
    Map<String, Point2D> positions,
    MirrorAxis axis, {
    double nodeSize = DiagramLayout.nodeSize,
  }) {
    if (positions.isEmpty) return positions;
    final centerX = _centerX(positions, nodeSize);
    final centerY = _centerY(positions, nodeSize);
    return positions.map((id, p) {
      if (axis == MirrorAxis.horizontal) {
        return MapEntry(id, Point2D(2 * centerX - (p.dx + nodeSize), p.dy));
      }
      return MapEntry(id, Point2D(p.dx, 2 * centerY - (p.dy + nodeSize)));
    });
  }

  /// Grid-cell offsets for Array Placement, excluding the `(0, 0)` cell
  /// (the original, already-placed copy) — one offset per additional
  /// copy `ArrayPlaceCommand` creates.
  static List<Point2D> arrayOffsets({
    required int countX,
    required int countY,
    required double spacingX,
    required double spacingY,
  }) {
    final offsets = <Point2D>[];
    for (var row = 0; row < countY; row++) {
      for (var col = 0; col < countX; col++) {
        if (row == 0 && col == 0) continue;
        offsets.add(Point2D(col * spacingX, row * spacingY));
      }
    }
    return offsets;
  }
}
