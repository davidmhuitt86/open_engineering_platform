import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Reasoning Dashboard (WP-EKE-008): Reasoning Sessions, Evidence
/// Graph, Engineering Conclusions, Confidence, and Supporting Evidence,
/// over the Engineering Analysis & Reasoning Engine's Reasoning surface
/// (WP-EKE-006).
class ReasoningDashboardPage extends ConsumerStatefulWidget {
  const ReasoningDashboardPage({super.key});

  @override
  ConsumerState<ReasoningDashboardPage> createState() => _ReasoningDashboardPageState();
}

class _ReasoningDashboardPageState extends ConsumerState<ReasoningDashboardPage> {
  final _objectiveController = TextEditingController();
  String? _startingObjectId;
  String? _sessionId;
  bool _busy = false;
  bool _graphReady = false;
  String? _error;

  ({OepReasoningSummary summary, List<String> conclusionIds, List<String> recommendationIds})? _reasoningResult;
  final Map<String, ({OepConclusion conclusion, List<String> supportingEvidenceIds, List<String> referencedObjects, List<String> referencedRules, List<String> referencedFindings})> _conclusions = {};
  final Map<String, OepEvidenceNode> _evidenceCache = {};

  @override
  void dispose() {
    _objectiveController.dispose();
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

  Future<void> _createAndRun() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null || _startingObjectId == null || _objectiveController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _conclusions.clear();
      _evidenceCache.clear();
    });
    await _ensureGraph();
    try {
      final sessionId = bridge.createReasoningSession(_objectiveController.text.trim(), [_startingObjectId!]);
      final result = bridge.executeReasoning(sessionId);
      setState(() {
        _sessionId = sessionId;
        _reasoningResult = result;
      });
      for (final conclusionId in result.conclusionIds) {
        final detail = bridge.getConclusion(sessionId, conclusionId);
        setState(() => _conclusions[conclusionId] = detail);
      }
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  OepEvidenceNode? _evidence(String evidenceId) {
    if (_evidenceCache.containsKey(evidenceId)) return _evidenceCache[evidenceId];
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null || _sessionId == null) return null;
    try {
      final node = bridge.getEvidenceNode(_sessionId!, evidenceId);
      _evidenceCache[evidenceId] = node;
      return node;
    } on FoundationBridgeException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final objects = foundation.objectList ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) EiErrorBanner(message: _error!),
          EiSectionCard(
            title: 'New Reasoning Session',
            icon: Icons.psychology_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _objectiveController,
                  decoration: const InputDecoration(labelText: 'Objective', isDense: true),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _startingObjectId,
                  decoration: const InputDecoration(labelText: 'Starting Object', isDense: true),
                  items: [for (final o in objects) DropdownMenuItem(value: o.objectId, child: Text(o.name, style: const TextStyle(fontSize: 12)))],
                  onChanged: (v) => setState(() => _startingObjectId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _createAndRun,
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Create Session & Execute Reasoning'),
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
          if (_reasoningResult != null)
            EiSectionCard(
              title: 'Reasoning Summary',
              icon: Icons.summarize_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Session ID', _sessionId ?? ''),
                  EiKeyValueRow('Conclusions', '${_reasoningResult!.summary.conclusionCount}'),
                  EiKeyValueRow('Recommendations', '${_reasoningResult!.summary.recommendationCount}'),
                  EiKeyValueRow('Execution Time', '${_reasoningResult!.summary.executionTimeMs.toStringAsFixed(3)} ms'),
                ],
              ),
            ),
          for (final conclusionId in _conclusions.keys)
            EiSectionCard(
              title: 'Conclusion — ${_conclusions[conclusionId]!.conclusion.statement}',
              icon: Icons.check_circle_outline,
              trailing: EiChip('${(_conclusions[conclusionId]!.conclusion.confidence * 100).toStringAsFixed(0)}% confidence'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_conclusions[conclusionId]!.conclusion.explanation,
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  EiKeyValueRow('Referenced Objects', _conclusions[conclusionId]!.referencedObjects.isEmpty ? '(none)' : _conclusions[conclusionId]!.referencedObjects.join(', ')),
                  EiKeyValueRow('Referenced Rules', _conclusions[conclusionId]!.referencedRules.isEmpty ? '(none)' : _conclusions[conclusionId]!.referencedRules.join(', ')),
                  EiKeyValueRow('Referenced Findings', _conclusions[conclusionId]!.referencedFindings.isEmpty ? '(none)' : _conclusions[conclusionId]!.referencedFindings.join(', ')),
                  const SizedBox(height: 8),
                  const Text('Evidence Graph', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  for (final evidenceId in _conclusions[conclusionId]!.supportingEvidenceIds)
                    Builder(builder: (context) {
                      final node = _evidence(evidenceId);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            EiChip(node?.kind.name ?? '?', color: StudioColors.info),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                node == null ? evidenceId : '${node.referenceId} — ${node.detail}',
                                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
