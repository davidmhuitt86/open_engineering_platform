import '../../core/foundation/oep_api_types.dart';
import 'knowledge_candidate.dart';
import 'relationship_candidate.dart';

/// A deterministic Commit Plan (Work Package 012 STUDIO-TASK-000030):
/// "Create a deterministic Commit Plan before any repository
/// modification occurs. The Commit Plan represents exactly what
/// Foundation will receive." Computed on demand by
/// `CommitPlanService.computeCommitPlan` from the Connection Manager's
/// existing candidate/relationship-candidate/repository-statistics/
/// object-list state — never stored, the same derived-not-stored
/// discipline every prior computed model in this project follows
/// (`CommitPreview`, which this supersedes; `CandidateValidationResult`;
/// `SessionHealthMetrics`).
///
/// Superseding, not extending, Work Package 008's `CommitPreview`:
/// that model existed specifically because "Commit remains disabled"
/// (Repository Commit was out of scope). Now that a real Commit exists,
/// one real plan of what commit will do supersedes a separate simulated
/// preview of what it would have done — keeping both would mean two
/// overlapping "what would committing do" concepts with no
/// architectural reason for the split.
class CommitPlan {
  const CommitPlan({
    required this.newObjects,
    required this.newRelationships,
    required this.existingObjectCount,
    required this.mergeOperationCount,
    required this.validationErrors,
    required this.warnings,
    required this.currentStatistics,
  });

  /// Knowledge Candidates that will become new Engineering Objects —
  /// accepted, not already committed, and of a type Foundation's
  /// `oep_object_type_t` has an entry for (see
  /// `KnowledgeCandidateType.foundationCategory`).
  final List<KnowledgeCandidate> newObjects;

  /// Relationship Candidates that will become new Foundation
  /// Relationships — not already committed, with both endpoints
  /// resolvable to a Foundation object id (either newly committing in
  /// this same plan, or already committed by an earlier commit of this
  /// session).
  final List<RelationshipCandidate> newRelationships;

  /// How many Engineering Objects already exist in the currently open
  /// repository — context ("Existing Objects"), not something this
  /// commit will touch.
  final int existingObjectCount;

  /// Always `0` — no repository-matching/duplicate-detection capability
  /// exists (same honest-zero display Work Package 008's
  /// `CommitPreview.mergedObjectCount` already used, for the same
  /// reason: merging presupposes matching a candidate against an
  /// existing object, which nothing in this or any prior work package
  /// implements).
  final int mergeOperationCount;

  /// Blocking findings — a non-empty list means [canCommit] is `false`
  /// regardless of how much there is to commit (this work package:
  /// "Commit shall remain disabled until validation succeeds").
  final List<String> validationErrors;

  /// Non-blocking findings — e.g. candidates still pending review,
  /// candidates excluded because their type has no Foundation object
  /// type, a name that collides with an existing Engineering Object
  /// (Error Handling: "Duplicate IDs" — Foundation itself does not
  /// enforce object name uniqueness, so this is advisory, not
  /// rejected).
  final List<String> warnings;

  /// The currently open Foundation repository's statistics, exactly as
  /// Foundation reported them — `null` if no repository is open or
  /// statistics haven't loaded.
  final RepositoryStatistics? currentStatistics;

  /// "Commit shall remain disabled until validation succeeds" — true
  /// only when there are no blocking errors *and* there is at least one
  /// new object or relationship to commit (an empty plan has nothing
  /// meaningful to commit, even though it is not, strictly, invalid).
  bool get canCommit => validationErrors.isEmpty && (newObjects.isNotEmpty || newRelationships.isNotEmpty);
}
