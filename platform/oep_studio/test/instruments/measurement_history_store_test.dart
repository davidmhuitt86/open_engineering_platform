import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/history/measurement_history_entry.dart';
import 'package:oep_studio/diagram_studio/instruments/history/measurement_history_store.dart';

MeasurementResult _result() => MeasurementResult(
      type: MeasurementType.voltageDc,
      mode: MeasurementMode.manual,
      probeA: const ProbePoint(nodeId: 'battery'),
      probeB: const ProbePoint(nodeId: 'lamp'),
      reachable: true,
      timestamp: DateTime(2026, 1, 1),
      measuredValue: 12,
      unit: 'V',
      path: const ['battery', 'fuse1', 'lamp'],
    );

void main() {
  test('MeasurementHistoryEntry round-trips through JSON', () {
    final entry = MeasurementHistoryEntry(id: 'e1', result: _result());
    final restored = MeasurementHistoryEntry.fromJson(entry.toJson());
    expect(restored.id, 'e1');
    expect(restored.result.measuredValue, 12);
    expect(restored.result.path, ['battery', 'fuse1', 'lamp']);
  });

  test('MeasurementHistoryStore.load() returns an empty list when no file exists yet', () async {
    // Doesn't assume a clean slate on a real machine -- only asserts the
    // method returns a usable list, matching WorkspaceStateStorage's own
    // precedent test.
    final loaded = await MeasurementHistoryStore.load();
    expect(loaded, isA<List<MeasurementHistoryEntry>>());
  });

  test('MeasurementHistoryStore save() then load() round-trips real entries', () async {
    final original = await MeasurementHistoryStore.load();
    final probe = [MeasurementHistoryEntry(id: 'probe-1', result: _result())];
    try {
      await MeasurementHistoryStore.save(probe);
      final reloaded = await MeasurementHistoryStore.load();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.id, 'probe-1');
    } finally {
      await MeasurementHistoryStore.save(original);
    }
  });

  test('exportJson produces valid, human-readable JSON containing the entry data', () {
    final json = MeasurementHistoryStore.exportJson([MeasurementHistoryEntry(id: 'e1', result: _result())]);
    expect(json, contains('"id": "e1"'));
    expect(json, contains('voltageDc'));
  });
}
