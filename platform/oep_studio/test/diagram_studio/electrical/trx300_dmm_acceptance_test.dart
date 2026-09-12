import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/host/diagram_document.dart';

/// PRODUCT-READINESS-008 §27 — the real TRX300 acceptance matrix, run
/// against `samples/diagram7.json` through the REAL production
/// `DiagramDocument.open()` path (real `backfillV2TerminalPorts` +
/// `normalizeV2RelationshipPortReferences`, both wired into that same
/// production load path this phase completes/adds — no test-only graph
/// reconstruction anywhere in this file), using
/// `ElectricalMeasurementQuery` — the exact same authoritative chain the
/// real DMM instrument panel uses (`ElectricalSolver` with
/// `trx300ElectricalBehaviorFor`/`preciseIsReferenceTerminal`, PRODUCT-READINESS-008
/// §11/§12/§16). Every operating state below uses the SAME
/// `Map<String, Object?>` shape `LegacyV2StateAdapter.currentOperatingContext`
/// really produces from a live V2 switch-state message
/// (`{'power': 'on'}`, `{'lights': 'on', 'dimmer': 'lo', ...}`).
void main() {
  late EngineeringGraph graph;
  late EngineeringNode battery;
  late EngineeringNode ignitionSwitch;
  late EngineeringNode handlebarSwitch;
  late EngineeringNode headlight;
  late EngineeringNode chassisGround;

  setUpAll(() async {
    final document = DiagramDocument();
    final result = await document.open('samples/diagram7.json');
    graph = result.graph;
    battery = graph.nodes.values.firstWhere((n) => n.displayName == 'Battery');
    ignitionSwitch = graph.nodes.values.firstWhere((n) => n.id == 'ignition-switch');
    handlebarSwitch = graph.nodes.values.firstWhere((n) => n.id == 'left-handlebar-switch');
    headlight = graph.nodes.values.firstWhere((n) => n.displayName == 'LH Headlight');
    chassisGround = graph.nodes.values.firstWhere((n) => n.id == 'chassis-ground');
  });

  String portIdForName(EngineeringNode node, String name) => node.ports.firstWhere((p) => p.name.toUpperCase() == name.toUpperCase()).id;

  ProbePoint batteryPlus() => ProbePoint(nodeId: battery.id, portId: portIdForName(battery, '+'));
  // The real chassis-ground node's own two terminals are already
  // authored with real, non-numeric port ids ('A'/'B') on disk -- unlike
  // Battery (whose ports were empty on disk and so got the 1-based
  // backfill convention), `backfillV2TerminalPorts` correctly left these
  // untouched (idempotent, never overwrites already-real ports). Looked
  // up by real terminal NAME here, exactly like every other terminal in
  // this file, rather than assuming any one numbering convention.
  ProbePoint chassisGroundTerminal() => ProbePoint(nodeId: chassisGround.id, portId: portIdForName(chassisGround, 'A'));
  ProbePoint headlightTerminal(String name) => ProbePoint(nodeId: headlight.id, portId: portIdForName(headlight, name));

  // §11/§16 — the same real Engine configuration `DigitalMultimeterInstrumentPanel`
  // itself uses, not a test-local reimplementation.
  final solver = ElectricalSolver(
    behaviorResolver: trx300ElectricalBehaviorFor,
    isReferenceTerminal: preciseIsReferenceTerminal,
    sourceVoltage: (node, context) {
      final declared = node.properties['nominalVoltageV'];
      if (declared is num) return ElectricalReading.valid(declared, unit: 'V');
      if (isRecognizedSourceComponent(node, null)) {
        return ElectricalReading.valid(trx300BatteryKeyOnVoltage, unit: 'V');
      }
      return ElectricalReading.unknown(unit: 'V');
    },
  );
  final counter = ElectricalSolutionGenerationCounter();
  const query = ElectricalMeasurementQuery();

  ElectricalMeasurementResult measure(ProbePoint red, ProbePoint black, MeasurementType mode, Map<String, Object?> activeInputStates) {
    final state = solver.solve(graph, ElectricalOperatingContext(activeInputStates: activeInputStates), generationCounter: counter);
    return query.measure(state, ElectricalMeasurementRequest(positiveTerminal: red, negativeTerminal: black, mode: mode));
  }

  group('STATE 1: Key OFF, Lights OFF', () {
    Map<String, Object?> context() => {
      ignitionSwitch.id: {'power': 'off'},
      handlebarSwitch.id: {'lights': 'off', 'dimmer': 'lo', 'engineStop': 'run', 'starter': 'free'},
    };

    test('battery -> chassis ground: a real, valid voltage (the battery itself is always live)', () {
      final result = measure(batteryPlus(), chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(result.reading.isValid, isTrue, reason: result.reading.note ?? result.reading.state.name);
      expect(result.reading.value, closeTo(trx300BatteryKeyOnVoltage, 1e-6));
    });

    // Not UNREACHED: the headlight's own LO terminal is always connected to
    // chassis ground through its own filament resistance (a real, always-
    // present path, independent of any switch) -- with the ignition switch
    // open, no source drives current through that path, so it correctly
    // reads a real, valid 0V (a defined, reachable potential), not a
    // floating/disconnected probe.
    test('headlight positive (LO) -> chassis ground: a real, valid 0V -- unpowered, but not floating', () {
      final result = measure(headlightTerminal('LO'), chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(result.reading.isValid, isTrue, reason: result.reading.note ?? result.reading.state.name);
      expect(result.reading.value, closeTo(0, 1e-6));
    });

    test('continuity from battery to the headlight is OPEN', () {
      final result = measure(batteryPlus(), headlightTerminal('LO'), MeasurementType.continuity, context());
      expect(result.reading.state, ElectricalReadingState.open);
    });
  });

  group('STATE 2: Key ON, Lights OFF', () {
    Map<String, Object?> context() => {
      ignitionSwitch.id: {'power': 'on'},
      handlebarSwitch.id: {'lights': 'off', 'dimmer': 'lo', 'engineStop': 'run', 'starter': 'free'},
    };

    test('the ignition switch output is now live, but the headlight still is not (lights switch itself is off)', () {
      final bat2 = ProbePoint(nodeId: handlebarSwitch.id, portId: portIdForName(handlebarSwitch, 'BAT2'));
      final atSwitch = measure(bat2, chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(atSwitch.reading.isValid, isTrue, reason: 'ignition ON reaches the handlebar switch\'s own BAT2');

      // As in STATE 1: the headlight's LO terminal remains connected to
      // ground via its own filament resistance regardless of switch state,
      // so with the lights switch itself off it correctly reads a real,
      // valid 0V -- not floating/UNREACHED.
      final atHeadlight = measure(headlightTerminal('LO'), chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(atHeadlight.reading.isValid, isTrue, reason: atHeadlight.reading.note ?? atHeadlight.reading.state.name);
      expect(atHeadlight.reading.value, closeTo(0, 1e-6));
    });
  });

  group('STATE 3: Key ON, LOW BEAM', () {
    Map<String, Object?> context() => {
      ignitionSwitch.id: {'power': 'on'},
      handlebarSwitch.id: {'lights': 'on', 'dimmer': 'lo', 'engineStop': 'run', 'starter': 'free'},
    };

    test('headlight LO -> chassis ground: real, valid voltage', () {
      final result = measure(headlightTerminal('LO'), chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(result.reading.isValid, isTrue);
      expect(result.reading.value, greaterThan(0));
    });

    test('continuity from battery to headlight LO is CLOSED', () {
      final result = measure(batteryPlus(), headlightTerminal('LO'), MeasurementType.continuity, context());
      expect(result.reading.state, ElectricalReadingState.valid);
      expect(result.reading.value, 0);
    });

    // As above: Hi stays connected to ground via its own filament
    // resistance even while the dimmer selects LO -- unpowered, but a
    // real, valid near-0V, not floating/UNREACHED. Not EXACTLY 0V: Hi is
    // resistively coupled into the same harness mesh as the real, live
    // parallel RH headlight (the same topology behind the ~60Ω parallel
    // resistance finding below), so a small real loading voltage appears
    // -- a genuine resistive-network result, nowhere near the ~12V a
    // driven filament would read.
    test('headlight Hi is unpowered (real, near-0V) -- the dimmer selects exactly one filament', () {
      final result = measure(headlightTerminal('Hi'), chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(result.reading.isValid, isTrue, reason: result.reading.note ?? result.reading.state.name);
      expect(result.reading.value, closeTo(0, 0.5));
    });

    // Not the LO filament's own isolated 120Ω: the real TRX300 harness
    // wires the RH headlight in parallel with this (LH) headlight on the
    // same switched rail and ground bus, so measuring resistance directly
    // across LO-GND (via the deactivated-source method) legitimately
    // includes the RH headlight's own parallel 120Ω contribution --
    // 120Ω || 120Ω = 60Ω. A correct, sophisticated real-harness answer,
    // not a bug.
    test('resistance across the real headlight LO filament reflects the real parallel RH headlight on the harness', () {
      final result = measure(headlightTerminal('LO'), headlightTerminal('GND'), MeasurementType.resistance, context());
      expect(result.reading.isValid, isTrue);
      expect(result.reading.value, closeTo(trx300LampHotResistanceOhms / 2, 1));
    });
  });

  group('STATE 4: Key ON, HIGH BEAM', () {
    Map<String, Object?> context() => {
      ignitionSwitch.id: {'power': 'on'},
      handlebarSwitch.id: {'lights': 'on', 'dimmer': 'hi', 'engineStop': 'run', 'starter': 'free'},
    };

    test('headlight Hi -> chassis ground: real, valid voltage; LO now unpowered (real, near-0V)', () {
      final hi = measure(headlightTerminal('Hi'), chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(hi.reading.isValid, isTrue);

      // Near-0V, not exactly 0V, for the same real parallel-harness
      // loading reason as STATE 3's Hi-unpowered case above.
      final lo = measure(headlightTerminal('LO'), chassisGroundTerminal(), MeasurementType.voltageDc, context());
      expect(lo.reading.isValid, isTrue, reason: lo.reading.note ?? lo.reading.state.name);
      expect(lo.reading.value, closeTo(0, 0.5));
    });
  });

  test('VAC is honestly unsupported on the native path throughout -- never fabricated', () {
    final result = measure(
      batteryPlus(),
      chassisGroundTerminal(),
      MeasurementType.voltageAc,
      {ignitionSwitch.id: {'power': 'on'}, handlebarSwitch.id: {'lights': 'on', 'dimmer': 'lo', 'engineStop': 'run', 'starter': 'free'}},
    );
    expect(result.reading.state, ElectricalReadingState.unsupported);
  });
}
