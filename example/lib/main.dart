import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'seed_graph.dart';
import 'symbol_bundle_loader.dart';
import 'wire_painter.dart';

/// Engineering Engine Demonstration Host.
///
/// This is NOT Diagram Studio — Diagram Studio belongs to `oep_studio` and
/// is out of scope here (STUDIO-TASK-000063). This app exists only to
/// verify the Engineering Engine, and consumes ONLY its public API
/// (`package:engineering_engine/engineering_engine.dart`).
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

class HostShell extends StatefulWidget {
  const HostShell({super.key});

  @override
  State<HostShell> createState() => _HostShellState();
}

class _HostShellState extends State<HostShell> {
  late final EngineeringEngine engine;
  EngineeringGraph? graph;
  ValidationReport? report;
  SelectionState selection = const SelectionState.none();
  bool loading = true;
  StreamSubscription<SelectionState>? _selectionSub;
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
    await engine.registry.graph.updateGraph(seeded);

    _selectionSub = engine.registry.selection.changes.listen((state) {
      setState(() => selection = state);
    });
    _navigationSub = engine.registry.navigation.events.listen(_onNavigationEvent);

    setState(() {
      graph = seeded;
      report = engine.validate(seeded);
      loading = false;
    });
  }

  void _onNavigationEvent(NavigationEvent event) {
    final current = graph;
    if (current == null) return;
    final highlightedNodes = event.highlightedNodeIds.toSet();
    final highlightedRelationships = event.highlightedRelationshipIds.toSet();
    setState(() {
      graph = current.copyWith(
        nodes: current.nodes.map(
          (id, node) => MapEntry(
            id,
            node.copyWith(
              runtime: node.runtime.copyWith(
                highlighted: highlightedNodes.contains(id),
              ),
            ),
          ),
        ),
        relationships: current.relationships.map(
          (id, relationship) => MapEntry(
            id,
            relationship.copyWith(
              runtime: relationship.runtime.copyWith(
                highlighted: highlightedRelationships.contains(id),
              ),
            ),
          ),
        ),
      );
    });
  }

  void _selectNode(String nodeId) {
    engine.registry.selection.selectNode(nodeId);
    final current = graph;
    if (current == null) return;
    setState(() {
      graph = current.copyWith(
        nodes: current.nodes.map(
          (id, node) => MapEntry(
            id,
            node.copyWith(runtime: node.runtime.copyWith(selected: id == nodeId)),
          ),
        ),
      );
    });
  }

  void _highlightBatteryToGround() {
    final current = graph;
    if (current == null) return;
    // highlightPathBetween is a NavigationService convenience method, not
    // part of the NavigationProvider interface — Phase 1's default
    // registration always registers a NavigationService, so this cast is
    // safe for this host.
    (engine.registry.navigation as NavigationService)
        .highlightPathBetween(current, 'battery', 'ground');
  }

  void _clearHighlight() => engine.registry.navigation.clearHighlight();

  void _revalidate() {
    final current = graph;
    if (current == null) return;
    setState(() => report = engine.validate(current));
  }

  @override
  void dispose() {
    _selectionSub?.cancel();
    _navigationSub?.cancel();
    unawaited(engine.shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || graph == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final currentGraph = graph!;
    final scene = engine.diagramView.render(currentGraph);

    return Scaffold(
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
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: _GraphExplorerPanel(
                    graph: currentGraph,
                    selection: selection,
                    onSelectNode: _selectNode,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _GraphViewPanel(scene: scene, onSelectNode: _selectNode),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 320,
                  child: _InspectorColumn(
                    graph: currentGraph,
                    selection: selection,
                    report: report,
                    onRevalidate: _revalidate,
                  ),
                ),
              ],
            ),
          ),
          _StatusBar(engine: engine),
        ],
      ),
    );
  }
}

class _GraphExplorerPanel extends StatelessWidget {
  final EngineeringGraph graph;
  final SelectionState selection;
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
              final isSelected =
                  selection.kind == SelectionKind.node && selection.id == node.id;
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
  final void Function(String nodeId) onSelectNode;

  const _GraphViewPanel({required this.scene, required this.onSelectNode});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: InteractiveViewer(
        minScale: 0.25,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(400),
        constrained: false,
        child: SizedBox(
          width: scene.contentWidth,
          height: scene.contentHeight,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: WirePainter(scene.wires))),
              for (final node in scene.nodes)
                Positioned(
                  left: node.position.dx,
                  top: node.position.dy,
                  width: node.width,
                  height: node.height,
                  child: _SymbolNode(node: node, onTap: () => onSelectNode(node.nodeId)),
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

  const _SymbolNode({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = node.highlighted
        ? Colors.orange
        : (node.selected ? Colors.blue : Colors.transparent);
    return GestureDetector(
      onTap: onTap,
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
  final EngineeringGraph graph;
  final SelectionState selection;
  final ValidationReport? report;
  final VoidCallback onRevalidate;

  const _InspectorColumn({
    required this.graph,
    required this.selection,
    required this.report,
    required this.onRevalidate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _PropertyInspectorPanel(graph: graph, selection: selection)),
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

class _PropertyInspectorPanel extends StatelessWidget {
  final EngineeringGraph graph;
  final SelectionState selection;

  const _PropertyInspectorPanel({required this.graph, required this.selection});

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (selection.kind) {
      case SelectionKind.node:
        final node = graph.nodes[selection.id];
        body = node == null
            ? const Text('Node not found.')
            : _KeyValueList(entries: {
                'Id': node.id,
                'Category': node.category.name,
                'Display Name': node.displayName,
                'Symbol': node.symbolId ?? '(none)',
                'Ports': node.ports.length.toString(),
                'Evidence Links': node.evidenceLinks.length.toString(),
              });
        break;
      case SelectionKind.relationship:
        final relationship = graph.relationships[selection.id];
        body = relationship == null
            ? const Text('Relationship not found.')
            : _KeyValueList(entries: {
                'Id': relationship.id,
                'Type': relationship.relationshipType.name,
                'Source': relationship.sourceNode,
                'Target': relationship.targetNode,
              });
        break;
      default:
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
  final SelectionState selection;

  const _EvidencePanel({required this.graph, required this.selection});

  @override
  Widget build(BuildContext context) {
    final node = selection.kind == SelectionKind.node ? graph.nodes[selection.id] : null;
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

  const _StatusBar({required this.engine});

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
          Text('Open graphs: ${diagnostics.openGraphIds.length}'),
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
