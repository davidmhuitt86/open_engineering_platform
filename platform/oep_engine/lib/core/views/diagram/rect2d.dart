import 'diagram_geometry.dart';

/// A plain axis-aligned rectangle, in the same spirit as [Point2D] — not
/// `dart:ui`'s `Rect`, so this module stays usable without a Flutter
/// binding.
class Rect2D {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const Rect2D({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory Rect2D.fromPoints(Point2D a, Point2D b) {
    return Rect2D(
      left: a.dx < b.dx ? a.dx : b.dx,
      top: a.dy < b.dy ? a.dy : b.dy,
      right: a.dx > b.dx ? a.dx : b.dx,
      bottom: a.dy > b.dy ? a.dy : b.dy,
    );
  }

  bool intersects(Rect2D other) {
    return left <= other.right &&
        right >= other.left &&
        top <= other.bottom &&
        bottom >= other.top;
  }
}
