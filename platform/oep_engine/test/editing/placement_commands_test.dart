import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('PlacementMath', () {
    test('rotatedPositions leaves a single node in place (rotates around itself)', () {
      final positions = {'a': const Point2D(10, 10)};
      final rotated = PlacementMath.rotatedPositions(positions, 90);
      expect(rotated, positions);
    });

    test('rotatedPositions rotates two nodes 180 degrees around their shared center', () {
      final positions = {'a': const Point2D(0, 0), 'b': const Point2D(100, 0)};
      final rotated = PlacementMath.rotatedPositions(positions, 180);
      // Center (including node size) is at x=(0+100)/2 + nodeSize/2... using
      // default DiagramLayout.nodeSize=100, bounding box is 0..200, center
      // (100,50). A 180-degree rotation swaps a and b's positions.
      expect(rotated['a']!.dx, closeTo(100, 0.01));
      expect(rotated['b']!.dx, closeTo(0, 0.01));
    });

    test('mirroredPositions reflects horizontally around the bounding-box center', () {
      final positions = {'a': const Point2D(0, 0), 'b': const Point2D(100, 0)};
      final mirrored = PlacementMath.mirroredPositions(positions, MirrorAxis.horizontal);
      // a and b swap x positions (mirrored across the shared center).
      expect(mirrored['a']!.dx, closeTo(100, 0.01));
      expect(mirrored['b']!.dx, closeTo(0, 0.01));
      expect(mirrored['a']!.dy, 0);
    });

    test('arrayOffsets excludes the (0,0) origin cell', () {
      final offsets = PlacementMath.arrayOffsets(countX: 2, countY: 2, spacingX: 10, spacingY: 20);
      expect(offsets, [
        const Point2D(10, 0),
        const Point2D(0, 20),
        const Point2D(10, 20),
      ]);
    });
  });

  late EditingSession session;

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(
              id: 'a', category: NodeCategory.component, displayName: 'A', symbolId: 'sym1')
          ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B'))
        .build();
    session = EditingSession.initial(graph).copyWith(
      layout: DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(100, 0)),
    );
  });

  group('RotateNodesCommand', () {
    test('rotates positions and advances each node transform; reverts exactly', () {
      final command = RotateNodesCommand({'a', 'b'}, 90);
      final after = command.apply(session);
      expect(after.layout.transformOf('a').rotation, 90);
      expect(after.layout.transformOf('b').rotation, 90);

      final reverted = command.revert(after);
      expect(reverted.layout.positionOf('a'), const Point2D(0, 0));
      expect(reverted.layout.positionOf('b'), const Point2D(100, 0));
      expect(reverted.layout.transformOf('a').rotation, 0);
    });
  });

  group('MirrorNodesCommand', () {
    test('reflects positions and flips the transform flag; reverts exactly', () {
      final command = MirrorNodesCommand({'a', 'b'}, MirrorAxis.horizontal);
      final after = command.apply(session);
      expect(after.layout.transformOf('a').flipHorizontal, isTrue);

      final reverted = command.revert(after);
      expect(reverted.layout.positionOf('a'), const Point2D(0, 0));
      expect(reverted.layout.transformOf('a').flipHorizontal, isFalse);
    });
  });

  group('ArrayPlaceCommand', () {
    test('duplicates each selected node into the grid, keeping originals in place', () {
      final command = ArrayPlaceCommand({'a'}, countX: 2, countY: 1, spacingX: 50, spacingY: 50);
      final after = command.apply(session);
      expect(after.graph.nodes.length, 3, reason: 'original a + original b + 1 duplicate');
      final duplicateId = after.graph.nodes.keys.firstWhere((id) => id != 'a' && id != 'b');
      expect(after.layout.positionOf(duplicateId), const Point2D(50, 0));
      expect(after.graph.nodes[duplicateId]!.symbolId, 'sym1');

      final reverted = command.revert(after);
      expect(reverted.graph.nodes.containsKey(duplicateId), isFalse);
      expect(reverted.graph.nodes.length, 2, reason: 'back to a + b');
    });

    test('is a no-op when the grid is 1x1 (no additional cells)', () {
      final command = ArrayPlaceCommand({'a'}, countX: 1, countY: 1);
      final after = command.apply(session);
      expect(after.graph.nodes.length, 2);
    });
  });

  group('Never-moved nodes (WORK_PACKAGE_023 regression)', () {
    // Rotate/Mirror/Array must resolve the same auto-layout fallback
    // DiagramView renders with, not require an already-tracked position.
    late EditingSession freshSession;

    setUp(() {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B'))
          .build();
      freshSession = EditingSession.initial(graph);
    });

    test('RotateNodesCommand rotates nodes that have never been moved', () {
      final command = RotateNodesCommand({'a', 'b'}, 90);
      final after = command.apply(freshSession);
      expect(after.layout.transformOf('a').rotation, 90);
      expect(after.layout.positionOf('a'), isNotNull);
    });

    test('MirrorNodesCommand mirrors nodes that have never been moved', () {
      final command = MirrorNodesCommand({'a', 'b'}, MirrorAxis.horizontal);
      final after = command.apply(freshSession);
      expect(after.layout.transformOf('a').flipHorizontal, isTrue);
      expect(after.layout.positionOf('a'), isNotNull);
    });

    test('ArrayPlaceCommand places copies of a node that has never been moved', () {
      final command = ArrayPlaceCommand({'a'}, countX: 2, countY: 1, spacingX: 50);
      final after = command.apply(freshSession);
      expect(after.graph.nodes.length, 3, reason: 'a + b + 1 duplicate');
    });
  });

  group('ReplaceSymbolCommand', () {
    test('replaces symbolId and reverts to the previous value', () {
      final command = ReplaceSymbolCommand('a', 'sym2');
      final after = command.apply(session);
      expect(after.graph.nodes['a']!.symbolId, 'sym2');
      final reverted = command.revert(after);
      expect(reverted.graph.nodes['a']!.symbolId, 'sym1');
    });

    test('reverting a node that never had a symbol clears it again', () {
      final command = ReplaceSymbolCommand('b', 'sym2');
      final after = command.apply(session);
      expect(after.graph.nodes['b']!.symbolId, 'sym2');
      final reverted = command.revert(after);
      expect(reverted.graph.nodes['b']!.symbolId, isNull);
    });
  });
}
