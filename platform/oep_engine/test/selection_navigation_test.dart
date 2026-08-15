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

    test('selectAnnotation / toggleAnnotation manage annotationIds independently', () {
      selection.selectAnnotation('ann1');
      expect(selection.current.annotationIds, {'ann1'});
      selection.selectAnnotation('ann2', additive: true);
      expect(selection.current.annotationIds, {'ann1', 'ann2'});
      selection.toggleAnnotation('ann1');
      expect(selection.current.annotationIds, {'ann2'});

      // Non-additive selectAnnotation replaces the whole selection, same
      // as non-additive selectNode/selectRelationship/selectGroup.
      selection.selectNode('n1');
      selection.selectAnnotation('ann3');
      expect(selection.current.nodeIds, isEmpty);
      expect(selection.current.annotationIds, {'ann3'});
    });
  });

  group('SelectionService advanced selection modes (WORK_PACKAGE_023)', () {
    late SelectionService selection;
    late EngineeringGraph graph;
    late DiagramLayoutState layout;

    setUp(() {
      selection = SelectionService(events: EngineEventBus());
      graph = (GraphBuilder(id: 'g')
            ..addNode(
                id: 'a',
                category: NodeCategory.component,
                displayName: 'A',
                symbolId: 'sym1')
            ..addNode(
                id: 'b',
                category: NodeCategory.component,
                displayName: 'B',
                symbolId: 'sym1')
            ..addNode(id: 'c', category: NodeCategory.switchNode, displayName: 'C')
            ..addNode(id: 'd', category: NodeCategory.component, displayName: 'D')
            ..connect('a', 'b', id: 'r1'))
          .build();
      layout = DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(200, 0))
          .withPosition('c', const Point2D(400, 0))
          .withPosition('d', const Point2D(600, 0))
          .withLayerAssignment('a', 'layer1')
          .withLayerAssignment('b', 'layer1');
    });

    DiagramScene sceneFor(EngineeringGraph graph, DiagramLayoutState layout) {
      return DiagramScene(
        nodes: [
          for (final node in graph.nodes.values)
            DiagramNodeVisual(
              nodeId: node.id,
              symbolId: node.symbolId,
              position: layout.positionOf(node.id)!,
              width: 100,
              height: 100,
            ),
        ],
        wires: const [],
        contentWidth: 800,
        contentHeight: 200,
      );
    }

    test('selectByRect with crossing:true selects any node the rect touches', () {
      final scene = sceneFor(graph, layout);
      // a: (0,0)-(100,100); b: (200,0)-(300,100) — a rect spanning x 50-250
      // only partially overlaps each, but "crossing" still selects both.
      selection.selectByRect(
        scene,
        const Rect2D(left: 50, top: -10, right: 250, bottom: 50),
      );
      expect(selection.current.nodeIds, {'a', 'b'});
    });

    test('selectByRect with crossing:false (window) requires full containment', () {
      final scene = sceneFor(graph, layout);
      selection.selectByRect(
        scene,
        const Rect2D(left: 50, top: -10, right: 150, bottom: 50),
        crossing: false,
      );
      expect(selection.current.nodeIds, isEmpty);

      selection.selectByRect(
        scene,
        const Rect2D(left: -10, top: -10, right: 310, bottom: 110),
        crossing: false,
      );
      expect(selection.current.nodeIds, {'a', 'b'});
    });

    test('selectByLasso selects nodes whose center falls inside the polygon', () {
      final scene = sceneFor(graph, layout);
      selection.selectByLasso(scene, const [
        Point2D(-10, -10),
        Point2D(310, -10),
        Point2D(310, 110),
        Point2D(-10, 110),
      ]);
      expect(selection.current.nodeIds, {'a', 'b'});
    });

    test('selectConnectedComponent selects the undirected reachable set', () {
      selection.selectConnectedComponent(graph, 'a');
      expect(selection.current.nodeIds, {'a', 'b'});
    });

    test('selectSimilar matches category + symbolId, including the origin node', () {
      selection.selectSimilar(graph, graph.nodes['a']!);
      expect(selection.current.nodeIds, {'a', 'b'});
    });

    test('selectByCategory selects every node of that category', () {
      selection.selectByCategory(graph, NodeCategory.component);
      expect(selection.current.nodeIds, {'a', 'b', 'd'});
    });

    test('selectByLayer selects every node/annotation assigned to that layer', () {
      selection.selectByLayer(layout, 'layer1');
      expect(selection.current.nodeIds, {'a', 'b'});
    });

    test('invertSelection replaces the selection with everything currently unselected', () {
      selection.selectNode('a');
      selection.invertSelection(graph, layout);
      expect(selection.current.nodeIds, {'b', 'c', 'd'});
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

    test('setSearchResults/nextResult/previousResult cycle through results (WORK_PACKAGE_023)', () {
      expect(navigation.currentResult, isNull);
      navigation.setSearchResults(const [
        SearchResult(id: 'a', kind: SearchResultKind.node, label: 'A', matchedField: 'displayName'),
        SearchResult(id: 'b', kind: SearchResultKind.node, label: 'B', matchedField: 'displayName'),
      ]);
      expect(navigation.currentResult?.id, 'a');
      navigation.nextResult();
      expect(navigation.currentResult?.id, 'b');
      navigation.nextResult();
      expect(navigation.currentResult?.id, 'a', reason: 'wraps around');
      navigation.previousResult();
      expect(navigation.currentResult?.id, 'b', reason: 'wraps backward too');
    });

    test('setSearchResults with an empty list clears currentResult', () {
      navigation.setSearchResults(const [
        SearchResult(id: 'a', kind: SearchResultKind.node, label: 'A', matchedField: 'displayName'),
      ]);
      navigation.setSearchResults(const []);
      expect(navigation.currentResult, isNull);
      navigation.nextResult(); // no-op, must not throw
      expect(navigation.currentResult, isNull);
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
