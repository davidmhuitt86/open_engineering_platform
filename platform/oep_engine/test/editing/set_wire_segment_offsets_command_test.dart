import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — `SetWireSegmentOffsetsCommand`/
/// `DiagramLayoutState.wireSegmentOffsets` are the Engine-level storage
/// for the Legacy Wiring Simulator V2 bridge's own relative wire-route
/// adjustment (a scalar perpendicular offset per V2-computed "movable
/// segment" index), kept deliberately separate from `wireOverrides`/
/// `SetWireRouteCommand` (an absolute point list) — see both classes' own
/// doc comments for the full rationale.
void main() {
  late EditingSession session;

  setUp(() {
    final graph =
        (GraphBuilder(id: 'g')
              ..addNode(
                id: 'a',
                category: NodeCategory.component,
                displayName: 'A',
                symbolId: 'battery',
              )
              ..addNode(
                id: 'b',
                category: NodeCategory.component,
                displayName: 'B',
                symbolId: 'ground',
              )
              ..connect('a', 'b', id: 'r1'))
            .build();
    session = EditingSession.initial(graph);
  });

  group('SetWireSegmentOffsetsCommand', () {
    test('applies segment offsets and reverts to none', () {
      final command = SetWireSegmentOffsetsCommand('r1', {0: 12.5, 1: -4.0});
      final after = command.apply(session);
      expect(after.layout.wireSegmentOffsetsOf('r1'), {0: 12.5, 1: -4.0});
      expect(
        after.graph,
        same(session.graph),
      ); // layout state, never Engineering Graph data

      final reverted = command.revert(after);
      expect(reverted.layout.wireSegmentOffsetsOf('r1'), isNull);
    });

    test(
      'reverting restores previously-set offsets rather than clearing them',
      () {
        final withOffsets = session.copyWith(
          layout: session.layout.withWireSegmentOffsets('r1', {0: 5.0}),
        );
        final command = SetWireSegmentOffsetsCommand('r1', {0: 20.0, 2: 7.5});
        final after = command.apply(withOffsets);
        expect(after.layout.wireSegmentOffsetsOf('r1'), {0: 20.0, 2: 7.5});

        final reverted = command.revert(after);
        expect(reverted.layout.wireSegmentOffsetsOf('r1'), {0: 5.0});
      },
    );

    test('offsets == null is Reset Route -- clears the whole entry', () {
      final withOffsets = session.copyWith(
        layout: session.layout.withWireSegmentOffsets('r1', {0: 5.0, 1: 3.0}),
      );
      final command = SetWireSegmentOffsetsCommand('r1', null);
      final after = command.apply(withOffsets);
      expect(after.layout.wireSegmentOffsetsOf('r1'), isNull);

      final reverted = command.revert(after);
      expect(reverted.layout.wireSegmentOffsetsOf('r1'), {0: 5.0, 1: 3.0});
    });

    test(
      'is entirely independent of wireOverrides for the same relationship',
      () {
        final withBoth = session.copyWith(
          layout: session.layout
              .withWireOverride('r1', const [Point2D(0, 0), Point2D(10, 10)])
              .withWireSegmentOffsets('r1', {0: 3.0}),
        );
        final command = SetWireSegmentOffsetsCommand('r1', null);
        final after = command.apply(withBoth);
        expect(after.layout.wireSegmentOffsetsOf('r1'), isNull);
        expect(after.layout.wireOverrideOf('r1'), const [
          Point2D(0, 0),
          Point2D(10, 10),
        ]);
      },
    );
  });

  group('DiagramLayoutState.wireSegmentOffsets', () {
    test(
      'round-trips through toJson/fromJson, including negative and multi-segment offsets',
      () {
        final layout = DiagramLayoutState.empty.withWireSegmentOffsets('r1', {
          0: -12.5,
          3: 40.0,
        });
        final restored = DiagramLayoutState.fromJson(layout.toJson());
        expect(restored.wireSegmentOffsetsOf('r1'), {0: -12.5, 3: 40.0});
      },
    );

    test(
      'an empty/absent layout has no wire segment offsets for any relationship',
      () {
        expect(DiagramLayoutState.empty.wireSegmentOffsetsOf('r1'), isNull);
      },
    );
  });
}
