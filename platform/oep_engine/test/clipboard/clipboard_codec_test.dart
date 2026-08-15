import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('ClipboardCodec', () {
    test('round-trips a ClipboardEntry through JSON', () {
      final entry = ClipboardEntry(
        nodes: [
          EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A', symbolId: 'battery'),
        ],
        relationships: [
          EngineeringRelationship(
            id: 'r1',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'a',
            targetNode: 'a',
          ),
        ],
        positions: const {'a': Point2D(10, 20)},
      );

      final encoded = ClipboardCodec.encode(entry);
      final decoded = ClipboardCodec.decode(encoded)!;

      expect(decoded.nodes.single.id, 'a');
      expect(decoded.nodes.single.displayName, 'A');
      expect(decoded.relationships.single.id, 'r1');
      expect(decoded.positions['a'], const Point2D(10, 20));
    });

    test('decode rejects arbitrary non-Diagram-Studio text', () {
      expect(ClipboardCodec.decode('just some copied text'), isNull);
      expect(ClipboardCodec.decode('{"unrelated": true}'), isNull);
      expect(ClipboardCodec.decode('{"__marker__": "wrong-tag", "entry": {}}'), isNull);
    });

    test('decode rejects malformed JSON without throwing', () {
      expect(ClipboardCodec.decode('{not valid json'), isNull);
    });
  });
}
