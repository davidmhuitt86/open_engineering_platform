import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

void main() {
  group('GridComputer', () {
    test('computeLines covers the visible bounds at the configured spacing', () {
      const settings = GridSettings(spacing: 10, majorEvery: 5);
      const bounds = Rect2D(left: 0, top: 0, right: 25, bottom: 15);
      final lines = GridComputer.computeLines(settings, bounds);

      final verticalPositions = lines.where((l) => l.axis == GridAxis.vertical).map((l) => l.position);
      expect(verticalPositions, containsAll([0.0, 10.0, 20.0]));

      final horizontalPositions =
          lines.where((l) => l.axis == GridAxis.horizontal).map((l) => l.position);
      expect(horizontalPositions, containsAll([0.0, 10.0]));
    });

    test('marks every Nth line as major', () {
      const settings = GridSettings(spacing: 10, majorEvery: 5);
      const bounds = Rect2D(left: 0, top: 0, right: 100, bottom: 0);
      final lines = GridComputer.computeLines(settings, bounds)
          .where((l) => l.axis == GridAxis.vertical)
          .toList();
      final majorPositions = lines.where((l) => l.isMajor).map((l) => l.position);
      expect(majorPositions, containsAll([0.0, 50.0, 100.0]));
      expect(lines.firstWhere((l) => l.position == 10.0).isMajor, isFalse);
    });

    test('returns no lines for non-positive spacing', () {
      const settings = GridSettings(spacing: 0);
      const bounds = Rect2D(left: 0, top: 0, right: 100, bottom: 100);
      expect(GridComputer.computeLines(settings, bounds), isEmpty);
    });

    test('snap rounds to the nearest grid intersection when enabled', () {
      const settings = GridSettings(spacing: 20, snapEnabled: true);
      expect(GridComputer.snap(const Point2D(24, 33), settings), const Point2D(20, 40));
    });

    test('snap is a no-op when disabled', () {
      const settings = GridSettings(spacing: 20, snapEnabled: false);
      expect(GridComputer.snap(const Point2D(24, 33), settings), const Point2D(24, 33));
    });
  });
}
