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

// Grid snapping moved to the engine's `GridComputer.snap` (WORK_PACKAGE_022,
// ENGINE-TASK-000090) — configurable spacing/toggle via ViewState.GridSettings
// rather than this package's own fixed constant.
