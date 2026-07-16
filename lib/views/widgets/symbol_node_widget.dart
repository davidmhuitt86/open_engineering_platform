import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:engineering_engine/engineering_engine.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        node.highlighted ? Colors.orange : (node.selected ? Colors.blue : Colors.transparent);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanStart: (_) => onDragStart(),
      onPanUpdate: (details) => onDragUpdate(details.delta),
      onPanEnd: (_) => onDragEnd(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(border: Border.all(color: borderColor, width: 2)),
            padding: const EdgeInsets.all(4),
            width: node.width,
            height: node.height,
            child: node.symbolId == null
                ? const Icon(Icons.help_outline)
                : SvgPicture.asset(
                    'assets/symbols/${node.symbolId}.svg',
                    package: 'engineering_engine',
                  ),
          ),
          for (final port in ports)
            Positioned(
              left: port.x * node.width - 6,
              top: port.y * node.height - 6,
              child: _PortMarker(
                reference: PortReference(nodeId: node.nodeId, portId: port.id),
                isHovered: hoveredPort == PortReference(nodeId: node.nodeId, portId: port.id),
                onHoverEnter: onPortHoverEnter,
                onHoverExit: onPortHoverExit,
                onDragStart: onPortDragStart,
                onDragUpdate: onPortDragUpdate,
                onDragEnd: onPortDragEnd,
              ),
            ),
        ],
      ),
    );
  }
}

class _PortMarker extends StatelessWidget {
  final PortReference reference;
  final bool isHovered;
  final void Function(PortReference port) onHoverEnter;
  final VoidCallback onHoverExit;
  final void Function(PortReference port) onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;

  const _PortMarker({
    required this.reference,
    required this.isHovered,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
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
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHovered ? Colors.orange : Colors.blueGrey,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    );
  }
}
