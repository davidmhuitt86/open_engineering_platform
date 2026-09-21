import 'dart:math' as math;

/// Persistent Extraction Orientation: the clockwise rotation (0/90/180/270)
/// applied to a document page BEFORE extraction so that OCR, entities,
/// evidence regions and thumbnails all live in the same upright ("oriented")
/// coordinate space. Distinct from the Inspector's temporary viewer rotation.
///
/// Coordinates are top-left-origin fractions (0..1) of the page.
enum DocumentOrientation {
  deg0(0),
  deg90(90),
  deg180(180),
  deg270(270);

  const DocumentOrientation(this.degrees);

  final int degrees;

  int get quarterTurns => degrees ~/ 90;

  static DocumentOrientation fromDegrees(int degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    for (final value in values) {
      if (value.degrees == normalized) return value;
    }
    throw ArgumentError.value(degrees, 'degrees', 'must be a multiple of 90');
  }

  /// Page space -> oriented space for a normalized point.
  ({double x, double y}) pageToOriented(double x, double y) => switch (this) {
    DocumentOrientation.deg0 => (x: x, y: y),
    DocumentOrientation.deg90 => (x: 1 - y, y: x),
    DocumentOrientation.deg180 => (x: 1 - x, y: 1 - y),
    DocumentOrientation.deg270 => (x: y, y: 1 - x),
  };

  /// Oriented space -> page space for a normalized point.
  ({double x, double y}) orientedToPage(double x, double y) => switch (this) {
    DocumentOrientation.deg0 => (x: x, y: y),
    DocumentOrientation.deg90 => (x: y, y: 1 - x),
    DocumentOrientation.deg180 => (x: 1 - x, y: 1 - y),
    DocumentOrientation.deg270 => (x: 1 - y, y: x),
  };

  ({double x, double y, double width, double height}) rectPageToOriented(
    double x,
    double y,
    double width,
    double height,
  ) => _mapRect(pageToOriented, x, y, width, height);

  ({double x, double y, double width, double height}) rectOrientedToPage(
    double x,
    double y,
    double width,
    double height,
  ) => _mapRect(orientedToPage, x, y, width, height);

  static ({double x, double y, double width, double height}) _mapRect(
    ({double x, double y}) Function(double, double) map,
    double x,
    double y,
    double width,
    double height,
  ) {
    final a = map(x, y);
    final b = map(x + width, y + height);
    final left = math.min(a.x, b.x);
    final top = math.min(a.y, b.y);
    return (x: left, y: top, width: (a.x - b.x).abs(), height: (a.y - b.y).abs());
  }
}
