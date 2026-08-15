import '../../graph/algorithms/graph_traversal.dart';
import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_relationship.dart';
import '../models/signal_types.dart';
import '../models/simulation_fault.dart';
import '../propagation/signal_propagator.dart';
import '../verification/verification_finding.dart';
import 'diagnostics_models.dart';

/// AP-DS-005 Engineering Diagnostics Engine — generates the spec's named
/// reports (Fault/Propagation/Power/Ground/Verification/Simulation Report)
/// as pure functions over already-computed state. Deliberately does NOT
/// generate a Recommendation Report — see `diagnostics_models.dart`'s file
/// doc and `SIMULATION_TRACEABILITY_MATRIX.md`.
class DiagnosticsEngine {
  const DiagnosticsEngine({SignalPropagator propagator = const SignalPropagator()}) : _propagator = propagator;

  final SignalPropagator _propagator;

  /// Fault Report — every active fault, its target, and (by diffing
  /// propagation with the fault present vs. absent) what it's currently
  /// blocking downstream.
  ///
  /// [blockedRelationshipIds] (Phase 11 -- Simulation Analysis
  /// Consistency): the same real-input-state-resolved set every other
  /// analysis entry point now consumes -- held CONSTANT across both the
  /// "with this fault" and "without this fault" propagation passes below
  /// (Part 13: clearing/toggling a fault must never disturb the
  /// independent state effect), so [FaultImpact.blockedNodeIds]
  /// isolates exactly what THIS fault blocks, not a mix of fault and
  /// state effects.
  FaultReport faultReport(EngineeringGraph graph, FaultOverlay faults, {Set<String> blockedRelationshipIds = const {}}) {
    final withAllState = _propagator.propagatePowerAndGround(graph, faults, blockedRelationshipIds: blockedRelationshipIds);
    final withAllFunctional = graph.nodes.keys.where(withAllState.isFunctional).toSet();

    final impacts = <FaultImpact>[];
    for (final fault in faults.active) {
      final without = FaultOverlay(faults: {
        for (final f in faults.active)
          if (f.id != fault.id) f.id: f,
      });
      final withoutState =
          _propagator.propagatePowerAndGround(graph, without, blockedRelationshipIds: blockedRelationshipIds);
      final withoutFunctional = graph.nodes.keys.where(withoutState.isFunctional).toSet();
      final blocked = withoutFunctional.difference(withAllFunctional).toList()..sort();
      impacts.add(FaultImpact(fault: fault, blockedNodeIds: blocked));
    }
    return FaultReport(impacts: impacts, generatedAt: DateTime.now());
  }

  /// Propagation Report — the path power/ground actually took to reach
  /// [targetNodeId], reusing `GraphTraversal.findPath` (no new pathfinder).
  PropagationReport propagationReport(
    EngineeringGraph graph,
    FaultOverlay faults,
    String targetNodeId, {
    SignalType type = SignalType.power,
    Set<String> blockedRelationshipIds = const {},
  }) {
    final state = _propagator.propagatePowerAndGround(graph, faults, blockedRelationshipIds: blockedRelationshipIds);
    final reachable = type == SignalType.ground ? state.isGrounded(targetNodeId) : state.isPowered(targetNodeId);

    final sources = <String>{};
    for (final r in graph.relationships.values) {
      if (type == SignalType.ground) {
        if (r.relationshipType == RelationshipType.grounds) sources.add(r.sourceNode);
      } else {
        if (r.relationshipType == RelationshipType.suppliesPower) sources.add(r.sourceNode);
      }
    }

    var path = <String>[];
    if (reachable) {
      for (final sourceId in sources) {
        final candidate = GraphTraversal.findPath(graph, sourceId, targetNodeId);
        if (candidate != null && (path.isEmpty || candidate.length < path.length)) {
          path = candidate;
        }
      }
    }
    return PropagationReport(
      targetNodeId: targetNodeId,
      type: type,
      reachable: reachable,
      path: path,
      generatedAt: DateTime.now(),
    );
  }

  /// Power Report — every node's powered status, plus nodes flagged
  /// unreachable-but-expected by `VerificationEngine`'s power check.
  PowerReport powerReport(
    EngineeringGraph graph,
    FaultOverlay faults,
    VerificationReport verification, {
    Set<String> blockedRelationshipIds = const {},
  }) {
    final state = _propagator.propagatePowerAndGround(graph, faults, blockedRelationshipIds: blockedRelationshipIds);
    final reachable = graph.nodes.keys.where(state.isPowered).toList()..sort();
    final unreachableExpected = verification
        .findingsFor(VerificationCheck.power)
        .map((f) => f.nodeId)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return PowerReport(reachableNodeIds: reachable, unreachableExpectedNodeIds: unreachableExpected, generatedAt: DateTime.now());
  }

  /// Ground Report — the ground-domain analogue of [powerReport].
  GroundReport groundReport(
    EngineeringGraph graph,
    FaultOverlay faults,
    VerificationReport verification, {
    Set<String> blockedRelationshipIds = const {},
  }) {
    final state = _propagator.propagatePowerAndGround(graph, faults, blockedRelationshipIds: blockedRelationshipIds);
    final reachable = graph.nodes.keys.where(state.isGrounded).toList()..sort();
    final unreachableExpected = verification
        .findingsFor(VerificationCheck.ground)
        .map((f) => f.nodeId)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return GroundReport(reachableNodeIds: reachable, unreachableExpectedNodeIds: unreachableExpected, generatedAt: DateTime.now());
  }

  /// Simulation Report — a composite session summary.
  SimulationReport simulationReport({
    required String sessionId,
    required String sessionName,
    required EngineeringGraph graph,
    required FaultOverlay faults,
    required VerificationReport verification,
    Set<String> blockedRelationshipIds = const {},
  }) {
    final state = _propagator.propagatePowerAndGround(graph, faults, blockedRelationshipIds: blockedRelationshipIds);
    final functionalCount = graph.nodes.keys.where(state.isFunctional).length;
    return SimulationReport(
      sessionId: sessionId,
      sessionName: sessionName,
      activeFaultCount: faults.active.length,
      verificationPassed: verification.passed,
      errorCount: verification.errorCount,
      warningCount: verification.warningCount,
      functionalNodeCount: functionalCount,
      totalNodeCount: graph.nodes.length,
      generatedAt: DateTime.now(),
    );
  }
}
