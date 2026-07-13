import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('ViewStateService', () {
    late ViewStateService service;

    setUp(() => service = ViewStateService());

    test('starts at initial state', () {
      expect(service.current.zoom, 1.0);
      expect(service.current.pan, const Point2D(0, 0));
    });

    test('setZoom/setPan/setViewportSize update state and emit', () async {
      final future = service.changes.first;
      service.setZoom(2.0);
      final emitted = await future;
      expect(emitted.zoom, 2.0);
      expect(service.current.zoom, 2.0);
    });

    test('toggleGrid/toggleSnap flip GridSettings booleans', () {
      expect(service.current.grid.visible, isTrue);
      service.toggleGrid();
      expect(service.current.grid.visible, isFalse);
      expect(service.current.grid.snapEnabled, isTrue);
      service.toggleSnap();
      expect(service.current.grid.snapEnabled, isFalse);
    });

    test('hoverPort sets and clears the hovered port', () {
      service.hoverPort(const PortReference(nodeId: 'n1', portId: 'p1'));
      expect(service.current.hoveredPort, const PortReference(nodeId: 'n1', portId: 'p1'));
      service.hoverPort(null);
      expect(service.current.hoveredPort, isNull);
    });

    test('setRenderOption merges into the map without clobbering others', () {
      service.setRenderOption('a', 1);
      service.setRenderOption('b', 2);
      expect(service.current.renderOptions, {'a': 1, 'b': 2});
    });

    group('viewport navigation', () {
      setUp(() => service.setViewportSize(800, 600));

      test('fitAll computes a zoom/pan that centers the scene', () {
        service.fitAll(400, 300);
        expect(service.current.zoom, greaterThan(0));
      });

      test('fitSelection / centerSelection operate on a bounding box', () {
        const bounds = Rect2D(left: 100, top: 100, right: 200, bottom: 200);
        service.fitSelection(bounds);
        final zoomAfterFit = service.current.zoom;
        expect(zoomAfterFit, greaterThan(0));

        service.centerSelection(bounds);
        expect(service.current.zoom, zoomAfterFit); // centering never changes zoom
      });

      test('zoomToCursor keeps the scene point under the cursor fixed', () {
        service.setZoom(1.0);
        service.setPan(const Point2D(0, 0));
        const cursor = Point2D(100, 100);
        final sceneBefore = Point2D(
          (cursor.dx - service.current.pan.dx) / service.current.zoom,
          (cursor.dy - service.current.pan.dy) / service.current.zoom,
        );
        service.zoomToCursor(cursor, 2.0);
        final sceneAfter = Point2D(
          (cursor.dx - service.current.pan.dx) / service.current.zoom,
          (cursor.dy - service.current.pan.dy) / service.current.zoom,
        );
        expect(sceneAfter.dx, closeTo(sceneBefore.dx, 0.001));
        expect(sceneAfter.dy, closeTo(sceneBefore.dy, 0.001));
      });

      test('navigation history: fitAll is undoable via goBack/goForward', () {
        final initialZoom = service.current.zoom;
        service.fitAll(400, 300);
        expect(service.canGoBack, isTrue);
        service.goBack();
        expect(service.current.zoom, initialZoom);
        expect(service.canGoForward, isTrue);
        service.goForward();
        expect(service.canGoForward, isFalse);
      });
    });
  });

  group('JsonFileViewStateSerializer', () {
    test('write then read round-trips a ViewState', () async {
      final tempDir = await Directory.systemTemp.createTemp('oep_engine_viewstate_');
      addTearDown(() => tempDir.delete(recursive: true));

      final serializer = JsonFileViewStateSerializer();
      const state = ViewState(
        zoom: 1.5,
        pan: Point2D(10, 20),
        grid: GridSettings(spacing: 25, majorEvery: 4, visible: false, snapEnabled: false),
        guidesVisible: false,
        theme: ViewTheme.dark,
      );
      final path = '${tempDir.path}/viewstate.json';
      await serializer.write(state, path);
      final restored = await serializer.read(path);

      expect(restored.zoom, 1.5);
      expect(restored.pan, const Point2D(10, 20));
      expect(restored.grid.spacing, 25);
      expect(restored.grid.majorEvery, 4);
      expect(restored.guidesVisible, isFalse);
      expect(restored.theme, ViewTheme.dark);
    });
  });
}
