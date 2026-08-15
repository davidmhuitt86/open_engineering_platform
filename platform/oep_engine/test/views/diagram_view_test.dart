import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('DiagramView', () {
    test('empty graph produces an empty scene', () {
      final view = DiagramView();
      final scene = view.render(EngineeringGraph.empty('empty'));
      expect(scene.nodes, isEmpty);
      expect(scene.wires, isEmpty);
    });

    test('renders one visual per node and per relationship', () {
      final graph = (GraphBuilder(id: 'demo')
            ..addNode(
              id: 'a',
              category: NodeCategory.component,
              displayName: 'A',
              symbolId: 'battery',
            )
            ..addNode(id: 'b', category: NodeCategory.ground, displayName: 'B')
            ..connect('a', 'b', id: 'r1'))
          .build();

      final scene = DiagramView().render(graph);
      expect(scene.nodes.length, 2);
      expect(scene.wires.length, 1);
      expect(scene.wires.first.points.length, 2);
      expect(scene.nodes.any((n) => n.symbolId == 'battery'), isTrue);
    });

    test('selection/highlight runtime flags carry into the scene', () {
      final node = const EngineeringNode(
        id: 'a',
        category: NodeCategory.component,
        displayName: 'A',
        runtime: RuntimeMetadata(selected: true, highlighted: true),
      );
      final graph = EngineeringGraph.empty('demo').withNode(node);
      final scene = DiagramView().render(graph);
      expect(scene.nodes.single.selected, isTrue);
      expect(scene.nodes.single.highlighted, isTrue);
    });
  });

  group('DiagramLayout', () {
    test('places nodes on a deterministic grid', () {
      final graph = (GraphBuilder(id: 'demo')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B'))
          .build();
      final positions = DiagramLayout.compute(graph, columns: 4);
      expect(positions.length, 2);
      expect(positions['a'], isNot(equals(positions['b'])));
    });
  });
}
