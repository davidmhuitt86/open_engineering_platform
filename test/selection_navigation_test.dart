import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
// Internal — see note in graph_service_test.dart.
import 'package:engineering_engine/core/events/engine_event.dart';
import 'package:engineering_engine/core/events/engine_event_bus.dart';

void main() {
  group('SelectionService', () {
    late SelectionService selection;

    setUp(() {
      selection = SelectionService(events: EngineEventBus());
    });

    test('starts with no selection', () {
      expect(selection.current.isEmpty, isTrue);
    });

    test('selectNode replaces the selection and emits a change', () async {
      final future = selection.changes.first;
      selection.selectNode('n1');
      final emitted = await future;
      expect(emitted.nodeIds, {'n1'});
      expect(selection.current.nodeIds, {'n1'});
    });

    test('selectNode with additive:true extends the selection', () {
      selection.selectNode('n1');
      selection.selectNode('n2', additive: true);
      expect(selection.current.nodeIds, {'n1', 'n2'});
    });

    test('toggleNode adds then removes', () {
      selection.toggleNode('n1');
      expect(selection.current.nodeIds, {'n1'});
      selection.toggleNode('n1');
      expect(selection.current.nodeIds, isEmpty);
    });

    test('selectMany replaces nodes/relationships/groups together', () {
      selection.selectMany(nodeIds: {'n1', 'n2'}, relationshipIds: {'r1'});
      expect(selection.current.nodeIds, {'n1', 'n2'});
      expect(selection.current.relationshipIds, {'r1'});
    });

    test('selectAll selects every node/relationship/group in the graph', () {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..connect('a', 'b', id: 'r1'))
          .build();
      selection.selectAll(graph);
      expect(selection.current.nodeIds, {'a', 'b'});
      expect(selection.current.relationshipIds, {'r1'});
    });

    test('deselectAll resets to empty', () {
      selection.selectNode('n1');
      selection.deselectAll();
      expect(selection.current.isEmpty, isTrue);
    });

    test('focusPort carries owner id, independent of the multi-selection', () {
      selection.selectNode('n1');
      selection.focusPort('n1', 'p1');
      expect(selection.focus.kind, FocusKind.port);
      expect(selection.focus.id, 'p1');
      expect(selection.focus.ownerId, 'n1');
      expect(selection.current.nodeIds, {'n1'}); // untouched by focus
    });
  });

  group('NavigationService', () {
    late NavigationService navigation;
    late EngineeringGraph graph;

    setUp(() {
      navigation = NavigationService();
      graph = (GraphBuilder(id: 'nav')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C')
            ..connect('a', 'b', id: 'r1')
            ..connect('b', 'c', id: 'r2'))
          .build();
    });

    test('highlightPathBetween emits the resolved path', () async {
      final future = navigation.events.first;
      final found = navigation.highlightPathBetween(graph, 'a', 'c');
      expect(found, isTrue);
      final event = await future;
      expect(event.kind, NavigationEventKind.highlightPath);
      expect(event.highlightedNodeIds, ['a', 'b', 'c']);
      expect(event.highlightedRelationshipIds, ['r1', 'r2']);
    });

    test('highlightPathBetween returns false when unreachable', () {
      final graphWithIsolated = graph.withNode(
        const EngineeringNode(
          id: 'isolated',
          category: NodeCategory.component,
          displayName: 'Isolated',
        ),
      );
      final found =
          navigation.highlightPathBetween(graphWithIsolated, 'a', 'isolated');
      expect(found, isFalse);
    });

    test('clearHighlight emits a clearHighlight event', () async {
      final future = navigation.events.first;
      navigation.clearHighlight();
      final event = await future;
      expect(event.kind, NavigationEventKind.clearHighlight);
    });
  });

  group('EngineEventBus', () {
    test('on() filters by event kind', () async {
      final bus = EngineEventBus();
      final future = bus.on(EngineEventKind.nodeSelected).first;
      bus.emit(EngineEvent(kind: EngineEventKind.graphChanged));
      bus.emit(EngineEvent(kind: EngineEventKind.nodeSelected, subjectId: 'n1'));
      final event = await future;
      expect(event.subjectId, 'n1');
    });
  });
}
