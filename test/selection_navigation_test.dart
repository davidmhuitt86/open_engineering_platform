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

    test('selectNode updates current and emits a change', () async {
      final future = selection.changes.first;
      selection.selectNode('n1');
      final emitted = await future;
      expect(emitted.kind, SelectionKind.node);
      expect(emitted.id, 'n1');
      expect(selection.current.id, 'n1');
    });

    test('clear resets to none', () {
      selection.selectNode('n1');
      selection.clear();
      expect(selection.current.isEmpty, isTrue);
    });

    test('selectPort carries owner id', () {
      selection.selectPort('n1', 'p1');
      expect(selection.current.kind, SelectionKind.port);
      expect(selection.current.id, 'p1');
      expect(selection.current.ownerId, 'n1');
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
