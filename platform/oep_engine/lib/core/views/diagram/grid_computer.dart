import '../../viewstate/grid_settings.dart';
import 'diagram_geometry.dart';
import 'grid_line.dart';
import 'rect2d.dart';

/// Renderer-independent grid geometry (WORK_PACKAGE_022,
/// ENGINE-TASK-000090). No Flutter, no `dart:ui` — a pure function from
/// [GridSettings] + a visible region to a list of lines to draw, and a
/// pure snap function. "No renderer-specific code in Engine": the
/// Demonstration Host is the only thing that turns a [GridLine] into an
/// actual stroke.
class GridComputer {
  GridComputer._();

  /// Lines covering [visibleBounds], spaced per [settings]. Returns both
  /// axes. A line index that's a multiple of [GridSettings.majorEvery] is
  /// marked major.
  static List<GridLine> computeLines(GridSettings settings, Rect2D visibleBounds) {
    if (settings.spacing <= 0) return const [];
    final lines = <GridLine>[];

    final firstColumnIndex = (visibleBounds.left / settings.spacing).floor();
    final lastColumnIndex = (visibleBounds.right / settings.spacing).ceil();
    for (var i = firstColumnIndex; i <= lastColumnIndex; i++) {
      lines.add(GridLine(
        axis: GridAxis.vertical,
        position: i * settings.spacing,
        isMajor: settings.majorEvery > 0 && i % settings.majorEvery == 0,
      ));
    }

    final firstRowIndex = (visibleBounds.top / settings.spacing).floor();
    final lastRowIndex = (visibleBounds.bottom / settings.spacing).ceil();
    for (var i = firstRowIndex; i <= lastRowIndex; i++) {
      lines.add(GridLine(
        axis: GridAxis.horizontal,
        position: i * settings.spacing,
        isMajor: settings.majorEvery > 0 && i % settings.majorEvery == 0,
      ));
    }

    return lines;
  }

  /// Snaps [point] to the nearest grid intersection. Returns [point]
  /// unchanged if [GridSettings.snapEnabled] is false or spacing is
  /// non-positive.
  static Point2D snap(Point2D point, GridSettings settings) {
    if (!settings.snapEnabled || settings.spacing <= 0) return point;
    return Point2D(
      (point.dx / settings.spacing).round() * settings.spacing,
      (point.dy / settings.spacing).round() * settings.spacing,
    );
  }
}
