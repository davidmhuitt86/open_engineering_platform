import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

class GraphExplorerPanel extends StatelessWidget {
  final EngineeringGraph graph;
  final GraphSelection selection;
  final void Function(String nodeId) onSelectNode;

  const GraphExplorerPanel({
    super.key,
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

class InspectorColumn extends StatelessWidget {
  final EngineeringEngine engine;
  final EngineeringGraph graph;
  final GraphSelection selection;
  final FocusState focus;
  final ValidationReport? report;
  final VoidCallback onRevalidate;

  const InspectorColumn({
    super.key,
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
          child: PropertyInspectorPanel(engine: engine, graph: graph, selection: selection),
        ),
        const Divider(height: 1),
        Expanded(child: EvidencePanel(graph: graph, selection: selection)),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: ValidationPanel(report: report, onRevalidate: onRevalidate),
        ),
      ],
    );
  }
}

class PropertyInspectorPanel extends StatefulWidget {
  final EngineeringEngine engine;
  final EngineeringGraph graph;
  final GraphSelection selection;

  const PropertyInspectorPanel({
    super.key,
    required this.engine,
    required this.graph,
    required this.selection,
  });

  @override
  State<PropertyInspectorPanel> createState() => _PropertyInspectorPanelState();
}

class _PropertyInspectorPanelState extends State<PropertyInspectorPanel> {
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
          : KeyValueList(entries: {
              'Id': relationship.id,
              'Type': relationship.relationshipType.name,
              'Source': relationship.sourceNode,
              'Target': relationship.targetNode,
            });
    } else if (selection.groupIds.length == 1) {
      final group = widget.graph.groups[selection.groupIds.first];
      body = group == null
          ? const Text('Group not found.')
          : KeyValueList(entries: {
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

class EvidencePanel extends StatelessWidget {
  final EngineeringGraph graph;
  final GraphSelection selection;

  const EvidencePanel({super.key, required this.graph, required this.selection});

  @override
  Widget build(BuildContext context) {
    final node = selection.nodeIds.length == 1 ? graph.nodes[selection.nodeIds.first] : null;
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

class ValidationPanel extends StatelessWidget {
  final ValidationReport? report;
  final VoidCallback onRevalidate;

  const ValidationPanel({super.key, required this.report, required this.onRevalidate});

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

class KeyValueList extends StatelessWidget {
  final Map<String, String> entries;

  const KeyValueList({super.key, required this.entries});

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
