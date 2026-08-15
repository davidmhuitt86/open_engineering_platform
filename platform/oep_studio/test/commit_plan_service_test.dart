import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/models/object_category.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/services/commit_plan_service.dart';

KnowledgeSession _session({String repositoryName = 'demo-repo'}) {
  return KnowledgeSession(
    id: 's1',
    name: 'Session',
    repositoryName: repositoryName,
    author: 'Author',
    createdTime: DateTime(2026, 1, 1),
    lastModified: DateTime(2026, 1, 1),
  );
}

KnowledgeCandidate _candidate(
  String id, {
  KnowledgeCandidateType type = KnowledgeCandidateType.component,
  KnowledgeCandidateStatus status = KnowledgeCandidateStatus.accepted,
  String name = 'Candidate',
  String? committedObjectId,
}) {
  return KnowledgeCandidate(
    id: id,
    type: type,
    name: name,
    status: status,
    createdTime: DateTime(2026, 1, 1),
    committedObjectId: committedObjectId,
    committedTime: committedObjectId == null ? null : DateTime(2026, 1, 1),
  );
}

void main() {
  group('computeCommitPlan', () {
    test('no repository open blocks the commit with a validation error', () {
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: const [],
        relationshipCandidates: const [],
        isRepositoryOpen: false,
      );
      expect(plan.validationErrors, isNotEmpty);
      expect(plan.canCommit, isFalse);
    });

    test('an open repository whose name differs from the session\'s repository blocks the commit', () {
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(repositoryName: 'expected-repo'),
        candidates: [_candidate('c1')],
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'different-repo',
      );
      expect(plan.validationErrors, isNotEmpty);
      expect(plan.canCommit, isFalse);
    });

    test('a matching repository name does not block the commit', () {
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(repositoryName: 'demo-repo'),
        candidates: [_candidate('c1')],
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.validationErrors, isEmpty);
    });

    test('an empty session repository name never blocks on a mismatch', () {
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(repositoryName: ''),
        candidates: [_candidate('c1')],
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'any-repo',
      );
      expect(plan.validationErrors, isEmpty);
    });

    test('pending and rejected candidates are excluded from new objects, with a warning', () {
      final candidates = [
        _candidate('c1', status: KnowledgeCandidateStatus.pending),
        _candidate('c2', status: KnowledgeCandidateStatus.rejected),
        _candidate('c3', status: KnowledgeCandidateStatus.accepted),
      ];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newObjects.map((c) => c.id), ['c3']);
      expect(plan.warnings.any((w) => w.contains('pending')), isTrue);
      expect(plan.warnings.any((w) => w.contains('rejected')), isTrue);
    });

    test('every accepted, mapped-type candidate is included: all four mapped types', () {
      final candidates = [
        _candidate('c1', type: KnowledgeCandidateType.component),
        _candidate('c2', type: KnowledgeCandidateType.procedure),
        _candidate('c3', type: KnowledgeCandidateType.image),
        _candidate('c4', type: KnowledgeCandidateType.document),
      ];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newObjects.map((c) => c.id).toSet(), {'c1', 'c2', 'c3', 'c4'});
    });

    test('the six unmapped candidate types are excluded from new objects, with a warning', () {
      const unmapped = [
        KnowledgeCandidateType.specification,
        KnowledgeCandidateType.tool,
        KnowledgeCandidateType.material,
        KnowledgeCandidateType.fluid,
        KnowledgeCandidateType.warning,
        KnowledgeCandidateType.measurement,
      ];
      final candidates = [for (final type in unmapped) _candidate(type.name, type: type)];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newObjects, isEmpty);
      expect(plan.warnings.any((w) => w.contains('no Foundation Engineering')), isTrue);
    });

    test('an already-committed candidate is excluded from new objects, with a warning, but not an error', () {
      final candidates = [_candidate('c1', committedObjectId: 'obj-1')];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newObjects, isEmpty);
      expect(plan.validationErrors, isEmpty);
      expect(plan.warnings.any((w) => w.contains('already committed')), isTrue);
    });

    test('a candidate whose name collides with an existing object gets a warning but is still included', () {
      final candidates = [_candidate('c1', name: 'Timing Cover')];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
        objectList: const [
          EngineeringObjectSummary(
            objectId: 'obj-1',
            category: ObjectCategory.component,
            name: 'Timing Cover',
            author: 'Someone',
            version: '1',
          ),
        ],
      );
      expect(plan.newObjects.map((c) => c.id), ['c1']);
      expect(plan.warnings.any((w) => w.contains('already exists')), isTrue);
    });

    test('a relationship candidate with both endpoints newly eligible is included', () {
      final candidates = [_candidate('c1'), _candidate('c2')];
      final relationships = [
        RelationshipCandidate(
          id: 'rel1',
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: relationships,
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newRelationships.map((r) => r.id), ['rel1']);
    });

    test('a relationship candidate whose endpoint was already committed by a prior commit is still included', () {
      final candidates = [_candidate('c1', committedObjectId: 'obj-1'), _candidate('c2')];
      final relationships = [
        RelationshipCandidate(
          id: 'rel1',
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: relationships,
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newRelationships.map((r) => r.id), ['rel1']);
    });

    test('a relationship candidate with an unresolvable endpoint is excluded, with a warning', () {
      final candidates = [_candidate('c1'), _candidate('c2', status: KnowledgeCandidateStatus.rejected)];
      final relationships = [
        RelationshipCandidate(
          id: 'rel1',
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
        ),
      ];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: relationships,
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newRelationships, isEmpty);
      expect(plan.warnings.any((w) => w.contains('endpoints must be committed')), isTrue);
    });

    test('an already-committed relationship candidate is excluded, with a warning', () {
      final candidates = [_candidate('c1'), _candidate('c2')];
      final relationships = [
        RelationshipCandidate(
          id: 'rel1',
          sourceCandidateId: 'c1',
          targetCandidateId: 'c2',
          type: RelationshipType.references,
          createdTime: DateTime(2026, 1, 1),
          committedRelationshipId: 'rship-1',
          committedTime: DateTime(2026, 1, 1),
        ),
      ];
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: candidates,
        relationshipCandidates: relationships,
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.newRelationships, isEmpty);
      expect(plan.warnings.any((w) => w.contains('already committed')), isTrue);
    });

    test('canCommit is false for an empty plan even without validation errors', () {
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: const [],
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.validationErrors, isEmpty);
      expect(plan.canCommit, isFalse);
    });

    test('canCommit is true once there is at least one new object', () {
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: [_candidate('c1')],
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
      );
      expect(plan.canCommit, isTrue);
    });

    test('existingObjectCount and currentStatistics come straight from the supplied statistics', () {
      const statistics = RepositoryStatistics(
        repositoryId: 'repo-1',
        repositoryName: 'demo-repo',
        repositoryVersion: '1',
        totalObjectCount: 42,
        objectCountByCategory: {},
        relationshipCount: 7,
        packageCount: 1,
      );
      final plan = CommitPlanService.computeCommitPlan(
        session: _session(),
        candidates: const [],
        relationshipCandidates: const [],
        isRepositoryOpen: true,
        openRepositoryName: 'demo-repo',
        currentStatistics: statistics,
      );
      expect(plan.existingObjectCount, 42);
      expect(plan.currentStatistics, same(statistics));
      expect(plan.mergeOperationCount, 0);
    });
  });
}
