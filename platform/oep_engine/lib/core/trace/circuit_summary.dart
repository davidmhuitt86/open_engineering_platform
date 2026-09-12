import '../simulation/electrical/electrical_conducting_state.dart';
import '../simulation/electrical/electrical_reading.dart';
import '../simulation/electrical/solved_electrical_state.dart';
import 'trace_result.dart';

/// PRODUCT-READINESS-010 §2/§12/§31/§45 — a transient, presentation-ready
/// summary DERIVED from an already-computed [TraceResult] (and, where
/// available, the [SolvedElectricalState] that produced it). This is
/// exactly the kind of "transient CircuitSummary... view model" §2
/// itself describes -- it is never persisted, never becomes a second
/// source of truth, and computes nothing [TraceEngine]/[ElectricalSolver]
/// did not already compute. Every field is either a plain count over
/// [TraceResult]'s own sets, or a value copied verbatim from an
/// [ElectricalReading]/[ElectricalTerminalState] the Engine already
/// produced -- never fabricated, never derived via new electrical math
/// (§31: "Do not show 0 A when the correct state is unsupported or
/// open").
class CircuitSummary {
  const CircuitSummary({
    required this.result,
    required this.componentCount,
    required this.wireCount,
    required this.branchCount,
    required this.isBlocked,
    required this.overallConductingState,
    this.sourceVoltage,
    this.current,
  });

  final TraceResult result;

  /// `result.componentIds.length` -- a real count, never estimated (§30).
  final int componentCount;

  /// `result.relationshipIds.length`.
  final int wireCount;

  /// `result.paths.length` -- the number of distinct branches TraceEngine
  /// itself found (§15: never collapsed into one).
  final int branchCount;

  /// True when every path was blocked (or there were no paths at all) --
  /// i.e. no branch of this circuit reaches its natural, unblocked end.
  final bool isBlocked;

  /// The aggregate [ElectricalConductingState] across every path: real
  /// `.conducting` if ANY branch conducts, `.unknown` for a
  /// [TraceMode.physical] result (which never evaluates conducting state
  /// at all), otherwise `.open`.
  final ElectricalConductingState overallConductingState;

  /// The solved voltage at the circuit's own (unambiguous) source
  /// terminal, when [SolvedElectricalState] was supplied to [derive] AND
  /// exactly one source terminal was identified -- `null` otherwise,
  /// never guessed (§13/§31).
  final ElectricalReading? sourceVoltage;

  /// The first genuinely valid solved current found across this result's
  /// own paths (only ever populated for [TraceMode.currentFlow] results,
  /// since [TracePath.current] itself is only populated there) -- `null`
  /// otherwise.
  final ElectricalReading? current;

  /// PRODUCT-READINESS-010 §12/§30/§31 — derives a [CircuitSummary]
  /// purely from data [TraceResult] (and, optionally, the
  /// [SolvedElectricalState] it was traced against) already computed.
  factory CircuitSummary.derive(TraceResult result, {SolvedElectricalState? solvedState}) {
    final hasAnyPath = result.paths.isNotEmpty;
    final isBlocked = !hasAnyPath || result.paths.every((p) => p.blockingStep != null);

    ElectricalConductingState overallConductingState;
    if (!hasAnyPath) {
      overallConductingState = ElectricalConductingState.unknown;
    } else if (result.paths.any((p) => p.conductingState == ElectricalConductingState.conducting)) {
      overallConductingState = ElectricalConductingState.conducting;
    } else if (result.paths.any((p) => p.conductingState == ElectricalConductingState.unknown)) {
      overallConductingState = ElectricalConductingState.unknown;
    } else {
      overallConductingState = ElectricalConductingState.open;
    }

    ElectricalReading? current;
    for (final path in result.paths) {
      if (path.current != null && path.current!.isValid) {
        current = path.current;
        break;
      }
    }

    ElectricalReading? sourceVoltage;
    if (solvedState != null && result.sourceTerminals.length == 1) {
      final reading = solvedState.terminalStates[result.sourceTerminals.single]?.voltage;
      if (reading != null && reading.isValid) sourceVoltage = reading;
    }

    return CircuitSummary(
      result: result,
      componentCount: result.componentIds.length,
      wireCount: result.relationshipIds.length,
      branchCount: result.paths.length,
      isBlocked: isBlocked,
      overallConductingState: overallConductingState,
      sourceVoltage: sourceVoltage,
      current: current,
    );
  }
}
