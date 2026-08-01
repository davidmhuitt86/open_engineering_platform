import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Recommendation Panel (WP-EKE-008): deterministic engineering
/// recommendations. Each recommendation shows Supporting Evidence,
/// Referenced Rules, Referenced Validation, and Referenced Engineering
/// Objects — resolved by cross-referencing each
/// [FoundationBridge.getRecommendation] evidence id against
/// [FoundationBridge.getEvidenceNode]'s [EvidenceKind] (object, rule,
/// or validation finding), never fabricated.
///
/// Uses [FoundationBridge.engineeringRecommendations] (WP-EKE-007, the
/// Engineering Intelligence Platform's higher-level entry point) to get
/// the recommendation ids for an object, and a Reasoning Session
/// (WP-EKE-006, same session-scoping [FoundationBridge.getRecommendation]
/// requires) to resolve each one's full detail plus supporting
/// evidence.
class RecommendationPanelPage extends ConsumerStatefulWidget {
  const RecommendationPanelPage({super.key});

  @override
  ConsumerState<RecommendationPanelPage> createState() => _RecommendationPanelPageState();
}

class _RecommendationPanelPageState extends ConsumerState<RecommendationPanelPage> {
  String? _objectId;
  bool _busy = false;
  bool _graphReady = false;
  String? _error;
  List<String> _recommendationIds = const [];
  String? _sessionId;
  final Map<String, ({OepRecommendation recommendation, List<String> supportingEvidenceIds})> _details = {};
  final Map<String, OepEvidenceNode> _evidenceCache = {};

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

  Future<void> _load() async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null || _objectId == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _details.clear();
      _evidenceCache.clear();
    });
    await _ensureGraph();
    try {
      // The Engineering Intelligence Platform's top-level entry point
      // (WP-EKE-007) for "what recommendations exist for this object" —
      // used instead of reaching past it into the lower-level Rules/
      // Validation engines directly, per this Work Package's "No page
      // may bypass the Intelligence Platform" constraint.
      final recommendationIds = bridge.engineeringRecommendations(_objectId!);
      // getRecommendation's full detail (supporting evidence ids) is
      // scoped to a Reasoning Session, so one is created here purely to
      // resolve that detail — the recommendation ids themselves came
      // from the Platform-level call above, not from this session.
      final sessionId = bridge.createReasoningSession('Recommendations for $_objectId', [_objectId!]);
      bridge.executeReasoning(sessionId);
      setState(() {
        _recommendationIds = recommendationIds;
        _sessionId = sessionId;
      });
      for (final id in recommendationIds) {
        try {
          final detail = bridge.getRecommendation(sessionId, id);
          setState(() => _details[id] = detail);
        } on FoundationBridgeException {
          // This recommendation id didn't come from this session's own
          // reasoning report (a normal outcome — engineeringRecommendations
          // and this session's own recommendationIds are not guaranteed
          // to be identical); skip it rather than showing a stale error.
        }
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

  String _evidenceLabel(EvidenceKind kind) {
    switch (kind) {
      case EvidenceKind.relationship:
        return 'Relationship';
      case EvidenceKind.ruleViolation:
        return 'Rule';
      case EvidenceKind.validationFinding:
        return 'Validation Finding';
      case EvidenceKind.analysisResult:
        return 'Analysis Result';
      case EvidenceKind.objectProperty:
        return 'Engineering Object';
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
            title: 'Get Recommendations',
            icon: Icons.lightbulb_outline,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _objectId,
                    decoration: const InputDecoration(labelText: 'Engineering Object', isDense: true),
                    items: [for (final o in objects) DropdownMenuItem(value: o.objectId, child: Text(o.name, style: const TextStyle(fontSize: 12)))],
                    onChanged: (v) => setState(() => _objectId = v),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _busy || _objectId == null ? null : _load,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Recommend'),
                ),
                if (_busy) ...[
                  const SizedBox(width: 12),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
          ),
          if (_details.isEmpty && !_busy && _recommendationIds.isNotEmpty)
            const EiEmptyState(icon: Icons.lightbulb_outline, message: 'Recommendations were found but detail could not be resolved for this session.'),
          if (_recommendationIds.isEmpty && !_busy && _objectId != null)
            const EiEmptyState(icon: Icons.check_circle_outline, message: 'No recommendations for this object.'),
          for (final id in _details.keys)
            EiSectionCard(
              title: _details[id]!.recommendation.message,
              icon: Icons.lightbulb_outline,
              trailing: EiChip(_details[id]!.recommendation.kind.name),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Referenced Object', _details[id]!.recommendation.objectId),
                  const SizedBox(height: 8),
                  const Text('Supporting Evidence', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  if (_details[id]!.supportingEvidenceIds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('(none)', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                    )
                  else
                    for (final evidenceId in _details[id]!.supportingEvidenceIds)
                      Builder(builder: (context) {
                        final node = _evidence(evidenceId);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              EiChip(node == null ? '?' : _evidenceLabel(node.kind)),
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
