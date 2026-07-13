/// A plain 2D point. Deliberately not `dart:ui`'s `Offset` — this module
/// stays usable without a Flutter binding (SDD-025/026: "No Flutter
/// Widgets... No Widget dependencies").
class Point2D {
  final double dx;
  final double dy;

  const Point2D(this.dx, this.dy);

  Point2D translate(double x, double y) => Point2D(dx + x, dy + y);

  @override
  String toString() => 'Point2D($dx, $dy)';
}
