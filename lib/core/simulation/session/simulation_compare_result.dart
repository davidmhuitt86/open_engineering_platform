/// One node's status divergence between two sessions' final
/// `SimulationStateSnapshot`s.
class SimulationNodeDiff {
  const SimulationNodeDiff({
    required this.nodeId,
    required this.poweredA,
    required this.poweredB,
    required this.groundedA,
    required this.groundedB,
    required this.functionalA,
    required this.functionalB,
  });

  final String nodeId;
  final bool poweredA;
  final bool poweredB;
  final bool groundedA;
  final bool groundedB;
  final bool functionalA;
  final bool functionalB;

  Map<String, Object?> toJson() => {
        'nodeId': nodeId,
        'poweredA': poweredA,
        'poweredB': poweredB,
        'groundedA': groundedA,
        'groundedB': groundedB,
        'functionalA': functionalA,
        'functionalB': functionalB,
      };
}

/// AP-DS-005 Session Management "Compare" — a structural diff of two
/// sessions' final [SimulationStateSnapshot]s: which nodes differ in
/// powered/grounded/functional status. Useful for "what changed between
/// this fault scenario and the baseline."
class SimulationCompareResult {
  const SimulationCompareResult({
    required this.sessionIdA,
    required this.sessionIdB,
    required this.differences,
    required this.generatedAt,
  });

  final String sessionIdA;
  final String sessionIdB;
  final List<SimulationNodeDiff> differences;
  final DateTime generatedAt;

  bool get identical => differences.isEmpty;

  Map<String, Object?> toJson() => {
        'sessionIdA': sessionIdA,
        'sessionIdB': sessionIdB,
        'differences': differences.map((d) => d.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}
