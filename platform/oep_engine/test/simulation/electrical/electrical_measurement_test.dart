import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-004 Phase A, §20.J-M — proves the future arbitrary
/// two-terminal measurement contract can represent every required request/
/// result shape, including the ones the CURRENT Legacy V2 solver's
/// wire-scoped `readWireMeasurement(wireId, mode)` API cannot (PRODUCT-
/// READINESS-003's own headline finding).
void main() {
  group('ElectricalMeasurementRequest/Result contract', () {
    test('J: a measurement can represent arbitrary positive/reference terminals '
        '(not merely the two ends of one existing wire)', () {
      // Exactly PRODUCT-READINESS-004 §17's own named examples.
      final batteryPlusVsChassisGround = ElectricalMeasurementRequest(
        positiveTerminal: ProbePoint(nodeId: 'battery-1', portId: 'plus'),
        negativeTerminal: ProbePoint(nodeId: 'chassis-ground-1'),
        mode: MeasurementType.voltageDc,
      );
      final headlightVsBatteryMinus = ElectricalMeasurementRequest(
        positiveTerminal: ProbePoint(nodeId: 'headlight-1', portId: 'plus'),
        negativeTerminal: ProbePoint(nodeId: 'battery-1', portId: 'minus'),
        mode: MeasurementType.voltageDc,
      );
      final switchTerminalToSwitchTerminal = ElectricalMeasurementRequest(
        positiveTerminal: ProbePoint(nodeId: 'ignition-switch-1', portId: 'BAT1'),
        negativeTerminal: ProbePoint(nodeId: 'ignition-switch-1', portId: 'BAT2'),
        mode: MeasurementType.continuity,
      );

      // Neither terminal is required to be a wire endpoint, nor do the two
      // terminals need to belong to the same relationship at all -- these
      // are two arbitrary components' own terminals, addressed directly.
      expect(batteryPlusVsChassisGround.positiveTerminal.nodeId, isNot(equals(batteryPlusVsChassisGround.negativeTerminal.nodeId)));
      expect(headlightVsBatteryMinus.positiveTerminal.nodeId, isNot(equals(headlightVsBatteryMinus.negativeTerminal.nodeId)));
      // Same component, two different terminals -- also a valid request.
      expect(switchTerminalToSwitchTerminal.positiveTerminal.nodeId, switchTerminalToSwitchTerminal.negativeTerminal.nodeId);
      expect(switchTerminalToSwitchTerminal.positiveTerminal.portId, isNot(equals(switchTerminalToSwitchTerminal.negativeTerminal.portId)));

      final roundTripped = ElectricalMeasurementRequest.fromJson(batteryPlusVsChassisGround.toJson());
      expect(roundTripped.positiveTerminal, batteryPlusVsChassisGround.positiveTerminal);
      expect(roundTripped.negativeTerminal, batteryPlusVsChassisGround.negativeTerminal);
      expect(roundTripped.mode, MeasurementType.voltageDc);
    });

    test('K: a measurement can represent OL (overload)', () {
      final request = ElectricalMeasurementRequest(
        positiveTerminal: ProbePoint(nodeId: 'a'),
        negativeTerminal: ProbePoint(nodeId: 'b'),
        mode: MeasurementType.resistance,
      );
      final result = ElectricalMeasurementResult(
        request: request,
        reading: ElectricalReading.overload(unit: 'Ω'),
        generation: ElectricalSolutionGeneration(sequence: 1, solvedAt: DateTime(2024)),
      );
      expect(result.reading.state, ElectricalReadingState.overload);
      expect(result.reading.value, isNull);
    });

    test('L: a measurement can represent fault', () {
      final request = ElectricalMeasurementRequest(
        positiveTerminal: ProbePoint(nodeId: 'a'),
        negativeTerminal: ProbePoint(nodeId: 'b'),
        mode: MeasurementType.voltageDc,
      );
      final result = ElectricalMeasurementResult(
        request: request,
        reading: ElectricalReading.fault(unit: 'V', note: 'short-to-ground fault active on this branch'),
        generation: ElectricalSolutionGeneration(sequence: 1, solvedAt: DateTime(2024)),
      );
      expect(result.reading.state, ElectricalReadingState.fault);
      expect(result.reading.note, contains('short-to-ground'));
    });

    test('M: a measurement can represent unsupported', () {
      final request = ElectricalMeasurementRequest(
        positiveTerminal: ProbePoint(nodeId: 'a'),
        negativeTerminal: ProbePoint(nodeId: 'b'),
        mode: MeasurementType.current,
      );
      final result = ElectricalMeasurementResult(
        request: request,
        reading: ElectricalReading.unsupported(note: 'current is not modeled by this solver'),
        generation: ElectricalSolutionGeneration(sequence: 1, solvedAt: DateTime(2024)),
      );
      expect(result.reading.state, ElectricalReadingState.unsupported);
      expect(result.request.mode, MeasurementType.current);
    });
  });
}
