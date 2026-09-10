import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-004 Phase A, §20.A/§20.B — proves the model is
/// genuinely terminal-centric: a component can carry multiple
/// independently-addressable terminal states, and two terminals on the
/// same component are never automatically treated as electrically
/// equivalent by the model itself (only a behavior's own
/// `conductingTerminalPairs` may assert that).
void main() {
  group('terminal-centric model', () {
    test('A: a component can have multiple independently addressable terminals', () {
      final battery = ProbePoint(nodeId: 'battery-1');
      final plus = ProbePoint(nodeId: 'battery-1', portId: 'plus');
      final minus = ProbePoint(nodeId: 'battery-1', portId: 'minus');

      final state = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: {
          plus: ElectricalTerminalState(
            terminal: plus,
            voltage: ElectricalReading.valid(12.6, unit: 'V'),
            current: ElectricalReading.unsupported(),
            isSourceTerminal: true,
          ),
          minus: ElectricalTerminalState(
            terminal: minus,
            voltage: ElectricalReading.valid(0, unit: 'V'),
            current: ElectricalReading.unsupported(),
            isReferenceTerminal: true,
          ),
        },
        branchStates: const {},
      );

      expect(state.terminalState('battery-1', 'plus')?.voltage.value, 12.6);
      expect(state.terminalState('battery-1', 'minus')?.voltage.value, 0);
      expect(state.terminalState('battery-1', 'plus'), isNot(equals(state.terminalState('battery-1', 'minus'))));
      expect(battery, isNot(equals(plus)), reason: 'a bare component address is not the same as one of its terminals');
    });

    test('B: two terminals on the same component are not automatically electrically equivalent', () {
      const behavior = PassThroughElectricalComponentBehavior();
      final node = EngineeringNode(
        id: 'connector-1',
        category: NodeCategory.connector,
        displayName: 'Test Connector',
        ports: const [
          Port(id: '1', name: 'Pin 1'),
          Port(id: '2', name: 'Pin 2'),
        ],
      );

      // Same pin: passes through (a legitimate physical passthrough).
      final samePin = behavior.resistanceBetween(node, '1', '1', ElectricalOperatingContext.none);
      expect(samePin.isValid, isTrue);
      expect(samePin.value, 0);

      // Different pins: NOT automatically equivalent -- must read open,
      // never a fabricated conducting value.
      final differentPins = behavior.resistanceBetween(node, '1', '2', ElectricalOperatingContext.none);
      expect(differentPins.state, ElectricalReadingState.open);
      expect(behavior.conductingTerminalPairs(node, ElectricalOperatingContext.none), isEmpty);
    });
  });
}
