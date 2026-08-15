import '../../core/foundation/oep_api_types.dart';
import '../../core/models/engineering_object_summary.dart';
import '../models/commit_plan.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_status.dart';
import '../models/knowledge_session.dart';
import '../models/relationship_candidate.dart';

/// Pure Commit Planning logic (Work Package 012 STUDIO-TASK-000030) —
/// "Create a deterministic Commit Plan before any repository
/// modification occurs." Holds no state; every method takes a snapshot
/// of the active session and the currently open repository and returns
/// a value. Performs no Foundation I/O itself — [CommitTransactionService]
/// is the only place that actually calls the Foundation Bridge.
abstract final class CommitPlanService {
  /// Computes the [CommitPlan] for [session]'s current candidates and
  /// relationship candidates against the currently open repository.
  ///
  /// [isRepositoryOpen]/[openRepositoryName] drive the "Repository
  /// unavailable"/repository-mismatch validation errors (Error
  /// Handling). [objectList] (the Current Object List, `null` if it
  /// hasn't loaded) drives the "Duplicate IDs" advisory warning — an
  /// accepted candidate whose name collides with an existing Engineering
  /// Object's name is still included in [CommitPlan.newObjects] (Foundation
  /// itself does not enforce object name uniqueness) but is flagged.
  /// [currentStatistics] becomes [CommitPlan.existingObjectCount] and
  /// [CommitPlan.currentStatistics] directly.
  static CommitPlan computeCommitPlan({
    required KnowledgeSession session,
    required List<KnowledgeCandidate> candidates,
    required List<RelationshipCandidate> relationshipCandidates,
    required bool isRepositoryOpen,
    String? openRepositoryName,
    List<EngineeringObjectSummary>? objectList,
    RepositoryStatistics? currentStatistics,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (!isRepositoryOpen) {
      errors.add('No repository is open. Open a repository before committing.');
    } else if (session.repositoryName.trim().isNotEmpty &&
        openRepositoryName != null &&
        openRepositoryName.trim().toLowerCase() != session.repositoryName.trim().toLowerCase()) {
      errors.add(
        'This session was created for repository "${session.repositoryName}", but '
        '"$openRepositoryName" is currently open. Open the correct repository before committing.',
      );
    }

    final existingNames = {for (final object in objectList ?? const []) object.name.trim().toLowerCase()};

    final newObjects = <KnowledgeCandidate>[];
    var pendingCount = 0;
    var rejectedCount = 0;
    var unmappedTypeCount = 0;
    var alreadyCommittedObjectCount = 0;

    for (final candidate in candidates) {
      if (candidate.isCommitted) {
        alreadyCommittedObjectCount++;
        continue;
      }
      switch (candidate.status) {
        case KnowledgeCandidateStatus.pending:
          pendingCount++;
          continue;
        case KnowledgeCandidateStatus.rejected:
          rejectedCount++;
          continue;
        case KnowledgeCandidateStatus.accepted:
          break;
      }
      if (candidate.type.foundationCategory == null) {
        unmappedTypeCount++;
        continue;
      }
      newObjects.add(candidate);
      if (existingNames.contains(candidate.name.trim().toLowerCase())) {
        warnings.add('An object named "${candidate.name}" already exists in this repository.');
      }
    }

    if (pendingCount > 0) {
      warnings.add(
        '$pendingCount candidate${pendingCount == 1 ? '' : 's'} still pending review (excluded from this commit).',
      );
    }
    if (rejectedCount > 0) {
      warnings.add('$rejectedCount rejected candidate${rejectedCount == 1 ? '' : 's'} excluded from this commit.');
    }
    if (unmappedTypeCount > 0) {
      warnings.add(
        '$unmappedTypeCount candidate${unmappedTypeCount == 1 ? '' : 's'} excluded: no Foundation Engineering '
        'Object type exists yet for their Knowledge Candidate type.',
      );
    }
    if (alreadyCommittedObjectCount > 0) {
      warnings.add(
        '$alreadyCommittedObjectCount candidate${alreadyCommittedObjectCount == 1 ? '' : 's'} already committed '
        'in a previous commit.',
      );
    }

    // Every candidate ID that will have a Foundation object_id once this
    // plan executes — either already committed, or newly committing now.
    final resolvableCandidateIds = <String>{
      for (final candidate in candidates)
        if (candidate.isCommitted) candidate.id,
      for (final candidate in newObjects) candidate.id,
    };

    final newRelationships = <RelationshipCandidate>[];
    var excludedRelationshipCount = 0;
    var alreadyCommittedRelationshipCount = 0;
    for (final relationship in relationshipCandidates) {
      if (relationship.isCommitted) {
        alreadyCommittedRelationshipCount++;
        continue;
      }
      if (!resolvableCandidateIds.contains(relationship.sourceCandidateId) ||
          !resolvableCandidateIds.contains(relationship.targetCandidateId)) {
        excludedRelationshipCount++;
        continue;
      }
      newRelationships.add(relationship);
    }
    if (excludedRelationshipCount > 0) {
      warnings.add(
        '$excludedRelationshipCount relationship candidate${excludedRelationshipCount == 1 ? '' : 's'} excluded: '
        'both endpoints must be committed, in this commit or an earlier one.',
      );
    }
    if (alreadyCommittedRelationshipCount > 0) {
      warnings.add(
        '$alreadyCommittedRelationshipCount relationship candidate${alreadyCommittedRelationshipCount == 1 ? '' : 's'} '
        'already committed in a previous commit.',
      );
    }

    return CommitPlan(
      newObjects: newObjects,
      newRelationships: newRelationships,
      existingObjectCount: currentStatistics?.totalObjectCount ?? 0,
      mergeOperationCount: 0,
      validationErrors: errors,
      warnings: warnings,
      currentStatistics: currentStatistics,
    );
  }
}
