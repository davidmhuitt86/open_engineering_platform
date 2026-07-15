import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../../interfaces/routing_provider.dart';
import '../../interfaces/symbol_provider.dart';
import '../../selection/graph_selection.dart';
import '../view.dart';
import 'diagram_geometry.dart';
import 'diagram_layout.dart';
import 'diagram_layout_state.dart';
import 'diagram_scene.dart';
import 'routing_context.dart';
import 'routing_request.dart';

/// The first View: a wiring-diagram-style visualization of the Engineering
/// Graph (SDD-024/025). Produces a [DiagramScene] — pure data, no drawing.
///
/// Sibling Views (Harness, Diagnostic, Physical Layout, Simulation, Print)
/// implement the same [EngineeringView] contract; none of them require the
/// Graph or each other to change.
///
/// [layout] positions come from [DiagramLayoutState] (WORK_PACKAGE_021) —
/// never from the graph itself (SDD-024 Rule 5). Any node missing a
/// tracked position falls back to the deterministic auto-layout grid, so
/// this stays backward compatible with graphs that haven't been moved
/// yet. [selection]/[highlightedNodeIds]/[highlightedRelationshipIds]
/// passed explicitly take precedence over — but fall back to — each
/// node/relationship's own `runtime.selected`/`runtime.highlighted`
/// flags, preserving Phase 1 callers.
///
/// WORK_PACKAGE_023 additions, both purely a matter of consulting
/// [layout] data this View already reads (no new subsystem): a
/// relationship with a manual [DiagramLayoutState.wireOverrideOf] entry
/// (ENGINE-TASK-000099) uses that point list verbatim instead of calling
/// [routing] — the deterministic auto-router path is otherwise untouched.
/// A node assigned to a layer whose [DiagramLayer.visible] is `false`
/// (ENGINE-TASK-000101) is excluded from the rendered [DiagramScene]
/// entirely, the same way a View has always decided what to draw from
/// layout data.
class DiagramView implements EngineeringView<DiagramScene> {
  @override
  final String id = 'diagram';

  @override
  final String displayName = 'Diagram View';

  @override
  DiagramScene render(
    EngineeringGraph graph, {
    DiagramLayoutState? layout,
    RoutingProvider? routing,
    SymbolProvider? symbols,
    GraphSelection? selection,
    Set<String> highlightedNodeIds = const {},
    Set<String> highlightedRelationshipIds = const {},
  }) {
    if (graph.nodes.isEmpty) return DiagramScene.empty;

    final fallbackPositions = DiagramLayout.compute(graph);
    Point2D positionOf(String nodeId) =>
        layout?.positionOf(nodeId) ?? fallbackPositions[nodeId] ?? const Point2D(0, 0);

    // WORK_PACKAGE_023, ENGINE-TASK-000101: a node assigned to a hidden
    // layer is excluded from the scene entirely. Unassigned nodes are
    // always visible.
    bool isNodeVisible(String nodeId) {
      final layerId = layout?.layerOf(nodeId);
      if (layerId == null) return true;
      return layout?.layerById(layerId)?.visible ?? true;
    }

    final nodeVisuals = graph.nodes.values.where((node) => isNodeVisible(node.id)).map((node) {
      final position = positionOf(node.id);
      final selected = selection?.containsNode(node.id) ?? node.runtime.selected;
      final highlighted = highlightedNodeIds.contains(node.id) || node.runtime.highlighted;
      return DiagramNodeVisual(
        nodeId: node.id,
        symbolId: node.symbolId,
        position: position,
        width: DiagramLayout.nodeSize,
        height: DiagramLayout.nodeSize,
        selected: selected,
        highlighted: highlighted,
      );
    }).toList();

    // Sorted by id, not raw Map iteration order — routing is required to
    // be deterministic (WORK_PACKAGE_022, ENGINE-TASK-000094): identical
    // graph content must always route identically, independent of
    // incidental insertion order.
    final orderedRelationships = graph.relationships.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final routingContext = RoutingContext();
    final wireVisuals = orderedRelationships.map((relationship) {
      final sourceNode = graph.nodes[relationship.sourceNode];
      final targetNode = graph.nodes[relationship.targetNode];
      final sourceAnchor = _anchorFor(
        sourceNode,
        positionOf(relationship.sourceNode),
        symbols,
        towards: positionOf(relationship.targetNode),
      );
      final targetAnchor = _anchorFor(
        targetNode,
        positionOf(relationship.targetNode),
        symbols,
        towards: positionOf(relationship.sourceNode),
      );

      // WORK_PACKAGE_023, ENGINE-TASK-000099: a manual wire override
      // (Insert/Remove Vertex, Drag Segment/Corner, Manual Route
      // Override) is used verbatim, bypassing the router entirely. The
      // auto-routed path stays deterministic (ADR-016) because this
      // check only ever short-circuits it — it never changes what the
      // router itself computes for un-overridden relationships.
      final points = layout?.wireOverrideOf(relationship.id) ??
          (routing == null
              ? [sourceAnchor, targetAnchor]
              : routing.route(
                  RoutingRequest(
                    relationshipId: relationship.id,
                    source: sourceAnchor,
                    target: targetAnchor,
                    trunkKey: relationship.sourceNode,
                  ),
                  routingContext,
                ));

      final selected =
          selection?.containsRelationship(relationship.id) ?? relationship.runtime.selected;
      final highlighted = highlightedRelationshipIds.contains(relationship.id) ||
          relationship.runtime.highlighted;

      return DiagramWireVisual(
        relationshipId: relationship.id,
        points: points,
        selected: selected,
        highlighted: highlighted,
      );
    }).toList();

    final allPositions = graph.nodes.keys.map(positionOf).toList();
    final maxColumn = allPositions.isEmpty
        ? 0.0
        : allPositions.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final maxRow = allPositions.isEmpty
        ? 0.0
        : allPositions.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    return DiagramScene(
      nodes: nodeVisuals,
      wires: wireVisuals,
      contentWidth: maxColumn + DiagramLayout.cellWidth,
      contentHeight: maxRow + DiagramLayout.cellHeight,
    );
  }

  /// Resolves a wire endpoint to the node's nearest port anchor (WP021
  /// "port snapping"), falling back to the node's center when it has no
  /// symbol/ports. `EngineeringRelationship` references nodes, not
  /// specific ports (SDD-027), so this snaps to whichever port is
  /// geometrically closest to [towards] rather than a named port —
  /// documented scoping decision, see docs/ROUTING_ENGINE.md.
  Point2D _anchorFor(
    EngineeringNode? node,
    Point2D nodePosition,
    SymbolProvider? symbols, {
    required Point2D towards,
  }) {
    final center = nodePosition.translate(
      DiagramLayout.nodeSize / 2,
      DiagramLayout.nodeSize / 2,
    );
    if (node?.symbolId == null || symbols == null) return center;

    final symbol = symbols.lookup(node!.symbolId!);
    if (symbol == null || symbol.ports.isEmpty) return center;

    Point2D? nearest;
    double nearestDistance = double.infinity;
    for (final port in symbol.ports) {
      final anchor = nodePosition.translate(
        port.x * DiagramLayout.nodeSize,
        port.y * DiagramLayout.nodeSize,
      );
      final dx = anchor.dx - towards.dx;
      final dy = anchor.dy - towards.dy;
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = anchor;
      }
    }
    return nearest ?? center;
  }
}
