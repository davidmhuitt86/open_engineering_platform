import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  late EditingSession session;

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A', symbolId: 'battery'))
        .build();
    session = EditingSession.initial(graph).copyWith(
      layout: DiagramLayoutState.empty.withPosition('a', const Point2D(10, 10)),
    );
  });

  group('ResizeNodeCommand', () {
    test('applies a new size and reverts to no tracked size', () {
      final resize = ResizeNodeCommand('a', const Size2D(200, 150));
      final after = resize.apply(session);
      expect(after.layout.sizeOf('a'), const Size2D(200, 150));
      expect(after.graph, same(session.graph)); // graph untouched — SDD-024 Rule 5

      final reverted = resize.revert(after);
      expect(reverted.layout.sizeOf('a'), isNull);
    });

    test('reverting restores a previously-tracked size rather than clearing it', () {
      final withSize = session.copyWith(layout: session.layout.withSize('a', const Size2D(100, 100)));
      final resize = ResizeNodeCommand('a', const Size2D(300, 250));
      final after = resize.apply(withSize);
      expect(after.layout.sizeOf('a'), const Size2D(300, 250));

      final reverted = resize.revert(after);
      expect(reverted.layout.sizeOf('a'), const Size2D(100, 100));
    });

    test('an optional newPosition moves the node atomically alongside the resize, and reverts both', () {
      final resize = ResizeNodeCommand('a', const Size2D(200, 200), newPosition: const Point2D(-40, -40));
      final after = resize.apply(session);
      expect(after.layout.sizeOf('a'), const Size2D(200, 200));
      expect(after.layout.positionOf('a'), const Point2D(-40, -40));

      final reverted = resize.revert(after);
      expect(reverted.layout.sizeOf('a'), isNull);
      expect(reverted.layout.positionOf('a'), const Point2D(10, 10));
    });

    test('DiagramView renders a resized node at its tracked size, not the default nodeSize', () {
      final resize = ResizeNodeCommand('a', const Size2D(180, 90));
      final after = resize.apply(session);
      final scene = DiagramView().render(after.graph, layout: after.layout);
      final node = scene.nodes.single;
      expect(node.width, 180);
      expect(node.height, 90);
    });
  });

  group('DiagramLayoutState sizes', () {
    test('round-trips through toJson/fromJson', () {
      final layout = DiagramLayoutState.empty.withSize('a', const Size2D(64, 48));
      final restored = DiagramLayoutState.fromJson(layout.toJson());
      expect(restored.sizeOf('a'), const Size2D(64, 48));
    });
  });
}
