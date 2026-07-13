import '../../graph/models/engineering_graph.dart';
import '../view.dart';
import 'diagram_geometry.dart';
import 'diagram_layout.dart';
import 'diagram_scene.dart';

/// The first View: a wiring-diagram-style visualization of the Engineering
/// Graph (SDD-024/025). Produces a [DiagramScene] — pure data, no drawing.
///
/// Sibling Views (Harness, Diagnostic, Physical Layout, Simulation, Print)
/// implement the same [EngineeringView] contract; none of them require the
/// Graph or each other to change.
class DiagramView implements EngineeringView<DiagramScene> {
  @override
  final String id = 'diagram';

  @override
  final String displayName = 'Diagram View';

  @override
  DiagramScene render(EngineeringGraph graph) {
    if (graph.nodes.isEmpty) return DiagramScene.empty;

    final positions = DiagramLayout.compute(graph);

    final nodeVisuals = graph.nodes.values.map((node) {
      final position = positions[node.id] ?? const Point2D(0, 0);
      return DiagramNodeVisual(
        nodeId: node.id,
        symbolId: node.symbolId,
        position: position,
        width: DiagramLayout.nodeSize,
        height: DiagramLayout.nodeSize,
        selected: node.runtime.selected,
        highlighted: node.runtime.highlighted,
      );
    }).toList();

    final wireVisuals = graph.relationships.values.map((relationship) {
      final sourcePos = positions[relationship.sourceNode] ?? const Point2D(0, 0);
      final targetPos = positions[relationship.targetNode] ?? const Point2D(0, 0);
      final half = DiagramLayout.nodeSize / 2;
      return DiagramWireVisual(
        relationshipId: relationship.id,
        points: [
          sourcePos.translate(half, half),
          targetPos.translate(half, half),
        ],
        selected: relationship.runtime.selected,
        highlighted: relationship.runtime.highlighted,
      );
    }).toList();

    final maxColumn = positions.values.isEmpty
        ? 0
        : positions.values.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final maxRow = positions.values.isEmpty
        ? 0
        : positions.values.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    return DiagramScene(
      nodes: nodeVisuals,
      wires: wireVisuals,
      contentWidth: maxColumn + DiagramLayout.cellWidth,
      contentHeight: maxRow + DiagramLayout.cellHeight,
    );
  }
}
