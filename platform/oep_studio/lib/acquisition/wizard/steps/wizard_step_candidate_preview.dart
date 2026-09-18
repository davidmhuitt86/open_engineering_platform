import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/foundation_runtime_service.dart';
import '../../../core/services/foundation_runtime_state.dart';
import '../../../core/theme/studio_colors.dart';
import '../../../knowledge/models/knowledge_candidate.dart';
import '../../../knowledge/models/knowledge_candidate_type.dart';
import '../acquisition_wizard_controller.dart';

/// Wizard Step 6 -- "Candidate Knowledge Preview" (WP-EAM-003 §10).
///
/// Replaces the WP-EAM-002 static placeholder with a real, read-only
/// summary of the actual [KnowledgeCandidate]/`RelationshipCandidate`/
/// evidence produced by the real ingestion this wizard now triggers
/// automatically (`AcquisitionWizardController._ingest` ->
/// `ReferenceVaultIngestionWorkflow` -> `FoundationRuntimeNotifier`).
/// Reuses the existing [KnowledgeCandidate]/`RelationshipCandidate`
/// models directly -- no second candidate model is introduced -- and the
/// same expand/collapse (`ExpansionTile`) pattern the prior placeholder
/// already used. This step never fabricates a candidate: every count and
/// name shown comes straight from `FoundationServiceState.candidates`/
/// `relationshipCandidates`/`evidenceRegions`, the same state
/// `EngineeringReviewPanel` (Step 7) reads. This step is display-only --
/// review actions (Accept/Reject/Edit/Delete) happen on the real
/// candidates in Step 7, not here.
class WizardStepCandidatePreview extends ConsumerWidget {
  const WizardStepCandidatePreview({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    return switch (controller.ingestionStatus) {
      WizardIngestionStatus.notStarted || WizardIngestionStatus.ingesting => const _IngestingView(),
      WizardIngestionStatus.blockedNoRepository => _BlockedView(controller: controller),
      WizardIngestionStatus.failed => _FailedView(controller: controller),
      WizardIngestionStatus.completed ||
      WizardIngestionStatus.partial =>
        _CandidateSummaryView(controller: controller, foundation: foundation),
    };
  }
}

class _IngestingView extends StatelessWidget {
  const _IngestingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Ingesting into the Universal Ingestion Framework…',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.controller});
  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudioColors.warning.withValues(alpha: 0.1),
              border: Border.all(color: StudioColors.warning.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.folder_off_outlined, size: 16, color: StudioColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No Foundation Repository is open, so the Knowledge Session that ingestion would produce '
                    'has nowhere to bind. The acquired artifact is already safely stored in the Reference '
                    'Vault. Open a Repository, then retry ingestion below.',
                    style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.retryIngestion,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry Ingestion'),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.controller});
  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Knowledge Extraction Failed',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            controller.ingestionErrorMessage ?? 'Ingestion failed for an unknown reason.',
            style: const TextStyle(color: StudioColors.error, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'No candidates were generated. The acquired artifact remains safely stored in the Reference '
            'Vault -- nothing was lost. Nothing is fabricated here to make it look like review can continue.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: controller.retryIngestion,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry Ingestion'),
          ),
        ],
      ),
    );
  }
}

class _CandidateSummaryView extends StatelessWidget {
  const _CandidateSummaryView({required this.controller, required this.foundation});
  final AcquisitionWizardController controller;
  final FoundationServiceState foundation;

  @override
  Widget build(BuildContext context) {
    final candidates = foundation.candidates;
    final relationships = foundation.relationshipCandidates;
    final evidence = foundation.evidenceRegions;
    final byType = <KnowledgeCandidateType, List<KnowledgeCandidate>>{
      for (final type in KnowledgeCandidateType.values) type: [],
    };
    for (final candidate in candidates) {
      byType[candidate.type]!.add(candidate);
    }
    final partial = controller.ingestionStatus == WizardIngestionStatus.partial;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Candidate Knowledge Preview',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            partial
                ? 'Ingestion completed with partial results. The candidates below are real -- generated by the '
                    'Universal Ingestion Framework from the acquired artifact -- but some stages did not fully '
                    'succeed. Review them in detail on the next step.'
                : 'These candidates were generated by the Universal Ingestion Framework from the acquired '
                    'artifact. Nothing here is committed to the Repository yet -- review happens on the next '
                    'step, and only an explicit Commit changes the Repository.',
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          for (final type in KnowledgeCandidateType.values)
            _CategoryTile(title: type.label, count: byType[type]!.length, names: [for (final c in byType[type]!) c.name]),
          _CategoryTile(
            title: 'Relationships',
            count: relationships.length,
            names: [for (final r in relationships) '${r.type.name}: ${r.sourceCandidateId} → ${r.targetCandidateId}'],
          ),
          _CategoryTile(title: 'Evidence', count: evidence.length, names: [for (final e in evidence) e.label]),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.title, required this.count, required this.names});
  final String title;
  final int count;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      // Keeps every category's real content (or honest "None generated"
      // disclosure) in the tree even while collapsed, so an engineer
      // scanning collapsed titles/subtitles and an automated check both
      // see the same real data -- never a difference between what's
      // rendered and what's true.
      maintainState: true,
      title: Text(title, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text('$count candidate${count == 1 ? '' : 's'}',
          style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11)),
      children: [
        if (names.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('None generated for this artifact.', style: TextStyle(color: StudioColors.textDisabled, fontSize: 12)),
            ),
          )
        else
          for (final name in names)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
              ),
            ),
      ],
    );
  }
}
