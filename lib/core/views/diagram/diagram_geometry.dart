/// A plain 2D point. Deliberately not `dart:ui`'s `Offset` — this module
/// stays usable without a Flutter binding (SDD-025/026: "No Flutter
/// Widgets... No Widget dependencies").
class Point2D {
  final double dx;
  final double dy;

  const Point2D(this.dx, this.dy);

  Point2D translate(double x, double y) => Point2D(dx + x, dy + y);

  @override
  bool operator ==(Object other) => other is Point2D && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Point2D($dx, $dy)';
}

/// A plain 2D size (width/height), used for per-node resize (AP-DS-001A).
/// Same rationale as [Point2D]: no `dart:ui` dependency here.
class Size2D {
  final double width;
  final double height;

  const Size2D(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      other is Size2D && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'Size2D($width, $height)';
}
