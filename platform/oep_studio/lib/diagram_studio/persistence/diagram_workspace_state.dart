import 'package:engineering_engine/engineering_engine.dart';

/// Diagram Studio's *workspace* state — everything about how you were
/// last looking at a diagram, as opposed to the diagram's own content
/// (WORK_PACKAGE_024, ENGINE-TASK-000115).
///
/// Deliberately excludes the Engineering Graph and Diagram Layout —
/// those are the diagram document's job (`DiagramDocument`, ENGINE-TASK-
/// 000111); saving them here too would create two sources of truth for
/// the same content. [viewState] is included because ViewState (zoom/
/// pan/grid/guides) is genuinely ambient session state, never part of
/// the diagram's own content (WP022's own ViewState philosophy).
class DiagramWorkspaceState {
  final String? lastDocumentPath;
  final bool showLayerPanel;
  final bool showSearchPanel;
  final double explorerWidth;
  final double sidePanelsWidth;
  final ViewState? viewState;

  const DiagramWorkspaceState({
    this.lastDocumentPath,
    this.showLayerPanel = true,
    this.showSearchPanel = true,
    this.explorerWidth = 220,
    this.sidePanelsWidth = 300,
    this.viewState,
  });

  static const DiagramWorkspaceState initial = DiagramWorkspaceState();

  DiagramWorkspaceState copyWith({
    String? lastDocumentPath,
    bool clearLastDocumentPath = false,
    bool? showLayerPanel,
    bool? showSearchPanel,
    double? explorerWidth,
    double? sidePanelsWidth,
    ViewState? viewState,
  }) {
    return DiagramWorkspaceState(
      lastDocumentPath: clearLastDocumentPath ? null : (lastDocumentPath ?? this.lastDocumentPath),
      showLayerPanel: showLayerPanel ?? this.showLayerPanel,
      showSearchPanel: showSearchPanel ?? this.showSearchPanel,
      explorerWidth: explorerWidth ?? this.explorerWidth,
      sidePanelsWidth: sidePanelsWidth ?? this.sidePanelsWidth,
      viewState: viewState ?? this.viewState,
    );
  }

  Map<String, Object?> toJson() => {
        'lastDocumentPath': lastDocumentPath,
        'showLayerPanel': showLayerPanel,
        'showSearchPanel': showSearchPanel,
        'explorerWidth': explorerWidth,
        'sidePanelsWidth': sidePanelsWidth,
        if (viewState != null) 'viewState': viewState!.toJson(),
      };

  factory DiagramWorkspaceState.fromJson(Map<String, Object?> json) {
    final viewStateJson = json['viewState'] as Map<String, Object?>?;
    return DiagramWorkspaceState(
      lastDocumentPath: json['lastDocumentPath'] as String?,
      showLayerPanel: json['showLayerPanel'] as bool? ?? true,
      showSearchPanel: json['showSearchPanel'] as bool? ?? true,
      explorerWidth: (json['explorerWidth'] as num?)?.toDouble() ?? 220,
      sidePanelsWidth: (json['sidePanelsWidth'] as num?)?.toDouble() ?? 300,
      viewState: viewStateJson == null ? null : ViewState.fromJson(viewStateJson),
    );
  }
}
