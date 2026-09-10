import '../measurement/measurement_types.dart';
import 'electrical_measurement.dart';
import 'electrical_reading.dart';
import 'electrical_resistive_network.dart';
import 'solved_electrical_state.dart';

/// PRODUCT-READINESS-006B — the canonical arbitrary two-terminal
/// measurement query (§1/§42): a deterministic READ over an already-
/// published [SolvedElectricalState] (specifically its additive
/// [SolvedElectricalState.network]). This class makes NO topology or
/// component-behavior decision of its own — every decision it reads
/// (which pairs conduct, what a component's resistance is, what a
/// source's declared voltage is) was already made once, by
/// [ElectricalSolver]/[ElectricalResistiveNetwork.build], at solve time.
/// This is exactly the "interprets/queries solved data" role §43 requires
/// — there is NOT a second electrical authority here, only a second way
/// of asking the first one a question.
///
/// **Current/power two-terminal semantics (§20/§21 — documented per that
/// section's own explicit instruction)**: this models a CONVENTIONAL
/// series-inserted ammeter, not an arbitrary potential-driven guess
/// between two unrelated nodes (which is not what a real ammeter measures,
/// and would require inventing a topology-dependent "the current between
/// these two random points" concept that has no single correct answer in
/// a branching network). [CURRENT]/[POWER] mode is therefore answered only
/// when [ElectricalMeasurementRequest.positiveTerminal]/`negativeTerminal`
/// are EXACTLY the two ends of one identifiable network edge (a real wire,
/// or a real component's own two terminals) — see
/// [ElectricalResistiveNetwork.edgeBetween]. Any other placement reports
/// [ElectricalReadingState.unsupported] with a note explaining why, never a
/// fabricated/ambiguous value.
class ElectricalMeasurementQuery {
  const ElectricalMeasurementQuery();

  ElectricalMeasurementResult measure(SolvedElectricalState solution, ElectricalMeasurementRequest request) {
    final reading = switch (request.mode) {
      MeasurementType.voltageDc => _vdc(solution, request),
      MeasurementType.groundPotential => _vdc(solution, request),
      MeasurementType.voltageAc =>
        ElectricalReading.unsupported(unit: 'V', note: 'AC voltage is out of scope — this solver models DC resistive networks only (§49).'),
      MeasurementType.resistance => _resistance(solution, request),
      MeasurementType.continuity => _continuity(solution, request),
      MeasurementType.diode => _diode(solution, request),
      MeasurementType.current => _current(solution, request),
      MeasurementType.power => _power(solution, request),
      MeasurementType.frequency => ElectricalReading.unsupported(unit: 'Hz', note: 'Not modeled by this DC resistive solver.'),
      MeasurementType.dutyCycle => ElectricalReading.unsupported(note: 'Not modeled by this DC resistive solver.'),
      MeasurementType.capacitance => ElectricalReading.unsupported(unit: 'F', note: 'Not modeled by this DC resistive solver.'),
      MeasurementType.temperature => ElectricalReading.unsupported(unit: '°C', note: 'Not modeled by this DC resistive solver.'),
    };
    return ElectricalMeasurementResult(request: request, reading: reading, generation: solution.generation);
  }

  ElectricalReading _voltageOf(SolvedElectricalState solution, ProbePoint p) {
    final network = solution.network;
    final fromNetwork = network?.operatingVoltage(p);
    if (fromNetwork != null) return fromNetwork;
    return solution.terminalStates[p]?.voltage ?? ElectricalReading.unreached(unit: 'V');
  }

  /// §6/§7/§23 — `V(positive) - V(positive)`... no: `V(positive) -
  /// V(negative)`, with real polarity (reversing the probes reverses the
  /// sign — proven by test M).
  ElectricalReading _vdc(SolvedElectricalState solution, ElectricalMeasurementRequest r) {
    if (r.positiveTerminal == r.negativeTerminal) {
      return ElectricalReading.valid(0, unit: 'V', note: 'Same terminal.');
    }
    final vp = _voltageOf(solution, r.positiveTerminal);
    final vn = _voltageOf(solution, r.negativeTerminal);
    final worst = worseReading(vp, vn);
    if (worst != null) return _restateForVdc(worst);
    return ElectricalReading.valid(vp.value! - vn.value!, unit: 'V');
  }

  ElectricalReading _restateForVdc(ElectricalReading worst) => ElectricalReading.fromJson({
        ...worst.toJson(),
        'unit': 'V',
      });

  ElectricalReading _resistance(SolvedElectricalState solution, ElectricalMeasurementRequest r) {
    final network = solution.network;
    if (network == null) return ElectricalReading.unsupported(unit: 'Ω', note: 'No network solution attached to this state.');
    return network.resistanceBetween(r.positiveTerminal, r.negativeTerminal);
  }

  ElectricalReading _continuity(SolvedElectricalState solution, ElectricalMeasurementRequest r) {
    final network = solution.network;
    if (network == null) return ElectricalReading.unsupported(note: 'No network solution attached to this state.');
    if (r.positiveTerminal == r.negativeTerminal) {
      return ElectricalReading.valid(0, unit: 'Ω', note: 'Same terminal — continuous.');
    }
    return network.continuityBetween(r.positiveTerminal, r.negativeTerminal)
        ? ElectricalReading.valid(0, unit: 'Ω', note: 'Continuous — a conducting path exists under the current operating state.')
        : ElectricalReading.open(note: 'No conducting path between these terminals under the current operating state.');
  }

  /// §19 — minimum correct two-terminal diode semantics: forward-biased
  /// (positive probe on the anode) reads the modeled forward drop;
  /// reverse-biased reads OL/open. A probe pair with no diode directly
  /// between them falls back to a plain continuity-style reading (a real
  /// DMM's diode-test function reads ~0V across an intact plain conductor
  /// too) — never a fabricated semiconductor curve (§49).
  ElectricalReading _diode(SolvedElectricalState solution, ElectricalMeasurementRequest r) {
    final network = solution.network;
    if (network == null) return ElectricalReading.unsupported(note: 'No network solution attached to this state.');
    final match = network.diodeBetween(r.positiveTerminal, r.negativeTerminal);
    if (match != null) {
      return match.forward
          ? ElectricalReading.valid(match.forwardDropVolts, unit: 'V', note: 'Forward-biased diode — modeled forward voltage drop (not a real semiconductor I-V curve, §49).')
          : ElectricalReading.open(note: 'Reverse-biased diode — OL.');
    }
    return network.continuityBetween(r.positiveTerminal, r.negativeTerminal)
        ? ElectricalReading.valid(0, unit: 'V', note: 'No diode between these terminals — reads as a plain conducting path.')
        : ElectricalReading.open(note: 'No diode and no conducting path between these terminals.');
  }

  ElectricalReading _current(SolvedElectricalState solution, ElectricalMeasurementRequest r) {
    final network = solution.network;
    if (network == null) return ElectricalReading.unsupported(unit: 'A', note: 'No network solution attached to this state.');
    final edge = network.edgeBetween(r.positiveTerminal, r.negativeTerminal);
    if (edge == null) {
      return ElectricalReading.unsupported(
        unit: 'A',
        note: 'These terminals are not the two ends of a single identifiable branch — a current probe must be a unique series '
            'insertion point (§20). Choose two terminals that are the direct two ends of one wire or one component.',
      );
    }
    return ElectricalReading.fromJson({
      ...edge.current.toJson(),
      if (edge.current.isValid) 'note': 'Current direction: ${edge.direction}.',
    });
  }

  ElectricalReading _power(SolvedElectricalState solution, ElectricalMeasurementRequest r) {
    final network = solution.network;
    if (network == null) return ElectricalReading.unsupported(unit: 'W', note: 'No network solution attached to this state.');
    final edge = network.edgeBetween(r.positiveTerminal, r.negativeTerminal);
    if (edge == null) {
      return ElectricalReading.unsupported(
        unit: 'W',
        note: 'These terminals are not the two ends of a single identifiable branch — see CURRENT mode\'s own §20 semantics.',
      );
    }
    return edge.power;
  }
}
