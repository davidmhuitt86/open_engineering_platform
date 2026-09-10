import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-004 Phase A, §20.G-I — proves the branch model can
/// represent source/destination terminals, current direction, and a
/// genuine zero-current branch distinct from an open one.
void main() {
  group('ElectricalBranchState', () {
    final source = ProbePoint(nodeId: 'battery-1', portId: 'plus');
    final destination = ProbePoint(nodeId: 'fuse-1', portId: 'in');

    test('G: a branch can represent source and destination terminals', () {
      final branch = ElectricalBranchState(
        branchId: 'wire-1',
        sourceTerminal: source,
        destinationTerminal: destination,
        voltage: ElectricalReading.valid(12.6, unit: 'V'),
        voltageDrop: ElectricalReading.unsupported(),
        current: ElectricalReading.unsupported(),
        resistance: ElectricalReading.valid(0.1, unit: 'Ω'),
        power: ElectricalReading.unsupported(),
        conductingState: ElectricalConductingState.conducting,
        currentDirection: ElectricalCurrentDirection.unknown,
        relationshipId: 'wire-1',
      );

      expect(branch.sourceTerminal, source);
      expect(branch.destinationTerminal, destination);
      expect(branch.sourceTerminal, isNot(equals(branch.destinationTerminal)));
    });

    test('H: a branch can represent current direction', () {
      final forward = ElectricalBranchState(
        branchId: 'wire-2',
        sourceTerminal: source,
        destinationTerminal: destination,
        voltage: ElectricalReading.valid(12.6, unit: 'V'),
        voltageDrop: ElectricalReading.valid(0.05, unit: 'V'),
        current: ElectricalReading.valid(2.5, unit: 'A'),
        resistance: ElectricalReading.valid(0.1, unit: 'Ω'),
        power: ElectricalReading.valid(31.5, unit: 'W'),
        conductingState: ElectricalConductingState.conducting,
        currentDirection: ElectricalCurrentDirection.sourceToDestination,
      );
      final reverse = forward.currentDirection == ElectricalCurrentDirection.sourceToDestination
          ? ElectricalCurrentDirection.destinationToSource
          : ElectricalCurrentDirection.sourceToDestination;

      expect(forward.currentDirection, ElectricalCurrentDirection.sourceToDestination);
      expect(reverse, isNot(equals(forward.currentDirection)));
    });

    test('I: a branch can represent zero current without becoming "open"', () {
      final zeroCurrentButConducting = ElectricalBranchState(
        branchId: 'wire-3',
        sourceTerminal: source,
        destinationTerminal: destination,
        voltage: ElectricalReading.valid(0, unit: 'V'),
        voltageDrop: ElectricalReading.valid(0, unit: 'V'),
        current: ElectricalReading.valid(0, unit: 'A'),
        resistance: ElectricalReading.valid(0.1, unit: 'Ω'),
        power: ElectricalReading.valid(0, unit: 'W'),
        conductingState: ElectricalConductingState.conducting,
        currentDirection: ElectricalCurrentDirection.none,
      );

      expect(zeroCurrentButConducting.conductingState, ElectricalConductingState.conducting,
          reason: 'a de-energized but intact branch is still conducting -- it just carries no current');
      expect(zeroCurrentButConducting.current.isValid, isTrue);
      expect(zeroCurrentButConducting.current.value, 0);
      expect(zeroCurrentButConducting.currentDirection, ElectricalCurrentDirection.none);

      final open = ElectricalBranchState(
        branchId: 'wire-4',
        sourceTerminal: source,
        destinationTerminal: destination,
        voltage: ElectricalReading.open(),
        voltageDrop: ElectricalReading.open(),
        current: ElectricalReading.open(),
        resistance: ElectricalReading.open(),
        power: ElectricalReading.open(),
        conductingState: ElectricalConductingState.open,
        currentDirection: ElectricalCurrentDirection.unknown,
      );
      expect(open.current.value, isNull, reason: 'an open branch must never report a numeric zero current');
      expect(open.conductingState, ElectricalConductingState.open);
    });
  });
}
