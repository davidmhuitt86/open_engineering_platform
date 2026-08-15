import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/procedure_step.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/models/specification_details.dart';
import 'package:oep_studio/knowledge/models/specification_type.dart';
import 'package:oep_studio/knowledge/services/dependency_service.dart';

final _cover = KnowledgeCandidate(
  id: 'c1',
  type: KnowledgeCandidateType.component,
  name: 'Timing Cover',
  createdTime: DateTime(2026, 1, 1),
);
final _install = KnowledgeCandidate(
  id: 'c2',
  type: KnowledgeCandidateType.procedure,
  name: 'Install Timing Cover',
  createdTime: DateTime(2026, 1, 1),
);
final _torque = KnowledgeCandidate(
  id: 'c3',
  type: KnowledgeCandidateType.specification,
  name: 'Cover Bolt Torque',
  createdTime: DateTime(2026, 1, 1),
);

void main() {
  group('computeDependencyInfo', () {
    test('returns null for a candidate that does not exist', () {
      final info = DependencyService.computeDependencyInfo(
        candidateId: 'missing',
        candidates: [_cover],
        relationshipCandidates: const [],
        procedureSteps: const [],
        evidenceLinks: const [],
        evidenceRegions: const [],
        specificationDetails: const [],
        validation: const {},
      );
      expect(info, isNull);
    });

    test('references / referencedBy come from Procedure Step references', () {
      final step = ProcedureStep(
        id: 'step1',
        candidateId: 'c2',
        title: 'Install cover',
        referencedCandidateIds: const ['c1'],
        createdTime: DateTime(2026, 1, 1),
      );
      final installInfo = DependencyService.computeDependencyInfo(
        candidateId: 'c2',
        candidates: [_cover, _install],
        relationshipCandidates: const [],
        procedureSteps: [step],
        evidenceLinks: const [],
        evidenceRegions: const [],
        specificationDetails: const [],
        validation: const {},
      )!;
      expect(installInfo.references.map((c) => c.id), ['c1']);
      expect(installInfo.procedureStepCount, 1);

      final coverInfo = DependencyService.computeDependencyInfo(
        candidateId: 'c1',
        candidates: [_cover, _install],
        relationshipCandidates: const [],
        procedureSteps: [step],
        evidenceLinks: const [],
        evidenceRegions: const [],
        specificationDetails: const [],
        validation: const {},
      )!;
      expect(coverInfo.referencedBy.map((c) => c.id), ['c2']);
      expect(coverInfo.procedureStepCount, isNull, reason: 'Component candidates are not Procedures');
    });

    test('relationships include the resolved source/target names', () {
      final relationship = RelationshipCandidate(
        id: 'rel1',
        sourceCandidateId: 'c1',
        targetCandidateId: 'c2',
        type: RelationshipType.dependsOn,
        createdTime: DateTime(2026, 1, 1),
      );
      final info = DependencyService.computeDependencyInfo(
        candidateId: 'c1',
        candidates: [_cover, _install],
        relationshipCandidates: [relationship],
        procedureSteps: const [],
        evidenceLinks: const [],
        evidenceRegions: const [],
        specificationDetails: const [],
        validation: const {},
      )!;
      final entry = info.relationships.single;
      expect(entry.sourceName, 'Timing Cover');
      expect(entry.targetName, 'Install Timing Cover');
    });

    test('specification is only populated for Specification-type candidates', () {
      final details = SpecificationDetails(
        candidateId: 'c3',
        specType: SpecificationType.torque,
        value: '25',
        unit: 'Nm',
        createdTime: DateTime(2026, 1, 1),
      );
      final specInfo = DependencyService.computeDependencyInfo(
        candidateId: 'c3',
        candidates: [_torque],
        relationshipCandidates: const [],
        procedureSteps: const [],
        evidenceLinks: const [],
        evidenceRegions: const [],
        specificationDetails: [details],
        validation: const {},
      )!;
      expect(specInfo.specification?.value, '25');

      final nonSpecInfo = DependencyService.computeDependencyInfo(
        candidateId: 'c1',
        candidates: [_cover, _torque],
        relationshipCandidates: const [],
        procedureSteps: const [],
        evidenceLinks: const [],
        evidenceRegions: const [],
        specificationDetails: [details],
        validation: const {},
      )!;
      expect(nonSpecInfo.specification, isNull);
    });

    test('evidenceCount counts only this candidate\'s links', () {
      final links = [
        EvidenceLink(id: 'l1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1)),
        EvidenceLink(id: 'l2', candidateId: 'c1', regionId: 'r2', createdTime: DateTime(2026, 1, 1)),
        EvidenceLink(id: 'l3', candidateId: 'c2', regionId: 'r3', createdTime: DateTime(2026, 1, 1)),
      ];
      final info = DependencyService.computeDependencyInfo(
        candidateId: 'c1',
        candidates: [_cover, _install],
        relationshipCandidates: const [],
        procedureSteps: const [],
        evidenceLinks: links,
        evidenceRegions: const [],
        specificationDetails: const [],
        validation: const {},
      )!;
      expect(info.evidenceCount, 2);
    });

    test('skips a Procedure Step\'s reference to a since-deleted region', () {
      final step = ProcedureStep(
        id: 'step1',
        candidateId: 'c2',
        title: 'Install cover',
        referencedRegionIds: const ['missing-region'],
        createdTime: DateTime(2026, 1, 1),
      );
      final info = DependencyService.computeDependencyInfo(
        candidateId: 'c2',
        candidates: [_install],
        relationshipCandidates: const [],
        procedureSteps: [step],
        evidenceLinks: const [],
        evidenceRegions: const <EvidenceRegion>[],
        specificationDetails: const [],
        validation: const {},
      )!;
      expect(info.referencedRegions, isEmpty);
    });
  });
}
