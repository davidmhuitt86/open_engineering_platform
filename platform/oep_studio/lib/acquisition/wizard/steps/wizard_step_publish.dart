import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/foundation_runtime_service.dart';
import '../../../core/theme/studio_colors.dart';
import '../../../knowledge/workspaces/commit_preview_panel.dart';
import '../acquisition_wizard_controller.dart';

/// Wizard Step 8 -- "Publish" in SPEC-ENG-ACQ-001's terminology
/// (WP-EAM-003 §12/§20).
///
/// **Terminology note (documented per WP-EAM-003 §20):** the spec names
/// this step "Publish," but the current architecture makes a real
/// distinction the spec's original one-word step name doesn't: Reference
/// Vault **publication** (the artifact becoming a permanent, immutable
/// Vault entry) already happened automatically back in Step 5/6, the
/// moment acquisition succeeded. What THIS step performs is an entirely
/// different, much more consequential operation -- an explicit,
/// engineer-confirmed **Commit** that creates real Foundation Engineering
/// Objects/Relationships in the open Repository. Collapsing those two
/// concepts under one "Publish" button would blur exactly the boundary
/// WP-EAM-003 §16 makes non-negotiable ("Must NEVER automatically ...
/// modify Repository knowledge"). This step therefore keeps both ideas
/// visible: a status summary of what already happened automatically
/// (Vault publication, Chain of Custody, ingestion), followed by the
/// real [CommitPreviewPanel] -- the same widget Knowledge Studio's own
/// "Commit Summary" tab uses, with its own explicit confirmation dialog
/// before anything reaches `FoundationRuntimeNotifier.commitToFoundation()`.
class WizardStepPublish extends ConsumerWidget {
  const WizardStepPublish({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final published = controller.runStatus == AcquisitionRunStatus.completed;
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final committed = foundation.latestCommitReport?.success == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Publish & Commit',
                  style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (!published)
                const Text('Run acquisition first before publishing.',
                    style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5))
              else ...[
                _StatusLine('Artifact Stored in Reference Vault', true, detail: controller.vaultPath),
                _StatusLine('SHA-256 Verified', true, detail: controller.sha256Hash),
                _StatusLine('Chain of Custody Complete', true, detail: 'Recorded for ${controller.engineer}'),
                _StatusLine(
                  'Candidate Objects Created',
                  controller.hasKnowledgeSession,
                  detail: switch (controller.ingestionStatus) {
                    WizardIngestionStatus.completed => 'Knowledge Session ready for review',
                    WizardIngestionStatus.partial => 'Knowledge Session ready (partial results)',
                    WizardIngestionStatus.failed =>
                      'Ingestion failed -- ${controller.ingestionErrorMessage ?? 'see Candidate Preview'}',
                    WizardIngestionStatus.blockedNoRepository =>
                      'Deferred -- open a Foundation Repository and retry ingestion on Candidate Preview',
                    _ => 'Not yet started',
                  },
                ),
                _StatusLine(
                  'Repository Commit',
                  committed,
                  detail: committed
                      ? 'Committed by explicit engineer confirmation below'
                      : 'Not committed yet -- nothing has changed in the Repository',
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: controller.hasKnowledgeSession
              ? const CommitPreviewPanel()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Commit Preview becomes available once ingestion has produced a Knowledge Session to '
                    'review (see Candidate Preview / Engineering Review).',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12.5),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.label, this.done, {this.detail});
  final String label;
  final bool done;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 16,
              color: done ? StudioColors.success : StudioColors.textDisabled),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: done ? StudioColors.textPrimary : StudioColors.textDisabled, fontSize: 13)),
                if (detail != null)
                  Text(detail!, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
