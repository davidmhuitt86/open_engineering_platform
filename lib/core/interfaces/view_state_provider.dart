import '../editing/editing_constraints.dart';
import '../viewstate/grid_settings.dart';
import '../viewstate/view_state.dart';
import '../viewstate/view_theme.dart';
import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/port_reference.dart';

/// Runtime visualization state (WORK_PACKAGE_022, ENGINE-TASK-000088; plus
/// editing constraints, WORK_PACKAGE_023, ENGINE-TASK-000103).
/// Architecturally identical to `SelectionProvider`: resolved through
/// `EngineRegistry` (ADR-001), never routed through the undo/redo command
/// system (ADR-011/ADR-014).
abstract class ViewStateProvider {
  ViewState get current;
  Stream<ViewState> get changes;

  void setZoom(double zoom);
  void setPan(Point2D pan);
  void setViewportSize(double width, double height);
  void setVisibleLayers(Set<String> layers);
  void setGridSettings(GridSettings settings);
  void toggleGrid();
  void toggleSnap();
  void setGuidesVisible(bool visible);
  void setTheme(ViewTheme theme);
  void setRenderOption(String key, Object? value);
  void hoverPort(PortReference? port);
  void setConstraints(EditingConstraints constraints);
}
