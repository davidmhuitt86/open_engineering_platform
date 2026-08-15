import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../../interfaces/routing_provider.dart';
import '../../interfaces/symbol_provider.dart';
import '../../selection/graph_selection.dart';
import '../../symbols/models/symbol_port.dart';
import '../view.dart';
import 'diagram_geometry.dart';
import 'diagram_layout.dart';
import 'diagram_layout_state.dart';
import 'diagram_scene.dart';
import 'fallback_port_layout.dart';
import 'rect2d.dart';
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

    // AP-DS-001A resize support: a node with a tracked `layout.sizeOf`
    // entry renders at that explicit size; otherwise it falls back to the
    // fixed `DiagramLayout.nodeSize`, same fallback pattern as position.
    Size2D sizeOf(String nodeId) =>
        layout?.sizeOf(nodeId) ?? const Size2D(DiagramLayout.nodeSize, DiagramLayout.nodeSize);

    final nodeVisuals = graph.nodes.values.where((node) => isNodeVisible(node.id)).map((node) {
      final position = positionOf(node.id);
      final size = sizeOf(node.id);
      final selected = selection?.containsNode(node.id) ?? node.runtime.selected;
      final highlighted = highlightedNodeIds.contains(node.id) || node.runtime.highlighted;
      return DiagramNodeVisual(
        nodeId: node.id,
        symbolId: node.symbolId,
        position: position,
        width: size.width,
        height: size.height,
        selected: selected,
        highlighted: highlighted,
        displayName: node.displayName,
        category: node.category,
        ports: node.ports,
        metadata: node.metadata,
      );
    }).toList();

    // Sorted by id, not raw Map iteration order — routing is required to
    // be deterministic (WORK_PACKAGE_022, ENGINE-TASK-000094): identical
    // graph content must always route identically, independent of
    // incidental insertion order.
    final orderedRelationships = graph.relationships.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    // "Never cross a component" (user-requested obstacle avoidance): every
    // node's current bounding box, so `OrthogonalRoutingProvider` can
    // route wires around components it isn't connecting, not just between
    // two bare anchor points. Built from the exact same position/size data
    // already computed above for `nodeVisuals`.
    final obstacles = {
      for (final visual in nodeVisuals)
        visual.nodeId: Rect2D(
          left: visual.position.dx,
          top: visual.position.dy,
          right: visual.position.dx + visual.width,
          bottom: visual.position.dy + visual.height,
        ),
    };
    final routingContext = RoutingContext(obstacles: obstacles);
    final wireVisuals = orderedRelationships.map((relationship) {
      final sourceNode = graph.nodes[relationship.sourceNode];
      final targetNode = graph.nodes[relationship.targetNode];
      final sourcePosition = positionOf(relationship.sourceNode);
      final sourceSize = sizeOf(relationship.sourceNode);
      final targetPosition = positionOf(relationship.targetNode);
      final targetSize = sizeOf(relationship.targetNode);
      final sourceResolved = _anchorFor(
        sourceNode,
        sourcePosition,
        sourceSize,
        symbols,
        towards: targetPosition,
      );
      final targetResolved = _anchorFor(
        targetNode,
        targetPosition,
        targetSize,
        symbols,
        towards: sourcePosition,
      );

      // WORK_PACKAGE_023, ENGINE-TASK-000099: a manual wire override
      // (Insert/Remove Vertex, Drag Segment/Corner, Manual Route
      // Override) is used verbatim, bypassing the router entirely. The
      // auto-routed path stays deterministic (ADR-016) because this
      // check only ever short-circuits it — it never changes what the
      // router itself computes for un-overridden relationships.
      final points = layout?.wireOverrideOf(relationship.id) ??
          (routing == null
              ? [sourceResolved.anchor, targetResolved.anchor]
              : routing.route(
                  RoutingRequest(
                    relationshipId: relationship.id,
                    source: sourceResolved.anchor,
                    target: targetResolved.anchor,
                    trunkKey: relationship.sourceNode,
                    sourceNodeId: relationship.sourceNode,
                    targetNodeId: relationship.targetNode,
                    sourceExitDirection: sourceResolved.direction,
                    targetExitDirection: targetResolved.direction,
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
  ///
  /// Also reports which edge of the node that anchor sits on
  /// (`'up'`/`'down'`/`'left'`/`'right'`, or `null` for a center
  /// fallback/interior anchor) — [OrthogonalRoutingProvider] uses this
  /// to exit each port perpendicular to its own node rather than cutting
  /// straight across it toward the other endpoint.
  ({Point2D anchor, String? direction}) _anchorFor(
    EngineeringNode? node,
    Point2D nodePosition,
    Size2D nodeSize,
    SymbolProvider? symbols, {
    required Point2D towards,
  }) {
    final center = nodePosition.translate(
      nodeSize.width / 2,
      nodeSize.height / 2,
    );
    if (node == null) return (anchor: center, direction: null);

    // (Phase 14 -- UI Layout Ratification.) Prefer the visual Symbol's
    // own authored port geometry when one resolves; otherwise fall back
    // to the SAME real-port-derived geometry `graph_view_panel.dart`'s
    // pin rendering and `diagram_studio_page.dart`'s drag-to-connect
    // anchor both use (`fallbackPorts`) -- all three must agree, or a
    // wire visually detaches from the pin it's meant to reach.
    final symbolPorts = (symbols != null && node.symbolId != null) ? symbols.lookup(node.symbolId!)?.ports ?? const [] : const <SymbolPort>[];
    final ports = symbolPorts.isNotEmpty ? symbolPorts : fallbackPorts(node.ports, exit: (node.metadata['exit'] as String?) ?? 'down');
    if (ports.isEmpty) return (anchor: center, direction: null);

    Point2D? nearest;
    double? nearestPortX;
    double? nearestPortY;
    double nearestDistance = double.infinity;
    for (final port in ports) {
      // Port coordinates are normalized [0,1] fractions of node size
      // (unchanged by resize — WORK_PACKAGE_021 port model), so anchors
      // scale with the node's actual (possibly resized) width/height
      // rather than the fixed `DiagramLayout.nodeSize`.
      final anchor = nodePosition.translate(
        port.x * nodeSize.width,
        port.y * nodeSize.height,
      );
      final dx = anchor.dx - towards.dx;
      final dy = anchor.dy - towards.dy;
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = anchor;
        nearestPortX = port.x;
        nearestPortY = port.y;
      }
    }
    if (nearest == null) return (anchor: center, direction: null);
    return (anchor: nearest, direction: _edgeDirectionOf(nearestPortX!, nearestPortY!));
  }

  /// Which of a node's four edges a normalized `[0,1]` port position sits
  /// on -- `null` for an interior port (not on any edge), since there's
  /// no single perpendicular direction to exit in that case.
  String? _edgeDirectionOf(double portX, double portY) {
    const edge = 0.001;
    if (portY <= edge) return 'up';
    if (portY >= 1 - edge) return 'down';
    if (portX <= edge) return 'left';
    if (portX >= 1 - edge) return 'right';
    return null;
  }
}
