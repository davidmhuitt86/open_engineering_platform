import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-009 §11/§12/§13 — pure translation from a native
/// [TraceResult] (OEP node/relationship identity) into the minimal,
/// V2-identity-agnostic set of facts the diagram needs highlighted: which
/// wires (by OEP relationship id) are on the traced path(s), which
/// components are source/return/blocked, and — for [TraceMode.currentFlow]
/// only — which wires carry solved current and in which direction
/// relative to that wire's own declared `sourceNode -> targetNode`.
///
/// Deliberately has NO dependency on `LegacyV2StateAdapter`/the WebView —
/// the OEP id -> V2 id translation happens at the call site (the Trace
/// Inspector panel), so this logic is fully unit-testable against plain
/// `EngineeringGraph`/`TraceResult` fixtures (§34).
///
/// §7 — current direction here is derived EXCLUSIVELY from
/// `TracePath.currentDirection`/`TracePath.current` (which themselves come
/// exclusively from the solved `ElectricalBranchState`, never from wire
/// orientation, screen coordinates, or voltage) — never re-derived from
/// anything else.
class TraceHighlightPlan {
  const TraceHighlightPlan({
    required this.relationshipIds,
    required this.allNodeIds,
    required this.sourceNodeIds,
    required this.returnNodeIds,
    required this.blockedNodeIds,
    required this.currentFlowByRelationshipId,
  });

  static const empty = TraceHighlightPlan(
    relationshipIds: {},
    allNodeIds: {},
    sourceNodeIds: {},
    returnNodeIds: {},
    blockedNodeIds: {},
    currentFlowByRelationshipId: {},
  );

  /// Every OEP relationship id (wire) that appears on any path in the
  /// result — the real diagram's own wires, never a synthesized topology
  /// (§1: "Highlight the real diagram").
  final Set<String> relationshipIds;

  /// PRODUCT-READINESS-010 §17 — every OEP component id involved in the
  /// result (`TraceResult.componentIds`, verbatim), used ONLY to compute
  /// "Fit Circuit"'s own bounding box over the real, rendered module
  /// cards — never a second topology, never persisted.
  final Set<String> allNodeIds;

  final Set<String> sourceNodeIds;
  final Set<String> returnNodeIds;

  /// §16 — the component each blocked path was blocked AT
  /// (`TracePath.blockingStep.terminal.nodeId`), so the diagram can mark
  /// exactly where the trace stopped, not just report "no path."
  final Set<String> blockedNodeIds;

  /// §12/§13 — populated ONLY for [TraceMode.currentFlow] paths with a
  /// genuinely valid solved current and a determined
  /// (`sourceToDestination`/`destinationToSource`) direction; `none`
  /// (conducting, zero current) and `unknown` are deliberately excluded —
  /// there is nothing meaningful to animate. `+1` means the current flows
  /// from this relationship's own `sourceNode` toward its `targetNode`;
  /// `-1` means the reverse.
  final Map<String, int> currentFlowByRelationshipId;

  bool get isEmpty =>
      relationshipIds.isEmpty && allNodeIds.isEmpty && sourceNodeIds.isEmpty && returnNodeIds.isEmpty && blockedNodeIds.isEmpty;
}

TraceHighlightPlan buildTraceHighlightPlan(EngineeringGraph graph, TraceResult result) {
  final relationshipIds = <String>{};
  final blockedNodeIds = <String>{};
  final flow = <String, int>{};

  for (final path in result.paths) {
    for (final step in path.steps) {
      final relId = step.viaRelationshipId;
      if (relId != null) relationshipIds.add(relId);
    }
    final blockingStep = path.blockingStep;
    if (blockingStep != null) blockedNodeIds.add(blockingStep.terminal.nodeId);

    if (result.mode != TraceMode.currentFlow) continue;
    final current = path.current;
    if (current == null || !current.isValid) continue;
    final directionKnown = path.currentDirection == ElectricalCurrentDirection.sourceToDestination ||
        path.currentDirection == ElectricalCurrentDirection.destinationToSource;
    if (!directionKnown) continue;
    final currentFlowsForwardAlongPath = path.currentDirection == ElectricalCurrentDirection.sourceToDestination;

    for (var i = 1; i < path.steps.length; i++) {
      final relId = path.steps[i].viaRelationshipId;
      if (relId == null) continue; // an internal same-component bridge has no wire to animate.
      final relationship = graph.relationships[relId];
      if (relationship == null) continue;
      final hopForward = path.steps[i - 1].terminal.nodeId == relationship.sourceNode;
      flow[relId] = (hopForward == currentFlowsForwardAlongPath) ? 1 : -1;
    }
  }

  return TraceHighlightPlan(
    relationshipIds: relationshipIds,
    allNodeIds: result.componentIds,
    sourceNodeIds: result.sourceTerminals.map((p) => p.nodeId).toSet(),
    returnNodeIds: result.returnTerminals.map((p) => p.nodeId).toSet(),
    blockedNodeIds: blockedNodeIds,
    currentFlowByRelationshipId: flow,
  );
}
