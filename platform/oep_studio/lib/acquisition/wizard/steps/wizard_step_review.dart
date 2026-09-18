import 'package:flutter/material.dart';

import '../../../knowledge/review/engineering_review_panel.dart';

/// Wizard Step 7 -- "Engineering Review" (WP-EAM-003 §11).
///
/// Replaces the WP-EAM-002 static, disconnected placeholder by hosting
/// the real [EngineeringReviewPanel] directly -- the same widget Knowledge
/// Studio's own "Engineering Review" tab uses, driven by the same
/// `foundationRuntimeServiceProvider` the wizard's ingestion step already
/// populated via `FoundationRuntimeNotifier.loadKnowledgeSessionRecord`.
/// No `WizardReviewService`/`WizardCandidateController`/
/// `WizardCandidateRepository` is introduced -- Accept/Reject/Edit/
/// Duplicate/Delete on Knowledge Candidates and Relationship Candidates
/// all go through the exact same, already-existing
/// `FoundationRuntimeNotifier` methods `EngineeringReviewPanel` always
/// used. Candidate acceptance/rejection therefore remains entirely
/// human-controlled -- this wizard step performs no automatic accept.
class WizardStepReview extends StatelessWidget {
  const WizardStepReview({super.key});

  @override
  Widget build(BuildContext context) {
    return const EngineeringReviewPanel();
  }
}
