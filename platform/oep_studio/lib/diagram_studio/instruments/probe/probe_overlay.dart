import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../multimeter/multimeter_controller.dart';

enum ProbeSlot { a, b }

/// WP-DS-005A Probe System — two independent probes (black = A, red = B),
/// click-to-place and drag.
///
/// Snaps to a specific **port** (terminal) on a node when the tap/drag
/// lands on one -- e.g. a battery's `positive`/`negative` terminals
/// (`SymbolDefinition.ports`, the same per-symbol port geometry the
/// canvas's own drag-to-connect wire gesture already hit-tests against),
/// falling back to the node's own center otherwise. This matters for
/// real measurements: probing "the battery" as a whole is ambiguous for
/// anything with more than one terminal, while probing its `positive`
/// port specifically is not.
///
/// Reuses the exact node-id -> screen-position transform every other
/// canvas overlay in this Studio already uses
/// (`pan.dx + zoom * position.dx`, matching `SimulationStateOverlay`'s
/// and `DiagramIntelligenceOverlay`'s own documented convention) and the
/// same `layout.positions` map the canvas's own node hit-testing is
/// built from — no separate/duplicated hit-testing geometry.
class ProbeOverlay extends StatelessWidget {
  const ProbeOverlay({
    super.key,
    required this.controller,
    required this.graph,
    required this.layout,
    required this.symbols,
    required this.pan,
    required this.zoom,
    required this.active,
    this.nodeSize = 100,
  });

  final MultimeterController controller;
  final EngineeringGraph graph;
  final DiagramLayoutState layout;
  final SymbolProvider symbols;
  final Point2D pan;
  final double zoom;

  /// Whether probe placement is currently enabled — when `false`, probes
  /// still render (if placed) but are not draggable, so the canvas's
  /// normal node-drag/selection gestures are not fought over.
  final bool active;

  /// Must match the host page's own node square size (`_nodeSize` in
  /// `DiagramStudioPage`) -- `SymbolPort.x`/`y` are normalized (0..1)
  /// within that square, mirroring `_portAnchor`'s own math there.
  final double nodeSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Stack(
        children: [
          if (controller.probeA != null) _probeMarker(context, ProbeSlot.a, controller.probeA!, StudioColors.textPrimary),
          if (controller.probeB != null) _probeMarker(context, ProbeSlot.b, controller.probeB!, StudioColors.error),
        ],
      ),
    );
  }

  /// The screen point a [ProbePoint] should render at: its specific port
  /// anchor when [ProbePoint.portId] is set and resolvable, else the
  /// node's own center (unchanged fallback for wire-snapped or
  /// port-less probes).
  Point2D? _anchorFor(ProbePoint point) {
    final position = layout.positionOf(point.nodeId);
    if (position == null) return null;
    if (point.portId == null) return position.translate(nodeSize / 2, nodeSize / 2);
    final node = graph.nodes[point.nodeId];
    final symbol = symbols.resolve(node?.symbolId ?? '');
    final match = symbol.ports.where((p) => p.id == point.portId);
    if (match.isEmpty) return position.translate(nodeSize / 2, nodeSize / 2);
    final port = match.first;
    return position.translate(port.x * nodeSize, port.y * nodeSize);
  }

  Widget _probeMarker(BuildContext context, ProbeSlot slot, ProbePoint point, Color color) {
    final anchor = _anchorFor(point);
    if (anchor == null) return const SizedBox.shrink();
    final left = pan.dx + zoom * anchor.dx;
    final top = pan.dy + zoom * anchor.dy;
    final label = point.portId == null ? point.nodeId : '${point.nodeId} (${point.portId})';
    return Positioned(
      left: left - 8,
      top: top - 8,
      child: GestureDetector(
        onPanUpdate: !active
            ? null
            : (details) => _snapToNearest(details.globalPosition, context, slot),
        child: Tooltip(
          message: '${slot == ProbeSlot.a ? 'Probe A (black)' : 'Probe B (red)'}: $label',
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: StudioColors.surfaceRaised, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  /// Click-to-place / drag: given a global pointer position, finds the
  /// nearest **port** across every node's symbol (falling back to the
  /// nearest node's own center when a node has no ports, e.g. ground)
  /// and re-anchors the probe there.
  void _snapToNearest(Offset globalPosition, BuildContext context, ProbeSlot slot) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final scenePoint = Point2D((local.dx - pan.dx) / zoom, (local.dy - pan.dy) / zoom);

    final newPoint = _nearestPoint(scenePoint);
    if (newPoint == null) return;
    if (slot == ProbeSlot.a) {
      controller.setProbeA(newPoint);
    } else {
      controller.setProbeB(newPoint);
    }
  }

  ProbePoint? _nearestPoint(Point2D scenePoint) {
    String? nearestNodeId;
    String? nearestPortId;
    double nearestDistanceSquared = double.infinity;

    void consider(String nodeId, String? portId, Point2D candidate) {
      final dx = candidate.dx - scenePoint.dx;
      final dy = candidate.dy - scenePoint.dy;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < nearestDistanceSquared) {
        nearestDistanceSquared = distanceSquared;
        nearestNodeId = nodeId;
        nearestPortId = portId;
      }
    }

    for (final entry in layout.positions.entries) {
      final nodeId = entry.key;
      final position = entry.value;
      final node = graph.nodes[nodeId];
      final symbol = node == null ? null : symbols.resolve(node.symbolId ?? '');
      final ports = symbol?.ports.where((p) => p.visible) ?? const [];
      if (ports.isEmpty) {
        consider(nodeId, null, position.translate(nodeSize / 2, nodeSize / 2));
      } else {
        for (final port in ports) {
          consider(nodeId, port.id, position.translate(port.x * nodeSize, port.y * nodeSize));
        }
      }
    }

    if (nearestNodeId == null) return null;
    return ProbePoint(nodeId: nearestNodeId!, portId: nearestPortId);
  }

  /// Places a probe by node id — called from the host page's existing
  /// `onNodeTap` handler when probe-placement mode is active (click-to-
  /// place) and the tap landed on a node's body rather than one of its
  /// ports, reusing that handler's own hit-testing rather than adding a
  /// second one.
  static void placeByNodeTap(MultimeterController controller, ProbeSlot slot, String nodeId) {
    final point = ProbePoint(nodeId: nodeId);
    if (slot == ProbeSlot.a) {
      controller.setProbeA(point);
    } else {
      controller.setProbeB(point);
    }
  }

  /// Places a probe by a specific port — called from the host page's
  /// existing `onPortDragStart` handler (the same one drag-to-connect
  /// wires already use) when probe-placement mode is active, so pressing
  /// down on a terminal (e.g. a battery's `positive`/`negative`) places
  /// the probe there instead of starting a wire connection.
  static void placeByPortTap(MultimeterController controller, ProbeSlot slot, PortReference port) {
    final point = ProbePoint(nodeId: port.nodeId, portId: port.portId);
    if (slot == ProbeSlot.a) {
      controller.setProbeA(point);
    } else {
      controller.setProbeB(point);
    }
  }
}
