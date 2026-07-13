import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'geometry_utils.dart';
import 'seed_graph.dart';
import 'symbol_bundle_loader.dart';
import 'wire_painter.dart';

/// Engineering Engine Demonstration Host.
///
/// This is NOT Diagram Studio — Diagram Studio belongs to `oep_studio` and
/// is out of scope here (STUDIO-TASK-000063, reaffirmed WORK_PACKAGE_021).
/// This app exists only to verify the Engineering Engine, and consumes
/// ONLY its public API (`package:engineering_engine/engineering_engine.dart`).
///
/// WORK_PACKAGE_021 extends it with a fully interactive editor: create/
/// delete/move/duplicate nodes, connect/reconnect/delete relationships,
/// multi/box selection, grouping, clipboard, and undo/redo — every
/// mutation goes through `EditingService.execute` (an `EditingCommand`),
/// never a direct graph edit, and the whole shell rebuilds from a single
/// `EditingService.sessionChanges` subscription rather than per-action
/// manual state rewriting.
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

const double _gridSize = 20;
const double _defaultNodeSpawnStep = 40;

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
  bool loading = true;
  int _spawnCounter = 0;

  Set<String> _highlightedNodeIds = {};
  Set<String> _highlightedRelationshipIds = {};

  Rect2D? _boxSelectRect;
  Offset? _boxSelectStart;

  Set<String>? _dragNodeIds;
  Map<String, Point2D>? _dragStartPositions;
  Point2D _dragTotalDelta = const Point2D(0, 0);

  StreamSubscription<EditingSession>? _sessionSub;
  StreamSubscription<GraphSelection>? _selectionSub;
  StreamSubscription<FocusState>? _focusSub;
  StreamSubscription<NavigationEvent>? _navigationSub;

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
    });
    _focusSub = engine.registry.selection.focusChanges.listen((f) {
      setState(() => focus = f);
    });
    _navigationSub = engine.registry.navigation.events.listen(_onNavigationEvent);

    setState(() {
      session = engine.editing.session;
      report = engine.validate(session!.graph);
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
    unawaited(engine.shutdown());
    super.dispose();
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

  void _handleNodeTap(String nodeId) {
    if (_toggleModifierPressed) {
      engine.registry.selection.toggleNode(nodeId);
    } else if (_additiveModifierPressed) {
      engine.registry.selection.selectNode(nodeId, additive: true);
    } else {
      engine.registry.selection.selectNode(nodeId);
    }
  }

  void _handleBackgroundTap() {
    if (!_additiveModifierPressed) {
      engine.registry.selection.deselectAll();
    }
  }

  void _handleBoxSelectStart(Offset localPosition) {
    _boxSelectStart = localPosition;
    setState(() => _boxSelectRect = Rect2D.fromPoints(
          offsetToPoint(localPosition),
          offsetToPoint(localPosition),
        ));
  }

  void _handleBoxSelectUpdate(Offset localPosition, DiagramScene scene) {
    final start = _boxSelectStart;
    if (start == null) return;
    setState(() {
      _boxSelectRect = rectFromOffsets(start, localPosition);
    });
  }

  void _handleBoxSelectEnd(DiagramScene scene) {
    final rect = _boxSelectRect;
    if (rect != null) {
      final ids = DiagramHitTesting.nodesInRect(scene, rect);
      if (ids.isNotEmpty) {
        engine.registry.selection.selectMany(
          nodeIds: ids,
          additive: _additiveModifierPressed,
        );
      }
    }
    setState(() {
      _boxSelectRect = null;
      _boxSelectStart = null;
    });
  }

  // --- Node dragging ----------------------------------------------------

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
    });
  }

  void _handleNodeDragEnd() {
    final nodeIds = _dragNodeIds;
    final startPositions = _dragStartPositions;
    if (nodeIds == null || startPositions == null) return;
    final newPositions = {
      for (final id in nodeIds)
        id: snapToGrid(
          startPositions[id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy),
          _gridSize,
        ),
    };
    engine.editing.execute(MoveNodesCommand(newPositions));
    setState(() {
      _dragNodeIds = null;
      _dragStartPositions = null;
      _dragTotalDelta = const Point2D(0, 0);
    });
  }

  DiagramLayoutState _effectiveLayout() {
    final current = session!;
    if (_dragNodeIds == null || _dragStartPositions == null) return current.layout;
    final preview = {
      for (final id in _dragNodeIds!)
        id: snapToGrid(
          _dragStartPositions![id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy),
          _gridSize,
        ),
    };
    return current.layout.withPositions(preview);
  }

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
              engine.registry.selection.selectAll(currentGraph),
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
              _Toolbar(
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
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: _GraphExplorerPanel(
                        graph: currentGraph,
                        selection: selection,
                        onSelectNode: _handleNodeTap,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _GraphViewPanel(
                        scene: scene,
                        boxSelectRect: _boxSelectRect,
                        transformController: transformController,
                        onNodeTap: _handleNodeTap,
                        onNodeDragStart: _handleNodeDragStart,
                        onNodeDragUpdate: _handleNodeDragUpdate,
                        onNodeDragEnd: _handleNodeDragEnd,
                        onBackgroundTap: _handleBackgroundTap,
                        onBoxSelectStart: _handleBoxSelectStart,
                        onBoxSelectUpdate: (position) =>
                            _handleBoxSelectUpdate(position, scene),
                        onBoxSelectEnd: () => _handleBoxSelectEnd(scene),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 320,
                      child: _InspectorColumn(
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
              _StatusBar(engine: engine, selection: selection),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final void Function(String symbolId) onAddNode;
  final VoidCallback? onDelete;
  final VoidCallback? onGroup;
  final VoidCallback? onUngroup;
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final VoidCallback? onDuplicate;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final List<String> symbolChoices;
  final String Function(String symbolId) resolveSymbolName;

  const _Toolbar({
    required this.onAddNode,
    required this.onDelete,
    required this.onGroup,
    required this.onUngroup,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onDuplicate,
    required this.onUndo,
    required this.onRedo,
    required this.symbolChoices,
    required this.resolveSymbolName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Add node',
            onSelected: onAddNode,
            itemBuilder: (context) => symbolChoices
                .map((id) => PopupMenuItem(value: id, child: Text(resolveSymbolName(id))))
                .toList(),
            child: const _ToolbarButtonLabel(icon: Icons.add_box, label: 'Add'),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete (Del)',
          ),
          IconButton(
            onPressed: onGroup,
            icon: const Icon(Icons.group_work),
            tooltip: 'Group',
          ),
          IconButton(
            onPressed: onUngroup,
            icon: const Icon(Icons.group_off),
            tooltip: 'Ungroup',
          ),
          const VerticalDivider(),
          IconButton(onPressed: onCopy, icon: const Icon(Icons.copy), tooltip: 'Copy (Ctrl+C)'),
          IconButton(onPressed: onCut, icon: const Icon(Icons.cut), tooltip: 'Cut (Ctrl+X)'),
          IconButton(
              onPressed: onPaste, icon: const Icon(Icons.paste), tooltip: 'Paste (Ctrl+V)'),
          IconButton(
            onPressed: onDuplicate,
            icon: const Icon(Icons.content_copy),
            tooltip: 'Duplicate (Ctrl+D)',
          ),
          const VerticalDivider(),
          IconButton(onPressed: onUndo, icon: const Icon(Icons.undo), tooltip: 'Undo (Ctrl+Z)'),
          IconButton(onPressed: onRedo, icon: const Icon(Icons.redo), tooltip: 'Redo (Ctrl+Y)'),
        ],
      ),
    );
  }
}

class _ToolbarButtonLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ToolbarButtonLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(label),
      ]),
    );
  }
}

class _GraphExplorerPanel extends StatelessWidget {
  final EngineeringGraph graph;
  final GraphSelection selection;
  final void Function(String nodeId) onSelectNode;

  const _GraphExplorerPanel({
    required this.graph,
    required this.selection,
    required this.onSelectNode,
  });

  @override
  Widget build(BuildContext context) {
    final nodes = graph.nodes.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Graph Explorer', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView(
            children: nodes.map((node) {
              final isSelected = selection.containsNode(node.id);
              return ListTile(
                dense: true,
                selected: isSelected,
                title: Text(node.displayName),
                subtitle: Text(node.category.name),
                onTap: () => onSelectNode(node.id),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _GraphViewPanel extends StatelessWidget {
  final DiagramScene scene;
  final Rect2D? boxSelectRect;
  final TransformationController transformController;
  final void Function(String nodeId) onNodeTap;
  final void Function(String nodeId) onNodeDragStart;
  final void Function(Offset delta) onNodeDragUpdate;
  final VoidCallback onNodeDragEnd;
  final VoidCallback onBackgroundTap;
  final void Function(Offset localPosition) onBoxSelectStart;
  final void Function(Offset localPosition) onBoxSelectUpdate;
  final VoidCallback onBoxSelectEnd;

  const _GraphViewPanel({
    required this.scene,
    required this.boxSelectRect,
    required this.transformController,
    required this.onNodeTap,
    required this.onNodeDragStart,
    required this.onNodeDragUpdate,
    required this.onNodeDragEnd,
    required this.onBackgroundTap,
    required this.onBoxSelectStart,
    required this.onBoxSelectUpdate,
    required this.onBoxSelectEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: InteractiveViewer(
        transformationController: transformController,
        minScale: 0.25,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(400),
        constrained: false,
        // Box-select drags and node drags both need the panel's own pan
        // handling, so InteractiveViewer's own pan is left to two-finger/
        // middle-button gestures implicitly (single-drag is claimed by
        // the GestureDetector below).
        panEnabled: false,
        child: SizedBox(
          width: scene.contentWidth,
          height: scene.contentHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBackgroundTap,
                  onPanStart: (details) => onBoxSelectStart(details.localPosition),
                  onPanUpdate: (details) => onBoxSelectUpdate(details.localPosition),
                  onPanEnd: (_) => onBoxSelectEnd(),
                  child: CustomPaint(painter: WirePainter(scene.wires)),
                ),
              ),
              for (final node in scene.nodes)
                Positioned(
                  left: node.position.dx,
                  top: node.position.dy,
                  width: node.width,
                  height: node.height,
                  child: _SymbolNode(
                    node: node,
                    onTap: () => onNodeTap(node.nodeId),
                    onDragStart: () => onNodeDragStart(node.nodeId),
                    onDragUpdate: onNodeDragUpdate,
                    onDragEnd: onNodeDragEnd,
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
    );
  }
}

class _SymbolNode extends StatelessWidget {
  final DiagramNodeVisual node;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;

  const _SymbolNode({
    required this.node,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = node.highlighted
        ? Colors.orange
        : (node.selected ? Colors.blue : Colors.transparent);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanStart: (_) => onDragStart(),
      onPanUpdate: (details) => onDragUpdate(details.delta),
      onPanEnd: (_) => onDragEnd(),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: borderColor, width: 2)),
        padding: const EdgeInsets.all(4),
        child: node.symbolId == null
            ? const Icon(Icons.help_outline)
            : SvgPicture.asset(
                'assets/symbols/${node.symbolId}.svg',
                package: 'engineering_engine',
              ),
      ),
    );
  }
}

class _InspectorColumn extends StatelessWidget {
  final EngineeringEngine engine;
  final EngineeringGraph graph;
  final GraphSelection selection;
  final FocusState focus;
  final ValidationReport? report;
  final VoidCallback onRevalidate;

  const _InspectorColumn({
    required this.engine,
    required this.graph,
    required this.selection,
    required this.focus,
    required this.report,
    required this.onRevalidate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _PropertyInspectorPanel(engine: engine, graph: graph, selection: selection),
        ),
        const Divider(height: 1),
        Expanded(child: _EvidencePanel(graph: graph, selection: selection)),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: _ValidationPanel(report: report, onRevalidate: onRevalidate),
        ),
      ],
    );
  }
}

class _PropertyInspectorPanel extends StatefulWidget {
  final EngineeringEngine engine;
  final EngineeringGraph graph;
  final GraphSelection selection;

  const _PropertyInspectorPanel({
    required this.engine,
    required this.graph,
    required this.selection,
  });

  @override
  State<_PropertyInspectorPanel> createState() => _PropertyInspectorPanelState();
}

class _PropertyInspectorPanelState extends State<_PropertyInspectorPanel> {
  late TextEditingController _nameController;
  String? _editingNodeId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncController(EngineeringNode? node) {
    if (node == null) return;
    if (_editingNodeId != node.id) {
      _editingNodeId = node.id;
      _nameController.text = node.displayName;
    }
  }

  void _commitRename(String nodeId, String value) {
    if (value.trim().isEmpty) return;
    widget.engine.editing.execute(RenameNodeCommand(nodeId, value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    final selection = widget.selection;
    if (selection.length == 1 && selection.nodeIds.isNotEmpty) {
      final node = widget.graph.nodes[selection.nodeIds.first];
      if (node == null) {
        body = const Text('Node not found.');
      } else {
        _syncController(node);
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Id: ${node.id}'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
              onSubmitted: (value) => _commitRename(node.id, value),
              onEditingComplete: () => _commitRename(node.id, _nameController.text),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<NodeCategory>(
              initialValue: node.category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: NodeCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                widget.engine.editing.execute(ChangeNodeCategoryCommand(node.id, value));
              },
            ),
            const SizedBox(height: 8),
            Text('Symbol: ${node.symbolId ?? '(none)'}'),
            Text('Ports: ${node.ports.length}'),
            Text('Evidence Links: ${node.evidenceLinks.length}'),
          ],
        );
      }
    } else if (selection.length > 1) {
      body = Text('${selection.length} items selected.');
    } else if (selection.relationshipIds.length == 1) {
      final relationship = widget.graph.relationships[selection.relationshipIds.first];
      body = relationship == null
          ? const Text('Relationship not found.')
          : _KeyValueList(entries: {
              'Id': relationship.id,
              'Type': relationship.relationshipType.name,
              'Source': relationship.sourceNode,
              'Target': relationship.targetNode,
            });
    } else if (selection.groupIds.length == 1) {
      final group = widget.graph.groups[selection.groupIds.first];
      body = group == null
          ? const Text('Group not found.')
          : _KeyValueList(entries: {
              'Id': group.id,
              'Kind': group.kind.name,
              'Name': group.displayName,
              'Members': group.memberNodeIds.length.toString(),
              'Locked': group.locked.toString(),
            });
    } else {
      body = const Text('Nothing selected.');
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Property Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: body)),
        ],
      ),
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  final EngineeringGraph graph;
  final GraphSelection selection;

  const _EvidencePanel({required this.graph, required this.selection});

  @override
  Widget build(BuildContext context) {
    final node =
        selection.nodeIds.length == 1 ? graph.nodes[selection.nodeIds.first] : null;
    final links = node?.evidenceLinks ?? const [];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: links.isEmpty
                  ? const Text('No evidence linked.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: links
                          .map((link) => Text('${link.kind.name}: ${link.sourceReference}'))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  final ValidationReport? report;
  final VoidCallback onRevalidate;

  const _ValidationPanel({required this.report, required this.onRevalidate});

  @override
  Widget build(BuildContext context) {
    final findings = report?.findings ?? const [];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Validation', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: onRevalidate,
                icon: const Icon(Icons.refresh),
                tooltip: 'Revalidate',
              ),
            ],
          ),
          if (findings.isEmpty)
            const Text('Clean — no findings.')
          else
            Expanded(
              child: ListView(
                children: findings.map((finding) {
                  final color = switch (finding.severity) {
                    ValidationSeverity.error => Colors.red,
                    ValidationSeverity.warning => Colors.orange,
                    ValidationSeverity.info => Colors.blueGrey,
                  };
                  return Text(finding.toString(), style: TextStyle(color: color));
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final EngineeringEngine engine;
  final GraphSelection selection;

  const _StatusBar({required this.engine, required this.selection});

  @override
  Widget build(BuildContext context) {
    final diagnostics = engine.diagnostics();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text('Engine: ${diagnostics.state.name}'),
          const SizedBox(width: 16),
          Text('v${diagnostics.version}'),
          const SizedBox(width: 16),
          Text('Symbols: ${diagnostics.registeredSymbolCount}'),
          const SizedBox(width: 16),
          Text('Selected: ${selection.length}'),
          const SizedBox(width: 16),
          Text(
            'Undo: ${engine.editing.canUndo ? engine.editing.nextUndoDescription : "—"}',
          ),
          const SizedBox(width: 16),
          Text(
            'Redo: ${engine.editing.canRedo ? engine.editing.nextRedoDescription : "—"}',
          ),
        ],
      ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  final Map<String, String> entries;

  const _KeyValueList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.entries
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${e.key}: ${e.value}'),
              ))
          .toList(),
    );
  }
}
