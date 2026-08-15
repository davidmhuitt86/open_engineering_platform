import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/runtime/instrument_lifecycle_state.dart';
import 'package:oep_instruments_runtime/runtime/instrument_lifecycle_state_machine.dart';

void main() {
  group('InstrumentLifecycleStateMachine', () {
    test('walks the full install-to-active path', () {
      final machine = InstrumentLifecycleStateMachine();
      for (final state in [
        InstrumentLifecycleState.installed,
        InstrumentLifecycleState.discovered,
        InstrumentLifecycleState.loaded,
        InstrumentLifecycleState.initializing,
        InstrumentLifecycleState.ready,
        InstrumentLifecycleState.connected,
        InstrumentLifecycleState.active,
      ]) {
        machine.transitionTo(state);
      }
      expect(machine.current, InstrumentLifecycleState.active);
    });

    test('rejects notInstalled -> connected directly (§19 named example)', () {
      final machine = InstrumentLifecycleStateMachine();
      expect(() => machine.transitionTo(InstrumentLifecycleState.connected), throwsStateError);
    });

    test('rejects ready -> destroyed without unloading (§19 named example)', () {
      final machine = InstrumentLifecycleStateMachine()
        ..transitionTo(InstrumentLifecycleState.installed)
        ..transitionTo(InstrumentLifecycleState.discovered)
        ..transitionTo(InstrumentLifecycleState.loaded)
        ..transitionTo(InstrumentLifecycleState.initializing)
        ..transitionTo(InstrumentLifecycleState.ready);
      expect(() => machine.transitionTo(InstrumentLifecycleState.destroyed), throwsStateError);
    });

    test('a disconnected instrument may reconnect without restarting its lifecycle (§20)', () {
      final machine = InstrumentLifecycleStateMachine()
        ..transitionTo(InstrumentLifecycleState.installed)
        ..transitionTo(InstrumentLifecycleState.discovered)
        ..transitionTo(InstrumentLifecycleState.loaded)
        ..transitionTo(InstrumentLifecycleState.initializing)
        ..transitionTo(InstrumentLifecycleState.ready)
        ..transitionTo(InstrumentLifecycleState.connected)
        ..transitionTo(InstrumentLifecycleState.disconnected)
        ..transitionTo(InstrumentLifecycleState.connected);
      expect(machine.current, InstrumentLifecycleState.connected);
    });

    test('destroyed returns to installed if the plugin remains available (§16)', () {
      final machine = InstrumentLifecycleStateMachine()
        ..transitionTo(InstrumentLifecycleState.installed)
        ..transitionTo(InstrumentLifecycleState.discovered)
        ..transitionTo(InstrumentLifecycleState.loaded)
        ..transitionTo(InstrumentLifecycleState.unloaded)
        ..transitionTo(InstrumentLifecycleState.destroyed)
        ..transitionTo(InstrumentLifecycleState.installed);
      expect(machine.current, InstrumentLifecycleState.installed);
    });
  });
}
