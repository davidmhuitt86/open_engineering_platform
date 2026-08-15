import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  late EditingSession session;

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(
            id: 'a',
            category: NodeCategory.component,
            displayName: 'A',
            symbolId: 'battery',
          )
          ..addNode(id: 'b', category: NodeCategory.ground, displayName: 'B')
          ..connect('a', 'b', id: 'r1'))
        .build();
    session = EditingSession.initial(graph);
  });

  group('CreateNodeCommand / DeleteNodeCommand', () {
    test('create adds a node and tracks its layout position; delete removes both', () {
      const node = EngineeringNode(id: 'c', category: NodeCategory.component, displayName: 'C');
      final create = CreateNodeCommand(node, position: const Point2D(10, 20));

      final afterCreate = create.apply(session);
      expect(afterCreate.graph.nodes.containsKey('c'), isTrue);
      expect(afterCreate.layout.positionOf('c'), const Point2D(10, 20));

      final afterRevertCreate = create.revert(afterCreate);
      expect(afterRevertCreate.graph.nodes.containsKey('c'), isFalse);
      expect(afterRevertCreate.layout.positionOf('c'), isNull);
    });

    test('delete cascades relationships and restores group membership on revert', () {
      final sessionWithGroup = session.copyWith(
        graph: session.graph.withGroup(
          const EngineeringGroup(id: 'grp', kind: GroupKind.circuit, displayName: 'Circuit', memberNodeIds: ['a', 'b']),
        ),
      );
      final delete = DeleteNodeCommand('a');

      final afterDelete = delete.apply(sessionWithGroup);
      expect(afterDelete.graph.nodes.containsKey('a'), isFalse);
      expect(afterDelete.graph.relationships.containsKey('r1'), isFalse);
      expect(afterDelete.graph.groups['grp']!.memberNodeIds, ['b']);

      final reverted = delete.revert(afterDelete);
      expect(reverted.graph.nodes.containsKey('a'), isTrue);
      expect(reverted.graph.relationships.containsKey('r1'), isTrue);
      expect(reverted.graph.groups['grp']!.memberNodeIds, ['a', 'b']);
    });
  });

  group('MoveNodesCommand', () {
    test('moving multiple nodes is one undoable step', () {
      final moveMany = MoveNodesCommand({'a': const Point2D(5, 5), 'b': const Point2D(6, 6)});
      final after = moveMany.apply(session);
      expect(after.layout.positionOf('a'), const Point2D(5, 5));
      expect(after.layout.positionOf('b'), const Point2D(6, 6));

      final reverted = moveMany.revert(after);
      expect(reverted.layout.positionOf('a'), isNull);
      expect(reverted.layout.positionOf('b'), isNull);
    });
  });

  group('DuplicateNodeCommand', () {
    test('duplicates category/displayName/symbolId with a fresh id, offsetting layout', () {
      final withPosition = session.copyWith(layout: session.layout.withPosition('a', const Point2D(0, 0)));
      final duplicate = DuplicateNodeCommand('a', offset: const Point2D(10, 10));
      final after = duplicate.apply(withPosition);

      final copies = after.graph.nodes.values.where((n) => n.id != 'a' && n.id != 'b');
      expect(copies.length, 1);
      final copy = copies.first;
      expect(copy.symbolId, 'battery');
      expect(copy.displayName, contains('copy'));
      expect(after.layout.positionOf(copy.id), const Point2D(10, 10));

      final reverted = duplicate.revert(after);
      expect(reverted.graph.nodes.length, 2);
    });
  });

  group('CreateRelationshipCommand / DeleteRelationshipCommand / ReconnectRelationshipCommand', () {
    test('create then delete round-trips', () {
      const relationship = EngineeringRelationship(
        id: 'r2',
        relationshipType: RelationshipType.connectedTo,
        sourceNode: 'a',
        targetNode: 'b',
      );
      final create = CreateRelationshipCommand(relationship);
      final afterCreate = create.apply(session);
      expect(afterCreate.graph.relationships.containsKey('r2'), isTrue);
      expect(create.revert(afterCreate).graph.relationships.containsKey('r2'), isFalse);

      final delete = DeleteRelationshipCommand('r2');
      final afterDelete = delete.apply(afterCreate);
      expect(afterDelete.graph.relationships.containsKey('r2'), isFalse);
      expect(delete.revert(afterDelete).graph.relationships.containsKey('r2'), isTrue);
    });

    test('reconnect re-points source/target and reverts exactly', () {
      final reconnect = ReconnectRelationshipCommand('r1', newTargetNode: 'a');
      final after = reconnect.apply(session);
      expect(after.graph.relationships['r1']!.targetNode, 'a');

      final reverted = reconnect.revert(after);
      expect(reverted.graph.relationships['r1']!.targetNode, 'b');
    });
  });

  group('Property/rename/category commands', () {
    test('UpdateNodePropertiesCommand merges and reverts', () {
      final update = UpdateNodePropertiesCommand('a', {'voltage': 12});
      final after = update.apply(session);
      expect(after.graph.nodes['a']!.properties['voltage'], 12);
      expect(update.revert(after).graph.nodes['a']!.properties.containsKey('voltage'), isFalse);
    });

    test('RenameNodeCommand renames and reverts', () {
      final rename = RenameNodeCommand('a', 'Battery Pack');
      final after = rename.apply(session);
      expect(after.graph.nodes['a']!.displayName, 'Battery Pack');
      expect(rename.revert(after).graph.nodes['a']!.displayName, 'A');
    });

    test('ChangeNodeCategoryCommand changes and reverts', () {
      final change = ChangeNodeCategoryCommand('a', NodeCategory.sensor);
      final after = change.apply(session);
      expect(after.graph.nodes['a']!.category, NodeCategory.sensor);
      expect(change.revert(after).graph.nodes['a']!.category, NodeCategory.component);
    });
  });
}
