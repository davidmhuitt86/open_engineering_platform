import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../geometry_utils.dart';
import '../wire_painter.dart';
import 'connection_preview_painter.dart';
import 'grid_painter.dart';
import 'guides_painter.dart';
import 'origin_indicator.dart';
import 'reconnect_handle.dart';
import 'symbol_node_widget.dart';

/// The Graph View canvas: grid, wires, symbol nodes with ports, smart
/// guides, box-select rectangle, connection preview, and reconnect
/// handles (WORK_PACKAGE_021/022). A crosshair cursor is shown while a
/// connection drag is in progress (ENGINE-TASK-000096).
class GraphViewPanel extends StatelessWidget {
  final DiagramScene scene;
  final ViewState viewState;
  final SymbolProvider symbols;
  final List<AlignmentGuide> guides;
  final Rect2D? boxSelectRect;
  final TransformationController transformController;

  final Point2D? connectionPreviewFrom;
  final Point2D? connectionPreviewTo;
  final bool connectionPreviewValid;

  final DiagramWireVisual? reconnectingWire;

  final void Function(String nodeId) onNodeTap;
  final void Function(String nodeId) onNodeDragStart;
  final void Function(Offset delta) onNodeDragUpdate;
  final VoidCallback onNodeDragEnd;
  final VoidCallback onBackgroundTap;
  final void Function(Offset localPosition) onBackgroundPanStart;
  final void Function(Offset localPosition, Offset delta) onBackgroundPanUpdate;
  final VoidCallback onBackgroundPanEnd;
  final void Function(Offset localPosition) onHover;

  final void Function(PortReference port) onPortHoverEnter;
  final VoidCallback onPortHoverExit;
  final void Function(PortReference port) onPortDragStart;
  final void Function(Offset delta) onPortDragUpdate;
  final VoidCallback onPortDragEnd;

  final void Function(bool isSourceEnd) onReconnectDragStart;
  final void Function(Offset delta) onReconnectDragUpdate;
  final VoidCallback onReconnectDragEnd;

  /// Called after a pinch/scroll zoom gesture completes, so the host can
  /// mirror the resulting transform back into `ViewState` (WP022: "ViewState
  /// owns viewport behavior").
  final VoidCallback onInteractionEnd;

  const GraphViewPanel({
    super.key,
    required this.scene,
    required this.viewState,
    required this.symbols,
    required this.guides,
    required this.boxSelectRect,
    required this.transformController,
    required this.connectionPreviewFrom,
    required this.connectionPreviewTo,
    required this.connectionPreviewValid,
    required this.reconnectingWire,
    required this.onNodeTap,
    required this.onNodeDragStart,
    required this.onNodeDragUpdate,
    required this.onNodeDragEnd,
    required this.onBackgroundTap,
    required this.onBackgroundPanStart,
    required this.onBackgroundPanUpdate,
    required this.onBackgroundPanEnd,
    required this.onHover,
    required this.onPortHoverEnter,
    required this.onPortHoverExit,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
    required this.onReconnectDragStart,
    required this.onReconnectDragUpdate,
    required this.onReconnectDragEnd,
    required this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isConnecting = connectionPreviewFrom != null;
    return MouseRegion(
      cursor: isConnecting ? SystemMouseCursors.precise : MouseCursor.defer,
      onHover: (event) => onHover(event.localPosition),
      child: ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: InteractiveViewer(
          transformationController: transformController,
          minScale: 0.25,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(400),
          constrained: false,
          panEnabled: false,
          onInteractionEnd: (_) => onInteractionEnd(),
          child: SizedBox(
            width: scene.contentWidth,
            height: scene.contentHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const OriginIndicator(),
                if (viewState.grid.visible)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridPainter(
                        GridComputer.computeLines(
                          viewState.grid,
                          Rect2D(left: 0, top: 0, right: scene.contentWidth, bottom: scene.contentHeight),
                        ),
                        width: scene.contentWidth,
                        height: scene.contentHeight,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBackgroundTap,
                    onPanStart: (details) => onBackgroundPanStart(details.localPosition),
                    onPanUpdate: (details) =>
                        onBackgroundPanUpdate(details.localPosition, details.delta),
                    onPanEnd: (_) => onBackgroundPanEnd(),
                    child: CustomPaint(painter: WirePainter(scene.wires)),
                  ),
                ),
                if (viewState.guidesVisible && guides.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GuidesPainter(
                        guides,
                        width: scene.contentWidth,
                        height: scene.contentHeight,
                      ),
                    ),
                  ),
                for (final node in scene.nodes)
                  Positioned(
                    left: node.position.dx,
                    top: node.position.dy,
                    width: node.width,
                    height: node.height,
                    child: SymbolNodeWidget(
                      node: node,
                      ports: symbols.resolve(node.symbolId ?? '').ports,
                      hoveredPort: viewState.hoveredPort,
                      onTap: () => onNodeTap(node.nodeId),
                      onDragStart: () => onNodeDragStart(node.nodeId),
                      onDragUpdate: onNodeDragUpdate,
                      onDragEnd: onNodeDragEnd,
                      onPortHoverEnter: onPortHoverEnter,
                      onPortHoverExit: onPortHoverExit,
                      onPortDragStart: onPortDragStart,
                      onPortDragUpdate: onPortDragUpdate,
                      onPortDragEnd: onPortDragEnd,
                    ),
                  ),
                if (reconnectingWire != null && reconnectingWire!.points.length >= 2) ...[
                  ReconnectHandle(
                    position: reconnectingWire!.points.first,
                    isSourceEnd: true,
                    onDragStart: onReconnectDragStart,
                    onDragUpdate: onReconnectDragUpdate,
                    onDragEnd: onReconnectDragEnd,
                  ),
                  ReconnectHandle(
                    position: reconnectingWire!.points.last,
                    isSourceEnd: false,
                    onDragStart: onReconnectDragStart,
                    onDragUpdate: onReconnectDragUpdate,
                    onDragEnd: onReconnectDragEnd,
                  ),
                ],
                if (connectionPreviewFrom != null && connectionPreviewTo != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ConnectionPreviewPainter(
                        from: connectionPreviewFrom!,
                        to: connectionPreviewTo!,
                        valid: connectionPreviewValid,
                      ),
                    ),
                  ),
                if (boxSelectRect != null)
                  Positioned.fromRect(
                    rect: rect2DToRect(boxSelectRect!),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.blue),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
