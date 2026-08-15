import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/relationship_summary.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/features/relationships/relationship_list_query.dart';

const _supplies = RelationshipSummary(
  relationshipId: '1',
  sourceObjectId: 'obj-generator',
  targetObjectId: 'obj-panel',
  sourceObjectName: 'Main Generator',
  targetObjectName: 'Distribution Panel',
  type: RelationshipType.connectedTo,
  author: 'jsmith',
  description: 'Generator supplies the distribution panel',
);
const _monitors = RelationshipSummary(
  relationshipId: '2',
  sourceObjectId: 'obj-control',
  targetObjectId: 'obj-generator',
  sourceObjectName: 'Control Unit',
  targetObjectName: 'Main Generator',
  type: RelationshipType.dependsOn,
  author: 'adoe',
);
const _documents = RelationshipSummary(
  relationshipId: '3',
  sourceObjectId: 'obj-overview',
  targetObjectId: 'obj-generator',
  sourceObjectName: 'System Overview',
  targetObjectName: 'Main Generator',
  type: RelationshipType.documents,
  author: 'jsmith',
);

void main() {
  final relationships = [_supplies, _monitors, _documents];

  test('sorts by type', () {
    final result = const RelationshipListQuery(sortField: RelationshipSortField.type).apply(relationships);
    expect(result.map((r) => r.type), [
      RelationshipType.connectedTo,
      RelationshipType.dependsOn,
      RelationshipType.documents,
    ]);
  });

  test('sorts by source', () {
    final result = const RelationshipListQuery(sortField: RelationshipSortField.source).apply(relationships);
    expect(result.map((r) => r.sourceObjectName), ['Control Unit', 'Main Generator', 'System Overview']);
  });

  test('sorts by target', () {
    final result = const RelationshipListQuery(sortField: RelationshipSortField.target).apply(relationships);
    expect(result.first.targetObjectName, 'Distribution Panel');
  });

  test('sorts by author', () {
    final result = const RelationshipListQuery(sortField: RelationshipSortField.author).apply(relationships);
    expect(result.map((r) => r.author), ['adoe', 'jsmith', 'jsmith']);
  });

  test('filters by type', () {
    final result = const RelationshipListQuery(typeFilter: RelationshipType.documents).apply(relationships);
    expect(result, [_documents]);
  });

  test('filters by source substring case-insensitively', () {
    final result = const RelationshipListQuery(sourceFilter: 'main gen').apply(relationships);
    expect(result, [_supplies]);
  });

  test('filters by target substring case-insensitively', () {
    final result = const RelationshipListQuery(targetFilter: 'generator').apply(relationships);
    expect(result.map((r) => r.relationshipId).toSet(), {'2', '3'});
  });

  test('filters by author', () {
    final result = const RelationshipListQuery(authorFilter: 'jsmith').apply(relationships);
    expect(result.map((r) => r.relationshipId).toSet(), {'1', '3'});
  });

  test('does not mutate the input list', () {
    final original = List.of(relationships);
    const RelationshipListQuery(typeFilter: RelationshipType.documents).apply(relationships);
    expect(relationships, original);
  });

  test('empty input produces an empty result', () {
    expect(const RelationshipListQuery().apply(const []), isEmpty);
  });
}
