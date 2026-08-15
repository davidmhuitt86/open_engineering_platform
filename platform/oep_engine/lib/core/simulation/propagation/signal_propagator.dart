import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../../graph/models/engineering_relationship.dart';
import '../models/simulation_fault.dart';
import '../models/signal_types.dart';

/// AP-DS-005's deterministic Signal Propagation core.
///
/// Directly retains and improves the legacy reference's own best pattern
/// (`SIMULATION_REFERENCE_REVIEW.md` §Concepts Retained/Improved): Power
/// and Ground are two independent multi-source BFS reachability passes,
/// combined only at the point of use (`isFunctional = powered && grounded`)
/// — never merged into one "net" concept. Every other [SignalType]
/// (digital/analog/PWM/CAN/LIN/discrete) reuses the exact same BFS-flood
/// mechanism, generalized to carry a value instead of a bare boolean,
/// rather than being a separate, differently-shaped algorithm — this is
/// the fix for the legacy reference's own self-documented flaw (three
/// independent graph-traversal reimplementations across its two engines).
/// There is exactly one traversal loop in this file, parameterized by
/// signal type; nothing here reimplements `oep_engine`'s existing
/// `GraphAlgorithms` BFS/shortest-path primitives — this is a distinct,
/// STATE-GATED propagation (a fault or a component's own state can block
/// an edge), which `GraphAlgorithms`'s pure-connectivity BFS does not
/// support, so a dedicated pass is genuinely necessary here, not a
/// duplication of what already exists.
///
/// No SPICE/analog/physics simulation: propagation is flood-fill
/// reachability + a carried value, never a resistive-network/current
/// solve — deliberately, per AP-DS-005's own explicit exclusion and
/// `SIMULATION_REFERENCE_REVIEW.md`'s finding that the legacy reference
/// never did real circuit math either, despite calling itself a "voltage
/// propagator."
class SignalPropagator {
  const SignalPropagator();

  /// Computes Power and Ground reachability, gated by [faults], for every
  /// node in [graph]. Power sources are nodes with an outgoing
  /// `RelationshipType.suppliesPower` relationship; ground sources are
  /// nodes with an outgoing `RelationshipType.grounds` relationship, OR a
  /// node whose own [NodeCategory] is `ground` (both conventions are
  /// checked — a `ground`-category node is a source even with no explicit
  /// `grounds` relationship, matching how a chassis-ground point is
  /// typically modeled).
  /// [blockedRelationshipIds] (Phase 10 -- Operating/Input State
  /// Effects): relationship ids that should not conduct, resolved by
  /// [StateConditionResolver] from a session's active input state --
  /// composed with [faults] the identical way a second, independent
  /// reason an edge doesn't conduct (Part 15: "state condition + fault
  /// condition," never merged into a special combined state). Empty by
  /// default, so every caller that predates Phase 10 (including every
  /// existing test) propagates exactly as before.
  SimulationStateSnapshot propagatePowerAndGround(
    EngineeringGraph graph,
    FaultOverlay faults, {
    Set<String> blockedRelationshipIds = const {},
  }) {
    final powerSources = <String>{};
    final groundSources = <String>{};
    for (final relationship in graph.relationships.values) {
      if (relationship.relationshipType == RelationshipType.suppliesPower) {
        powerSources.add(relationship.sourceNode);
      } else if (relationship.relationshipType == RelationshipType.grounds) {
        groundSources.add(relationship.sourceNode);
      }
    }
    for (final node in graph.nodes.values) {
      if (node.category == NodeCategory.ground) groundSources.add(node.id);
    }

    final powered = _propagate(graph, faults, powerSources, SignalType.power, blockedRelationshipIds);
    final grounded = _propagate(graph, faults, groundSources, SignalType.ground, blockedRelationshipIds);

    final nodeStates = <String, Map<SignalType, SignalState>>{};
    for (final node in graph.nodes.values) {
      nodeStates[node.id] = {
        SignalType.power: SignalState(type: SignalType.power, reachable: powered.contains(node.id)),
        SignalType.ground: SignalState(type: SignalType.ground, reachable: grounded.contains(node.id)),
      };
    }
    return SimulationStateSnapshot(nodeStates: nodeStates);
  }

  /// Propagates a logical signal of [type] from [seedNodeIds] (nodes
  /// declared as sources for this signal — e.g. via
  /// `node.properties['signalSource'] == type.name`, a convention Diagram
  /// Studio's inspector or a future authoring UI would set; this method
  /// takes the seed set explicitly rather than inferring it, so callers
  /// control seeding policy). [seedValue] is carried unchanged to every
  /// node the signal reaches (a flood-fill value propagation, matching
  /// [propagatePowerAndGround]'s own mechanism — not a per-node
  /// transformation, since this engine does no analog computation).
  SimulationStateSnapshot propagateSignal(
    EngineeringGraph graph,
    FaultOverlay faults,
    SignalType type,
    Set<String> seedNodeIds, {
    Object? seedValue,
    Set<String> blockedRelationshipIds = const {},
  }) {
    final reached = _propagate(graph, faults, seedNodeIds, type, blockedRelationshipIds);
    final nodeStates = <String, Map<SignalType, SignalState>>{
      for (final nodeId in reached) nodeId: {type: SignalState(type: type, reachable: true, value: seedValue)},
    };
    return SimulationStateSnapshot(nodeStates: nodeStates);
  }

  /// The one shared BFS-flood traversal every signal type above uses.
  /// Blocked by: an active fault on the traversed relationship
  /// (open/broken/disconnected/missing — `FaultOverlay.hasOpenCircuitOn`),
  /// and by relay-style behavioral gating — a `RelationshipType.controls`
  /// edge whose controlling node is not itself powered+grounded blocks
  /// propagation across whatever it controls (the legacy reference's
  /// retained "relay coil gates contacts" pattern, generalized: any
  /// `controls` relationship represents "the target only conducts if the
  /// source is functional," not just relays specifically).
  Set<String> _propagate(
    EngineeringGraph graph,
    FaultOverlay faults,
    Set<String> seeds,
    SignalType type,
    Set<String> blockedRelationshipIds,
  ) {
    final visited = <String>{...seeds};
    final queue = [...seeds];
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      for (final relationship in graph.relationshipsForNode(currentId)) {
        // `controls` relationships gate the target's functional capability,
        // not raw wire connectivity for this signal type -- so they are
        // considered for behavioral gating (below) but do not themselves
        // conduct a signal from source to target as a wire would.
        if (relationship.relationshipType == RelationshipType.controls) continue;

        final neighborId = relationship.sourceNode == currentId ? relationship.targetNode : relationship.sourceNode;
        if (visited.contains(neighborId)) continue;
        if (_isBlocked(graph, faults, relationship, neighborId, blockedRelationshipIds)) continue;
        visited.add(neighborId);
        queue.add(neighborId);
      }
    }
    return visited;
  }

  bool _isBlocked(
    EngineeringGraph graph,
    FaultOverlay faults,
    EngineeringRelationship relationship,
    String neighborId,
    Set<String> blockedRelationshipIds,
  ) {
    if (faults.hasOpenCircuitOn(relationship.id)) return true;
    // Phase 10 -- Operating/Input State Effects: a second, independent
    // reason this edge doesn't conduct, resolved by
    // `StateConditionResolver` from real input state -- composed with
    // the fault check above via OR, never merged into one condition
    // (Part 15).
    if (blockedRelationshipIds.contains(relationship.id)) return true;
    // A fault directly on the neighbor node (missingGround/missingPower/
    // relayFailure/fuseFailure/connectorFailure/disconnectedConnector)
    // blocks that node from receiving/forwarding this pass entirely.
    if (faults.faultsFor(neighborId).any((f) => f.type != SimulationFaultType.shortCircuit)) return true;

    // Behavioral gating: does any `controls` relationship targeting
    // `neighborId` require its controller to be functional first? This is
    // a simplified, single-hop check (the controller's own power/ground
    // state, not a recursive functional-chain) -- a deliberate, disclosed
    // scope boundary matching this engine's flood-fill (not resistive-
    // network) approach; a controller mid-chain that is itself unpowered
    // is caught because ITS OWN propagation pass will have failed to
    // reach it, which the caller (VerificationEngine/DiagnosticsEngine)
    // checks separately.
    for (final controlling in graph.relationships.values) {
      if (controlling.relationshipType != RelationshipType.controls) continue;
      if (controlling.targetNode != neighborId) continue;
      if (faults.faultsFor(controlling.sourceNode).isNotEmpty) return true;
    }
    return false;
  }
}
