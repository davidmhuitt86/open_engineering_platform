import 'diagram_geometry.dart';

/// A placed node, ready to be painted by a Flutter-side renderer. Carries
/// enough information (symbol id, bounds) for a painter to resolve the
/// Symbol's geometry asset itself — this module never touches `dart:ui`.
class DiagramNodeVisual {
  final String nodeId;
  final String? symbolId;
  final Point2D position;
  final double width;
  final double height;
  final bool selected;
  final bool highlighted;

  const DiagramNodeVisual({
    required this.nodeId,
    required this.symbolId,
    required this.position,
    this.width = 100,
    this.height = 100,
    this.selected = false,
    this.highlighted = false,
  });
}

/// A placed relationship, drawn as a polyline between node anchor points.
class DiagramWireVisual {
  final String relationshipId;
  final List<Point2D> points;
  final bool selected;
  final bool highlighted;

  const DiagramWireVisual({
    required this.relationshipId,
    required this.points,
    this.selected = false,
    this.highlighted = false,
  });
}

/// The full scene description produced by [DiagramView.render] for one
/// paint pass. Pure data — no drawing occurs here (SDD-025/026).
class DiagramScene {
  final List<DiagramNodeVisual> nodes;
  final List<DiagramWireVisual> wires;
  final double contentWidth;
  final double contentHeight;

  const DiagramScene({
    required this.nodes,
    required this.wires,
    required this.contentWidth,
    required this.contentHeight,
  });

  static const DiagramScene empty =
      DiagramScene(nodes: [], wires: [], contentWidth: 0, contentHeight: 0);
}
