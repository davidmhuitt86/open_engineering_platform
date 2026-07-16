import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'dialogs/layer_panel_dialog.dart';
import 'dialogs/search_panel_dialog.dart';
import 'seed_graph.dart';
import 'symbol_bundle_loader.dart';
import 'widgets/inspector_panels.dart';
import 'widgets/rulers.dart';
import 'widgets/secondary_toolbar.dart';
import 'widgets/status_bar.dart';
import 'widgets/toolbar.dart';

/// Engineering Engine Demonstration Host.
///
/// This is NOT Diagram Studio. As of WORK_PACKAGE_024, Diagram Studio is
/// a real, shipping production workspace in `oep_studio`
/// (`lib/diagram_studio/`) — this app's role is now formally narrowed to
/// regression testing, architectural validation, and Engine development
/// support only (see `docs/ARCHITECTURE_DECISIONS.md` ADR-023). It is
/// never the primary user experience and is not evolved for end-user
/// polish; new user-facing capability belongs in Diagram Studio, calling
/// straight into this same public API
/// (`package:engineering_engine/engineering_engine.dart`). This app
/// still consumes ONLY that public API, and its own canvas-rendering
/// widgets (`GraphViewPanel` and friends) were promoted into
/// `lib/views/widgets/` in WORK_PACKAGE_024 specifically so Diagram
/// Studio reuses them rather than duplicating them — this Demonstration
/// Host and Diagram Studio render `DiagramScene`/`ViewState` through the
/// exact same classes.
///
/// WORK_PACKAGE_022 adds the professional editing environment around the
/// WP021 command/selection/clipboard/routing foundation: grid/snap,
/// smart alignment guides, named layout persistence, port hover/drag-to-
/// connect/drag-to-reconnect, fit-all/fit-selection/center/zoom-to-cursor
/// navigation, and drafting-tool polish (rulers, origin indicator,
/// coordinate readout). ViewState (zoom/pan/grid/guides/theme) is a
/// permanently separate runtime concern from the Engineering Graph and
/// Diagram Layout — see docs/ARCHITECTURE_DECISIONS.md ADR-014.
void main() {
  runApp(const DemonstrationHostApp());
}

class DemonstrationHostApp extends StatelessWidget {
  const DemonstrationHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engineering Engine — Demonstration Host',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HostShell(),
    );
  }
}

const double _defaultNodeSpawnStep = 40;
const double _nodeSize = 100; // DiagramLayout.nodeSize, mirrored for hit-testing.

class HostShell extends StatefulWidget {
  const HostShell({super.key});

  @override
  State<HostShell> createState() => _HostShellState();
}

class _HostShellState extends State<HostShell> {
  late final EngineeringEngine engine;
  final TransformationController transformController = TransformationController();

  EditingSession? session;
  ValidationReport? report;
  GraphSelection selection = GraphSelection.empty;
  FocusState focus = const FocusState.none();
  ViewState viewState = ViewState.initial;
  bool loading = true;
  int _spawnCounter = 0;

  Set<String> _highlightedNodeIds = {};
  Set<String> _highlightedRelationshipIds = {};

  Rect2D? _boxSelectRect;
  Offset? _boxSelectStart;
  Point2D? _panStartPan;

  Set<String>? _dragNodeIds;
  Map<String, Point2D>? _dragStartPositions;
  Point2D _dragTotalDelta = const Point2D(0, 0);
  List<AlignmentGuide> _activeGuides = const [];

  Point2D? _cursorScenePosition;

  PortReference? _connectFromPort;
  Point2D? _connectionCurrentPoint;
  bool _connectionValid = false;

  String? _reconnectRelationshipId;
  bool _reconnectIsSourceEnd = false;
  Point2D? _reconnectCurrentPoint;

  double _explorerWidth = 220;
  double _inspectorWidth = 320;

  // WORK_PACKAGE_023: annotation drag state (ENGINE-TASK-000100).
  String? _draggingAnnotationId;
  Point2D? _annotationDragStartPosition;
  Point2D _annotationDragTotalDelta = const Point2D(0, 0);

  // WORK_PACKAGE_023: "Edit Route" mode (ENGINE-TASK-000099).
  bool _wireEditModeActive = false;
  List<Point2D>? _wireEditWorkingPoints;
  int? _wireEditSelectedVertex;
  int? _wireDragCornerIndex;
  int? _wireDragSegmentIndex;
  List<Point2D>? _wireDragBasePoints;
  Point2D _wireDragTotalDelta = const Point2D(0, 0);

  StreamSubscription<EditingSession>? _sessionSub;
  StreamSubscription<GraphSelection>? _selectionSub;
  StreamSubscription<FocusState>? _focusSub;
  StreamSubscription<NavigationEvent>? _navigationSub;
  StreamSubscription<ViewState>? _viewStateSub;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    engine = EngineeringEngine.create();
    await engine.initialize();
    await loadBundledSymbols(engine.registry.symbols as SymbolLibrary);

    final seeded = buildSeedGraph();
    engine.beginEditingSession(seeded);

    _sessionSub = engine.editing.sessionChanges.listen((s) {
      setState(() {
        session = s;
        report = engine.validate(s.graph);
      });
    });
    _selectionSub = engine.registry.selection.changes.listen((s) {
      setState(() => selection = s);
      if (_wireEditModeActive) _reseedWireEditPoints();
    });
    _focusSub = engine.registry.selection.focusChanges.listen((f) {
      setState(() => focus = f);
    });
    _navigationSub = engine.registry.navigation.events.listen(_onNavigationEvent);
    _viewStateSub = engine.registry.viewState.changes.listen((v) {
      setState(() => viewState = v);
      _applyViewStateToTransform();
    });

    setState(() {
      session = engine.editing.session;
      report = engine.validate(session!.graph);
      viewState = engine.registry.viewState.current;
      loading = false;
    });
  }

  void _onNavigationEvent(NavigationEvent event) {
    setState(() {
      switch (event.kind) {
        case NavigationEventKind.highlightPath:
          _highlightedNodeIds = event.highlightedNodeIds.toSet();
          _highlightedRelationshipIds = event.highlightedRelationshipIds.toSet();
        case NavigationEventKind.clearHighlight:
          _highlightedNodeIds = {};
          _highlightedRelationshipIds = {};
        case NavigationEventKind.focusNode:
        case NavigationEventKind.evidenceSync:
          break;
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _selectionSub?.cancel();
    _focusSub?.cancel();
    _navigationSub?.cancel();
    _viewStateSub?.cancel();
    unawaited(engine.shutdown());
    super.dispose();
  }

  // --- ViewState / viewport --------------------------------------------

  ViewStateService get _viewStateService => engine.registry.viewState as ViewStateService;

  void _applyViewStateToTransform() {
    transformController.value = Matrix4.identity()
      ..translateByDouble(viewState.pan.dx, viewState.pan.dy, 0, 1)
      ..scaleByDouble(viewState.zoom, viewState.zoom, viewState.zoom, 1);
  }

  void _syncViewStateFromTransform() {
    final matrix = transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    _viewStateService
      ..setZoom(scale)
      ..setPan(Point2D(translation.x, translation.y));
  }

  void _ensureViewportSize(double width, double height) {
    if (viewState.viewportWidth == width && viewState.viewportHeight == height) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewStateService.setViewportSize(width, height);
    });
  }

  Rect2D? _selectionBounds(DiagramScene scene) {
    final selected = scene.nodes.where((n) => selection.containsNode(n.nodeId)).toList();
    if (selected.isEmpty) return null;
    var left = selected.first.position.dx;
    var top = selected.first.position.dy;
    var right = left + selected.first.width;
    var bottom = top + selected.first.height;
    for (final node in selected.skip(1)) {
      left = left < node.position.dx ? left : node.position.dx;
      top = top < node.position.dy ? top : node.position.dy;
      right = right > node.position.dx + node.width ? right : node.position.dx + node.width;
      bottom = bottom > node.position.dy + node.height ? bottom : node.position.dy + node.height;
    }
    return Rect2D(left: left, top: top, right: right, bottom: bottom);
  }

  void _fitAll(DiagramScene scene) {
    _viewStateService.fitAll(scene.contentWidth, scene.contentHeight);
  }

  void _fitSelection(DiagramScene scene) {
    final bounds = _selectionBounds(scene);
    if (bounds != null) _viewStateService.fitSelection(bounds);
  }

  void _centerSelection(DiagramScene scene) {
    final bounds = _selectionBounds(scene);
    if (bounds != null) _viewStateService.centerSelection(bounds);
  }

  // --- Editing actions -----------------------------------------------

  void _addNode(String symbolId) {
    final symbol = engine.registry.symbols.resolve(symbolId);
    _spawnCounter++;
    final id = engine.graph.generateId('node');
    final node = EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: symbol.name,
      symbolId: symbolId,
    );
    final position = Point2D(
      40 + (_spawnCounter % 6) * _defaultNodeSpawnStep,
      40 + (_spawnCounter ~/ 6) * _defaultNodeSpawnStep,
    );
    engine.editing.execute(CreateNodeCommand(node, position: position));
    engine.registry.selection.selectNode(id);
  }

  void _deleteSelection() {
    if (selection.isEmpty) return;
    engine.editing.execute(DeleteManyCommand(
      nodeIds: selection.nodeIds,
      relationshipIds: selection.relationshipIds,
      groupIds: selection.groupIds,
      annotationIds: selection.annotationIds,
    ));
    engine.registry.selection.deselectAll();
  }

  void _groupSelection() {
    if (selection.nodeIds.length < 2) return;
    final group = EngineeringGroup(
      id: engine.graph.generateId('group'),
      kind: GroupKind.other,
      displayName: 'Group',
      memberNodeIds: selection.nodeIds.toList(),
    );
    engine.editing.execute(CreateGroupCommand(group));
    engine.registry.selection.selectGroup(group.id);
  }

  void _ungroupSelection() {
    for (final groupId in selection.groupIds.toList()) {
      engine.editing.execute(UngroupCommand(groupId));
    }
    engine.registry.selection.deselectAll();
  }

  void _copy() => engine.clipboard.copy(session!, selection);

  void _cut() {
    if (selection.isEmpty) return;
    final command = engine.clipboard.cut(session!, selection);
    engine.editing.execute(command);
    engine.registry.selection.deselectAll();
  }

  void _paste() {
    final command = engine.clipboard.paste();
    if (command == null) return;
    engine.editing.execute(command);
    engine.registry.selection.selectMany(nodeIds: command.pastedNodeIds.toSet());
  }

  void _duplicateSelection() {
    if (selection.isEmpty) return;
    final command = engine.clipboard.duplicate(selection);
    engine.editing.execute(command);
    engine.registry.selection.selectMany(nodeIds: command.duplicatedNodeIds.toSet());
  }

  void _undo() => engine.editing.undo();
  void _redo() => engine.editing.redo();

  void _align(AlignmentMode mode) {
    if (selection.nodeIds.length < 2) return;
    engine.editing.execute(AlignNodesCommand(selection.nodeIds, mode));
  }

  void _distribute(DistributionAxis axis) {
    if (selection.nodeIds.length < 3) return;
    engine.editing.execute(DistributeNodesCommand(selection.nodeIds, axis));
  }

  void _highlightBatteryToGround() {
    final current = session;
    if (current == null) return;
    (engine.registry.navigation as NavigationService)
        .highlightPathBetween(current.graph, 'battery', 'ground');
  }

  void _clearHighlight() => engine.registry.navigation.clearHighlight();

  // --- Selection interaction ------------------------------------------

  bool get _additiveModifierPressed =>
      HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed;

  bool get _toggleModifierPressed => HardwareKeyboard.instance.isControlPressed;

  bool get _spacePressed => HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);

  void _handleNodeTap(String nodeId) {
    if (_toggleModifierPressed) {
      engine.registry.selection.toggleNode(nodeId);
    } else if (_additiveModifierPressed) {
      engine.registry.selection.selectNode(nodeId, additive: true);
    } else {
      engine.registry.selection.selectNode(nodeId);
    }
  }

  // WORK_PACKAGE_023: clicking near a wire selects its relationship —
  // without this, a relationship could never be selected via the canvas,
  // making "Edit Route" mode (ENGINE-TASK-000099) unreachable.
  void _handleBackgroundTap(Offset localPosition, DiagramScene scene) {
    final relationshipId =
        DiagramHitTesting.relationshipAt(scene, offsetToPoint(localPosition));
    if (relationshipId != null) {
      if (_toggleModifierPressed) {
        engine.registry.selection.toggleRelationship(relationshipId);
      } else {
        engine.registry.selection.selectRelationship(relationshipId);
      }
      return;
    }
    if (!_additiveModifierPressed) {
      engine.registry.selection.deselectAll();
    }
  }

  // Space+drag pans the viewport (mirrors the reference implementation's
  // own convention — see docs/EKE_INTERACTION_MODEL.md); a plain drag on
  // empty space performs box selection (Marquee Selection).
  void _handleBackgroundPanStart(Offset localPosition) {
    if (_spacePressed) {
      _panStartPan = viewState.pan;
      return;
    }
    _boxSelectStart = localPosition;
    setState(() => _boxSelectRect = Rect2D.fromPoints(
          offsetToPoint(localPosition),
          offsetToPoint(localPosition),
        ));
  }

  void _handleBackgroundPanUpdate(Offset localPosition, Offset delta) {
    if (_panStartPan != null) {
      // Panning: `delta` is already scene-space (see `_SymbolNode` drag
      // for the same behavior), but the viewport's pan is screen-space —
      // scale by the current zoom so a scene-space drag produces the
      // correct screen-space translation.
      _viewStateService.setPan(viewState.pan.translate(
        delta.dx * viewState.zoom,
        delta.dy * viewState.zoom,
      ));
      return;
    }
    final start = _boxSelectStart;
    if (start == null) return;
    setState(() => _boxSelectRect = rectFromOffsets(start, localPosition));
  }

  void _handleBackgroundPanEnd(DiagramScene scene) {
    if (_panStartPan != null) {
      _panStartPan = null;
      return;
    }
    final rect = _boxSelectRect;
    if (rect != null) {
      final ids = DiagramHitTesting.nodesInRect(scene, rect);
      if (ids.isNotEmpty) {
        engine.registry.selection.selectMany(nodeIds: ids, additive: _additiveModifierPressed);
      }
    }
    setState(() {
      _boxSelectRect = null;
      _boxSelectStart = null;
    });
  }

  void _handleHover(Offset localPosition) {
    _cursorScenePosition = offsetToPoint(localPosition);
    if (_connectFromPort != null || _reconnectRelationshipId != null) return;
    // Coordinate readout updates every frame; throttling isn't critical at
    // Demonstration Host scale.
    setState(() {});
  }

  // --- Node dragging + smart guides ------------------------------------

  List<Rect2D> _siblingBounds(String excludingNodeId) {
    final layout = session!.layout;
    return [
      for (final entry in session!.graph.nodes.entries)
        if (entry.key != excludingNodeId && layout.positionOf(entry.key) != null)
          Rect2D(
            left: layout.positionOf(entry.key)!.dx,
            top: layout.positionOf(entry.key)!.dy,
            right: layout.positionOf(entry.key)!.dx + _nodeSize,
            bottom: layout.positionOf(entry.key)!.dy + _nodeSize,
          ),
    ];
  }

  void _handleNodeDragStart(String nodeId) {
    final current = session;
    if (current == null) return;
    final targets = (selection.nodeIds.contains(nodeId) && selection.nodeIds.length > 1)
        ? selection.nodeIds
        : {nodeId};
    if (!selection.nodeIds.contains(nodeId)) {
      engine.registry.selection.selectNode(nodeId);
    }
    setState(() {
      _dragNodeIds = targets;
      _dragStartPositions = {
        for (final id in targets) id: current.layout.positionOf(id) ?? const Point2D(0, 0),
      };
      _dragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleNodeDragUpdate(Offset delta) {
    if (_dragNodeIds == null) return;
    setState(() {
      _dragTotalDelta = _dragTotalDelta.translate(delta.dx, delta.dy);
      if (_dragNodeIds!.length == 1 && viewState.guidesVisible) {
        final id = _dragNodeIds!.first;
        final candidate = _dragStartPositions![id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy);
        final bounds = Rect2D(
          left: candidate.dx,
          top: candidate.dy,
          right: candidate.dx + _nodeSize,
          bottom: candidate.dy + _nodeSize,
        );
        _activeGuides = AlignmentGuideComputer.computeGuides(
          draggedBounds: bounds,
          siblingBounds: _siblingBounds(id),
        );
      } else {
        _activeGuides = const [];
      }
    });
  }

  Point2D _snappedDragPosition(String nodeId, Point2D raw) {
    var result = raw;
    if (viewState.guidesVisible && _dragNodeIds?.length == 1) {
      result = AlignmentGuideComputer.snapToGuides(
        candidatePosition: result,
        width: _nodeSize,
        height: _nodeSize,
        siblingBounds: _siblingBounds(nodeId),
      );
    }
    return GridComputer.snap(result, viewState.grid);
  }

  void _handleNodeDragEnd() {
    final nodeIds = _dragNodeIds;
    final startPositions = _dragStartPositions;
    if (nodeIds == null || startPositions == null) return;
    final newPositions = {
      for (final id in nodeIds)
        id: _snappedDragPosition(id, startPositions[id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy)),
    };
    engine.editing.execute(MoveNodesCommand(newPositions));
    setState(() {
      _dragNodeIds = null;
      _dragStartPositions = null;
      _dragTotalDelta = const Point2D(0, 0);
      _activeGuides = const [];
    });
  }

  DiagramLayoutState _effectiveLayout() {
    final current = session!;
    if (_dragNodeIds == null || _dragStartPositions == null) return current.layout;
    final preview = {
      for (final id in _dragNodeIds!)
        id: _snappedDragPosition(id, _dragStartPositions![id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy)),
    };
    return current.layout.withPositions(preview);
  }

  // --- Port interaction / drag-to-connect ------------------------------

  Point2D? _portAnchor(PortReference port) {
    final node = session!.graph.nodes[port.nodeId];
    final position = session!.layout.positionOf(port.nodeId);
    if (node == null || position == null) return null;
    final symbol = engine.registry.symbols.resolve(node.symbolId ?? '');
    final match = symbol.ports.where((p) => p.id == port.portId);
    if (match.isEmpty) return position.translate(_nodeSize / 2, _nodeSize / 2);
    final p = match.first;
    return position.translate(p.x * _nodeSize, p.y * _nodeSize);
  }

  String? _nodeAt(Point2D point) {
    for (final entry in session!.layout.positions.entries) {
      final within = point.dx >= entry.value.dx &&
          point.dx <= entry.value.dx + _nodeSize &&
          point.dy >= entry.value.dy &&
          point.dy <= entry.value.dy + _nodeSize;
      if (within) return entry.key;
    }
    return null;
  }

  void _handlePortHoverEnter(PortReference port) => _viewStateService.hoverPort(port);
  void _handlePortHoverExit() => _viewStateService.hoverPort(null);

  void _handlePortDragStart(PortReference port) {
    setState(() {
      _connectFromPort = port;
      _connectionCurrentPoint = _portAnchor(port);
      _connectionValid = false;
    });
  }

  void _handlePortDragUpdate(Offset delta) {
    if (_connectionCurrentPoint == null) return;
    setState(() {
      _connectionCurrentPoint = _connectionCurrentPoint!.translate(delta.dx, delta.dy);
      final targetNodeId = _nodeAt(_connectionCurrentPoint!);
      _connectionValid = targetNodeId != null &&
          ConnectionValidator.canConnect(session!.graph, _connectFromPort!.nodeId, targetNodeId);
    });
  }

  void _handlePortDragEnd() {
    final source = _connectFromPort;
    final point = _connectionCurrentPoint;
    if (source != null && point != null) {
      final targetNodeId = _nodeAt(point);
      if (targetNodeId != null && ConnectionValidator.canConnect(session!.graph, source.nodeId, targetNodeId)) {
        engine.editing.execute(CreateRelationshipCommand(EngineeringRelationship(
          id: engine.graph.generateId('rel'),
          relationshipType: RelationshipType.connectedTo,
          sourceNode: source.nodeId,
          targetNode: targetNodeId,
        )));
      }
    }
    setState(() {
      _connectFromPort = null;
      _connectionCurrentPoint = null;
      _connectionValid = false;
    });
  }

  // --- Drag-to-reconnect ------------------------------------------------

  DiagramWireVisual? _reconnectingWire(DiagramScene scene) {
    if (selection.relationshipIds.length != 1) return null;
    final id = selection.relationshipIds.first;
    for (final wire in scene.wires) {
      if (wire.relationshipId == id) return wire;
    }
    return null;
  }

  void _handleReconnectDragStart(bool isSourceEnd) {
    final relationshipId = selection.relationshipIds.single;
    final relationship = session!.graph.relationships[relationshipId]!;
    final anchorNodeId = isSourceEnd ? relationship.sourceNode : relationship.targetNode;
    final position = session!.layout.positionOf(anchorNodeId) ?? const Point2D(0, 0);
    setState(() {
      _reconnectRelationshipId = relationshipId;
      _reconnectIsSourceEnd = isSourceEnd;
      _reconnectCurrentPoint = position.translate(_nodeSize / 2, _nodeSize / 2);
    });
  }

  void _handleReconnectDragUpdate(Offset delta) {
    if (_reconnectCurrentPoint == null) return;
    setState(() => _reconnectCurrentPoint = _reconnectCurrentPoint!.translate(delta.dx, delta.dy));
  }

  void _handleReconnectDragEnd() {
    final relationshipId = _reconnectRelationshipId;
    final point = _reconnectCurrentPoint;
    if (relationshipId != null && point != null) {
      final targetNodeId = _nodeAt(point);
      if (targetNodeId != null) {
        engine.editing.execute(ReconnectRelationshipCommand(
          relationshipId,
          newSourceNode: _reconnectIsSourceEnd ? targetNodeId : null,
          newTargetNode: _reconnectIsSourceEnd ? null : targetNodeId,
        ));
      }
    }
    setState(() {
      _reconnectRelationshipId = null;
      _reconnectCurrentPoint = null;
    });
  }

  // --- Annotations (ENGINE-TASK-000100) --------------------------------

  List<DiagramAnnotation> _effectiveAnnotations() {
    final annotations = session!.layout.annotations.values.toList();
    final draggingId = _draggingAnnotationId;
    final start = _annotationDragStartPosition;
    if (draggingId == null || start == null) return annotations;
    return [
      for (final a in annotations)
        if (a.id == draggingId)
          a.copyWith(
              position: start.translate(_annotationDragTotalDelta.dx, _annotationDragTotalDelta.dy))
        else
          a,
    ];
  }

  void _addAnnotation(AnnotationType type) {
    final id = engine.graph.generateId('annotation');
    final position = _cursorScenePosition ?? const Point2D(40, 40);
    engine.editing.execute(CreateAnnotationCommand(DiagramAnnotation(
      id: id,
      type: type,
      text: 'New ${type.name}',
      position: position,
    )));
    engine.registry.selection.selectAnnotation(id);
  }

  void _handleAnnotationTap(String id) {
    if (_toggleModifierPressed) {
      engine.registry.selection.toggleAnnotation(id);
    } else if (_additiveModifierPressed) {
      engine.registry.selection.selectAnnotation(id, additive: true);
    } else {
      engine.registry.selection.selectAnnotation(id);
    }
  }

  void _handleAnnotationDragStart(String id) {
    final annotation = session!.layout.annotationOf(id);
    if (annotation == null) return;
    if (!selection.annotationIds.contains(id)) {
      engine.registry.selection.selectAnnotation(id);
    }
    setState(() {
      _draggingAnnotationId = id;
      _annotationDragStartPosition = annotation.position;
      _annotationDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleAnnotationDragUpdate(Offset delta) {
    if (_draggingAnnotationId == null) return;
    setState(() =>
        _annotationDragTotalDelta = _annotationDragTotalDelta.translate(delta.dx, delta.dy));
  }

  void _handleAnnotationDragEnd() {
    final id = _draggingAnnotationId;
    final start = _annotationDragStartPosition;
    if (id == null || start == null) return;
    final newPosition = GridComputer.snap(
      start.translate(_annotationDragTotalDelta.dx, _annotationDragTotalDelta.dy),
      viewState.grid,
    );
    engine.editing.execute(UpdateAnnotationCommand(id, position: newPosition));
    setState(() {
      _draggingAnnotationId = null;
      _annotationDragStartPosition = null;
      _annotationDragTotalDelta = const Point2D(0, 0);
    });
  }

  Future<void> _editAnnotationText(String id) async {
    final annotation = session!.layout.annotationOf(id);
    if (annotation == null) return;
    final controller = TextEditingController(text: annotation.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit annotation'),
        content: TextField(controller: controller, autofocus: true, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newText != null) {
      engine.editing.execute(UpdateAnnotationCommand(id, text: newText));
    }
  }

  // --- Wire editing / "Edit Route" mode (ENGINE-TASK-000099) ------------

  bool get _wireEditActive => _wireEditModeActive && selection.relationshipIds.length == 1;

  void _reseedWireEditPoints() {
    if (selection.relationshipIds.length != 1) {
      setState(() {
        _wireEditModeActive = false;
        _wireEditWorkingPoints = null;
        _wireEditSelectedVertex = null;
      });
      return;
    }
    final relationshipId = selection.relationshipIds.single;
    final scene = engine.diagramView.render(
      session!.graph,
      layout: session!.layout,
      routing: engine.registry.routing,
      symbols: engine.registry.symbols,
    );
    final matches = scene.wires.where((w) => w.relationshipId == relationshipId).toList();
    if (matches.isEmpty) return;
    setState(() {
      _wireEditWorkingPoints = List.of(matches.first.points);
      _wireEditSelectedVertex = null;
    });
  }

  void _toggleWireEditMode() {
    if (_wireEditModeActive) {
      setState(() {
        _wireEditModeActive = false;
        _wireEditWorkingPoints = null;
        _wireEditSelectedVertex = null;
      });
      return;
    }
    if (selection.relationshipIds.length != 1) return;
    setState(() => _wireEditModeActive = true);
    _reseedWireEditPoints();
  }

  void _handleWireVertexTap(int index) => setState(() => _wireEditSelectedVertex = index);

  void _insertWireVertex() {
    final points = _wireEditWorkingPoints;
    if (points == null || selection.relationshipIds.length != 1 || points.length < 2) return;
    final relationshipId = selection.relationshipIds.single;
    final afterIndex = (_wireEditSelectedVertex ?? 0).clamp(0, points.length - 2);
    final a = points[afterIndex];
    final b = points[afterIndex + 1];
    final midpoint = Point2D((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final updated = WireEditing.insertVertex(points, afterIndex, midpoint);
    engine.editing.execute(SetWireRouteCommand(relationshipId, updated));
    setState(() {
      _wireEditWorkingPoints = updated;
      _wireEditSelectedVertex = afterIndex + 1;
    });
  }

  void _removeWireVertex() {
    final points = _wireEditWorkingPoints;
    final index = _wireEditSelectedVertex;
    if (points == null || index == null || selection.relationshipIds.length != 1) return;
    final relationshipId = selection.relationshipIds.single;
    final updated = WireEditing.removeVertex(points, index);
    engine.editing.execute(SetWireRouteCommand(relationshipId, updated));
    setState(() {
      _wireEditWorkingPoints = updated;
      _wireEditSelectedVertex = null;
    });
  }

  void _restoreAutomaticRouting() {
    if (selection.relationshipIds.length != 1) return;
    final relationshipId = selection.relationshipIds.single;
    engine.editing.execute(SetWireRouteCommand(relationshipId, null));
    _reseedWireEditPoints();
  }

  void _handleWireCornerDragStart(int index) {
    final points = _wireEditWorkingPoints;
    if (points == null) return;
    setState(() {
      _wireDragCornerIndex = index;
      _wireDragBasePoints = List.of(points);
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireCornerDragUpdate(Offset delta) {
    final index = _wireDragCornerIndex;
    final base = _wireDragBasePoints;
    if (index == null || base == null) return;
    setState(() {
      _wireDragTotalDelta = _wireDragTotalDelta.translate(delta.dx, delta.dy);
      final candidate = base[index].translate(_wireDragTotalDelta.dx, _wireDragTotalDelta.dy);
      _wireEditWorkingPoints = WireEditing.dragCorner(
        base,
        index,
        candidate,
        minimumWireLength: viewState.constraints.minimumWireLength,
      );
    });
  }

  void _handleWireCornerDragEnd() {
    final points = _wireEditWorkingPoints;
    if (points != null && selection.relationshipIds.length == 1) {
      engine.editing.execute(SetWireRouteCommand(selection.relationshipIds.single, points));
    }
    setState(() {
      _wireDragCornerIndex = null;
      _wireDragBasePoints = null;
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireSegmentDragStart(int segmentIndex) {
    final points = _wireEditWorkingPoints;
    if (points == null) return;
    setState(() {
      _wireDragSegmentIndex = segmentIndex;
      _wireDragBasePoints = List.of(points);
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireSegmentDragUpdate(Offset delta) {
    final segmentIndex = _wireDragSegmentIndex;
    final base = _wireDragBasePoints;
    if (segmentIndex == null || base == null) return;
    setState(() {
      _wireDragTotalDelta = _wireDragTotalDelta.translate(delta.dx, delta.dy);
      _wireEditWorkingPoints = WireEditing.dragSegment(
        base,
        segmentIndex,
        _wireDragTotalDelta,
        minimumWireLength: viewState.constraints.minimumWireLength,
      );
    });
  }

  void _handleWireSegmentDragEnd() {
    final points = _wireEditWorkingPoints;
    if (points != null && selection.relationshipIds.length == 1) {
      engine.editing.execute(SetWireRouteCommand(selection.relationshipIds.single, points));
    }
    setState(() {
      _wireDragSegmentIndex = null;
      _wireDragBasePoints = null;
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  // --- Placement tools (ENGINE-TASK-000102) ------------------------------

  void _rotateSelection(double degrees) {
    if (selection.nodeIds.isEmpty) return;
    engine.editing.execute(RotateNodesCommand(selection.nodeIds, degrees));
  }

  void _mirrorSelection(MirrorAxis axis) {
    if (selection.nodeIds.isEmpty) return;
    engine.editing.execute(MirrorNodesCommand(selection.nodeIds, axis));
  }

  Future<void> _openArrayPlacement() async {
    if (selection.nodeIds.isEmpty) return;
    final result = await showArrayPlacementDialog(context);
    if (result == null) return;
    engine.editing.execute(ArrayPlaceCommand(
      selection.nodeIds,
      countX: result.countX,
      countY: result.countY,
      spacingX: result.spacingX,
      spacingY: result.spacingY,
    ));
  }

  void _replaceSymbol(String symbolId) {
    if (selection.nodeIds.length != 1) return;
    engine.editing.execute(ReplaceSymbolCommand(selection.nodeIds.single, symbolId));
  }

  // --- Search (ENGINE-TASK-000104) ---------------------------------------

  Future<void> _openSearch() => showSearchPanelDialog(
        context,
        engine: engine,
        session: () => session!,
        onGoToResult: _goToSearchResult,
      );

  void _goToSearchResult(SearchResult result) {
    switch (result.kind) {
      case SearchResultKind.node:
        engine.registry.selection.selectNode(result.id);
        final position = session!.layout.positionOf(result.id);
        if (position != null) {
          _viewStateService.centerSelection(Rect2D(
            left: position.dx,
            top: position.dy,
            right: position.dx + _nodeSize,
            bottom: position.dy + _nodeSize,
          ));
        }
      case SearchResultKind.relationship:
        engine.registry.selection.selectRelationship(result.id);
      case SearchResultKind.annotation:
        engine.registry.selection.selectAnnotation(result.id);
        final annotation = session!.layout.annotationOf(result.id);
        if (annotation != null) {
          _viewStateService.centerSelection(Rect2D(
            left: annotation.position.dx,
            top: annotation.position.dy,
            right: annotation.position.dx + 40,
            bottom: annotation.position.dy + 20,
          ));
        }
      case SearchResultKind.symbol:
      case SearchResultKind.layer:
        break;
    }
  }

  // --- Layouts / dialogs -------------------------------------------------

  Future<void> _openLayers() => showLayerPanelDialog(
        context,
        engine: engine,
        session: () => session!,
        selection: () => selection,
      );

  Future<void> _openGridSettings() => showGridSettingsDialog(context, _viewStateService);

  Future<void> _openNamedLayouts() => showNamedLayoutsDialog(
        context,
        layoutProvider: engine.registry.layout,
        graphId: session!.graph.id,
        currentLayout: () => session!.layout,
        onLoad: (layout) => engine.editing.resetSession(session!.copyWith(layout: layout)),
        onReset: () => engine.editing.resetSession(session!.copyWith(layout: DiagramLayoutState.empty)),
      );

  @override
  Widget build(BuildContext context) {
    if (loading || session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final currentGraph = session!.graph;
    final scene = engine.diagramView.render(
      currentGraph,
      layout: _effectiveLayout(),
      routing: engine.registry.routing,
      symbols: engine.registry.symbols,
      selection: selection,
      highlightedNodeIds: _highlightedNodeIds,
      highlightedRelationshipIds: _highlightedRelationshipIds,
    );
    final reconnectingWire = _reconnectingWire(scene);

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
          const SingleActivator(LogicalKeyboardKey.keyX, control: true): _cut,
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateSelection,
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
              engine.registry.selection.selectAll(currentGraph, layout: session!.layout),
          const SingleActivator(LogicalKeyboardKey.delete): _deleteSelection,
          const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelection,
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              engine.registry.selection.deselectAll(),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Engineering Engine — Demonstration Host'),
            actions: [
              TextButton.icon(
                onPressed: _highlightBatteryToGround,
                icon: const Icon(Icons.route, color: Colors.white),
                label: const Text('Highlight Battery → Ground',
                    style: TextStyle(color: Colors.white)),
              ),
              IconButton(
                onPressed: _clearHighlight,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear highlight',
              ),
            ],
          ),
          body: Column(
            children: [
              DemoToolbar(
                onAddNode: _addNode,
                onDelete: selection.isEmpty ? null : _deleteSelection,
                onGroup: selection.nodeIds.length < 2 ? null : _groupSelection,
                onUngroup: selection.groupIds.isEmpty ? null : _ungroupSelection,
                onCopy: selection.isEmpty ? null : _copy,
                onCut: selection.isEmpty ? null : _cut,
                onPaste: engine.clipboard.hasContent ? _paste : null,
                onDuplicate: selection.isEmpty ? null : _duplicateSelection,
                onUndo: engine.editing.canUndo ? _undo : null,
                onRedo: engine.editing.canRedo ? _redo : null,
                symbolChoices: seedSymbolIdentifiers,
                resolveSymbolName: (id) => engine.registry.symbols.resolve(id).name,
                onFitAll: () => _fitAll(scene),
                onFitSelection: selection.nodeIds.isEmpty ? null : () => _fitSelection(scene),
                onCenterSelection: selection.nodeIds.isEmpty ? null : () => _centerSelection(scene),
                onGoBack: _viewStateService.canGoBack ? _viewStateService.goBack : null,
                onGoForward: _viewStateService.canGoForward ? _viewStateService.goForward : null,
                onAlign: selection.nodeIds.length < 2 ? null : _align,
                onDistribute: selection.nodeIds.length < 3 ? null : _distribute,
                viewState: viewState,
                onToggleGrid: _viewStateService.toggleGrid,
                onToggleSnap: _viewStateService.toggleSnap,
                onToggleGuides: () => _viewStateService.setGuidesVisible(!viewState.guidesVisible),
                onOpenGridSettings: _openGridSettings,
                onOpenNamedLayouts: _openNamedLayouts,
              ),
              const Divider(height: 1),
              SecondaryToolbar(
                onOpenLayers: _openLayers,
                onOpenSearch: _openSearch,
                onAddAnnotation: _addAnnotation,
                wireEditModeActive: _wireEditActive,
                onToggleWireEditMode:
                    selection.relationshipIds.length == 1 ? _toggleWireEditMode : null,
                onInsertVertex: _wireEditActive ? _insertWireVertex : null,
                onRemoveVertex:
                    _wireEditActive && _wireEditSelectedVertex != null ? _removeWireVertex : null,
                onRestoreAutomaticRouting: _wireEditActive ? _restoreAutomaticRouting : null,
                onRotate90: selection.nodeIds.isEmpty ? null : () => _rotateSelection(90),
                onRotate180: selection.nodeIds.isEmpty ? null : () => _rotateSelection(180),
                onRotateArbitrary: selection.nodeIds.isEmpty ? null : _rotateSelection,
                onMirrorHorizontal:
                    selection.nodeIds.isEmpty ? null : () => _mirrorSelection(MirrorAxis.horizontal),
                onMirrorVertical:
                    selection.nodeIds.isEmpty ? null : () => _mirrorSelection(MirrorAxis.vertical),
                onArrayPlace: selection.nodeIds.isEmpty ? null : _openArrayPlacement,
                onReplaceSymbol: selection.nodeIds.length == 1 ? _replaceSymbol : null,
                symbolChoices: seedSymbolIdentifiers,
                resolveSymbolName: (id) => engine.registry.symbols.resolve(id).name,
                constraints: viewState.constraints,
                onConstraintsChanged: _viewStateService.setConstraints,
                recentDescriptions: engine.editing.recentDescriptions,
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: _explorerWidth,
                      child: GraphExplorerPanel(
                        graph: currentGraph,
                        selection: selection,
                        onSelectNode: _handleNodeTap,
                      ),
                    ),
                    _ResizeHandle(onDrag: (dx) => setState(() => _explorerWidth = (_explorerWidth + dx).clamp(150, 400))),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Reserve 20px for the rulers (ENGINE-TASK-000096)
                          // when computing the actual canvas viewport size.
                          _ensureViewportSize(constraints.maxWidth - 20, constraints.maxHeight - 20);
                          final graphView = GraphViewPanel(
                            scene: scene,
                            viewState: viewState,
                            symbols: engine.registry.symbols,
                            guides: _activeGuides,
                            boxSelectRect: _boxSelectRect,
                            transformController: transformController,
                            connectionPreviewFrom:
                                _connectFromPort == null ? null : _portAnchor(_connectFromPort!),
                            connectionPreviewTo: _connectionCurrentPoint,
                            connectionPreviewValid: _connectionValid,
                            reconnectingWire: reconnectingWire,
                            annotations: _effectiveAnnotations(),
                            selectedAnnotationIds: selection.annotationIds,
                            onAnnotationTap: _handleAnnotationTap,
                            onAnnotationDragStart: _handleAnnotationDragStart,
                            onAnnotationDragUpdate: _handleAnnotationDragUpdate,
                            onAnnotationDragEnd: _handleAnnotationDragEnd,
                            onAnnotationEditRequested: _editAnnotationText,
                            editingWirePoints: _wireEditActive ? _wireEditWorkingPoints : null,
                            editingWireSelectedVertex: _wireEditSelectedVertex,
                            onWireVertexTap: _handleWireVertexTap,
                            onWireCornerDragStart: _handleWireCornerDragStart,
                            onWireCornerDragUpdate: _handleWireCornerDragUpdate,
                            onWireCornerDragEnd: _handleWireCornerDragEnd,
                            onWireSegmentDragStart: _handleWireSegmentDragStart,
                            onWireSegmentDragUpdate: _handleWireSegmentDragUpdate,
                            onWireSegmentDragEnd: _handleWireSegmentDragEnd,
                            onNodeTap: _handleNodeTap,
                            onNodeDragStart: _handleNodeDragStart,
                            onNodeDragUpdate: _handleNodeDragUpdate,
                            onNodeDragEnd: _handleNodeDragEnd,
                            onBackgroundTap: (position) => _handleBackgroundTap(position, scene),
                            onBackgroundPanStart: _handleBackgroundPanStart,
                            onBackgroundPanUpdate: _handleBackgroundPanUpdate,
                            onBackgroundPanEnd: () => _handleBackgroundPanEnd(scene),
                            onHover: _handleHover,
                            onPortHoverEnter: _handlePortHoverEnter,
                            onPortHoverExit: _handlePortHoverExit,
                            onPortDragStart: _handlePortDragStart,
                            onPortDragUpdate: _handlePortDragUpdate,
                            onPortDragEnd: _handlePortDragEnd,
                            onReconnectDragStart: _handleReconnectDragStart,
                            onReconnectDragUpdate: _handleReconnectDragUpdate,
                            onReconnectDragEnd: _handleReconnectDragEnd,
                            onInteractionEnd: _syncViewStateFromTransform,
                          );
                          return Column(
                            children: [
                              Row(
                                children: [
                                  const SizedBox(width: 20, height: 20),
                                  Expanded(
                                    child: HorizontalRuler(
                                      viewState: viewState,
                                      width: constraints.maxWidth - 20,
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    VerticalRuler(
                                      viewState: viewState,
                                      height: constraints.maxHeight - 20,
                                    ),
                                    Expanded(child: graphView),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    _ResizeHandle(onDrag: (dx) => setState(() => _inspectorWidth = (_inspectorWidth - dx).clamp(220, 480))),
                    SizedBox(
                      width: _inspectorWidth,
                      child: InspectorColumn(
                        engine: engine,
                        graph: currentGraph,
                        selection: selection,
                        focus: focus,
                        report: report,
                        onRevalidate: () => setState(() {
                          report = engine.validate(currentGraph);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              DemoStatusBar(
                engine: engine,
                selection: selection,
                viewState: viewState,
                cursorScenePosition: _cursorScenePosition,
                layerCount: session!.layout.layers.length,
                searchResultCount:
                    (engine.registry.navigation as NavigationService).searchResults.length,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin draggable divider between side panels — "Resizable side panels...
/// Basic implementation only. Do NOT implement a docking framework"
/// (WORK_PACKAGE_022, ENGINE-TASK-000097).
class _ResizeHandle extends StatelessWidget {
  final void Function(double dx) onDrag;

  const _ResizeHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta.dx),
        child: const SizedBox(width: 6, child: VerticalDivider(width: 6)),
      ),
    );
  }
}
