import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/port_reference.dart';
import 'grid_settings.dart';
import 'view_theme.dart';

/// Runtime-only visualization state — zoom, pan, viewport size, visible
/// layers, grid, guides, theme, render options, hovered port
/// (WORK_PACKAGE_022, ENGINE-TASK-000088).
///
/// **Not** Engineering Knowledge (SDD-024) and **not** Diagram Layout
/// (WP021) — a third, permanently separate concern (see
/// docs/ARCHITECTURE_DECISIONS.md ADR-014). Never routed through the
/// undo/redo command system, exactly like `GraphSelection`/`FocusState`.
/// Serializable independently of the graph and layout so a future Studio
/// workspace can persist/restore it on its own.
class ViewState {
  final double zoom;
  final Point2D pan;
  final double viewportWidth;
  final double viewportHeight;
  final Set<String> visibleLayers;
  final GridSettings grid;
  final bool guidesVisible;
  final ViewTheme theme;
  final Map<String, Object?> renderOptions;
  final PortReference? hoveredPort;

  const ViewState({
    this.zoom = 1.0,
    this.pan = const Point2D(0, 0),
    this.viewportWidth = 0,
    this.viewportHeight = 0,
    this.visibleLayers = const {},
    this.grid = const GridSettings(),
    this.guidesVisible = true,
    this.theme = ViewTheme.system,
    this.renderOptions = const {},
    this.hoveredPort,
  });

  static const ViewState initial = ViewState();

  ViewState copyWith({
    double? zoom,
    Point2D? pan,
    double? viewportWidth,
    double? viewportHeight,
    Set<String>? visibleLayers,
    GridSettings? grid,
    bool? guidesVisible,
    ViewTheme? theme,
    Map<String, Object?>? renderOptions,
    PortReference? hoveredPort,
    bool clearHoveredPort = false,
  }) {
    return ViewState(
      zoom: zoom ?? this.zoom,
      pan: pan ?? this.pan,
      viewportWidth: viewportWidth ?? this.viewportWidth,
      viewportHeight: viewportHeight ?? this.viewportHeight,
      visibleLayers: visibleLayers ?? this.visibleLayers,
      grid: grid ?? this.grid,
      guidesVisible: guidesVisible ?? this.guidesVisible,
      theme: theme ?? this.theme,
      renderOptions: renderOptions ?? this.renderOptions,
      hoveredPort: clearHoveredPort ? null : (hoveredPort ?? this.hoveredPort),
    );
  }

  Map<String, Object?> toJson() => {
        'zoom': zoom,
        'pan': {'dx': pan.dx, 'dy': pan.dy},
        'viewportWidth': viewportWidth,
        'viewportHeight': viewportHeight,
        'visibleLayers': visibleLayers.toList(),
        'grid': grid.toJson(),
        'guidesVisible': guidesVisible,
        'theme': theme.name,
        'renderOptions': renderOptions,
        'hoveredPort': hoveredPort == null
            ? null
            : {'nodeId': hoveredPort!.nodeId, 'portId': hoveredPort!.portId},
      };

  factory ViewState.fromJson(Map<String, Object?> json) {
    final panJson = json['pan'] as Map?;
    final hoveredPortJson = json['hoveredPort'] as Map?;
    return ViewState(
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      pan: panJson == null
          ? const Point2D(0, 0)
          : Point2D((panJson['dx'] as num).toDouble(), (panJson['dy'] as num).toDouble()),
      viewportWidth: (json['viewportWidth'] as num?)?.toDouble() ?? 0,
      viewportHeight: (json['viewportHeight'] as num?)?.toDouble() ?? 0,
      visibleLayers: Set<String>.from(json['visibleLayers'] as List? ?? const []),
      grid: json['grid'] == null
          ? const GridSettings()
          : GridSettings.fromJson(Map<String, Object?>.from(json['grid'] as Map)),
      guidesVisible: json['guidesVisible'] as bool? ?? true,
      theme: ViewTheme.values.firstWhere(
        (t) => t.name == json['theme'],
        orElse: () => ViewTheme.system,
      ),
      renderOptions: Map<String, Object?>.from(json['renderOptions'] as Map? ?? const {}),
      hoveredPort: hoveredPortJson == null
          ? null
          : PortReference(
              nodeId: hoveredPortJson['nodeId'] as String,
              portId: hoveredPortJson['portId'] as String,
            ),
    );
  }
}
