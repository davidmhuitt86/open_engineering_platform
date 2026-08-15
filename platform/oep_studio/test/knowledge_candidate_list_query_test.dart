import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/candidate_validation_result.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/review/knowledge_candidate_list_query.dart';

final _cover = KnowledgeCandidate(
  id: 'c1',
  type: KnowledgeCandidateType.component,
  name: 'Timing Chain Cover',
  status: KnowledgeCandidateStatus.pending,
  createdTime: DateTime(2026, 1, 1),
);
final _procedure = KnowledgeCandidate(
  id: 'c2',
  type: KnowledgeCandidateType.procedure,
  name: 'Install Timing Chain Cover',
  status: KnowledgeCandidateStatus.accepted,
  createdTime: DateTime(2026, 1, 1),
);
final _spec = KnowledgeCandidate(
  id: 'c3',
  type: KnowledgeCandidateType.specification,
  name: 'Cover Bolt Torque',
  status: KnowledgeCandidateStatus.rejected,
  createdTime: DateTime(2026, 1, 1),
);

void main() {
  final candidates = [_cover, _procedure, _spec];

  test('sorts by name case-insensitively', () {
    final result = const KnowledgeCandidateListQuery().apply(candidates);
    expect(result.map((c) => c.id), ['c3', 'c2', 'c1']);
  });

  test('sorts by type', () {
    final result = const KnowledgeCandidateListQuery(sortField: KnowledgeCandidateSortField.type).apply(candidates);
    expect(result.map((c) => c.type).toList(), [
      KnowledgeCandidateType.component,
      KnowledgeCandidateType.procedure,
      KnowledgeCandidateType.specification,
    ]);
  });

  test('sorts by status', () {
    final result = const KnowledgeCandidateListQuery(sortField: KnowledgeCandidateSortField.status).apply(candidates);
    expect(result.map((c) => c.status).toList(), [
      KnowledgeCandidateStatus.accepted,
      KnowledgeCandidateStatus.pending,
      KnowledgeCandidateStatus.rejected,
    ]);
  });

  test('sorts by validation severity, errors first', () {
    final validation = {
      'c1': const CandidateValidationResult(candidateId: 'c1', severity: ValidationSeverity.ok, issues: []),
      'c2': const CandidateValidationResult(candidateId: 'c2', severity: ValidationSeverity.warning, issues: []),
      'c3': const CandidateValidationResult(candidateId: 'c3', severity: ValidationSeverity.error, issues: []),
    };
    final result = const KnowledgeCandidateListQuery(
      sortField: KnowledgeCandidateSortField.validation,
    ).apply(candidates, validation: validation);
    expect(result.map((c) => c.id), ['c3', 'c2', 'c1']);
  });

  test('filters by type', () {
    final result = const KnowledgeCandidateListQuery(typeFilter: KnowledgeCandidateType.procedure).apply(candidates);
    expect(result, [_procedure]);
  });

  test('filters by status', () {
    final result = const KnowledgeCandidateListQuery(statusFilter: KnowledgeCandidateStatus.rejected).apply(candidates);
    expect(result, [_spec]);
  });

  test('filters by name substring case-insensitively', () {
    final result = const KnowledgeCandidateListQuery(textFilter: 'cover').apply(candidates);
    expect(result.map((c) => c.id).toSet(), {'c1', 'c2', 'c3'});
  });

  test('filters never mutate the input list, and combine (AND) correctly', () {
    final original = List.of(candidates);
    final result = const KnowledgeCandidateListQuery(
      typeFilter: KnowledgeCandidateType.component,
      textFilter: 'timing',
    ).apply(candidates);

    expect(candidates, original, reason: 'apply() must not mutate its input');
    expect(result, [_cover]);
  });

  test('empty input produces an empty result', () {
    expect(const KnowledgeCandidateListQuery().apply(const []), isEmpty);
  });
}
