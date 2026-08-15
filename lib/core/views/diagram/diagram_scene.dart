import '../../graph/models/engineering_node.dart';
import '../../graph/models/port.dart';
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

  /// (Phase 14 -- UI Layout Ratification.) The real
  /// `EngineeringNode.displayName`/`.category` for this node, threaded
  /// through so the renderer can show a real label/category-color
  /// without needing its own separate graph lookup. `displayName`
  /// defaults to [nodeId] (never blank) when a node genuinely has no
  /// authored display name.
  final String displayName;
  final NodeCategory category;

  /// (Phase 14 -- UI Layout Ratification.) The real
  /// `EngineeringNode.ports` for this node -- threaded through so a
  /// renderer can fall back to real port data when no visual Symbol
  /// asset is available for `symbolId` (which carries no geometry of
  /// its own), rather than silently showing zero connection points.
  final List<Port> ports;

  /// (Phase 14.) The real `EngineeringNode.metadata` -- specifically
  /// consulted for an `'exit'` entry ('up'/'down'/'left'/'right', the
  /// edge fallback ports sit on -- see [fallbackPorts]) when
  /// present. Never a new layout concept invented at this level: this
  /// is a plain pass-through of the node's own existing, generic
  /// metadata bag.
  final Map<String, Object?> metadata;

  const DiagramNodeVisual({
    required this.nodeId,
    required this.symbolId,
    required this.position,
    this.width = 100,
    this.height = 100,
    this.selected = false,
    this.highlighted = false,
    String? displayName,
    this.category = NodeCategory.unknown,
    this.ports = const [],
    this.metadata = const {},
  }) : displayName = displayName ?? nodeId;
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
