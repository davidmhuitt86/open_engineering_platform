import '../measurement/measurement_types.dart';
import 'electrical_reading.dart';
import 'electrical_solution_generation.dart';

/// PRODUCT-READINESS-004 Phase A, §10 — the future canonical measurement
/// query: an arbitrary pair of terminals plus a mode, NOT a wire id.
///
/// Reuses the existing [ProbePoint] (component + optional port + optional
/// relationship — see that class's own doc comment) for both terminals and
/// the existing [MeasurementType] enum for [mode] — both already cover
/// exactly what this contract needs (VDC/VAC/resistance/continuity/diode/
/// current/power), so neither is duplicated here (§10/§11's own "do not
/// blindly introduce duplicate ID types" instruction, and PRODUCT-
/// READINESS-004's own audit finding that `MeasurementType` already lists
/// every mode the Legacy V2 solver does — and does not — support).
///
/// This class is the CONTRACT this phase establishes, per §10's own
/// instruction ("Do NOT implement the complete arbitrary solver yet...
/// establish the model/contract and write tests proving the model can
/// represent these queries") — there is deliberately no solver behind it
/// yet that can answer e.g. "battery+ vs. an arbitrary unrelated
/// component's terminal" for every possible pair; see PRODUCT-READINESS-004's
/// own audit (§5/§6 of that report) for exactly which such queries are and
/// are not answerable by extending today's per-node model alone.
class ElectricalMeasurementRequest {
  const ElectricalMeasurementRequest({
    required this.positiveTerminal,
    required this.negativeTerminal,
    required this.mode,
  });

  /// The "red probe" / positive/measurement terminal.
  final ProbePoint positiveTerminal;

  /// The "black probe" / negative/reference terminal. May be ANY valid
  /// terminal — a chassis ground point, another component's terminal, or
  /// (as today's `readWireMeasurement(wireId, mode)` effectively assumes)
  /// the other end of the same wire as [positiveTerminal] — this contract
  /// does not privilege any one of those shapes over another (§10: "Do not
  /// constrain the future architecture to 'selected wire only'").
  final ProbePoint negativeTerminal;

  final MeasurementType mode;

  Map<String, Object?> toJson() => {
        'positiveTerminal': positiveTerminal.toJson(),
        'negativeTerminal': negativeTerminal.toJson(),
        'mode': mode.name,
      };

  factory ElectricalMeasurementRequest.fromJson(Map<String, Object?> json) => ElectricalMeasurementRequest(
        positiveTerminal: ProbePoint.fromJson(Map<String, Object?>.from(json['positiveTerminal'] as Map)),
        negativeTerminal: ProbePoint.fromJson(Map<String, Object?>.from(json['negativeTerminal'] as Map)),
        mode: MeasurementType.values.firstWhere((t) => t.name == json['mode']),
      );
}

/// PRODUCT-READINESS-004 Phase A, §11 — the canonical measurement result
/// for an [ElectricalMeasurementRequest]. Distinct from the existing
/// `MeasurementResult` (`measurement_result.dart`, WP-DS-005A/AP-DS-005):
/// that type is the established result shape for the generic, non-terminal-
/// centric `SimulationEngine.measure()` (`reachable: bool` + a single
/// `measuredValue`/`expectedValue` pair) — it cannot represent OL/fault/
/// unsupported as distinguishable outcomes (§6/§11's own explicit
/// requirement), and is left completely unchanged here (§2 of this task's
/// own instruction: "Do not blindly introduce duplicate ID types... where
/// an existing canonical type can serve" cuts the other way just as much —
/// don't silently repurpose an existing type for a shape it was never
/// designed to hold). This type is additive, new, and reuses
/// [ElectricalReading]/[ElectricalSolutionGeneration] rather than
/// reinventing their distinctions.
class ElectricalMeasurementResult {
  const ElectricalMeasurementResult({
    required this.request,
    required this.reading,
    required this.generation,
  });

  final ElectricalMeasurementRequest request;

  /// The full VALID/UNKNOWN/UNREACHED/OPEN/OVERLOAD/FAULT/UNSUPPORTED
  /// distinction (§6/§11) — `reading.unit` and `reading.note` carry the
  /// unit and any explanatory text; `reading.value` is non-null only when
  /// `reading.state == ElectricalReadingState.valid`.
  final ElectricalReading reading;

  /// Which solved generation produced this answer (§12/§13) — a caller
  /// holding results from two requests can compare their `generation`s to
  /// discard a stale one without any request-id/correlation machinery of
  /// its own (that machinery, and the DMM/bridge wiring that would use it,
  /// is explicitly out of scope for this phase — §19/§24).
  final ElectricalSolutionGeneration generation;

  Map<String, Object?> toJson() => {
        'request': request.toJson(),
        'reading': reading.toJson(),
        'generation': generation.toJson(),
      };

  factory ElectricalMeasurementResult.fromJson(Map<String, Object?> json) => ElectricalMeasurementResult(
        request: ElectricalMeasurementRequest.fromJson(Map<String, Object?>.from(json['request'] as Map)),
        reading: ElectricalReading.fromJson(Map<String, Object?>.from(json['reading'] as Map)),
        generation:
            ElectricalSolutionGeneration.fromJson(Map<String, Object?>.from(json['generation'] as Map)),
      );
}
