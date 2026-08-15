import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// (Phase 14 -- UI Layout Ratification.) A left-edge category-color
/// stripe per real [NodeCategory] -- modeled on
/// `legacy_wiring_sim_v2`'s own `CAT_CLR` map
/// (`js/diagram/renderer.js:17`), re-expressed against OEP's own real
/// category enum rather than the reference's ad hoc string categories.
/// Presentation only -- carries no engineering meaning.
Color categoryStripeColor(NodeCategory category) {
  switch (category) {
    case NodeCategory.component:
      return const Color(0xFF3B82F6);
    case NodeCategory.connector:
      return const Color(0xFF14B8A6);
    case NodeCategory.wire:
      return const Color(0xFF9CA3AF);
    case NodeCategory.circuit:
      return const Color(0xFF8B5CF6);
    case NodeCategory.harness:
      return const Color(0xFFF97316);
    case NodeCategory.module:
      return const Color(0xFF6366F1);
    case NodeCategory.relay:
      return const Color(0xFFA855F7);
    case NodeCategory.fuse:
      return const Color(0xFFF59E0B);
    case NodeCategory.switchNode:
      return const Color(0xFF22C55E);
    case NodeCategory.ground:
      return const Color(0xFF737373);
    case NodeCategory.sensor:
      return const Color(0xFF06B6D4);
    case NodeCategory.actuator:
      return const Color(0xFFEF4444);
    case NodeCategory.measurementPoint:
      return const Color(0xFFEAB308);
    case NodeCategory.procedure:
    case NodeCategory.specification:
      return const Color(0xFF64748B);
    case NodeCategory.unknown:
      return const Color(0xFF9CA3AF);
  }
}

/// Port dot color by real [PortDirection] -- input/output/bidirectional
/// are already real, authored port data (`SymbolPort.direction`), never
/// fabricated per-wire color (this engine's `Port`/`SymbolPort` models
/// carry no wire-color field today -- see this widget's own file doc
/// for the honest scope of this).
Color _portDotColor(PortDirection direction) {
  switch (direction) {
    case PortDirection.input:
      return const Color(0xFF3B82F6);
    case PortDirection.output:
      return const Color(0xFFF97316);
    case PortDirection.bidirectional:
      return const Color(0xFF22C55E);
    case PortDirection.unspecified:
      return const Color(0xFF9CA3AF);
  }
}

/// How far a port marker's own hit region (see `_PortMarker`'s 12x12
/// `Container` below) can extend past this node's card on any edge --
/// an edge-exit port (`x`/`y` of exactly 0.0 or 1.0, this widget's own
/// most common case) centers its marker exactly ON the card boundary,
/// so half the marker (6px) sits outside `node.width`/`node.height`.
/// `Clip.none` on this widget's root `Stack` lets that half PAINT fine,
/// but Flutter's hit-testing is gated by each RenderBox's own `size`
/// independent of its clip behavior -- a marker centered exactly on
/// that boundary (as every edge-exit port is) fell on the far side of
/// `Size.contains()`'s half-open interval (`dx < width`, not `<=`),
/// silently losing every tap to whatever sat behind this node instead
/// of ever reaching `_PortMarker`'s own `GestureDetector`. Both this
/// widget and its caller (`GraphViewPanel`'s node `Positioned`) inflate
/// their bounds by this margin and shift the card/label/ports inward
/// by the same amount, so the node's on-screen position is unchanged
/// but every port marker now sits fully inside the hit-testable box.
const double kNodeHitMargin = 8.0;

/// Half of `_PortMarker`'s own 12x12 size -- how far a port dot extends
/// from its anchor point in every direction.
const double _portMarkerRadius = 6.0;

/// Clear space kept between a port dot's near edge and its pin label,
/// so the label never paints behind the dot (the markers are later
/// `Stack` children than the labels, so an overlap hides the label's
/// nearer half rather than the dot).
const double _pinLabelGap = 2.0;

const double _pinLabelFontSize = 5.5;

/// The pin label's own laid-out height -- fixed rather than measured,
/// since the label's `TextStyle` pins `height: 1.0` (one em, no extra
/// leading), making this exact rather than an estimate.
const double _pinLabelHeight = _pinLabelFontSize;

/// A node's symbol, plus small draggable port markers on top of it
/// (WORK_PACKAGE_022, ENGINE-TASK-000092: hover/highlight/selection/
/// drag-preview/port-preview). Dragging from a port starts a connection
/// drag (ENGINE-TASK-000093); dragging from elsewhere on the node moves it
/// (WORK_PACKAGE_021).
class SymbolNodeWidget extends StatelessWidget {
  final DiagramNodeVisual node;
  final List<SymbolPort> ports;
  final PortReference? hoveredPort;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(PortReference port) onPortHoverEnter;
  final VoidCallback onPortHoverExit;
  final void Function(PortReference port) onPortDragStart;
  final void Function(Offset delta) onPortDragUpdate;
  final VoidCallback onPortDragEnd;

  /// A plain, no-drag click on a port -- distinct from [onPortDragStart]
  /// (which only fires once a pan gesture is recognized, i.e. after the
  /// pointer has moved past the touch-slop threshold; a precise
  /// click-and-release with no movement never reaches it). Optional and
  /// `null` by default so existing callers (which only ever cared about
  /// drag-to-connect) are unaffected.
  final void Function(PortReference port)? onPortTap;

  /// A right-click (secondary-button tap) directly on a port marker
  /// (OEP Diagram Studio -- Phase 4, Part 4): reuses the exact same
  /// real, model-backed 12x12 hit region `_PortMarker`'s own
  /// `onTap`/drag handlers already use -- not a separately computed
  /// approximation. `null` for callers that don't need port-level
  /// contextual-menu targeting.
  final void Function(PortReference port, Offset globalPosition)? onPortSecondaryTapUp;

  /// A right-click (secondary-button tap) directly on this node's body.
  /// This widget's own `GestureDetector` is `HitTestBehavior.opaque` and
  /// sits above `GraphViewPanel`'s background gesture detector in the
  /// `Stack`, so it claims the entire hit-test path for any point over
  /// the node -- a background-only `onSecondaryTapUp` (as
  /// `GraphViewPanel` has) never receives pointer events for a click
  /// that lands on a node. Optional and `null` by default so existing
  /// callers are unaffected.
  final void Function(Offset globalPosition)? onSecondaryTapUp;

  const SymbolNodeWidget({
    super.key,
    required this.node,
    required this.ports,
    required this.hoveredPort,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onPortHoverEnter,
    required this.onPortHoverExit,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
    this.onPortTap,
    this.onPortSecondaryTapUp,
    this.onSecondaryTapUp,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        node.highlighted ? Colors.orange : (node.selected ? Colors.blue : Colors.transparent);
    // `SizedBox` here (not `Stack`'s own natural sizing) is what makes
    // `kNodeHitMargin`'s fix actually work: `Clip.none` on the `Stack`
    // below only widens *painting*, but Flutter's hit-testing gates on
    // each RenderBox's own reported `size` regardless of clip -- this
    // box has to genuinely report the inflated size for the port
    // markers positioned outside `(0,0,node.width,node.height)` to be
    // reachable at all. `GraphViewPanel`'s own node `Positioned` gives
    // this widget the matching inflated constraints (shifted by
    // `-kNodeHitMargin` so the node's on-screen position is unchanged).
    return SizedBox(
      width: node.width + kNodeHitMargin * 2,
      height: node.height + kNodeHitMargin * 2,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapUp: onSecondaryTapUp == null ? null : (details) => onSecondaryTapUp!(details.globalPosition),
      onPanStart: (_) => onDragStart(),
      onPanUpdate: (details) => onDragUpdate(details.delta),
      onPanEnd: (_) => onDragEnd(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // (Phase 14 -- UI Layout Ratification.) The card label, above
          // the card body -- modeled on `legacy_wiring_sim_v2`'s own
          // `.mod-label` (`css/main.css:142`, positioned via
          // `translate(-50%,-100%)`), sourced from the real
          // `DiagramNodeVisual.displayName` this widget already
          // receives (Phase 14 also threaded this through
          // `diagram_view.dart`).
          Positioned(
            left: kNodeHitMargin,
            right: kNodeHitMargin,
            top: kNodeHitMargin - 18,
            child: Text(
              node.displayName,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ),
          Positioned(
            left: kNodeHitMargin,
            top: kNodeHitMargin,
            child: Container(
              width: node.width,
              height: node.height,
              decoration: BoxDecoration(
                // Cards stay white/black regardless of app theme,
                // matching the reference's own deliberate choice (its own
                // dark/light CSS variables leave `--card-bg`/`--card-border`
                // fixed in both palettes) -- the engineering diagram
                // itself is not themed, only chrome around it is.
                color: Colors.white,
                border: Border.all(
                  color: node.highlighted || node.selected ? borderColor : Colors.black87,
                  width: node.highlighted || node.selected ? 2.5 : 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: categoryStripeColor(node.category)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: node.symbolId == null
                          ? const Icon(Icons.help_outline, color: Colors.black54)
                          : SvgPicture.asset(
                              'assets/symbols/${node.symbolId}.svg',
                              package: 'engineering_engine',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Each pin's own real name, as small caps text just inside
          // the card from its dot -- the port data
          // (`SymbolPort.displayName`) was always real and available
          // here, it simply was never rendered as visible text before.
          // Only for vertical-edge ports (top/bottom, this app's
          // two-row wiring-harness layout), where there's room to stack
          // a label above/below the dot without colliding with the
          // neighboring pin's own label.
          //
          // Positioned to fully CLEAR the dot, not merely near it: a
          // port marker is 12x12 centered on its own anchor, so it
          // spans +/-6 around `port.y * node.height`. A label placed
          // inside that band paints behind the dot (the markers are
          // later `Stack` children, so they win) and gets visually cut
          // in half -- a real, observed bug. `_pinLabelGap` is measured
          // from the dot's own near EDGE, not its center, so the two
          // never overlap at any node size.
          for (final port in ports)
            if (port.displayName.isNotEmpty && (port.y <= 0.001 || port.y >= 0.999))
              Positioned(
                left: kNodeHitMargin + port.x * node.width - 22,
                top: port.y <= 0.001
                    // Top-edge pin: label sits BELOW the dot, inside the card.
                    ? kNodeHitMargin + _portMarkerRadius + _pinLabelGap
                    // Bottom-edge pin: label sits ABOVE the dot, inside the card.
                    : kNodeHitMargin + node.height - _portMarkerRadius - _pinLabelGap - _pinLabelHeight,
                width: 44,
                child: IgnorePointer(
                  child: Text(
                    port.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: _pinLabelFontSize,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
          for (final port in ports)
            Positioned(
              // A marker centered exactly on the card's edge (every
              // edge-exit port -- `x`/`y` of 0.0 or 1.0, this widget's
              // most common case) extends half its 12x12 hit region
              // (6px) past `node.width`/`node.height`. `kNodeHitMargin`
              // (this widget's own root `Stack`/`GestureDetector` are
              // sized `node.width/height + kNodeHitMargin*2`, see
              // `build()` above) keeps that overhang fully inside the
              // hit-testable box on every edge, not just this one --
              // this offset is unrelated to the marker's own 12x12 size
              // (kept small deliberately, see below).
              left: kNodeHitMargin + port.x * node.width - 6,
              top: kNodeHitMargin + port.y * node.height - 6,
              child: _PortMarker(
                key: ValueKey('port-${node.nodeId}-${port.id}'),
                reference: PortReference(nodeId: node.nodeId, portId: port.id),
                isHovered: hoveredPort == PortReference(nodeId: node.nodeId, portId: port.id),
                color: _portDotColor(port.direction),
                onHoverEnter: onPortHoverEnter,
                onHoverExit: onPortHoverExit,
                onDragStart: onPortDragStart,
                onDragUpdate: onPortDragUpdate,
                onDragEnd: onPortDragEnd,
                onTap: onPortTap,
                onSecondaryTapUp: onPortSecondaryTapUp,
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _PortMarker extends StatelessWidget {
  final PortReference reference;
  final bool isHovered;
  final Color color;
  final void Function(PortReference port) onHoverEnter;
  final VoidCallback onHoverExit;
  final void Function(PortReference port) onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(PortReference port)? onTap;
  final void Function(PortReference port, Offset globalPosition)? onSecondaryTapUp;

  const _PortMarker({
    super.key,
    required this.reference,
    required this.isHovered,
    this.color = Colors.blueGrey,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onTap,
    this.onSecondaryTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      onEnter: (_) => onHoverEnter(reference),
      onExit: (_) => onHoverExit(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onDragStart(reference),
        onPanUpdate: (details) => onDragUpdate(details.delta),
        onPanEnd: (_) => onDragEnd(),
        // A plain click (no movement) never reaches `onPanStart` --
        // `onTapUp` is the one that actually fires for it.
        onTapUp: onTap == null ? null : (_) => onTap!(reference),
        onSecondaryTapUp: onSecondaryTapUp == null ? null : (details) => onSecondaryTapUp!(reference, details.globalPosition),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHovered ? Colors.orange : color,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    );
  }
}
