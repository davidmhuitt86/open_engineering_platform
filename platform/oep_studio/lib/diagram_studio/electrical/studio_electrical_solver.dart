import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-009 §33 — the one, shared production
/// [ElectricalSolver] configuration Diagram Studio uses everywhere it
/// needs to solve the real electrical network (the DMM instrument and the
/// new electrical trace feature both need an identically-configured
/// solver; this factors PRODUCT-READINESS-008's own
/// `DigitalMultimeterInstrumentPanel._solver`/`_sourceVoltage` out to a
/// shared place rather than letting a second, independently-maintained
/// copy accumulate here).
///
/// §16/PRODUCT-READINESS-006B — [studioSourceVoltage] is the same
/// production-precise reference resolver validated against the real,
/// full-harness `diagram7.json`, not a broad heuristic.
ElectricalReading studioSourceVoltage(EngineeringNode node, ElectricalOperatingContext context) {
  final declared = node.properties['nominalVoltageV'];
  if (declared is num) return ElectricalReading.valid(declared, unit: 'V');
  // The real diagram7.json Battery has no authored `nominalVoltageV` at
  // all (PRODUCT-READINESS-006B's own disclosed finding) -- the real,
  // disclosed Legacy V2 `BatteryBehavior.VOLTAGE[1]` (key-ON resting
  // voltage) constant is the best available REAL value for a recognized
  // source component, never fabricated for anything else.
  if (isRecognizedSourceComponent(node, null)) {
    return ElectricalReading.valid(
      trx300BatteryKeyOnVoltage,
      unit: 'V',
      note: 'No nominalVoltageV authored on this component -- using the real, disclosed Legacy V2 key-ON constant.',
    );
  }
  return ElectricalReading.unknown(unit: 'V', note: 'No declared source voltage.');
}

/// §11/§12/§13 -- real, generic-by-terminal-signature TRX300 reference
/// behaviors (splice/connector/switch/lamp), never a hardcoded
/// `if (diagram == trx300)` inside the Engine itself.
ElectricalSolver buildStudioElectricalSolver() => ElectricalSolver(
      behaviorResolver: trx300ElectricalBehaviorFor,
      isReferenceTerminal: preciseIsReferenceTerminal,
      sourceVoltage: studioSourceVoltage,
    );

/// PRODUCT-READINESS-009 §1/§9 -- the shared production [TraceEngine]
/// configuration. `TraceEngine.behaviorResolver` is its OWN, independent
/// constructor parameter (not reused from [ElectricalSolver] -- the two
/// classes have no dependency on one another, §41), so it must be given
/// the same real `trx300ElectricalBehaviorFor` reference behaviors
/// explicitly here, or a component's own real internal-bridge capability
/// (e.g. a switch's `physicallyConnectableTerminalPairs`) silently falls
/// back to the generic `defaultElectricalBehaviorFor` and a genuinely
/// connected physical path goes undiscovered. Kept in the one shared
/// place every Diagram Studio trace consumer uses, never a second,
/// independently-configured `TraceEngine`.
TraceEngine buildStudioTraceEngine() => TraceEngine(behaviorResolver: trx300ElectricalBehaviorFor);
