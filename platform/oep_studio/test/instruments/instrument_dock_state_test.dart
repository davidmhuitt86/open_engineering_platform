import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/instruments/dock/instrument_dock_state.dart';
import 'package:oep_studio/diagram_studio/instruments/dock/instrument_dock_storage.dart';

void main() {
  test('InstrumentDockState round-trips through JSON', () {
    const state = InstrumentDockState(
      position: DockPosition.floating,
      visible: true,
      autoHide: true,
      size: 400,
      floatingLeft: 10,
      floatingTop: 20,
      floatingWidth: 500,
      floatingHeight: 300,
      activeInstrumentId: 'digital_multimeter',
    );

    final restored = InstrumentDockState.fromJson(state.toJson());

    expect(restored.position, DockPosition.floating);
    expect(restored.visible, isTrue);
    expect(restored.autoHide, isTrue);
    expect(restored.size, 400);
    expect(restored.floatingLeft, 10);
    expect(restored.floatingTop, 20);
    expect(restored.floatingWidth, 500);
    expect(restored.floatingHeight, 300);
    expect(restored.activeInstrumentId, 'digital_multimeter');
  });

  test('InstrumentDockState.fromJson falls back to defaults for a malformed/empty map', () {
    final restored = InstrumentDockState.fromJson(const {});
    expect(restored.position, DockPosition.bottom);
    expect(restored.visible, isFalse);
    expect(restored.activeInstrumentId, isNull);
  });

  test('copyWith(clearActiveInstrumentId: true) clears even with a non-null default', () {
    const state = InstrumentDockState(activeInstrumentId: 'digital_multimeter');
    final cleared = state.copyWith(clearActiveInstrumentId: true);
    expect(cleared.activeInstrumentId, isNull);
  });

  test('InstrumentDockStorage.load() returns initial state when no file exists yet', () async {
    final loaded = await InstrumentDockStorage.load();
    expect(loaded, isNotNull);
  });

  test('InstrumentDockStorage save() then load() round-trips a real change', () async {
    final original = await InstrumentDockStorage.load();
    const probe = InstrumentDockState(
      position: DockPosition.floating,
      visible: true,
      size: 250,
      activeInstrumentId: 'probe-test',
    );
    try {
      await InstrumentDockStorage.save(probe);
      final reloaded = await InstrumentDockStorage.load();
      expect(reloaded.position, DockPosition.floating);
      expect(reloaded.visible, isTrue);
      expect(reloaded.size, 250);
      expect(reloaded.activeInstrumentId, 'probe-test');
    } finally {
      await InstrumentDockStorage.save(original);
    }
  });
}
