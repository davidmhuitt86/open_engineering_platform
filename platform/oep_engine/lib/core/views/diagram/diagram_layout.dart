import '../../graph/models/engineering_graph.dart';
import 'diagram_geometry.dart';
import 'diagram_layout_state.dart';

/// Deterministic auto-layout for [DiagramView].
///
/// Phase 1 intentionally uses a simple grid rather than a force-directed or
/// hierarchical layout — auto-layout quality is a rendering concern that
/// can improve independently later without the Graph or the View contract
/// changing. Layout is never stored on the graph (SDD-024): it is
/// recomputed on each [DiagramLayout.compute] call.
class DiagramLayout {
  DiagramLayout._();

  static const double cellWidth = 160;
  static const double cellHeight = 140;
  static const double nodeSize = 100;

  static Map<String, Point2D> compute(EngineeringGraph graph, {int columns = 4}) {
    final positions = <String, Point2D>{};
    var index = 0;
    for (final node in graph.nodes.values) {
      final column = index % columns;
      final row = index ~/ columns;
      positions[node.id] = Point2D(column * cellWidth, row * cellHeight);
      index++;
    }
    return positions;
  }

  /// A node's effective position — [layout]'s tracked position if it has
  /// one, otherwise the same deterministic auto-layout fallback
  /// [DiagramView] already renders with. Layout-mutating commands
  /// (Align/Distribute/Rotate/Mirror/Array) use this instead of reading
  /// `layout.positionOf` directly, so they work correctly even on nodes
  /// that have never been explicitly moved — otherwise a node with no
  /// tracked position silently drops out of the operation (WORK_PACKAGE_023
  /// found this affecting a fresh, never-dragged seed graph).
  static Point2D resolvePosition(
    EngineeringGraph graph,
    DiagramLayoutState layout,
    String nodeId,
  ) {
    return layout.positionOf(nodeId) ?? compute(graph)[nodeId] ?? const Point2D(0, 0);
  }
}
