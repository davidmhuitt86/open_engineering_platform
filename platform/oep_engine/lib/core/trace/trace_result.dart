import '../simulation/electrical/electrical_solution_generation.dart';
import '../simulation/measurement/measurement_types.dart';
import 'trace_diagnostic.dart';
import 'trace_mode.dart';
import 'trace_path.dart';
import 'trace_target.dart';

/// PRODUCT-READINESS-005, §6 — the canonical trace result: structured
/// engineering data, never a formatted string (§6's own explicit
/// requirement).
///
/// [generation] is `null` only when the trace was run in [TraceMode.physical]
/// with no [SolvedElectricalState] supplied at all (physical trace does not
/// require one — §4.1) — every conducting/current-flow trace carries the
/// generation of the solved state it read (§19/PRODUCT-READINESS-004 §12).
class TraceResult {
  const TraceResult({
    required this.target,
    required this.mode,
    required this.generation,
    required this.paths,
    required this.sourceTerminals,
    required this.returnTerminals,
    required this.componentIds,
    required this.relationshipIds,
    required this.terminalsVisited,
    required this.spliceComponentIds,
    required this.connectorComponentIds,
    required this.diagnostics,
  });

  final TraceTarget target;
  final TraceMode mode;
  final ElectricalSolutionGeneration? generation;

  /// Every distinct path discovered, deterministically ordered (§18/§19 —
  /// never dependent on collection iteration order) and deduplicated by
  /// [TracePath.pathId].
  final List<TracePath> paths;

  /// §9 — every terminal, among all terminals actually visited by this
  /// trace, that [ElectricalTerminalState.isSourceTerminal] identifies as
  /// a modeled power source. May be empty, one, or several (§9: "Multiple-
  /// source situations must remain representable") — never hardcoded to
  /// "battery."
  final Set<ProbePoint> sourceTerminals;

  /// §10 — the return/ground-role counterpart of [sourceTerminals].
  final Set<ProbePoint> returnTerminals;

  final Set<String> componentIds;
  final Set<String> relationshipIds;
  final Set<ProbePoint> terminalsVisited;

  /// §11 — every splice-classified component touched by this trace,
  /// tracked separately from [connectorComponentIds] (§11/§12: the two
  /// must never be conflated).
  final Set<String> spliceComponentIds;

  /// §12 — every connector-classified component touched.
  final Set<String> connectorComponentIds;

  final List<TraceDiagnostic> diagnostics;

  bool get isEmpty => paths.isEmpty;

  bool get hasMultipleSources => sourceTerminals.length > 1;

  bool get hasMultipleReturns => returnTerminals.length > 1;

  @override
  String toString() =>
      'TraceResult(${target.toString()}, ${mode.name}, ${paths.length} paths, ${diagnostics.length} diagnostics)';
}
