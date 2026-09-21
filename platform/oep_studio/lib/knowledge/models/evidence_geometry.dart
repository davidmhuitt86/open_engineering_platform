import 'dart:math' as math;

import 'knowledge_validation_exception.dart';

/// One vertex of a [PolylineGeometry], as a fraction (0..1, top-left origin)
/// of the page: the SAME normalized page convention [RectangleGeometry] and
/// every OCR/entity overlay already use (in the source's Extraction
/// Orientation frame, see `DocumentOrientation`).
class GeometryPoint {
  const GeometryPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is GeometryPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// The axis-aligned extent of a geometry, in the same normalized page space.
class GeometryBounds {
  const GeometryBounds(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;
}

/// WHERE an [EvidenceRegion] is. Independent of WHAT it is (that is the
/// region's `EvidenceAnnotation`): a geometry never encodes a semantic type.
sealed class EvidenceGeometry {
  const EvidenceGeometry();

  GeometryBounds get bounds;

  Map<String, dynamic> toJson();

  static EvidenceGeometry fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'rectangle':
        return RectangleGeometry(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
          (json['width'] as num).toDouble(),
          (json['height'] as num).toDouble(),
        );
      case 'polyline':
        return PolylineGeometry(
          [
            for (final p in json['points'] as List<dynamic>)
              GeometryPoint(((p as List<dynamic>)[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
          strokeWidth: (json['strokeWidth'] as num).toDouble(),
        );
      default:
        throw KnowledgeValidationException('Unknown evidence geometry type "$type".');
    }
  }
}

/// Area evidence.
class RectangleGeometry extends EvidenceGeometry {
  const RectangleGeometry(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  GeometryBounds get bounds => GeometryBounds(x, y, width, height);

  @override
  Map<String, dynamic> toJson() => {'type': 'rectangle', 'x': x, 'y': y, 'width': width, 'height': height};
}

/// Linear/path evidence: an ordered sequence of normalized page points plus a
/// visual stroke width.
///
/// [strokeWidth] is in PDF points (1/72 in) of the page: a document-space unit
/// that is independent of zoom and of the Flutter logical-pixel size. It is a
/// VISUALIZATION width for the evidence path, never a claim about a physical
/// wire's diameter or gauge.
class PolylineGeometry extends EvidenceGeometry {
  /// Default visual width, in PDF points. Conservative for engineering
  /// drawings, where a wire is typically a hairline.
  static const double defaultStrokeWidth = 2.0;
  static const double maxStrokeWidth = 100.0;

  factory PolylineGeometry(List<GeometryPoint> points, {double strokeWidth = defaultStrokeWidth}) {
    if (points.length < 2) {
      throw const KnowledgeValidationException('A path needs at least two points.');
    }
    for (final p in points) {
      if (!p.x.isFinite || !p.y.isFinite || p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1) {
        throw KnowledgeValidationException('Path point $p is outside the page (coordinates must be finite, 0..1).');
      }
    }
    if (!strokeWidth.isFinite || strokeWidth <= 0 || strokeWidth > maxStrokeWidth) {
      throw KnowledgeValidationException('Path width must be greater than 0 and at most $maxStrokeWidth pt.');
    }
    return PolylineGeometry._(List.unmodifiable(points), strokeWidth);
  }

  const PolylineGeometry._(this.points, this.strokeWidth);

  final List<GeometryPoint> points;
  final double strokeWidth;

  PolylineGeometry withStrokeWidth(double width) => PolylineGeometry(points, strokeWidth: width);

  @override
  GeometryBounds get bounds {
    var minX = points.first.x, maxX = minX, minY = points.first.y, maxY = minY;
    for (final p in points) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return GeometryBounds(minX, minY, maxX - minX, maxY - minY);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'polyline',
    'points': [
      for (final p in points) [p.x, p.y],
    ],
    'strokeWidth': strokeWidth,
  };
}

/// The in-progress path an engineer is tracing: vertices accumulate on one
/// page until finished (needs at least two) or cancelled (nothing is created).
class PathDraft {
  final List<GeometryPoint> _points = [];
  int? _page;

  int? get page => _page;
  List<GeometryPoint> get points => List.unmodifiable(_points);
  int get length => _points.length;
  bool get isEmpty => _points.isEmpty;
  bool get canFinish => _points.length >= 2;

  /// Adds a vertex; a point on a different page than the first is ignored.
  /// Returns whether it was added.
  bool add(int page, GeometryPoint point) {
    if (_page != null && _page != page) return false;
    _page = page;
    _points.add(point);
    return true;
  }

  void cancel() {
    _points.clear();
    _page = null;
  }

  /// Removes the most recently placed vertex. Returns whether one was removed;
  /// undoing the only remaining point empties the draft.
  bool undoLast() {
    if (_points.isEmpty) return false;
    _points.removeLast();
    if (_points.isEmpty) _page = null;
    return true;
  }

  /// The finished polyline (default width); throws for fewer than two points.
  /// The draft is cleared on success.
  PolylineGeometry finish({double strokeWidth = PolylineGeometry.defaultStrokeWidth}) {
    final geometry = PolylineGeometry(List.of(_points), strokeWidth: strokeWidth);
    cancel();
    return geometry;
  }
}

/// Converts a document-space stroke width (PDF points) to canvas pixels for a
/// page drawn [canvasWidthPx] wide whose real width is [pageWidthPt] points.
/// Zoom changes only [canvasWidthPx], so the width stays the same document size.
double strokeWidthToCanvasPx(double strokeWidthPt, double canvasWidthPx, double pageWidthPt) =>
    strokeWidthPt * canvasWidthPx / pageWidthPt;
