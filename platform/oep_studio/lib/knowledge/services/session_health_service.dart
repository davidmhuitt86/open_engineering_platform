import '../models/candidate_validation_result.dart';
import '../models/evidence_link.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/procedure_step.dart';
import '../models/relationship_candidate.dart';
import '../models/session_health_metrics.dart';

/// Pure session-health computation for the Session Health Dashboard
/// (Work Package 011 STUDIO-TASK-000029) — "these metrics are
/// informational only," computed fresh every time, never stored, never
/// modifying candidate data. Holds no state of its own.
abstract final class SessionHealthService {
  /// Computes [SessionHealthMetrics] for the active session. [validation]
  /// is the already-computed `candidateValidation` map (Work Package
  /// 010) — accepted as a parameter rather than recomputed here, so
  /// this service stays decoupled from `KnowledgeSessionService` and
  /// the Connection Manager only ever computes validation once per
  /// rebuild.
  static SessionHealthMetrics computeSessionHealth({
    required List<KnowledgeCandidate> candidates,
    required List<RelationshipCandidate> relationshipCandidates,
    required List<EvidenceRegion> evidenceRegions,
    required List<EvidenceLink> evidenceLinks,
    required List<ProcedureStep> procedureSteps,
    required Map<String, CandidateValidationResult> validation,
  }) {
    final nameCounts = <String, int>{};
    for (final candidate in candidates) {
      final key = candidate.name.trim().toLowerCase();
      nameCounts[key] = (nameCounts[key] ?? 0) + 1;
    }
    final duplicateCandidateCount = candidates
        .where((candidate) => (nameCounts[candidate.name.trim().toLowerCase()] ?? 0) > 1)
        .length;

    final candidatesMissingEvidenceCount = candidates
        .where((candidate) => !evidenceLinks.any((link) => link.candidateId == candidate.id))
        .length;

    final orphanedCandidateCount = candidates.where((candidate) {
      final hasEvidence = evidenceLinks.any((link) => link.candidateId == candidate.id);
      final hasRelationship = relationshipCandidates.any(
        (relationship) =>
            relationship.sourceCandidateId == candidate.id || relationship.targetCandidateId == candidate.id,
      );
      final referencesOthers = procedureSteps.any(
        (step) =>
            step.candidateId == candidate.id &&
            (step.referencedCandidateIds.isNotEmpty || step.referencedRegionIds.isNotEmpty),
      );
      final referencedByOthers = procedureSteps.any(
        (step) => step.candidateId != candidate.id && step.referencedCandidateIds.contains(candidate.id),
      );
      return !hasEvidence && !hasRelationship && !referencesOthers && !referencedByOthers;
    }).length;

    final validationErrorCount = validation.values.where((result) => result.severity == ValidationSeverity.error).length;

    return SessionHealthMetrics(
      candidateCount: candidates.length,
      relationshipCandidateCount: relationshipCandidates.length,
      evidenceRegionCount: evidenceRegions.length,
      procedureCount: candidates.where((candidate) => candidate.type == KnowledgeCandidateType.procedure).length,
      specificationCount: candidates.where((candidate) => candidate.type == KnowledgeCandidateType.specification).length,
      validationErrorCount: validationErrorCount,
      candidatesMissingEvidenceCount: candidatesMissingEvidenceCount,
      duplicateCandidateCount: duplicateCandidateCount,
      orphanedCandidateCount: orphanedCandidateCount,
      relationshipDensity: candidates.isEmpty ? 0 : relationshipCandidates.length / candidates.length,
      averageEvidenceCoveragePercent: candidates.isEmpty
          ? 0
          : (candidates.length - candidatesMissingEvidenceCount) / candidates.length * 100,
    );
  }
}
