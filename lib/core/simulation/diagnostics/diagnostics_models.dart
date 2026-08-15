import '../models/signal_types.dart';
import '../models/simulation_fault.dart';

/// AP-DS-005 Engineering Diagnostics report shapes — matches the governing
/// spec's own "Engineering Diagnostics" list exactly, MINUS Recommendation
/// Report (deliberately not built here: per
/// `SIMULATION_TRACEABILITY_MATRIX.md`, recommendation-quality reasoning is
/// Engineering Intelligence Platform's job, consumed via
/// `DiagramIntelligenceService` at the Studio layer, never reimplemented
/// in the Simulation Engine). Every report below is a PURE function over
/// already-computed state (`SimulationStateSnapshot` + `FaultOverlay` +
/// `VerificationReport`) — no new propagation or verification logic lives
/// here, only packaging/summarizing what `SignalPropagator`/
/// `VerificationEngine` already produced.

/// One fault's current downstream blocking effect.
class FaultImpact {
  const FaultImpact({required this.fault, required this.blockedNodeIds});

  final SimulationFault fault;

  /// Node ids this fault is (at least partly) responsible for making
  /// unreachable, computed by diffing propagation with vs. without this
  /// fault active.
  final List<String> blockedNodeIds;

  Map<String, Object?> toJson() => {
        'fault': fault.toJson(),
        'blockedNodeIds': blockedNodeIds,
      };
}

class FaultReport {
  const FaultReport({required this.impacts, required this.generatedAt});

  final List<FaultImpact> impacts;
  final DateTime generatedAt;

  int get activeFaultCount => impacts.length;

  Map<String, Object?> toJson() => {
        'impacts': impacts.map((i) => i.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}

/// The path power/ground actually took to reach a target node — direct
/// retention of the legacy reference's `PathFinder` concept, reimplemented
/// on top of `GraphTraversal.findPath` (no new pathfinder).
class PropagationReport {
  const PropagationReport({
    required this.targetNodeId,
    required this.type,
    required this.reachable,
    required this.path,
    required this.generatedAt,
  });

  final String targetNodeId;
  final SignalType type;
  final bool reachable;

  /// Node ids from the nearest active source to [targetNodeId], or empty
  /// if unreachable / no path could be found from any source.
  final List<String> path;

  final DateTime generatedAt;

  Map<String, Object?> toJson() => {
        'targetNodeId': targetNodeId,
        'type': type.name,
        'reachable': reachable,
        'path': path,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

/// Shared shape for Power Report and Ground Report — every node's
/// powered/grounded status plus unreachable nodes that were expected to be
/// reachable (per verification findings for that check).
class DomainStatusReport {
  const DomainStatusReport({
    required this.reachableNodeIds,
    required this.unreachableExpectedNodeIds,
    required this.generatedAt,
  });

  final List<String> reachableNodeIds;
  final List<String> unreachableExpectedNodeIds;
  final DateTime generatedAt;

  Map<String, Object?> toJson() => {
        'reachableNodeIds': reachableNodeIds,
        'unreachableExpectedNodeIds': unreachableExpectedNodeIds,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

typedef PowerReport = DomainStatusReport;
typedef GroundReport = DomainStatusReport;

/// Composite session summary — genuinely useful, not padding: the one
/// report a UI status bar / export cover page actually wants.
class SimulationReport {
  const SimulationReport({
    required this.sessionId,
    required this.sessionName,
    required this.activeFaultCount,
    required this.verificationPassed,
    required this.errorCount,
    required this.warningCount,
    required this.functionalNodeCount,
    required this.totalNodeCount,
    required this.generatedAt,
  });

  final String sessionId;
  final String sessionName;
  final int activeFaultCount;
  final bool verificationPassed;
  final int errorCount;
  final int warningCount;
  final int functionalNodeCount;
  final int totalNodeCount;
  final DateTime generatedAt;

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'sessionName': sessionName,
        'activeFaultCount': activeFaultCount,
        'verificationPassed': verificationPassed,
        'errorCount': errorCount,
        'warningCount': warningCount,
        'functionalNodeCount': functionalNodeCount,
        'totalNodeCount': totalNodeCount,
        'generatedAt': generatedAt.toIso8601String(),
      };
}
