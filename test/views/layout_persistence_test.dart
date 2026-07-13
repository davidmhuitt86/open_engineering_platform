import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('InMemoryLayoutProvider named layouts', () {
    late InMemoryLayoutProvider provider;

    setUp(() => provider = InMemoryLayoutProvider());

    test('save/load/list/delete a named layout', () async {
      final layout = DiagramLayoutState.empty.withPosition('a', const Point2D(1, 2));
      await provider.saveNamedLayout('g1', 'Default', layout);

      expect(provider.listNamedLayouts('g1'), ['Default']);
      expect(provider.loadNamedLayout('g1', 'Default')?.positionOf('a'), const Point2D(1, 2));
      expect(provider.loadNamedLayout('g1', 'Missing'), isNull);

      await provider.deleteNamedLayout('g1', 'Default');
      expect(provider.listNamedLayouts('g1'), isEmpty);
    });

    test('named layouts are independent of the live current layout', () async {
      await provider.updateLayout('g1', DiagramLayoutState.empty.withPosition('a', const Point2D(9, 9)));
      await provider.saveNamedLayout('g1', 'Saved', DiagramLayoutState.empty.withPosition('a', const Point2D(1, 1)));

      expect(provider.currentLayout('g1').positionOf('a'), const Point2D(9, 9));
      expect(provider.loadNamedLayout('g1', 'Saved')?.positionOf('a'), const Point2D(1, 1));
    });

    test('resetLayout clears the current (not named) layout', () async {
      await provider.updateLayout('g1', DiagramLayoutState.empty.withPosition('a', const Point2D(9, 9)));
      await provider.saveNamedLayout('g1', 'Saved', DiagramLayoutState.empty.withPosition('a', const Point2D(1, 1)));

      await provider.resetLayout('g1');
      expect(provider.currentLayout('g1'), DiagramLayoutState.empty);
      expect(provider.loadNamedLayout('g1', 'Saved'), isNotNull);
    });

    test('layouts are scoped per graph id', () async {
      await provider.saveNamedLayout('g1', 'Default', DiagramLayoutState.empty);
      expect(provider.listNamedLayouts('g2'), isEmpty);
    });
  });

  group('JsonFileLayoutSerializer', () {
    test('write then read round-trips a DiagramLayoutState', () async {
      final tempDir = await Directory.systemTemp.createTemp('oep_engine_layout_');
      addTearDown(() => tempDir.delete(recursive: true));

      final serializer = JsonFileLayoutSerializer();
      final layout = DiagramLayoutState.empty
          .withPosition('a', const Point2D(10, 20))
          .withPosition('b', const Point2D(-5, 30));
      final path = '${tempDir.path}/layout.json';
      await serializer.write(layout, path);
      final restored = await serializer.read(path);

      expect(restored.positionOf('a'), const Point2D(10, 20));
      expect(restored.positionOf('b'), const Point2D(-5, 30));
    });
  });
}
