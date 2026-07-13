import 'package:flutter/material.dart' show Offset, Rect;
import 'package:engineering_engine/engineering_engine.dart' show Point2D, Rect2D;

/// Conversions between Flutter's `dart:ui`-based geometry and the engine's
/// plain-Dart [Point2D]/[Rect2D] — kept out of `lib/core` so the engine
/// itself never needs to know Flutter exists (SDD-025/026).
Point2D offsetToPoint(Offset offset) => Point2D(offset.dx, offset.dy);

Offset pointToOffset(Point2D point) => Offset(point.dx, point.dy);

Rect2D rectFromOffsets(Offset a, Offset b) {
  return Rect2D.fromPoints(offsetToPoint(a), offsetToPoint(b));
}

Rect rect2DToRect(Rect2D rect) {
  return Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);
}

/// Snaps a point to a square grid (WORK_PACKAGE_021 ENGINE-TASK-000081:
/// "Snap Preview").
Point2D snapToGrid(Point2D point, double gridSize) {
  return Point2D(
    (point.dx / gridSize).round() * gridSize,
    (point.dy / gridSize).round() * gridSize,
  );
}
