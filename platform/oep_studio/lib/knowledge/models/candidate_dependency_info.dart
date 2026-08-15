import 'candidate_validation_result.dart';
import 'evidence_region.dart';
import 'knowledge_candidate.dart';
import 'relationship_candidate.dart';
import 'specification_details.dart';

/// A [RelationshipCandidate] paired with its resolved source/target
/// display names — a small local counterpart to
/// `ResolvedRelationshipCandidate`
/// (`lib/knowledge/review/relationship_candidate_list_query.dart`),
/// kept separate so `DependencyService` (a service) doesn't depend on
/// a `review/` (UI-adjacent) file for a two-field record.
class DependencyRelationshipEntry {
  const DependencyRelationshipEntry({required this.relationship, required this.sourceName, required this.targetName});

  final RelationshipCandidate relationship;
  final String sourceName;
  final String targetName;
}

/// The Candidate Dependency Viewer's full picture of one Knowledge
/// Candidate (Work Package 011 STUDIO-TASK-000028): "Referenced By,
/// References, Relationships, Procedure Usage, Specification Usage,
/// Evidence Count, Validation Status." Computed on demand by
/// `DependencyService.computeDependencyInfo` — never stored.
class CandidateDependencyInfo {
  const CandidateDependencyInfo({
    required this.candidateId,
    required this.referencedBy,
    required this.references,
    required this.referencedRegions,
    required this.relationships,
    required this.procedureStepCount,
    required this.specification,
    required this.evidenceCount,
    required this.validation,
  });

  final String candidateId;

  /// Other Knowledge Candidates whose own Procedure Steps reference
  /// this candidate ("Referenced By").
  final List<KnowledgeCandidate> referencedBy;

  /// Knowledge Candidates this candidate's own Procedure Steps
  /// reference ("References") — always empty for a non-Procedure
  /// candidate, since only Procedure candidates own steps.
  final List<KnowledgeCandidate> references;

  /// Evidence Regions this candidate's own Procedure Steps reference —
  /// the Evidence-Region half of "References", shown alongside it.
  final List<EvidenceRegion> referencedRegions;

  /// Relationship Candidates connecting this candidate to another, as
  /// source or target ("Relationships").
  final List<DependencyRelationshipEntry> relationships;

  /// This candidate's own step count ("Procedure Usage") — `null`
  /// unless [KnowledgeCandidate.type] is `procedure`, distinguishing
  /// "not a Procedure" from "a Procedure with zero steps" (`0`).
  final int? procedureStepCount;

  /// This candidate's own Specification fields ("Specification
  /// Usage") — meaningful only when [KnowledgeCandidate.type] is
  /// `specification`; `null` otherwise, or if a Specification
  /// candidate has none recorded yet.
  final SpecificationDetails? specification;

  /// How many Evidence Regions are linked to this candidate
  /// ("Evidence Count").
  final int evidenceCount;

  /// This candidate's computed validation result ("Validation
  /// Status") — reuses Work Package 010's `CandidateValidationResult`
  /// rather than a second, parallel status concept.
  final CandidateValidationResult? validation;
}
