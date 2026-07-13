import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('ConnectionValidator', () {
    late EngineeringGraph graph;

    setUp(() {
      graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B')
            ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C')
            ..connect('a', 'b', id: 'r1'))
          .build();
    });

    test('rejects self-loops', () {
      expect(ConnectionValidator.canConnect(graph, 'a', 'a'), isFalse);
    });

    test('rejects duplicate relationships in either direction', () {
      expect(ConnectionValidator.canConnect(graph, 'a', 'b'), isFalse);
      expect(ConnectionValidator.canConnect(graph, 'b', 'a'), isFalse);
    });

    test('allows a genuinely new connection', () {
      expect(ConnectionValidator.canConnect(graph, 'a', 'c'), isTrue);
      expect(ConnectionValidator.canConnect(graph, 'b', 'c'), isTrue);
    });
  });
}
