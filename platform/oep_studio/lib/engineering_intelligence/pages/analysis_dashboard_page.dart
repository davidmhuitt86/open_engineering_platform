import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Analysis Dashboard (WP-EKE-008): Dependency Analysis, Impact
/// Analysis, Reachability, Root Cause, and overall Engineering Health,
/// over the Engineering Analysis & Reasoning Engine (WP-EKE-006) and
/// the Engineering Intelligence Platform (WP-EKE-007).
class AnalysisDashboardPage extends ConsumerStatefulWidget {
  const AnalysisDashboardPage({super.key});

  @override
  ConsumerState<AnalysisDashboardPage> createState() => _AnalysisDashboardPageState();
}

class _AnalysisDashboardPageState extends ConsumerState<AnalysisDashboardPage> {
  final _objectIdController = TextEditingController();
  final _targetIdController = TextEditingController();
  bool _busy = false;
  bool _graphReady = false;
  String? _error;
  String? _mode;

  ({int maxDepth, List<String> dependencyObjectIds, List<String> dependencyRelationshipIds})? _dependencies;
  ({int maxDepth, List<String> affectedObjectIds, List<String> affectedRelationshipIds})? _impact;
  ({bool reachable, List<String> path})? _reachability;
  ({List<String> candidateRootCauses, List<String> failureChain})? _rootCause;
  OepEngineeringHealthReport? _health;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadHealth();
    });
  }

  @override
  void dispose() {
    _objectIdController.dispose();
    _targetIdController.dispose();
    super.dispose();
  }

  Future<void> _ensureGraph() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null || _graphReady) return;
    try {
      bridge.loadEngineeringGraph();
      bridge.buildKnowledgeGraph();
      _graphReady = true;
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _loadHealth() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    await _ensureGraph();
    try {
      final health = bridge.engineeringHealth();
      setState(() => _health = health);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _run(String mode) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    final objectId = _objectIdController.text.trim();
    if (objectId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _mode = mode;
    });
    await _ensureGraph();
    try {
      switch (mode) {
        case 'dependencies':
          setState(() => _dependencies = bridge.analyzeDependencies(objectId));
        case 'impact':
          setState(() => _impact = bridge.analyzeImpact(objectId));
        case 'reachability':
          final target = _targetIdController.text.trim();
          if (target.isEmpty) break;
          setState(() => _reachability = bridge.analyzeReachability(objectId, target));
        case 'rootCause':
          setState(() => _rootCause = bridge.analyzeRootCause(objectId));
      }
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) EiErrorBanner(message: _error!),
          if (_health != null)
            EiSectionCard(
              title: 'Engineering Health',
              icon: Icons.monitor_heart_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(_health!.healthScore.toStringAsFixed(1),
                        style: const TextStyle(color: StudioColors.selection, fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Text('/ 100', style: TextStyle(color: StudioColors.textSecondary, fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    EiChip('Passed ${_health!.passed}', color: StudioColors.success),
                    EiChip('Warnings ${_health!.warnings}', color: StudioColors.warning),
                    EiChip('Failed ${_health!.failed}', color: StudioColors.error),
                    EiChip('Errors ${_health!.errors}', color: StudioColors.error),
                    EiChip('Critical ${_health!.critical}', color: StudioColors.error),
                  ]),
                  const SizedBox(height: 8),
                  Text(_health!.summary, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          EiSectionCard(
            title: 'Analysis Inputs',
            icon: Icons.insights_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _objectIdController,
                  decoration: const InputDecoration(labelText: 'Object ID (or Symptom Object ID for Root Cause)', isDense: true),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _targetIdController,
                  decoration: const InputDecoration(labelText: 'Target Object ID (for Reachability)', isDense: true),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(onPressed: _busy ? null : () => _run('dependencies'), child: const Text('Dependency Analysis')),
                    ElevatedButton(onPressed: _busy ? null : () => _run('impact'), child: const Text('Impact Analysis')),
                    ElevatedButton(onPressed: _busy ? null : () => _run('reachability'), child: const Text('Reachability')),
                    ElevatedButton(onPressed: _busy ? null : () => _run('rootCause'), child: const Text('Root Cause')),
                    if (_busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ],
            ),
          ),
          if (_mode == 'dependencies' && _dependencies != null)
            EiSectionCard(
              title: 'Dependency Analysis',
              icon: Icons.account_tree_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Max Depth', '${_dependencies!.maxDepth}'),
                  EiKeyValueRow('Dependency Objects', '${_dependencies!.dependencyObjectIds.length}'),
                  EiKeyValueRow('Dependency Relationships', '${_dependencies!.dependencyRelationshipIds.length}'),
                  const SizedBox(height: 6),
                  Text(_dependencies!.dependencyObjectIds.join(', '),
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                ],
              ),
            ),
          if (_mode == 'impact' && _impact != null)
            EiSectionCard(
              title: 'Impact Analysis',
              icon: Icons.bolt_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Max Depth', '${_impact!.maxDepth}'),
                  EiKeyValueRow('Affected Objects', '${_impact!.affectedObjectIds.length}'),
                  EiKeyValueRow('Affected Relationships', '${_impact!.affectedRelationshipIds.length}'),
                  const SizedBox(height: 6),
                  Text(_impact!.affectedObjectIds.join(', '),
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                ],
              ),
            ),
          if (_mode == 'reachability' && _reachability != null)
            EiSectionCard(
              title: 'Reachability',
              icon: Icons.alt_route_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Reachable', _reachability!.reachable ? 'Yes' : 'No',
                      valueColor: _reachability!.reachable ? StudioColors.success : StudioColors.error),
                  EiKeyValueRow('Path', _reachability!.path.isEmpty ? '(none)' : _reachability!.path.join(' -> ')),
                ],
              ),
            ),
          if (_mode == 'rootCause' && _rootCause != null)
            EiSectionCard(
              title: 'Root Cause Analysis',
              icon: Icons.troubleshoot_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Candidate Root Causes',
                      _rootCause!.candidateRootCauses.isEmpty ? '(none)' : _rootCause!.candidateRootCauses.join(', ')),
                  EiKeyValueRow('Failure Chain',
                      _rootCause!.failureChain.isEmpty ? '(none)' : _rootCause!.failureChain.join(' -> ')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
