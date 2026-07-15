import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  late EditingSession session;
  const layer = DiagramLayer(id: 'layer1', name: 'Power');

  setUp(() {
    final graph = (GraphBuilder(id: 'g')
          ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A'))
        .build();
    session = EditingSession.initial(graph);
  });

  group('CreateLayerCommand / DeleteLayerCommand', () {
    test('create adds the layer; revert removes it', () {
      final command = CreateLayerCommand(layer);
      final after = command.apply(session);
      expect(after.layout.layerById('layer1'), layer);
      final reverted = command.revert(after);
      expect(reverted.layout.layerById('layer1'), isNull);
    });

    test('delete removes the layer and unassigns its members; revert restores both', () {
      var withLayer = session.copyWith(layout: session.layout.withLayer(layer));
      withLayer = withLayer.copyWith(layout: withLayer.layout.withLayerAssignment('a', 'layer1'));

      final command = DeleteLayerCommand('layer1');
      final after = command.apply(withLayer);
      expect(after.layout.layerById('layer1'), isNull);
      expect(after.layout.layerOf('a'), isNull);

      final reverted = command.revert(after);
      expect(reverted.layout.layerById('layer1'), layer);
      expect(reverted.layout.layerOf('a'), 'layer1');
    });
  });

  group('UpdateLayerCommand', () {
    test('patches name/visible/locked/printVisible/order and reverts exactly', () {
      final withLayer = session.copyWith(layout: session.layout.withLayer(layer));
      final command = UpdateLayerCommand(
        'layer1',
        name: 'Renamed',
        visible: false,
        locked: true,
        printVisible: false,
        order: 3,
      );
      final after = command.apply(withLayer);
      final updated = after.layout.layerById('layer1')!;
      expect(updated.name, 'Renamed');
      expect(updated.visible, isFalse);
      expect(updated.locked, isTrue);
      expect(updated.printVisible, isFalse);
      expect(updated.order, 3);

      final reverted = command.revert(after);
      expect(reverted.layout.layerById('layer1'), layer);
    });
  });

  group('AssignLayerCommand', () {
    test('assigns then reverts to the previous (unassigned) state', () {
      final command = AssignLayerCommand('a', 'layer1');
      final after = command.apply(session);
      expect(after.layout.layerOf('a'), 'layer1');
      final reverted = command.revert(after);
      expect(reverted.layout.layerOf('a'), isNull);
    });

    test('null layerId unassigns; revert restores the previous assignment', () {
      final assigned = session.copyWith(layout: session.layout.withLayerAssignment('a', 'layer1'));
      final command = AssignLayerCommand('a', null);
      final after = command.apply(assigned);
      expect(after.layout.layerOf('a'), isNull);
      final reverted = command.revert(after);
      expect(reverted.layout.layerOf('a'), 'layer1');
    });
  });

  group('DiagramView layer visibility filtering', () {
    test('a node on a hidden layer is excluded from the rendered scene', () {
      final graph = (GraphBuilder(id: 'g')
            ..addNode(id: 'a', category: NodeCategory.component, displayName: 'A')
            ..addNode(id: 'b', category: NodeCategory.component, displayName: 'B'))
          .build();
      final hiddenLayer = const DiagramLayer(id: 'hidden', name: 'Hidden', visible: false);
      final layout = DiagramLayoutState.empty
          .withPosition('a', const Point2D(0, 0))
          .withPosition('b', const Point2D(100, 0))
          .withLayer(hiddenLayer)
          .withLayerAssignment('a', 'hidden');

      final scene = DiagramView().render(graph, layout: layout);
      expect(scene.nodes.map((n) => n.nodeId), ['b']);
    });
  });
}
