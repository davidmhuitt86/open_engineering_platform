import 'dart:async';

import '../interfaces/view_state_provider.dart';
import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/rect2d.dart';
import '../views/diagram/port_reference.dart';
import 'grid_settings.dart';
import 'navigation_history.dart';
import 'view_state.dart';
import 'view_theme.dart';
import 'viewport_math.dart';

/// Runtime visualization state (WORK_PACKAGE_022, ENGINE-TASK-000088).
/// Architecturally identical to `SelectionService`: holds one live value,
/// broadcasts changes, never touches `CommandHistory`.
class ViewStateService implements ViewStateProvider {
  final StreamController<ViewState> _changes = StreamController<ViewState>.broadcast();
  final NavigationHistory navigationHistory = NavigationHistory();

  ViewState _current = ViewState.initial;

  @override
  ViewState get current => _current;

  @override
  Stream<ViewState> get changes => _changes.stream;

  void _set(ViewState state) {
    _current = state;
    _changes.add(state);
  }

  @override
  void setZoom(double zoom) => _set(_current.copyWith(zoom: zoom));

  @override
  void setPan(Point2D pan) => _set(_current.copyWith(pan: pan));

  @override
  void setViewportSize(double width, double height) =>
      _set(_current.copyWith(viewportWidth: width, viewportHeight: height));

  @override
  void setVisibleLayers(Set<String> layers) => _set(_current.copyWith(visibleLayers: layers));

  @override
  void setGridSettings(GridSettings settings) => _set(_current.copyWith(grid: settings));

  @override
  void toggleGrid() =>
      _set(_current.copyWith(grid: _current.grid.copyWith(visible: !_current.grid.visible)));

  @override
  void toggleSnap() => _set(
      _current.copyWith(grid: _current.grid.copyWith(snapEnabled: !_current.grid.snapEnabled)));

  @override
  void setGuidesVisible(bool visible) => _set(_current.copyWith(guidesVisible: visible));

  @override
  void setTheme(ViewTheme theme) => _set(_current.copyWith(theme: theme));

  @override
  void setRenderOption(String key, Object? value) {
    _set(_current.copyWith(renderOptions: {..._current.renderOptions, key: value}));
  }

  @override
  void hoverPort(PortReference? port) {
    _set(_current.copyWith(hoveredPort: port, clearHoveredPort: port == null));
  }

  // --- Viewport navigation (ENGINE-TASK-000095) --------------------------
  // Pure computation lives in ViewportMath; this just applies the result
  // and records history. Animation (if any) is the host's job.

  void _applyTarget(ViewportTarget target, {bool recordHistory = true}) {
    if (recordHistory) {
      navigationHistory.push(ViewportTarget(zoom: _current.zoom, pan: _current.pan));
    }
    _set(_current.copyWith(zoom: target.zoom, pan: target.pan));
  }

  void fitAll(double sceneWidth, double sceneHeight) {
    _applyTarget(ViewportMath.fitAll(
      sceneWidth: sceneWidth,
      sceneHeight: sceneHeight,
      viewportWidth: _current.viewportWidth,
      viewportHeight: _current.viewportHeight,
    ));
  }

  void fitSelection(Rect2D bounds) {
    _applyTarget(ViewportMath.fitSelection(
      bounds: bounds,
      viewportWidth: _current.viewportWidth,
      viewportHeight: _current.viewportHeight,
    ));
  }

  void centerSelection(Rect2D bounds) {
    _applyTarget(ViewportMath.centerOn(
      bounds: bounds,
      currentZoom: _current.zoom,
      viewportWidth: _current.viewportWidth,
      viewportHeight: _current.viewportHeight,
    ));
  }

  void zoomToCursor(Point2D cursorScreenPoint, double newZoom) {
    _applyTarget(
      ViewportMath.zoomToCursor(
        cursorScreenPoint: cursorScreenPoint,
        currentZoom: _current.zoom,
        newZoom: newZoom,
        currentPan: _current.pan,
      ),
      recordHistory: false, // continuous zoom gestures shouldn't spam history
    );
  }

  bool get canGoBack => navigationHistory.canGoBack;
  bool get canGoForward => navigationHistory.canGoForward;

  void goBack() {
    final target = navigationHistory.goBack(ViewportTarget(zoom: _current.zoom, pan: _current.pan));
    if (target != null) _applyTarget(target, recordHistory: false);
  }

  void goForward() {
    final target =
        navigationHistory.goForward(ViewportTarget(zoom: _current.zoom, pan: _current.pan));
    if (target != null) _applyTarget(target, recordHistory: false);
  }

  Future<void> dispose() => _changes.close();
}
