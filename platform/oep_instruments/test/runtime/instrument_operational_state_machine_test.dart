import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/runtime/instrument_operational_state.dart';
import 'package:oep_instruments_runtime/runtime/instrument_operational_state_machine.dart';

void main() {
  group('InstrumentOperationalStateMachine', () {
    test('starts idle and follows a real measurement workflow (OIP-STATE-001 §15)', () {
      final machine = InstrumentOperationalStateMachine();
      expect(machine.current, InstrumentOperationalState.idle);

      machine.transitionTo(InstrumentOperationalState.measuring);
      expect(machine.current, InstrumentOperationalState.measuring);
      expect(machine.previous, InstrumentOperationalState.idle);

      machine.transitionTo(InstrumentOperationalState.holding);
      machine.transitionTo(InstrumentOperationalState.measuring);
      machine.transitionTo(InstrumentOperationalState.recording);
      machine.transitionTo(InstrumentOperationalState.playback);
      machine.transitionTo(InstrumentOperationalState.paused);
      machine.transitionTo(InstrumentOperationalState.playback);

      expect(machine.current, InstrumentOperationalState.playback);
    });

    test('rejects an illegal transition (§19: shutdown -> measuring without initialization)', () {
      final machine = InstrumentOperationalStateMachine();
      machine.transitionTo(InstrumentOperationalState.shutdown);
      expect(() => machine.transitionTo(InstrumentOperationalState.measuring), throwsStateError);
    });

    test('fault recovers back to idle', () {
      final machine = InstrumentOperationalStateMachine();
      machine.transitionTo(InstrumentOperationalState.measuring);
      machine.transitionTo(InstrumentOperationalState.fault);
      machine.transitionTo(InstrumentOperationalState.recovering);
      machine.transitionTo(InstrumentOperationalState.idle);
      expect(machine.current, InstrumentOperationalState.idle);
    });

    test('canTransitionTo reports without mutating state', () {
      final machine = InstrumentOperationalStateMachine();
      expect(machine.canTransitionTo(InstrumentOperationalState.playback), isFalse);
      expect(machine.current, InstrumentOperationalState.idle);
    });
  });
}
