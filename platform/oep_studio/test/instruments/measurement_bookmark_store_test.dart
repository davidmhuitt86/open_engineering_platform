import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/bookmarks/measurement_bookmark.dart';
import 'package:oep_studio/diagram_studio/instruments/bookmarks/measurement_bookmark_store.dart';

void main() {
  test('MeasurementBookmark round-trips through JSON', () {
    const bookmark = MeasurementBookmark(
      id: 'b1',
      name: 'Battery rail',
      group: 'Power',
      probeA: ProbePoint(nodeId: 'battery'),
      probeB: ProbePoint(nodeId: 'lamp'),
      type: MeasurementType.voltageDc,
    );
    final restored = MeasurementBookmark.fromJson(bookmark.toJson());
    expect(restored.id, 'b1');
    expect(restored.name, 'Battery rail');
    expect(restored.group, 'Power');
    expect(restored.probeA.nodeId, 'battery');
    expect(restored.probeB.nodeId, 'lamp');
    expect(restored.type, MeasurementType.voltageDc);
  });

  test('MeasurementBookmark.fromJson defaults group to "Ungrouped"', () {
    final restored = MeasurementBookmark.fromJson({
      'id': 'b1',
      'name': 'x',
      'probeA': const ProbePoint(nodeId: 'a').toJson(),
      'probeB': const ProbePoint(nodeId: 'b').toJson(),
      'type': 'current',
    });
    expect(restored.group, 'Ungrouped');
  });

  test('MeasurementBookmarkStore save() then load() round-trips real bookmarks', () async {
    final original = await MeasurementBookmarkStore.load();
    const probe = [
      MeasurementBookmark(
        id: 'probe-b1',
        name: 'probe bookmark',
        probeA: ProbePoint(nodeId: 'battery'),
        probeB: ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.resistance,
      ),
    ];
    try {
      await MeasurementBookmarkStore.save(probe);
      final reloaded = await MeasurementBookmarkStore.load();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.id, 'probe-b1');
    } finally {
      await MeasurementBookmarkStore.save(original);
    }
  });
}
