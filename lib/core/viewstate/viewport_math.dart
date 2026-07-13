import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/rect2d.dart';

/// A target zoom/pan pair — the *result* of a viewport computation, not a
/// live state holder. `ViewState`/the Demonstration Host apply it (either
/// immediately or by animating toward it — animation is a Demonstration
/// Host concern, never engine code: WORK_PACKAGE_022 ENGINE-TASK-000095,
/// "No Flutter animation code inside Engine").
///
/// Screen/scene convention used throughout: `screenPoint = scenePoint *
/// zoom + pan` (pan is a screen-space translation, matching a typical
/// `Matrix4..translate(pan)..scale(zoom)` transform).
class ViewportTarget {
  final double zoom;
  final Point2D pan;

  const ViewportTarget({required this.zoom, required this.pan});
}

/// Pure viewport geometry (WORK_PACKAGE_022, ENGINE-TASK-000095). No
/// Flutter, no timers — every function is a plain calculation from inputs
/// to a target zoom/pan.
class ViewportMath {
  ViewportMath._();

  /// Fits [contentWidth]x[contentHeight] within [viewportWidth]x
  /// [viewportHeight], centered, leaving [margin] fraction of empty space
  /// (0.1 = 10% breathing room).
  static ViewportTarget fitBounds({
    required double contentWidth,
    required double contentHeight,
    required double viewportWidth,
    required double viewportHeight,
    double margin = 0.1,
    double contentLeft = 0,
    double contentTop = 0,
    double minZoom = 0.05,
    double maxZoom = 8,
  }) {
    if (contentWidth <= 0 || contentHeight <= 0 || viewportWidth <= 0 || viewportHeight <= 0) {
      return const ViewportTarget(zoom: 1, pan: Point2D(0, 0));
    }
    final fill = 1 - margin;
    final zoomX = (viewportWidth / contentWidth) * fill;
    final zoomY = (viewportHeight / contentHeight) * fill;
    final zoom = zoomX < zoomY ? zoomX : zoomY;
    final clampedZoom = zoom.clamp(minZoom, maxZoom);

    final contentCenter = Point2D(
      contentLeft + contentWidth / 2,
      contentTop + contentHeight / 2,
    );
    final viewportCenter = Point2D(viewportWidth / 2, viewportHeight / 2);
    final pan = Point2D(
      viewportCenter.dx - clampedZoom * contentCenter.dx,
      viewportCenter.dy - clampedZoom * contentCenter.dy,
    );
    return ViewportTarget(zoom: clampedZoom, pan: pan);
  }

  /// "Fit All" (ENGINE-TASK-000095): fits the whole scene.
  static ViewportTarget fitAll({
    required double sceneWidth,
    required double sceneHeight,
    required double viewportWidth,
    required double viewportHeight,
    double margin = 0.1,
  }) {
    return fitBounds(
      contentWidth: sceneWidth,
      contentHeight: sceneHeight,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      margin: margin,
    );
  }

  /// "Fit Selection": fits just [bounds].
  static ViewportTarget fitSelection({
    required Rect2D bounds,
    required double viewportWidth,
    required double viewportHeight,
    double margin = 0.2,
  }) {
    return fitBounds(
      contentWidth: bounds.right - bounds.left,
      contentHeight: bounds.bottom - bounds.top,
      contentLeft: bounds.left,
      contentTop: bounds.top,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      margin: margin,
    );
  }

  /// "Center Selection": keeps [currentZoom], pans so [bounds]' center is
  /// centered in the viewport.
  static ViewportTarget centerOn({
    required Rect2D bounds,
    required double currentZoom,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final center = Point2D(
      (bounds.left + bounds.right) / 2,
      (bounds.top + bounds.bottom) / 2,
    );
    final viewportCenter = Point2D(viewportWidth / 2, viewportHeight / 2);
    final pan = Point2D(
      viewportCenter.dx - currentZoom * center.dx,
      viewportCenter.dy - currentZoom * center.dy,
    );
    return ViewportTarget(zoom: currentZoom, pan: pan);
  }

  /// "Zoom To Cursor": changes zoom from [currentZoom] to [newZoom] while
  /// keeping the scene point currently under [cursorScreenPoint] fixed on
  /// screen.
  static ViewportTarget zoomToCursor({
    required Point2D cursorScreenPoint,
    required double currentZoom,
    required double newZoom,
    required Point2D currentPan,
  }) {
    final sceneUnderCursor = Point2D(
      (cursorScreenPoint.dx - currentPan.dx) / currentZoom,
      (cursorScreenPoint.dy - currentPan.dy) / currentZoom,
    );
    final pan = Point2D(
      cursorScreenPoint.dx - newZoom * sceneUnderCursor.dx,
      cursorScreenPoint.dy - newZoom * sceneUnderCursor.dy,
    );
    return ViewportTarget(zoom: newZoom, pan: pan);
  }
}
