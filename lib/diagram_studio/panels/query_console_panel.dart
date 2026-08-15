import 'package:flutter/material.dart';

import '../../core/foundation/oep_api_types.dart';
import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import '../intelligence/diagram_intelligence_service.dart';
import 'intelligence_panel_shared.dart';

/// AP-DS-003 Query Console panel: ad-hoc Engineering Query execution
/// embedded in Diagram Studio ("Embed the Engineering Query Console" --
/// the spec's own words), scoped down from the standalone
/// `QueryConsolePage` (WP-EKE-008) to the one primitive
/// [DiagramIntelligenceService.query] actually exposes: category +
/// target id. "Selecting query results highlights corresponding diagram
/// elements" is satisfied the same way every other panel here does it --
/// [IntelligenceObjectChips] + [onSelectNode].
class QueryConsolePanel extends StatefulWidget {
  const QueryConsolePanel({
    super.key,
    required this.intelligence,
    required this.onSelectNode,
    this.selectedNodeId,
  });

  final DiagramIntelligenceService intelligence;
  final void Function(String nodeId) onSelectNode;
  final String? selectedNodeId;

  @override
  State<QueryConsolePanel> createState() => _QueryConsolePanelState();
}

class _QueryConsolePanelState extends State<QueryConsolePanel> {
  QueryCategory _category = QueryCategory.object;
  final _idController = TextEditingController();
  bool _treatAsNodeId = true;
  bool _busy = false;
  String? _error;
  ({OepWorkflowResult result, List<String> objectIds})? _last;
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.selectedNodeId != null) _idController.text = widget.selectedNodeId!;
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter an object id or canvas node id.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await widget.intelligence.query(_category, id, isNodeId: _treatAsNodeId);
      if (!mounted) return;
      setState(() {
        _last = outcome;
        _history.insert(0, '${_category.name}($id)');
        if (_history.length > 20) _history.removeLast();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<QueryCategory>(
            initialValue: _category,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Category', isDense: true),
            items: [
              for (final c in QueryCategory.values)
                DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _idController,
            decoration: const InputDecoration(labelText: 'Object id / canvas node id', isDense: true),
            style: const TextStyle(fontSize: 12),
          ),
          Row(
            children: [
              Checkbox(
                value: _treatAsNodeId,
                onChanged: (v) => setState(() => _treatAsNodeId = v ?? true),
              ),
              const Text('Canvas node id', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _busy ? null : _run,
                icon: const Icon(Icons.play_arrow, size: 15),
                label: const Text('Run Query'),
              ),
            ],
          ),
          IntelligenceBusyBar(busy: _busy),
          if (_error != null) EiErrorBanner(message: _error!),
          if (_last != null) ...[
            const SizedBox(height: 8),
            IntelligenceResultSummary(result: _last!.result),
            const SizedBox(height: 10),
            Text(
              'Results (${_last!.objectIds.length})',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            IntelligenceObjectChips(
              objectIds: _last!.objectIds,
              intelligence: widget.intelligence,
              onSelectNode: widget.onSelectNode,
            ),
          ] else if (!_busy)
            const EiEmptyState(
              icon: Icons.terminal,
              message: 'Run an Engineering Query against the synced diagram — results highlight matching nodes.',
            ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Query History',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            for (final entry in _history)
              Text('• $entry', style: const TextStyle(color: StudioColors.textDisabled, fontSize: 10.5)),
          ],
        ],
      ),
    );
  }
}
