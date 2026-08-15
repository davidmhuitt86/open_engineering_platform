/// AP-DS-005 Engineering Verification finding severity — deliberately a
/// small, fixed ordinal set, not a fabricated decimal "confidence" score.
/// `SIMULATION_REFERENCE_REVIEW.md` §Concepts Rejected: the legacy
/// reference presented hand-tuned literals (0.9/0.8/0.85/0.5) as if they
/// were calibrated probabilities. This engine's findings are ranked
/// ordinally (error > warning > info), never with invented precision.
enum VerificationSeverity { info, warning, error }

enum VerificationCheck {
  connectivity,
  continuity,
  openCircuit,
  shortCircuit,
  ground,
  power,
  relationship,
  dependency,
  package,
  harness,
  connector,
}

/// One verification finding — a fact about the graph's state, not a
/// diagnosis of WHY (that's `DiagnosticsEngine`'s job, and ultimately
/// Engineering Intelligence Platform's `ReasoningEngine` for anything
/// beyond simulation-local facts, per `SIMULATION_TRACEABILITY_MATRIX.md`).
class VerificationFinding {
  const VerificationFinding({
    required this.check,
    required this.severity,
    required this.message,
    this.nodeId,
    this.relationshipId,
  });

  final VerificationCheck check;
  final VerificationSeverity severity;
  final String message;
  final String? nodeId;
  final String? relationshipId;

  Map<String, Object?> toJson() => {
        'check': check.name,
        'severity': severity.name,
        'message': message,
        if (nodeId != null) 'nodeId': nodeId,
        if (relationshipId != null) 'relationshipId': relationshipId,
      };
}

/// The full result of one Verification Engine pass.
class VerificationReport {
  const VerificationReport({required this.findings, required this.generatedAt});

  final List<VerificationFinding> findings;
  final DateTime generatedAt;

  bool get passed => findings.every((f) => f.severity != VerificationSeverity.error);
  int get errorCount => findings.where((f) => f.severity == VerificationSeverity.error).length;
  int get warningCount => findings.where((f) => f.severity == VerificationSeverity.warning).length;

  List<VerificationFinding> findingsFor(VerificationCheck check) => findings.where((f) => f.check == check).toList();
}
