import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
// Internal — see note in graph_service_test.dart.
import 'package:engineering_engine/core/events/engine_event_bus.dart';

void main() {
  late EditingSession session;

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
          ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B'))
        .build();
    session = EditingSession.initial(graph);
  });

  group('CreateGroupCommand / UngroupCommand', () {
    test('create then revert', () {
      const group = EngineeringGroup(
        id: 'g1',
        kind: GroupKind.circuit,
        displayName: 'Circuit 1',
        memberNodeIds: ['a', 'b'],
      );
      final create = CreateGroupCommand(group);
      final after = create.apply(session);
      expect(after.graph.groups.containsKey('g1'), isTrue);
      expect(create.revert(after).graph.groups.containsKey('g1'), isFalse);
    });

    test('ungroup removes the group without touching member nodes, and reparents children', () {
      final withGroups = session.copyWith(
        graph: session.graph
            .withGroup(const EngineeringGroup(
              id: 'parent',
              kind: GroupKind.harness,
              displayName: 'Parent',
              memberNodeIds: ['a'],
            ))
            .withGroup(const EngineeringGroup(
              id: 'child',
              kind: GroupKind.circuit,
              displayName: 'Child',
              memberNodeIds: ['b'],
              parentGroupId: 'parent',
            )),
      );

      final ungroup = UngroupCommand('parent');
      final after = ungroup.apply(withGroups);
      expect(after.graph.groups.containsKey('parent'), isFalse);
      expect(after.graph.nodes.containsKey('a'), isTrue); // member untouched
      expect(after.graph.groups['child']!.parentGroupId, isNull); // reparented to root

      final reverted = ungroup.revert(after);
      expect(reverted.graph.groups.containsKey('parent'), isTrue);
      expect(reverted.graph.groups['child']!.parentGroupId, 'parent');
    });
  });

  group('Lock / visibility / collapse', () {
    test('SetGroupLockedCommand is undoable', () {
      final withGroup = session.copyWith(
        graph: session.graph.withGroup(
          const EngineeringGroup(id: 'g1', kind: GroupKind.other, displayName: 'G'),
        ),
      );
      final lock = SetGroupLockedCommand('g1', true);
      final after = lock.apply(withGroup);
      expect(after.graph.groups['g1']!.locked, isTrue);
      expect(lock.revert(after).graph.groups['g1']!.locked, isFalse);
    });

    test('EditingService.toggleGroupExpanded/setGroupVisible bypass the command history', () {
      final events = EngineEventBus();
      final withGroup = session.copyWith(
        graph: session.graph.withGroup(
          const EngineeringGroup(id: 'g1', kind: GroupKind.other, displayName: 'G'),
        ),
      );
      final service = EditingService(initialSession: withGroup, events: events);

      expect(service.session.graph.groups['g1']!.runtime.expanded, isFalse);
      service.toggleGroupExpanded('g1');
      expect(service.session.graph.groups['g1']!.runtime.expanded, isTrue);
      expect(service.canUndo, isFalse); // not part of undo history

      service.setGroupVisible('g1', false);
      expect(service.session.graph.groups['g1']!.runtime.visible, isFalse);
      expect(service.canUndo, isFalse);
    });
  });
}
