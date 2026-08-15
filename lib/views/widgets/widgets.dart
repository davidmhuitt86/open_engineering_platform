/// Diagram canvas presentation widgets (WORK_PACKAGE_024) — promoted from
/// the Demonstration Host so every consumer of the Engineering Engine
/// (Demonstration Host, Diagram Studio) renders `DiagramScene`/`ViewState`
/// identically instead of maintaining parallel copies. Requires
/// `flutter_svg` (declared in this package's own `pubspec.yaml`).
library;

export 'annotation_widget.dart';
export 'connection_preview_painter.dart';
export 'geometry_utils.dart';
export 'graph_view_panel.dart';
export 'grid_painter.dart';
export 'guides_painter.dart';
export 'origin_indicator.dart';
export 'reconnect_handle.dart';
export 'resize_handles.dart';
export 'symbol_node_widget.dart';
export 'wire_edit_handles.dart';
export 'wire_painter.dart';
