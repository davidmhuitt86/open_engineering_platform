import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Validation Dashboard (WP-EKE-008): Validation Profiles, Validation
/// Sessions, Validation Reports, Findings, Rule Statistics, and
/// Severity summaries, over the Engineering Validation Engine
/// (WP-EKE-005) and Engineering Rules Engine (WP-EKE-004).
class ValidationDashboardPage extends ConsumerStatefulWidget {
  const ValidationDashboardPage({super.key});

  @override
  ConsumerState<ValidationDashboardPage> createState() => _ValidationDashboardPageState();
}

class _ValidationDashboardPageState extends ConsumerState<ValidationDashboardPage> {
  ValidationProfile _profile = ValidationProfile.complete;
  final _objectIdController = TextEditingController();
  String? _sessionId;
  bool _busy = false;
  String? _error;
  bool _graphReady = false;

  ({OepValidationReportSummary summary, List<OepValidationFinding> findings})? _report;
  OepValidationStatistics? _statistics;
  List<String> _allRules = const [];
  List<String> _enabledRules = const [];
  List<String> _disabledRules = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRuleStats();
    });
  }

  @override
  void dispose() {
    _objectIdController.dispose();
    super.dispose();
  }

  Future<void> _loadRuleStats() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    try {
      setState(() {
        _allRules = bridge.listAllRules();
        _enabledRules = bridge.listEnabledRules();
        _disabledRules = bridge.listDisabledRules();
      });
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _createSession() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sessionId = bridge.createValidationSession(_profile);
      setState(() {
        _sessionId = sessionId;
        _report = null;
        _statistics = null;
      });
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
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

  Future<void> _validateContext() async {
    if (_sessionId == null) return;
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _ensureGraph();
    try {
      final report = bridge.validateContext(_sessionId!);
      final stats = bridge.validationStatistics(_sessionId!);
      setState(() {
        _report = report;
        _statistics = stats;
      });
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _validateObject() async {
    if (_sessionId == null || _objectIdController.text.trim().isEmpty) return;
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _ensureGraph();
    try {
      final report = bridge.validateObject(_sessionId!, _objectIdController.text.trim());
      final stats = bridge.validationStatistics(_sessionId!);
      setState(() {
        _report = report;
        _statistics = stats;
      });
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
          EiSectionCard(
            title: 'Validation Session',
            icon: Icons.fact_check_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<ValidationProfile>(
                        initialValue: _profile,
                        decoration: const InputDecoration(labelText: 'Validation Profile', isDense: true),
                        items: [
                          for (final p in ValidationProfile.values)
                            DropdownMenuItem(value: p, child: Text(p.name, style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _profile = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _createSession,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Session'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_sessionId != null) ...[
                  EiKeyValueRow('Session ID', _sessionId!),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _validateContext,
                        icon: const Icon(Icons.dataset_outlined, size: 16),
                        label: const Text('Validate Whole Context'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _objectIdController,
                          decoration: const InputDecoration(labelText: 'Object ID', isDense: true),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _validateObject,
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Validate Object'),
                      ),
                    ],
                  ),
                ],
                if (_busy) const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ],
            ),
          ),
          if (_statistics != null)
            EiSectionCard(
              title: 'Severity Summary & Rule Statistics',
              icon: Icons.summarize_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, children: [
                    EiChip('Pass ${_report?.summary.passCount ?? 0}', color: StudioColors.success),
                    EiChip('Warning ${_report?.summary.warningCount ?? 0}', color: StudioColors.warning),
                    EiChip('Error ${_report?.summary.errorCount ?? 0}', color: StudioColors.error),
                    EiChip('Critical ${_report?.summary.criticalCount ?? 0}', color: StudioColors.error),
                  ]),
                  const SizedBox(height: 10),
                  EiKeyValueRow('Rules Evaluated', '${_statistics!.rulesEvaluated}'),
                  EiKeyValueRow('Rules Passed', '${_statistics!.rulesPassed}'),
                  EiKeyValueRow('Rules Failed', '${_statistics!.rulesFailed}'),
                  EiKeyValueRow('Rules N/A', '${_statistics!.rulesNotApplicable}'),
                  EiKeyValueRow('Rules Errored', '${_statistics!.rulesErrored}'),
                  EiKeyValueRow('Execution Time', '${_statistics!.executionTimeMs.toStringAsFixed(3)} ms'),
                ],
              ),
            ),
          if (_report != null)
            EiSectionCard(
              title: 'Findings (${_report!.findings.length})',
              icon: Icons.report_gmailerrorred_outlined,
              child: _report!.findings.isEmpty
                  ? const Text('No findings.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12))
                  : Column(
                      children: [
                        for (final finding in _report!.findings)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EiChip(finding.severity.name, color: severityColor(finding.severity.name)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(finding.message,
                                          style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                                      Text('Rule ${finding.ruleId} • ${finding.category.name}',
                                          style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10)),
                                      if (finding.recommendation.isNotEmpty)
                                        Text('Recommendation: ${finding.recommendation}',
                                            style: const TextStyle(color: StudioColors.textDisabled, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          EiSectionCard(
            title: 'Registered Rules',
            icon: Icons.rule_folder_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EiKeyValueRow('Total Rules', '${_allRules.length}'),
                EiKeyValueRow('Enabled', '${_enabledRules.length}'),
                EiKeyValueRow('Disabled', '${_disabledRules.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
