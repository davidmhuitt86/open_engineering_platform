import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/knowledge/models/candidate_validation_result.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_validation_exception.dart';
import 'package:oep_studio/knowledge/models/procedure_step.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/models/session_status.dart';
import 'package:oep_studio/knowledge/models/specification_details.dart';
import 'package:oep_studio/knowledge/models/specification_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';

KnowledgeCandidate _candidate(
  String name, {
  String? id,
  KnowledgeCandidateStatus status = KnowledgeCandidateStatus.pending,
  KnowledgeCandidateType type = KnowledgeCandidateType.component,
}) {
  return KnowledgeCandidate(
    id: id ?? name,
    type: type,
    name: name,
    status: status,
    createdTime: DateTime(2026, 1, 1),
  );
}

void main() {
  group('validateNewSession', () {
    test('rejects an empty name', () {
      expect(
        () => KnowledgeSessionService.validateNewSession(name: '  ', repositoryName: 'demo'),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a missing repository', () {
      expect(
        () => KnowledgeSessionService.validateNewSession(name: 'Session A', repositoryName: ''),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a valid name and repository', () {
      expect(
        () => KnowledgeSessionService.validateNewSession(name: 'Session A', repositoryName: 'demo'),
        returnsNormally,
      );
    });
  });

  group('validateCandidateName', () {
    final existing = [_candidate('Main Generator'), _candidate('Backup Battery')];

    test('rejects an empty name', () {
      expect(
        () => KnowledgeSessionService.validateCandidateName('  ', existing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a duplicate name case-insensitively', () {
      expect(
        () => KnowledgeSessionService.validateCandidateName('main generator', existing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a unique name', () {
      expect(() => KnowledgeSessionService.validateCandidateName('Timing Cover', existing), returnsNormally);
    });

    test('excludingId allows a candidate to keep its own name while editing', () {
      expect(
        () => KnowledgeSessionService.validateCandidateName(
          'Main Generator',
          existing,
          excludingId: 'Main Generator',
        ),
        returnsNormally,
      );
    });
  });

  group('validateStatusTransition', () {
    test('allows the forward sequence', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.created, SessionStatus.preparing),
        returnsNormally,
      );
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.preparing, SessionStatus.reviewing),
        returnsNormally,
      );
      expect(
        () =>
            KnowledgeSessionService.validateStatusTransition(SessionStatus.reviewing, SessionStatus.readyToCommit),
        returnsNormally,
      );
    });

    test('rejects skipping a stage', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.created, SessionStatus.reviewing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('allows cancelling from any non-cancelled state', () {
      for (final status in [
        SessionStatus.created,
        SessionStatus.preparing,
        SessionStatus.reviewing,
        SessionStatus.readyToCommit,
      ]) {
        expect(
          () => KnowledgeSessionService.validateStatusTransition(status, SessionStatus.cancelled),
          returnsNormally,
        );
      }
    });

    test('rejects cancelling an already-cancelled session', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.cancelled, SessionStatus.cancelled),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects advancing a cancelled session', () {
      expect(
        () => KnowledgeSessionService.validateStatusTransition(SessionStatus.cancelled, SessionStatus.preparing),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });
  });

  group('validateRelationshipCandidate', () {
    final existing = [_candidate('Main Generator', id: 'c1'), _candidate('Backup Battery', id: 'c2')];

    test('rejects a self-referencing relationship', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c1',
          existingCandidates: existing,
        ),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a relationship whose source does not exist', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'missing',
          targetCandidateId: 'c2',
          existingCandidates: existing,
        ),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects a relationship whose target does not exist', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'missing',
          existingCandidates: existing,
        ),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a relationship between two existing, distinct candidates', () {
      expect(
        () => KnowledgeSessionService.validateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          existingCandidates: existing,
        ),
        returnsNormally,
      );
    });
  });

  group('isDuplicateRelationshipCandidate', () {
    final relationship = RelationshipCandidate(
      id: 'r1',
      sourceCandidateId: 'c1',
      targetCandidateId: 'c2',
      type: RelationshipType.references,
      createdTime: DateTime(2026, 1, 1),
    );

    test('is true for a matching source/target/type', () {
      expect(
        KnowledgeSessionService.isDuplicateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          existingRelationships: [relationship],
        ),
        isTrue,
      );
    });

    test('is false for a different relationship type', () {
      expect(
        KnowledgeSessionService.isDuplicateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.dependsOn,
          existingRelationships: [relationship],
        ),
        isFalse,
      );
    });

    test('excludingId ignores the relationship being edited', () {
      expect(
        KnowledgeSessionService.isDuplicateRelationshipCandidate(
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          existingRelationships: [relationship],
          excludingId: 'r1',
        ),
        isFalse,
      );
    });
  });

  group('validateEvidenceRegionLabel', () {
    test('rejects an empty label', () {
      expect(
        () => KnowledgeSessionService.validateEvidenceRegionLabel('   '),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a non-empty label', () {
      expect(() => KnowledgeSessionService.validateEvidenceRegionLabel('Torque Spec'), returnsNormally);
    });
  });

  group('isEvidenceLinked', () {
    final link = EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1));

    test('is true for a matching candidate/region pair', () {
      expect(
        KnowledgeSessionService.isEvidenceLinked(candidateId: 'c1', regionId: 'r1', existingLinks: [link]),
        isTrue,
      );
    });

    test('is false for a different region', () {
      expect(
        KnowledgeSessionService.isEvidenceLinked(candidateId: 'c1', regionId: 'r2', existingLinks: [link]),
        isFalse,
      );
    });

    test('is false for a different candidate', () {
      expect(
        KnowledgeSessionService.isEvidenceLinked(candidateId: 'c2', regionId: 'r1', existingLinks: [link]),
        isFalse,
      );
    });
  });

  group('validateProcedureStepTitle', () {
    test('rejects an empty title', () {
      expect(
        () => KnowledgeSessionService.validateProcedureStepTitle('  '),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a non-empty title', () {
      expect(() => KnowledgeSessionService.validateProcedureStepTitle('Remove cover bolts'), returnsNormally);
    });
  });

  group('validateSpecificationDetails', () {
    test('rejects an empty value', () {
      expect(
        () => KnowledgeSessionService.validateSpecificationDetails(value: '  ', unit: 'Nm'),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('rejects an empty unit', () {
      expect(
        () => KnowledgeSessionService.validateSpecificationDetails(value: '25', unit: '  '),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('accepts a non-empty value and unit', () {
      expect(() => KnowledgeSessionService.validateSpecificationDetails(value: '25', unit: 'Nm'), returnsNormally);
    });
  });

  group('computeCandidateValidation', () {
    test('a candidate with no findings is ok with no issues', () {
      final candidates = [_candidate('Timing Cover', id: 'c1')];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: [EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: const [],
      );
      expect(result['c1']!.severity, ValidationSeverity.ok);
      expect(result['c1']!.issues, isEmpty);
    });

    test('flags duplicate candidate names as an error on both candidates', () {
      final candidates = [_candidate('Timing Cover', id: 'c1'), _candidate('Timing Cover', id: 'c2')];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: const [],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: const [],
      );
      expect(result['c1']!.severity, ValidationSeverity.error);
      expect(result['c2']!.severity, ValidationSeverity.error);
    });

    test('flags a candidate with no linked evidence as a warning', () {
      final candidates = [_candidate('Timing Cover', id: 'c1')];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: const [],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: const [],
      );
      expect(result['c1']!.severity, ValidationSeverity.warning);
      expect(result['c1']!.issues, contains('No evidence is linked to this candidate.'));
    });

    test('flags an empty procedure as a warning', () {
      final candidates = [_candidate('Install Cover', id: 'c1', type: KnowledgeCandidateType.procedure)];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: [EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: const [],
      );
      expect(result['c1']!.severity, ValidationSeverity.warning);
      expect(result['c1']!.issues, contains('This procedure has no steps.'));
    });

    test('flags a procedure step referencing a deleted candidate as a warning', () {
      final candidates = [_candidate('Install Cover', id: 'c1', type: KnowledgeCandidateType.procedure)];
      final steps = [
        ProcedureStep(
          id: 's1',
          candidateId: 'c1',
          title: 'Torque bolts',
          referencedCandidateIds: const ['missing'],
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: [EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))],
        evidenceRegions: const [],
        procedureSteps: steps,
        specificationDetails: const [],
      );
      expect(result['c1']!.severity, ValidationSeverity.warning);
      expect(
        result['c1']!.issues,
        contains('One or more procedure steps reference evidence or a candidate that no longer exists.'),
      );
    });

    test('flags a specification with no details as an error', () {
      final candidates = [_candidate('Head Bolt Torque', id: 'c1', type: KnowledgeCandidateType.specification)];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: [EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: const [],
      );
      expect(result['c1']!.severity, ValidationSeverity.error);
      expect(result['c1']!.issues, contains('This specification is missing Type, Value, and Unit.'));
    });

    test('flags a specification with an empty value or unit as an error', () {
      final candidates = [_candidate('Head Bolt Torque', id: 'c1', type: KnowledgeCandidateType.specification)];
      final details = [
        SpecificationDetails(
          candidateId: 'c1',
          specType: SpecificationType.torque,
          value: '',
          unit: '',
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: [EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: details,
      );
      expect(result['c1']!.severity, ValidationSeverity.error);
      expect(result['c1']!.issues, contains('Specification value is missing.'));
      expect(result['c1']!.issues, contains('Specification unit is missing.'));
    });

    test('a complete specification has no specification-related issues', () {
      final candidates = [_candidate('Head Bolt Torque', id: 'c1', type: KnowledgeCandidateType.specification)];
      final details = [
        SpecificationDetails(
          candidateId: 'c1',
          specType: SpecificationType.torque,
          value: '25',
          unit: 'Nm',
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: const [],
        evidenceLinks: [EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: details,
      );
      expect(result['c1']!.severity, ValidationSeverity.ok);
    });

    test('flags a relationship candidate whose endpoint no longer exists as an error', () {
      final candidates = [_candidate('Timing Cover', id: 'c1')];
      final relationships = [
        RelationshipCandidate(
          id: 'r1',
          sourceCandidateId: 'c1',
          targetCandidateId: 'missing',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final result = KnowledgeSessionService.computeCandidateValidation(
        candidates: candidates,
        relationshipCandidates: relationships,
        evidenceLinks: [EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1))],
        evidenceRegions: const [],
        procedureSteps: const [],
        specificationDetails: const [],
      );
      expect(result['c1']!.severity, ValidationSeverity.error);
      expect(result['c1']!.issues, contains('A relationship references a candidate that no longer exists.'));
    });
  });
}
