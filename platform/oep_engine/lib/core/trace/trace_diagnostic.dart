import '../simulation/measurement/measurement_types.dart';

/// PRODUCT-READINESS-005, §21 — the structured vocabulary every
/// noteworthy trace outcome is reported through, instead of a UI-only
/// string.
enum TraceDiagnosticCode {
  targetNotFound,
  terminalNotFound,
  noPhysicalPath,
  physicalPathBlocked,
  noConductingPath,
  conductingPathZeroCurrent,
  currentFlowing,
  multipleSources,
  multipleReturns,
  unresolvedTopology,
  unsupportedComponentBehavior,
  faultedPath,
  cycleDetected,
}

/// One structured diagnostic entry. [terminal]/[relationshipId] are
/// present when the diagnostic concerns a specific point in the graph
/// (e.g. [TraceDiagnosticCode.cycleDetected] names where the cycle was
/// found); both `null` for a whole-result-level diagnostic (e.g.
/// [TraceDiagnosticCode.multipleSources]).
class TraceDiagnostic {
  const TraceDiagnostic({required this.code, this.message = '', this.terminal, this.relationshipId});

  final TraceDiagnosticCode code;
  final String message;
  final ProbePoint? terminal;
  final String? relationshipId;

  @override
  String toString() => 'TraceDiagnostic(${code.name}${message.isNotEmpty ? ": $message" : ""})';
}
