import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// The Graph View canvas: grid, wires, symbol nodes with ports, smart
/// guides, box-select rectangle, connection preview, and reconnect
/// handles (WORK_PACKAGE_021/022). A crosshair cursor is shown while a
/// connection drag is in progress (ENGINE-TASK-000096).
///
/// Promoted from the Demonstration Host into the Engine package itself
/// (WORK_PACKAGE_024) — it depends only on Engine data types
/// (`DiagramScene`, `ViewState`, `SymbolProvider`, ...) plus plain
/// callbacks, with zero Demonstration-Host-specific state, so both the
/// Demonstration Host and Diagram Studio consume this exact same class
/// rather than each maintaining their own copy of ~900 lines of canvas
/// painting code. This is the "Rendering model" half of the ownership
/// model's Engine column; only Studio-specific chrome (toolbars, panel
/// framing, property inspector) is re-authored per-host.
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

  // WORK_PACKAGE_023: annotations (ENGINE-TASK-000100).
  final List<DiagramAnnotation> annotations;
  final Set<String> selectedAnnotationIds;
  final void Function(String annotationId) onAnnotationTap;
  final void Function(String annotationId) onAnnotationDragStart;
  final void Function(Offset delta) onAnnotationDragUpdate;
  final VoidCallback onAnnotationDragEnd;
  final void Function(String annotationId) onAnnotationEditRequested;

  // WORK_PACKAGE_023: manual wire editing, "Edit Route" mode
  // (ENGINE-TASK-000099).
  final List<Point2D>? editingWirePoints;
  final int? editingWireSelectedVertex;
  final void Function(int index) onWireVertexTap;
  final void Function(int index) onWireCornerDragStart;
  final void Function(Offset delta) onWireCornerDragUpdate;
  final VoidCallback onWireCornerDragEnd;
  final void Function(int segmentIndex) onWireSegmentDragStart;
  final void Function(Offset delta) onWireSegmentDragUpdate;
  final VoidCallback onWireSegmentDragEnd;

  final void Function(String nodeId) onNodeTap;
  final void Function(String nodeId) onNodeDragStart;
  final void Function(Offset delta) onNodeDragUpdate;
  final VoidCallback onNodeDragEnd;
  final void Function(Offset localPosition) onBackgroundTap;

  /// Optional secondary-button (right-click) tap on the canvas.
  /// [Offset] #1 is the same already-scene-transformed local position
  /// [onBackgroundTap] receives (for hit-testing); #2 is the tap's
  /// screen-global position (for positioning a context menu, which
  /// `Offset` #1 cannot do on its own since it is relative to the
  /// `InteractiveViewer`'s panned/zoomed child, not the screen). `null`
  /// for any consumer that does not need contextual-menu targeting
  /// (this parameter is additive and optional specifically so the
  /// Demonstration Host, the other consumer of this widget, is
  /// unaffected).
  final void Function(Offset localPosition, Offset globalPosition)? onSecondaryTapUp;

  /// Optional secondary-button (right-click) tap landing directly on a
  /// node's body. `SymbolNodeWidget`'s own `GestureDetector` is
  /// `HitTestBehavior.opaque` and sits above the background gesture
  /// detector in the `Stack`, so it claims the hit-test path for any
  /// point over a node -- [onSecondaryTapUp] (wired to the background
  /// detector only) never fires for these. `null` for any consumer that
  /// does not need contextual-menu targeting.
  final void Function(String nodeId, Offset globalPosition)? onNodeSecondaryTapUp;

  final void Function(Offset localPosition) onBackgroundPanStart;
  final void Function(Offset localPosition, Offset delta) onBackgroundPanUpdate;
  final VoidCallback onBackgroundPanEnd;
  final void Function(Offset localPosition) onHover;

  final void Function(PortReference port) onPortHoverEnter;
  final VoidCallback onPortHoverExit;
  final void Function(PortReference port) onPortDragStart;
  final void Function(Offset delta) onPortDragUpdate;
  final VoidCallback onPortDragEnd;

  /// A plain, no-drag click on a port -- see `SymbolNodeWidget`'s own doc
  /// comment on its identically-named field for why this is distinct
  /// from [onPortDragStart]. Optional; existing callers are unaffected.
  final void Function(PortReference port)? onPortTap;

  /// A right-click (secondary-button tap) directly on a port marker
  /// (OEP Diagram Studio -- Phase 4, Part 4). `null` for any consumer
  /// that does not need contextual-menu targeting.
  final void Function(PortReference port, Offset globalPosition)? onPortSecondaryTapUp;

  /// A right-click (secondary-button tap) directly on an annotation
  /// (OEP Diagram Studio -- Phase 4, Part 6): reuses `AnnotationWidget`'s
  /// own real, already-rendered hit region (its `GestureDetector`,
  /// `HitTestBehavior.opaque`) -- not a separately computed
  /// approximation of its text-dependent bounds. `null` for any
  /// consumer that does not need contextual-menu targeting.
  final void Function(String annotationId, Offset globalPosition)? onAnnotationSecondaryTapUp;

  final void Function(bool isSourceEnd) onReconnectDragStart;
  final void Function(Offset delta) onReconnectDragUpdate;
  final VoidCallback onReconnectDragEnd;

  /// Called after a pinch/scroll zoom gesture completes, so the host can
  /// mirror the resulting transform back into `ViewState` (WP022: "ViewState
  /// owns viewport behavior").
  final VoidCallback onInteractionEnd;

  // AP-DS-001A: resize handles, shown only when [resizingNodeId] names a
  // single selected node.
  final String? resizingNodeId;
  final void Function(String nodeId, ResizeHandleKind handle) onNodeResizeStart;
  final void Function(Offset delta) onNodeResizeUpdate;
  final VoidCallback onNodeResizeEnd;

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
    required this.annotations,
    required this.selectedAnnotationIds,
    required this.onAnnotationTap,
    required this.onAnnotationDragStart,
    required this.onAnnotationDragUpdate,
    required this.onAnnotationDragEnd,
    required this.onAnnotationEditRequested,
    required this.editingWirePoints,
    required this.editingWireSelectedVertex,
    required this.onWireVertexTap,
    required this.onWireCornerDragStart,
    required this.onWireCornerDragUpdate,
    required this.onWireCornerDragEnd,
    required this.onWireSegmentDragStart,
    required this.onWireSegmentDragUpdate,
    required this.onWireSegmentDragEnd,
    required this.onNodeTap,
    required this.onNodeDragStart,
    required this.onNodeDragUpdate,
    required this.onNodeDragEnd,
    required this.onBackgroundTap,
    this.onSecondaryTapUp,
    this.onNodeSecondaryTapUp,
    required this.onBackgroundPanStart,
    required this.onBackgroundPanUpdate,
    required this.onBackgroundPanEnd,
    required this.onHover,
    required this.onPortHoverEnter,
    required this.onPortHoverExit,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
    this.onPortTap,
    this.onPortSecondaryTapUp,
    this.onAnnotationSecondaryTapUp,
    required this.onReconnectDragStart,
    required this.onReconnectDragUpdate,
    required this.onReconnectDragEnd,
    required this.onInteractionEnd,
    this.resizingNodeId,
    required this.onNodeResizeStart,
    required this.onNodeResizeUpdate,
    required this.onNodeResizeEnd,
  });

  /// The currently-visible scene-coordinate rect, inverting the
  /// `translate(pan)..scale(zoom)` transform this panel's host
  /// (`DiagramStudioPage._applyTransformFromViewState`) drives the
  /// `TransformationController` with: screen point `s = pan + zoom*p`,
  /// so `p = (s - pan) / zoom`. `null` before the first layout pass
  /// reports a real viewport size (`viewportWidth`/`Height` are 0), in
  /// which case culling is skipped entirely (nothing is off-screen yet
  /// to cull).
  Rect2D? _visibleSceneRect() {
    if (viewState.viewportWidth <= 0 || viewState.viewportHeight <= 0) return null;
    final zoom = viewState.zoom == 0 ? 1.0 : viewState.zoom;
    return Rect2D(
      left: -viewState.pan.dx / zoom,
      top: -viewState.pan.dy / zoom,
      right: (viewState.viewportWidth - viewState.pan.dx) / zoom,
      bottom: (viewState.viewportHeight - viewState.pan.dy) / zoom,
    );
  }

  bool _intersects(Rect2D visible, double left, double top, double width, double height, double margin) {
    return left + width >= visible.left - margin &&
        left <= visible.right + margin &&
        top + height >= visible.top - margin &&
        top <= visible.bottom + margin;
  }

  @override
  Widget build(BuildContext context) {
    final isConnecting = connectionPreviewFrom != null;
    // Viewport culling (AP-DS-001A / PERFORMANCE_TARGETS.md): skip nodes
    // and annotations whose bounds don't intersect the visible viewport
    // rect before building their widgets, so a large diagram's off-screen
    // content costs nothing per frame. A generous margin (one node's
    // worth of scene units) avoids pop-in at the viewport edge during a
    // fast pan.
    //
    // Wire culling (AP-DS-001B): AP-DS-001A's note here claimed
    // "`WirePainter` (unaudited here) may itself already clip per-segment
    // during paint" — that was speculative and turned out false.
    // `WirePainter.paint()` unconditionally iterates and draws every wire
    // in the list it's given every repaint, with no per-segment clip.
    // Benchmarked directly (`test/performance/rendering_performance_test.dart`,
    // "WirePainter.paint() cost" group) against a real `Canvas`: ~179ms to
    // paint 40,000 wires unculled at a 100,000-object synthetic diagram —
    // roughly 10x a single frame's 16ms budget, and the single largest
    // rendering cost measured in this phase, well above the culled
    // node/annotation widget-tree build cost at the same object count.
    // So wires now get the same bounding-box viewport cull as
    // nodes/annotations before being handed to `WirePainter`.
    final visibleRect = _visibleSceneRect();
    const cullMargin = 200.0;
    bool nodeVisible(DiagramNodeVisual node) =>
        visibleRect == null ||
        _intersects(visibleRect, node.position.dx, node.position.dy, node.width, node.height, cullMargin);
    bool annotationVisible(DiagramAnnotation annotation) =>
        visibleRect == null ||
        _intersects(visibleRect, annotation.position.dx, annotation.position.dy, 160, 80, cullMargin);
    bool wireVisible(DiagramWireVisual wire) {
      if (visibleRect == null) return true;
      if (wire.points.isEmpty) return false;
      var left = wire.points.first.dx, right = wire.points.first.dx;
      var top = wire.points.first.dy, bottom = wire.points.first.dy;
      for (final point in wire.points) {
        if (point.dx < left) left = point.dx;
        if (point.dx > right) right = point.dx;
        if (point.dy < top) top = point.dy;
        if (point.dy > bottom) bottom = point.dy;
      }
      return _intersects(visibleRect, left, top, right - left, bottom - top, cullMargin);
    }
    final visibleNodes = scene.nodes.where(nodeVisible).toList();
    final visibleAnnotations = annotations.where(annotationVisible).toList();
    final visibleWires = scene.wires.where(wireVisible).toList();
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
                    child: RepaintBoundary(
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
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => onBackgroundTap(details.localPosition),
                    onSecondaryTapUp: onSecondaryTapUp == null
                        ? null
                        : (details) => onSecondaryTapUp!(details.localPosition, details.globalPosition),
                    onPanStart: (details) => onBackgroundPanStart(details.localPosition),
                    onPanUpdate: (details) =>
                        onBackgroundPanUpdate(details.localPosition, details.delta),
                    onPanEnd: (_) => onBackgroundPanEnd(),
                    child: RepaintBoundary(child: CustomPaint(painter: WirePainter(visibleWires))),
                  ),
                ),
                if (viewState.guidesVisible && guides.isNotEmpty)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: GuidesPainter(
                          guides,
                          width: scene.contentWidth,
                          height: scene.contentHeight,
                        ),
                      ),
                    ),
                  ),
                for (final node in visibleNodes)
                  Positioned(
                    key: ValueKey('node-${node.nodeId}'),
                    // Inflated by `kNodeHitMargin` on every side (and
                    // shifted so the node's on-screen position/size is
                    // unchanged) -- `SymbolNodeWidget` positions its
                    // card/label/ports inward by the same margin. See
                    // `kNodeHitMargin`'s doc comment for why: an
                    // edge-exit port's marker, centered exactly on
                    // `node.width`/`node.height`'s boundary, otherwise
                    // fell just outside Flutter's `Size.contains()`
                    // (half-open interval), silently losing the tap to
                    // whatever was behind the node.
                    left: node.position.dx - kNodeHitMargin,
                    top: node.position.dy - kNodeHitMargin,
                    width: node.width + kNodeHitMargin * 2,
                    height: node.height + kNodeHitMargin * 2,
                    child: RepaintBoundary(
                      child: SymbolNodeWidget(
                        node: node,
                        ports: _portsFor(node, symbols),
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
                        onPortTap: onPortTap,
                        onPortSecondaryTapUp: onPortSecondaryTapUp,
                        onSecondaryTapUp: onNodeSecondaryTapUp == null
                            ? null
                            : (globalPosition) => onNodeSecondaryTapUp!(node.nodeId, globalPosition),
                      ),
                    ),
                  ),
                for (final annotation in visibleAnnotations)
                  // AP-DS-001B fix: no outer RepaintBoundary here.
                  // AnnotationWidget.build() returns a Positioned, which
                  // must be a direct Stack child — wrapping it in
                  // RepaintBoundary at this call site (as AP-DS-001A did)
                  // interposes a RenderObject between Stack and Positioned
                  // and throws "Incorrect use of ParentDataWidget" at
                  // runtime for every annotation. AnnotationWidget now
                  // places its own RepaintBoundary *inside* the Positioned
                  // it returns, preserving the intended repaint isolation.
                  AnnotationWidget(
                    key: ValueKey('annotation-${annotation.id}'),
                    annotation: annotation,
                    selected: selectedAnnotationIds.contains(annotation.id),
                    onTap: () => onAnnotationTap(annotation.id),
                    onDragStart: () => onAnnotationDragStart(annotation.id),
                    onDragUpdate: onAnnotationDragUpdate,
                    onDragEnd: onAnnotationDragEnd,
                    onEditRequested: () => onAnnotationEditRequested(annotation.id),
                    onSecondaryTapUp: onAnnotationSecondaryTapUp == null
                        ? null
                        : (globalPosition) => onAnnotationSecondaryTapUp!(annotation.id, globalPosition),
                  ),
                if (resizingNodeId != null)
                  for (final node in scene.nodes)
                    if (node.nodeId == resizingNodeId)
                      ResizeHandles(
                        position: Offset(node.position.dx, node.position.dy),
                        size: Size(node.width, node.height),
                        onDragStart: (handle) => onNodeResizeStart(node.nodeId, handle),
                        onDragUpdate: onNodeResizeUpdate,
                        onDragEnd: onNodeResizeEnd,
                      ),
                if (editingWirePoints != null && editingWirePoints!.length >= 2)
                  WireEditHandles(
                    points: editingWirePoints!,
                    selectedVertexIndex: editingWireSelectedVertex,
                    onVertexTap: onWireVertexTap,
                    onCornerDragStart: onWireCornerDragStart,
                    onCornerDragUpdate: onWireCornerDragUpdate,
                    onCornerDragEnd: onWireCornerDragEnd,
                    onSegmentDragStart: onWireSegmentDragStart,
                    onSegmentDragUpdate: onWireSegmentDragUpdate,
                    onSegmentDragEnd: onWireSegmentDragEnd,
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
                  // `IgnorePointer`: a bare `CustomPaint`'s default
                  // `CustomPainter.hitTest()` returns null, which
                  // `RenderCustomPaint` treats as "hit" (opaque) --
                  // without this, this full-canvas preview line (shown
                  // while a connection is pending, i.e. exactly during
                  // both the drag-to-connect AND two-click Wire-mode
                  // flows) silently absorbed every pointer event over
                  // the entire diagram, including the second port tap
                  // that's supposed to complete the connection.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ConnectionPreviewPainter(
                          from: connectionPreviewFrom!,
                          to: connectionPreviewTo!,
                          valid: connectionPreviewValid,
                        ),
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

  /// (Phase 14 -- UI Layout Ratification.) Prefers the visual Symbol's
  /// own authored port geometry (`SymbolPort`, positioned by an actual
  /// artist) when one resolves with real ports. When it doesn't --
  /// `node.symbolId` is `null`, or points to a symbol with no port
  /// geometry authored -- falls back to [fallbackPorts], the SAME
  /// real-port-derived geometry `diagram_view.dart`'s wire-endpoint
  /// anchoring and `diagram_studio_page.dart`'s drag-to-connect anchor
  /// both use, respecting `node.metadata['exit']` (which edge ports sit
  /// on) so pins/wires/drag-anchors always agree.
  static List<SymbolPort> _portsFor(DiagramNodeVisual node, SymbolProvider symbols) {
    final resolved = symbols.resolve(node.symbolId ?? '').ports;
    if (resolved.isNotEmpty) return resolved;
    return fallbackPorts(node.ports, exit: (node.metadata['exit'] as String?) ?? 'down');
  }
}
