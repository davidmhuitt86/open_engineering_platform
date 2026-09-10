import '../graph/models/engineering_graph.dart';
import '../graph/models/engineering_node.dart';
import '../graph/models/engineering_relationship.dart';
import '../simulation/electrical/electrical_branch_state.dart';
import '../simulation/electrical/electrical_component_behavior.dart';
import '../simulation/electrical/electrical_conducting_state.dart';
import '../simulation/electrical/electrical_node_roles.dart';
import '../simulation/electrical/electrical_operating_context.dart';
import '../simulation/electrical/electrical_reading.dart';
import '../simulation/electrical/solved_electrical_state.dart';
import '../simulation/measurement/measurement_types.dart';
import 'trace_diagnostic.dart';
import 'trace_mode.dart';
import 'trace_path.dart';
import 'trace_result.dart';
import 'trace_target.dart';

/// PRODUCT-READINESS-005 — the Trace Engine.
///
/// **Architectural authority (§2)**: this class NEVER computes voltage,
/// current, resistance, or conducting state itself. Physical-mode
/// connectivity comes from [EngineeringGraph]'s own relationships plus
/// each component's STATE-INDEPENDENT terminal topology
/// ([ElectricalComponentBehavior.physicallyConnectableTerminalPairs] /
/// built-in connector-same-pin / splice-all-bridge / ground-sink rules —
/// none of which is an electrical calculation, all of which is either
/// static graph structure or a component's own declared, state-
/// independent wiring shape). Conducting/current-flow gating is read
/// DIRECTLY from a caller-supplied [SolvedElectricalState] — this class
/// never re-derives it. Read-only throughout (§37): nothing here mutates
/// [EngineeringGraph], [SolvedElectricalState], or any argument.
///
/// **Algorithm**: every physical path is computed once, as the structural
/// backbone (see [_physicalPaths]). A [TraceMode.conducting] or
/// [TraceMode.currentFlow] trace re-walks each physical path in order and
/// truncates it at the first hop that fails conducting-mode gating,
/// recording the blocking step rather than discarding the path (§17) —
/// this is a direct, literal expression of "conducting connectivity is a
/// subset of physical connectivity" (§4), not a second, independently-
/// derived traversal.
class TraceEngine {
  const TraceEngine({this.behaviorResolver, this.maxDepth = 64});

  final ElectricalBehaviorResolver? behaviorResolver;

  /// Safety bound against runaway/cyclic graphs (§20) — a path longer
  /// than this is truncated with a [TraceDiagnosticCode.cycleDetected]-
  /// adjacent note rather than traversed indefinitely. 64 is generous for
  /// any real wiring diagram (PRODUCT-READINESS-004's own TRX300 fixture
  /// has 47 nodes total) while still bounding worst-case work.
  final int maxDepth;

  TraceResult trace({
    required EngineeringGraph graph,
    required TraceTarget target,
    required TraceMode mode,
    SolvedElectricalState? solvedState,
    ElectricalOperatingContext operatingContext = ElectricalOperatingContext.none,
  }) {
    final diagnostics = <TraceDiagnostic>[];
    final startTerminals = _resolveStartTerminals(graph, target, diagnostics);
    if (startTerminals.isEmpty) {
      return TraceResult(
        target: target,
        mode: mode,
        generation: solvedState?.generation,
        paths: const [],
        sourceTerminals: const {},
        returnTerminals: const {},
        componentIds: const {},
        relationshipIds: const {},
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: diagnostics,
      );
    }

    final physicalPaths = <TracePath>[];
    final seenPathIds = <String>{};
    for (final start in startTerminals) {
      _collectPhysicalPaths(graph, start, physicalPaths, seenPathIds, diagnostics);
    }
    physicalPaths.sort((a, b) => a.pathId.compareTo(b.pathId));

    final paths = mode == TraceMode.physical
        ? physicalPaths
        : physicalPaths
            .map((p) => _applyConductingGate(graph, p, mode, solvedState, operatingContext, diagnostics))
            .toList(growable: false);

    if (paths.isEmpty) {
      diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.noPhysicalPath));
    } else if (mode != TraceMode.physical && paths.every((p) => p.conductingState == ElectricalConductingState.open)) {
      diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.noConductingPath));
    }

    final componentIds = <String>{};
    final relationshipIds = <String>{};
    final terminalsVisited = <ProbePoint>{};
    final spliceComponentIds = <String>{};
    final connectorComponentIds = <String>{};
    for (final path in paths) {
      for (final step in path.steps) {
        terminalsVisited.add(step.terminal);
        componentIds.add(step.terminal.nodeId);
        if (step.viaRelationshipId != null) relationshipIds.add(step.viaRelationshipId!);
        final node = graph.nodes[step.terminal.nodeId];
        if (node == null) continue;
        if (isSpliceNode(node)) spliceComponentIds.add(node.id);
        if (isConnectorNode(node)) connectorComponentIds.add(node.id);
      }
    }

    final sourceTerminals = <ProbePoint>{};
    final returnTerminals = <ProbePoint>{};
    if (solvedState != null) {
      for (final terminal in terminalsVisited) {
        final state = solvedState.terminalStates[terminal];
        if (state == null) continue;
        if (state.isSourceTerminal) sourceTerminals.add(terminal);
        if (state.isReferenceTerminal) returnTerminals.add(terminal);
      }
    }
    if (sourceTerminals.length > 1) {
      diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.multipleSources));
    }
    if (returnTerminals.length > 1) {
      diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.multipleReturns));
    }
    if (mode == TraceMode.currentFlow) {
      final anyFlowing = paths.any((p) =>
          p.conductingState == ElectricalConductingState.conducting &&
          p.current != null &&
          p.current!.isValid &&
          (p.current!.value ?? 0) != 0);
      final anyZero = paths.any((p) =>
          p.conductingState == ElectricalConductingState.conducting &&
          p.current != null &&
          p.current!.isValid &&
          (p.current!.value ?? 0) == 0);
      if (anyFlowing) diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.currentFlowing));
      if (anyZero && !anyFlowing) {
        diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.conductingPathZeroCurrent));
      }
    }

    return TraceResult(
      target: target,
      mode: mode,
      generation: solvedState?.generation,
      paths: paths,
      sourceTerminals: sourceTerminals,
      returnTerminals: returnTerminals,
      componentIds: componentIds,
      relationshipIds: relationshipIds,
      terminalsVisited: terminalsVisited,
      spliceComponentIds: spliceComponentIds,
      connectorComponentIds: connectorComponentIds,
      diagnostics: diagnostics,
    );
  }

  // ---- Target normalization (§5) ----------------------------------------

  Set<ProbePoint> _resolveStartTerminals(EngineeringGraph graph, TraceTarget target, List<TraceDiagnostic> diagnostics) {
    switch (target.kind) {
      case TraceTargetKind.terminal:
        final terminal = target.terminal!;
        if (!graph.nodes.containsKey(terminal.nodeId)) {
          diagnostics.add(TraceDiagnostic(code: TraceDiagnosticCode.terminalNotFound, terminal: terminal));
          return const {};
        }
        return {terminal};
      case TraceTargetKind.component:
        final node = graph.nodes[target.componentId];
        if (node == null) {
          diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.targetNotFound));
          return const {};
        }
        return _terminalsOf(graph, node);
      case TraceTargetKind.relationship:
        final relationship = graph.relationships[target.relationshipId];
        if (relationship == null) {
          diagnostics.add(const TraceDiagnostic(code: TraceDiagnosticCode.targetNotFound));
          return const {};
        }
        return {
          _endpointTerminal(relationship, atSource: true),
          _endpointTerminal(relationship, atSource: false),
        };
    }
  }

  /// Every electrically-relevant terminal a component exposes — its own
  /// [Port]s if it has any declared, or a single portless [ProbePoint] as
  /// a graceful fallback for a node with no port metadata at all (§8:
  /// "must not assume a component has only two terminals," but also must
  /// not fabricate ports that were never authored).
  Set<ProbePoint> _terminalsOf(EngineeringGraph graph, EngineeringNode node) {
    if (node.ports.isEmpty) return {ProbePoint(nodeId: node.id)};
    return node.ports.map((p) => ProbePoint(nodeId: node.id, portId: p.id)).toSet();
  }

  ProbePoint _endpointTerminal(EngineeringRelationship relationship, {required bool atSource}) {
    final nodeId = atSource ? relationship.sourceNode : relationship.targetNode;
    final portId = atSource
        ? relationship.metadata['sourcePort'] as String?
        : relationship.metadata['targetPort'] as String?;
    return ProbePoint(nodeId: nodeId, portId: portId);
  }

  // ---- Physical topology trace (§4.1) ------------------------------------

  void _collectPhysicalPaths(
    EngineeringGraph graph,
    ProbePoint start,
    List<TracePath> out,
    Set<String> seenPathIds,
    List<TraceDiagnostic> diagnostics,
  ) {
    final visited = <ProbePoint>{start};
    _dfsPhysical(graph, [TracePathStep(terminal: start)], visited, out, seenPathIds, diagnostics);
  }

  void _dfsPhysical(
    EngineeringGraph graph,
    List<TracePathStep> steps,
    Set<ProbePoint> visited,
    List<TracePath> out,
    Set<String> seenPathIds,
    List<TraceDiagnostic> diagnostics,
  ) {
    final current = steps.last.terminal;
    final edges = _physicalEdgesFrom(graph, current);
    var extended = false;
    if (steps.length < maxDepth) {
      for (final edge in edges) {
        if (visited.contains(edge.terminal)) {
          diagnostics.add(TraceDiagnostic(
            code: TraceDiagnosticCode.cycleDetected,
            terminal: edge.terminal,
            relationshipId: edge.viaRelationshipId,
            message: 'Cycle back to an already-visited terminal — branch not extended further here.',
          ));
          continue;
        }
        extended = true;
        final nextSteps = [
          ...steps,
          TracePathStep(
            terminal: edge.terminal,
            viaRelationshipId: edge.viaRelationshipId,
            isInternalBridge: edge.isInternalBridge,
          ),
        ];
        _dfsPhysical(graph, nextSteps, {...visited, edge.terminal}, out, seenPathIds, diagnostics);
      }
    }
    // Record this path at every point it cannot be extended further (a
    // genuine dead end, maxDepth reached, or every onward edge was a
    // cycle back into itself) — matching the JS reference's own
    // "maximal simple path" enumeration, but terminal-aware and mode-safe.
    if (!extended) {
      final pathId = _pathId(steps);
      if (seenPathIds.add(pathId)) {
        out.add(TracePath(
          pathId: pathId,
          steps: List.unmodifiable(steps),
          conductingState: ElectricalConductingState.unknown,
        ));
      }
    }
  }

  List<_TerminalEdge> _physicalEdgesFrom(EngineeringGraph graph, ProbePoint terminal) {
    final edges = <_TerminalEdge>[];
    edges.addAll(_wireEdgesFrom(graph, terminal));
    final node = graph.nodes[terminal.nodeId];
    if (node != null) {
      for (final pair in _physicalInternalPairs(node)) {
        if (pair.contains(terminal.portId ?? '')) {
          final other = pair.terminalA == terminal.portId ? pair.terminalB : pair.terminalA;
          edges.add(_TerminalEdge(
            terminal: ProbePoint(nodeId: node.id, portId: other),
            viaRelationshipId: null,
            isInternalBridge: true,
          ));
        }
      }
    }
    return edges;
  }

  Set<ElectricalTerminalPair> _physicalInternalPairs(EngineeringNode node) {
    if (isGroundNode(node)) return const {}; // A ground point is a sink — see class doc comment on read-only sinks.
    final resolved = behaviorResolver?.call(node) ?? defaultElectricalBehaviorFor(node);
    if (resolved != null) return resolved.physicallyConnectableTerminalPairs(node);
    // No known behavior at all: the same conservative default PRODUCT-
    // READINESS-002 proved correct in the Legacy V2 solver
    // (AP-DEADEND-GENERALIZE-001) — never bridge two DIFFERENT terminals
    // of an unmodeled component by default; only a real, caller-supplied
    // behavior may assert that.
    return const {};
  }

  // ---- Wire (relationship) adjacency -------------------------------------

  List<_TerminalEdge> _wireEdgesFrom(EngineeringGraph graph, ProbePoint terminal) {
    final edges = <_TerminalEdge>[];
    for (final relationship in graph.relationshipsForNode(terminal.nodeId)) {
      final atSource = relationship.sourceNode == terminal.nodeId;
      final ownPort = atSource
          ? relationship.metadata['sourcePort'] as String?
          : relationship.metadata['targetPort'] as String?;
      // A relationship with no port metadata at all is treated as
      // touching every terminal of its node (graceful degradation for a
      // node with no declared ports — see `_terminalsOf`); one WITH port
      // metadata only matches the terminal it actually names, so it never
      // silently bridges past a node's other, unrelated terminals.
      if (ownPort != null && ownPort != terminal.portId) continue;
      final other = _endpointTerminal(relationship, atSource: !atSource);
      edges.add(_TerminalEdge(terminal: other, viaRelationshipId: relationship.id, isInternalBridge: false));
    }
    return edges;
  }

  // ---- Conducting / current-flow gating (§4.2/§4.3/§17) ------------------

  TracePath _applyConductingGate(
    EngineeringGraph graph,
    TracePath physicalPath,
    TraceMode mode,
    SolvedElectricalState? solvedState,
    ElectricalOperatingContext context,
    List<TraceDiagnostic> diagnostics,
  ) {
    final steps = physicalPath.steps;
    final acceptedSteps = <TracePathStep>[steps.first];
    for (var i = 1; i < steps.length; i++) {
      final previous = steps[i - 1];
      final step = steps[i];
      final gate = _evaluateHop(graph, previous, step, solvedState, context);
      if (!gate.conducts) {
        return TracePath(
          pathId: physicalPath.pathId,
          steps: List.unmodifiable(acceptedSteps),
          conductingState: ElectricalConductingState.open,
          blockingStep: step,
          blockingReason: gate.reason,
        );
      }
      acceptedSteps.add(step);
    }
    if (mode == TraceMode.physical || acceptedSteps.length < 2) {
      return TracePath(
        pathId: physicalPath.pathId,
        steps: List.unmodifiable(acceptedSteps),
        conductingState: ElectricalConductingState.conducting,
      );
    }
    if (mode != TraceMode.currentFlow) {
      return TracePath(
        pathId: physicalPath.pathId,
        steps: List.unmodifiable(acceptedSteps),
        conductingState: ElectricalConductingState.conducting,
      );
    }
    // currentFlow: derive an aggregate current/direction from a wire hop
    // along this path, oriented relative to the path's own traversal
    // order (§15: never from wire.from->wire.to, screen coordinates, or
    // voltage — only from the solved branch itself). Prefers the first
    // hop with a genuinely VALID current reading — a pass-through
    // component (a fuse, a closed switch) that merely bridges voltage
    // straight across itself always solves to a real but UNINFORMATIVE
    // zero-drop reading at its own two terminals (§19's minimal Ohm's-law
    // scope only produces a meaningful nonzero answer at an actual
    // resistive dead-end, e.g. the load itself) — falling through past
    // those to find the one hop that actually carries the circuit's real
    // current, rather than reporting the first (technically non-null,
    // but uninformative) branch entry encountered.
    ElectricalBranchState? firstBranchSeen;
    for (var i = 1; i < acceptedSteps.length; i++) {
      final relId = acceptedSteps[i].viaRelationshipId;
      if (relId == null) continue;
      final branch = solvedState?.branchState(relId);
      if (branch == null) continue;
      firstBranchSeen ??= branch;
      if (!branch.current.isValid) continue;
      final reversed = branch.sourceTerminal == acceptedSteps[i].terminal;
      final direction = !reversed
          ? branch.currentDirection
          : switch (branch.currentDirection) {
              ElectricalCurrentDirection.sourceToDestination => ElectricalCurrentDirection.destinationToSource,
              ElectricalCurrentDirection.destinationToSource => ElectricalCurrentDirection.sourceToDestination,
              ElectricalCurrentDirection.none => ElectricalCurrentDirection.none,
              ElectricalCurrentDirection.unknown => ElectricalCurrentDirection.unknown,
            };
      return TracePath(
        pathId: physicalPath.pathId,
        steps: List.unmodifiable(acceptedSteps),
        conductingState: ElectricalConductingState.conducting,
        currentDirection: direction,
        current: branch.current,
      );
    }
    return TracePath(
      pathId: physicalPath.pathId,
      steps: List.unmodifiable(acceptedSteps),
      conductingState: ElectricalConductingState.conducting,
      current: firstBranchSeen?.current ??
          ElectricalReading.unknown(note: 'No wire hop on this path carries solved branch data.'),
    );
  }

  _HopGate _evaluateHop(
    EngineeringGraph graph,
    TracePathStep previous,
    TracePathStep step,
    SolvedElectricalState? solvedState,
    ElectricalOperatingContext context,
  ) {
    if (step.viaRelationshipId != null) {
      final branch = solvedState?.branchState(step.viaRelationshipId!);
      if (branch == null) {
        return const _HopGate(false, 'No solved branch state available for this wire.');
      }
      if (branch.conductingState != ElectricalConductingState.conducting) {
        return const _HopGate(false, 'Wire is not conducting under the current solved state.');
      }
      return const _HopGate(true, null);
    }
    // Internal (same-component) bridge — consult the REAL, state-aware
    // conductingTerminalPairs, never physicallyConnectableTerminalPairs
    // (that one is physical-mode only, by design).
    final node = graph.nodes[previous.terminal.nodeId];
    if (node == null) return const _HopGate(false, 'Component no longer present in the graph.');
    final resolved = behaviorResolver?.call(node) ?? defaultElectricalBehaviorFor(node);
    if (resolved == null) {
      return const _HopGate(false, 'No component behavior known — cannot confirm internal conduction.');
    }
    final pairs = resolved.conductingTerminalPairs(node, context);
    final pair = ElectricalTerminalPair(previous.terminal.portId ?? '', step.terminal.portId ?? '');
    if (!pairs.contains(pair)) {
      return const _HopGate(false, 'Component is not bridging these two terminals under the current operating state.');
    }
    return const _HopGate(true, null);
  }

  String _pathId(List<TracePathStep> steps) => steps
      .map((s) => '${s.terminal.nodeId}:${s.terminal.portId ?? ""}${s.viaRelationshipId != null ? "/${s.viaRelationshipId}" : ""}')
      .join('>');
}

class _TerminalEdge {
  const _TerminalEdge({required this.terminal, required this.viaRelationshipId, required this.isInternalBridge});
  final ProbePoint terminal;
  final String? viaRelationshipId;
  final bool isInternalBridge;
}

class _HopGate {
  const _HopGate(this.conducts, this.reason);
  final bool conducts;
  final String? reason;
}
