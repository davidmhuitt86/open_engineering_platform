import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/knowledge/models/candidate_validation_result.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/procedure_step.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/services/session_health_service.dart';

KnowledgeCandidate _candidate(String id, String name, {KnowledgeCandidateType type = KnowledgeCandidateType.component}) {
  return KnowledgeCandidate(id: id, type: type, name: name, createdTime: DateTime(2026, 1, 1));
}

void main() {
  group('computeSessionHealth', () {
    test('an empty session reports zero for every count and metric', () {
      final health = SessionHealthService.computeSessionHealth(
        candidates: const [],
        relationshipCandidates: const [],
        evidenceRegions: const [],
        evidenceLinks: const [],
        procedureSteps: const [],
        validation: const {},
      );
      expect(health.candidateCount, 0);
      expect(health.relationshipDensity, 0);
      expect(health.averageEvidenceCoveragePercent, 0);
    });

    test('counts Procedures and Specifications by type', () {
      final candidates = [
        _candidate('c1', 'Timing Cover'),
        _candidate('c2', 'Install Cover', type: KnowledgeCandidateType.procedure),
        _candidate('c3', 'Bolt Torque', type: KnowledgeCandidateType.specification),
      ];
      final health = SessionHealthService.computeSessionHealth(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceRegions: const [],
        evidenceLinks: const [],
        procedureSteps: const [],
        validation: const {},
      );
      expect(health.procedureCount, 1);
      expect(health.specificationCount, 1);
    });

    test('duplicateCandidateCount counts every candidate sharing a name, not just the group count', () {
      final candidates = [
        _candidate('c1', 'Timing Cover'),
        _candidate('c2', 'Timing Cover'),
        _candidate('c3', 'timing cover'),
        _candidate('c4', 'Unique'),
      ];
      final health = SessionHealthService.computeSessionHealth(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceRegions: const [],
        evidenceLinks: const [],
        procedureSteps: const [],
        validation: const {},
      );
      expect(health.duplicateCandidateCount, 3);
    });

    test('candidatesMissingEvidenceCount counts candidates with zero Evidence Links', () {
      final candidates = [_candidate('c1', 'A'), _candidate('c2', 'B')];
      final links = [EvidenceLink(id: 'l1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))];
      final health = SessionHealthService.computeSessionHealth(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceRegions: const [],
        evidenceLinks: links,
        procedureSteps: const [],
        validation: const {},
      );
      expect(health.candidatesMissingEvidenceCount, 1);
      expect(health.averageEvidenceCoveragePercent, 50);
    });

    test('orphanedCandidateCount excludes a candidate with evidence, a relationship, or a step reference', () {
      final candidates = [
        _candidate('c1', 'Has Evidence'),
        _candidate('c2', 'Has Relationship'),
        _candidate('c3', 'Referenced By A Step'),
        _candidate('c4', 'Truly Orphaned'),
        _candidate('c5', 'References Others', type: KnowledgeCandidateType.procedure),
      ];
      final links = [EvidenceLink(id: 'l1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))];
      final relationships = [
        RelationshipCandidate(
          id: 'rel1',
          sourceCandidateId: 'c2',
          targetCandidateId: 'c1',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final steps = [
        ProcedureStep(
          id: 'step1',
          candidateId: 'c5',
          title: 'Step',
          referencedCandidateIds: const ['c3'],
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final health = SessionHealthService.computeSessionHealth(
        candidates: candidates,
        relationshipCandidates: relationships,
        evidenceRegions: const [],
        evidenceLinks: links,
        procedureSteps: steps,
        validation: const {},
      );
      // c1 (evidence), c2 (relationship), c3 (referenced by), c5 (references
      // others) are all connected; only c4 is orphaned.
      expect(health.orphanedCandidateCount, 1);
    });

    test('validationErrorCount counts only error-severity results', () {
      final candidates = [_candidate('c1', 'A'), _candidate('c2', 'B')];
      final validation = {
        'c1': const CandidateValidationResult(candidateId: 'c1', severity: ValidationSeverity.error, issues: []),
        'c2': const CandidateValidationResult(candidateId: 'c2', severity: ValidationSeverity.warning, issues: []),
      };
      final health = SessionHealthService.computeSessionHealth(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceRegions: const [],
        evidenceLinks: const [],
        procedureSteps: const [],
        validation: validation,
      );
      expect(health.validationErrorCount, 1);
    });

    test('relationshipDensity is relationships per candidate', () {
      final candidates = [_candidate('c1', 'A'), _candidate('c2', 'B'), _candidate('c3', 'C'), _candidate('c4', 'D')];
      final relationships = [
        RelationshipCandidate(
          id: 'rel1',
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final health = SessionHealthService.computeSessionHealth(
        candidates: candidates,
        relationshipCandidates: relationships,
        evidenceRegions: const [],
        evidenceLinks: const [],
        procedureSteps: const [],
        validation: const {},
      );
      expect(health.relationshipDensity, 0.25);
    });
  });
}
