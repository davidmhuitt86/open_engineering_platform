import '../models/candidate_dependency_info.dart';
import '../models/candidate_validation_result.dart';
import '../models/evidence_link.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/procedure_step.dart';
import '../models/relationship_candidate.dart';
import '../models/specification_details.dart';

/// Pure dependency-analysis logic for the Candidate Dependency Viewer
/// (Work Package 011 STUDIO-TASK-000028) — "dependency analysis ...
/// inside services." Holds no state; every method takes a snapshot and
/// returns a value.
abstract final class DependencyService {
  /// Computes the full [CandidateDependencyInfo] for [candidateId].
  /// Returns `null` if [candidateId] doesn't exist among [candidates]
  /// — the caller (the Property Inspector's Dependencies tab) shows a
  /// professional "not available" message rather than a crash, per
  /// this work package's Error Handling: "Invalid graph nodes."
  static CandidateDependencyInfo? computeDependencyInfo({
    required String candidateId,
    required List<KnowledgeCandidate> candidates,
    required List<RelationshipCandidate> relationshipCandidates,
    required List<ProcedureStep> procedureSteps,
    required List<EvidenceLink> evidenceLinks,
    required List<EvidenceRegion> evidenceRegions,
    required List<SpecificationDetails> specificationDetails,
    required Map<String, CandidateValidationResult> validation,
  }) {
    KnowledgeCandidate? candidate;
    for (final entry in candidates) {
      if (entry.id == candidateId) {
        candidate = entry;
        break;
      }
    }
    if (candidate == null) return null;

    final candidatesById = {for (final entry in candidates) entry.id: entry};
    final regionsById = {for (final region in evidenceRegions) region.id: region};

    final ownSteps = procedureSteps.where((step) => step.candidateId == candidateId).toList();
    final referencedCandidateIds = <String>{};
    final referencedRegionIds = <String>{};
    for (final step in ownSteps) {
      referencedCandidateIds.addAll(step.referencedCandidateIds);
      referencedRegionIds.addAll(step.referencedRegionIds);
    }
    final references = [for (final id in referencedCandidateIds) if (candidatesById[id] != null) candidatesById[id]!];
    final referencedRegions = [
      for (final id in referencedRegionIds) if (regionsById[id] != null) regionsById[id]!,
    ];

    final referencedByIds = <String>{};
    for (final step in procedureSteps) {
      if (step.candidateId == candidateId) continue;
      if (step.referencedCandidateIds.contains(candidateId)) referencedByIds.add(step.candidateId);
    }
    final referencedBy = [for (final id in referencedByIds) if (candidatesById[id] != null) candidatesById[id]!];

    final relationships = <DependencyRelationshipEntry>[
      for (final relationship in relationshipCandidates)
        if (relationship.sourceCandidateId == candidateId || relationship.targetCandidateId == candidateId)
          DependencyRelationshipEntry(
            relationship: relationship,
            sourceName: candidatesById[relationship.sourceCandidateId]?.name ?? relationship.sourceCandidateId,
            targetName: candidatesById[relationship.targetCandidateId]?.name ?? relationship.targetCandidateId,
          ),
    ];

    SpecificationDetails? specification;
    if (candidate.type == KnowledgeCandidateType.specification) {
      for (final entry in specificationDetails) {
        if (entry.candidateId == candidateId) {
          specification = entry;
          break;
        }
      }
    }

    return CandidateDependencyInfo(
      candidateId: candidateId,
      referencedBy: referencedBy,
      references: references,
      referencedRegions: referencedRegions,
      relationships: relationships,
      procedureStepCount: candidate.type == KnowledgeCandidateType.procedure ? ownSteps.length : null,
      specification: specification,
      evidenceCount: evidenceLinks.where((link) => link.candidateId == candidateId).length,
      validation: validation[candidateId],
    );
  }
}
