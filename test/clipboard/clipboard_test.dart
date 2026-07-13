import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  late EditingSession session;
  late ClipboardService clipboardService;

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A', symbolId: 'battery')
          ..addNode(id: 'b', category: NodeCategory.ground, displayName: 'B', symbolId: 'ground')
          ..addNode(id: 'c', category: NodeCategory.component, displayName: 'C')
          ..connect('a', 'b', id: 'r1'))
        .build();
    session = EditingSession.initial(graph).copyWith(
      layout: DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(50, 50)),
    );
    clipboardService = ClipboardService(provider: InMemoryClipboardProvider());
  });

  group('ClipboardExtraction', () {
    test('preserves relationships only when both endpoints are selected', () {
      final selection = GraphSelection(nodeIds: {'a', 'b'});
      final entry = ClipboardExtraction.extract(session, selection);
      expect(entry.nodes.length, 2);
      expect(entry.relationships.length, 1);
      expect(entry.positions['a'], const Point2D(0, 0));
    });

    test('excludes relationships when only one endpoint is selected', () {
      final selection = GraphSelection(nodeIds: {'a', 'c'});
      final entry = ClipboardExtraction.extract(session, selection);
      expect(entry.relationships, isEmpty);
    });
  });

  group('PasteCommand', () {
    test('generates fresh ids and remaps relationship endpoints', () {
      clipboardService.copy(session, GraphSelection(nodeIds: {'a', 'b'}));
      final paste = clipboardService.paste()!;
      final after = paste.apply(session);

      expect(after.graph.nodes.length, 5); // a, b, c + 2 pasted
      expect(paste.pastedNodeIds.length, 2);
      expect(paste.pastedNodeIds.toSet().intersection({'a', 'b'}), isEmpty);

      final pastedRelationship =
          after.graph.relationships.values.firstWhere((r) => r.id != 'r1');
      expect(paste.pastedNodeIds, contains(pastedRelationship.sourceNode));
      expect(paste.pastedNodeIds, contains(pastedRelationship.targetNode));

      final reverted = paste.revert(after);
      expect(reverted.graph.nodes.length, 3);
    });

    test('offsets pasted layout positions', () {
      clipboardService.copy(session, GraphSelection(nodeIds: {'a'}));
      final paste = clipboardService.paste(offset: const Point2D(10, 10))!;
      final after = paste.apply(session);
      final newId = paste.pastedNodeIds.single;
      expect(after.layout.positionOf(newId), const Point2D(10, 10));
    });
  });

  group('DuplicateSelectionCommand', () {
    test('duplicates the current selection without touching the clipboard', () {
      final duplicate = clipboardService.duplicate(GraphSelection(nodeIds: {'a', 'b'}));
      final after = duplicate.apply(session);
      expect(after.graph.nodes.length, 5);
      expect(clipboardService.hasContent, isFalse);
    });
  });

  group('Cut (via DeleteManyCommand)', () {
    test('cut copies then deletes the selection', () {
      final cutCommand = clipboardService.cut(session, GraphSelection(nodeIds: {'a', 'b'}));
      expect(clipboardService.hasContent, isTrue);
      final after = cutCommand.apply(session);
      expect(after.graph.nodes.containsKey('a'), isFalse);
      expect(after.graph.nodes.containsKey('b'), isFalse);
      expect(after.graph.relationships.containsKey('r1'), isFalse);

      final reverted = cutCommand.revert(after);
      expect(reverted.graph.nodes.length, 3);
      expect(reverted.graph.relationships.containsKey('r1'), isTrue);
    });
  });
}
