import 'alignment_guide.dart';
import 'diagram_geometry.dart';
import 'grid_line.dart';
import 'rect2d.dart';

/// Computes ephemeral "smart guide" hints while dragging (WORK_PACKAGE_022,
/// ENGINE-TASK-000091). Pure and runtime-only — guides are visual only,
/// never a command, never persisted (unlike the real Align/Distribute
/// mutations, which go through `AlignNodesCommand`/`DistributeNodesCommand`).
///
/// Compares the dragged rectangle's left/center/right and top/center/
/// bottom against every sibling's, within [threshold] scene units.
class AlignmentGuideComputer {
  AlignmentGuideComputer._();

  static const double defaultThreshold = 4;

  static List<double> _xEdges(Rect2D r) => [r.left, (r.left + r.right) / 2, r.right];
  static List<double> _yEdges(Rect2D r) => [r.top, (r.top + r.bottom) / 2, r.bottom];

  static List<AlignmentGuide> computeGuides({
    required Rect2D draggedBounds,
    required List<Rect2D> siblingBounds,
    double threshold = defaultThreshold,
  }) {
    final guides = <AlignmentGuide>[];
    final draggedX = _xEdges(draggedBounds);
    final draggedY = _yEdges(draggedBounds);

    for (final sibling in siblingBounds) {
      for (final sx in _xEdges(sibling)) {
        for (final dx in draggedX) {
          if ((dx - sx).abs() <= threshold) {
            guides.add(AlignmentGuide(axis: GridAxis.vertical, position: sx));
          }
        }
      }
      for (final sy in _yEdges(sibling)) {
        for (final dy in draggedY) {
          if ((dy - sy).abs() <= threshold) {
            guides.add(AlignmentGuide(axis: GridAxis.horizontal, position: sy));
          }
        }
      }
    }
    return guides;
  }

  /// Nudges [candidatePosition] (the dragged rectangle's top-left) so an
  /// edge/center that's within [threshold] of a sibling snaps exactly to
  /// it — independently per axis, first match wins.
  static Point2D snapToGuides({
    required Point2D candidatePosition,
    required double width,
    required double height,
    required List<Rect2D> siblingBounds,
    double threshold = defaultThreshold,
  }) {
    final bounds = Rect2D(
      left: candidatePosition.dx,
      top: candidatePosition.dy,
      right: candidatePosition.dx + width,
      bottom: candidatePosition.dy + height,
    );
    var x = candidatePosition.dx;
    var y = candidatePosition.dy;

    outerX:
    for (final sibling in siblingBounds) {
      for (final sx in _xEdges(sibling)) {
        for (final dx in _xEdges(bounds)) {
          if ((dx - sx).abs() <= threshold) {
            x = candidatePosition.dx + (sx - dx);
            break outerX;
          }
        }
      }
    }
    outerY:
    for (final sibling in siblingBounds) {
      for (final sy in _yEdges(sibling)) {
        for (final dy in _yEdges(bounds)) {
          if ((dy - sy).abs() <= threshold) {
            y = candidatePosition.dy + (sy - dy);
            break outerY;
          }
        }
      }
    }
    return Point2D(x, y);
  }
}
