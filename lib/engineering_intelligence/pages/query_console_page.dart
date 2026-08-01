import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Query Console (WP-EKE-008): an interactive interface over the
/// Engineering Query Engine (WP-EKE-003). Shows the Query being built,
/// its Execution Plan ([FoundationBridge.planQuery]), Results and
/// Statistics ([FoundationBridge.executeQuery]), and Execution Time.
class QueryConsolePage extends ConsumerStatefulWidget {
  const QueryConsolePage({super.key});

  @override
  ConsumerState<QueryConsolePage> createState() => _QueryConsolePageState();
}

class _QueryConsolePageState extends ConsumerState<QueryConsolePage> {
  QueryCategory _category = QueryCategory.type;
  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  bool _graphReady = false;
  bool _busy = false;
  String? _error;

  ({OepQueryPlan plan, List<String> indexesUsed, List<String> executionOrder})? _plan;
  ({OepQueryResultSummary summary, List<String> objectIds, List<String> relationshipIds})? _result;

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  Future<void> _ensureGraph() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null || _graphReady) return;
    try {
      bridge.buildKnowledgeGraph();
      setState(() => _graphReady = true);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _runPlan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await _ensureGraph();
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      final plan = bridge.planQuery(
        category: _category,
        primaryObjectId: _primaryController.text.trim(),
        secondaryObjectId: _secondaryController.text.trim(),
      );
      setState(() => _plan = plan);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _execute() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await _ensureGraph();
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      final result = bridge.executeQuery(
        category: _category,
        primaryObjectId: _primaryController.text.trim(),
        secondaryObjectId: _secondaryController.text.trim(),
      );
      setState(() => _result = result);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final byId = {for (final o in foundation.objectList ?? const []) o.objectId: o.name};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) EiErrorBanner(message: _error!),
          EiSectionCard(
            title: 'Query',
            icon: Icons.terminal_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<QueryCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Query Category', isDense: true),
                    items: [
                      for (final c in QueryCategory.values)
                        DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _primaryController,
                  decoration: const InputDecoration(labelText: 'Primary Object ID', isDense: true),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _secondaryController,
                  decoration: const InputDecoration(labelText: 'Secondary Object ID (e.g. shortest path target)', isDense: true),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _runPlan,
                      icon: const Icon(Icons.route_outlined, size: 16),
                      label: const Text('Plan'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _execute,
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Execute'),
                    ),
                    if (_busy) ...[
                      const SizedBox(width: 12),
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_plan != null)
            EiSectionCard(
              title: 'Execution Plan',
              icon: Icons.route_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Category', _plan!.plan.category.name),
                  EiKeyValueRow('Strategy', _plan!.plan.strategy.name),
                  EiKeyValueRow('Estimated Cost', _plan!.plan.estimatedCost.toStringAsFixed(2)),
                  EiKeyValueRow('Indexes Used', _plan!.indexesUsed.isEmpty ? '(none)' : _plan!.indexesUsed.join(', ')),
                  EiKeyValueRow(
                    'Execution Order',
                    _plan!.executionOrder.isEmpty ? '(none)' : _plan!.executionOrder.join(' -> '),
                  ),
                ],
              ),
            ),
          if (_result != null) ...[
            EiSectionCard(
              title: 'Statistics & Execution Time',
              icon: Icons.speed_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Execution Time', '${_result!.summary.executionTimeMs.toStringAsFixed(3)} ms'),
                  EiKeyValueRow('Objects Examined', '${_result!.summary.objectsExamined}'),
                  EiKeyValueRow('Relationships Examined', '${_result!.summary.relationshipsExamined}'),
                  EiKeyValueRow('Traversal Depth', '${_result!.summary.traversalDepth}'),
                  EiKeyValueRow('Result Count', '${_result!.summary.resultCount}'),
                  EiKeyValueRow('Traversal Summary', _result!.summary.traversalSummary),
                ],
              ),
            ),
            EiSectionCard(
              title: 'Results (${_result!.objectIds.length} objects, ${_result!.relationshipIds.length} relationships)',
              icon: Icons.list_alt_outlined,
              child: _result!.objectIds.isEmpty
                  ? const Text('No matching objects.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final id in _result!.objectIds)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('${byId[id] ?? id}  ($id)',
                                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
