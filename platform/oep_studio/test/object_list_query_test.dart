import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/engineering_object_summary.dart';
import 'package:oep_studio/core/models/object_category.dart';
import 'package:oep_studio/features/objects/object_list_query.dart';

const _generator = EngineeringObjectSummary(
  objectId: '1',
  category: ObjectCategory.component,
  name: 'Main Generator',
  author: 'jsmith',
  version: 'A',
  tags: ['electrical', 'power'],
);
const _battery = EngineeringObjectSummary(
  objectId: '2',
  category: ObjectCategory.component,
  name: 'Backup Battery',
  author: 'adoe',
  version: 'B',
  tags: ['electrical'],
);
const _wiringDiagram = EngineeringObjectSummary(
  objectId: '3',
  category: ObjectCategory.diagram,
  name: 'Generator Wiring Diagram',
  author: 'jsmith',
  version: 'A',
  tags: ['electrical', 'schematic'],
);

void main() {
  final objects = [_generator, _battery, _wiringDiagram];

  test('sorts by name case-insensitively', () {
    final result = const ObjectListQuery().apply(objects);
    expect(result.map((o) => o.name), ['Backup Battery', 'Generator Wiring Diagram', 'Main Generator']);
  });

  test('sorts by type', () {
    final result = const ObjectListQuery(sortField: ObjectSortField.type).apply(objects);
    expect(result.first.category, ObjectCategory.component);
    expect(result.last.category, ObjectCategory.diagram);
  });

  test('sorts by author', () {
    final result = const ObjectListQuery(sortField: ObjectSortField.author).apply(objects);
    expect(result.map((o) => o.author), ['adoe', 'jsmith', 'jsmith']);
  });

  test('filters by type', () {
    final result = const ObjectListQuery(typeFilter: ObjectCategory.diagram).apply(objects);
    expect(result, [_wiringDiagram]);
  });

  test('filters by author', () {
    final result = const ObjectListQuery(authorFilter: 'jsmith').apply(objects);
    expect(result.map((o) => o.objectId).toSet(), {'1', '3'});
  });

  test('filters by tag', () {
    final result = const ObjectListQuery(tagFilter: 'schematic').apply(objects);
    expect(result, [_wiringDiagram]);
  });

  test('incremental filter matches name substrings case-insensitively', () {
    final result = const ObjectListQuery(searchText: 'gener').apply(objects);
    expect(result.map((o) => o.objectId).toSet(), {'1', '3'});
  });

  test('filters never mutate the input list, and combine (AND) correctly', () {
    final original = List.of(objects);
    final result = const ObjectListQuery(
      typeFilter: ObjectCategory.component,
      authorFilter: 'jsmith',
    ).apply(objects);

    expect(objects, original, reason: 'apply() must not mutate its input');
    expect(result, [_generator]);
  });

  test('empty input produces an empty result', () {
    expect(const ObjectListQuery().apply(const []), isEmpty);
  });
}
