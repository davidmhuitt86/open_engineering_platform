import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

EngineeringRelationship _wire(String id, String fromNode, String fromPort, String toNode, String toPort) {
  return EngineeringRelationship(
    id: id,
    relationshipType: RelationshipType.connectedTo,
    sourceNode: fromNode,
    targetNode: toNode,
    metadata: {'sourcePort': fromPort, 'targetPort': toPort},
  );
}

/// PRODUCT-READINESS-006 §36 — proves TraceEngine genuinely CONSUMES a
/// real [SolvedElectricalState] produced by [ElectricalSolver] (not a
/// hand-built fixture standing in for one, as every PRODUCT-READINESS-005
/// trace test necessarily used, since no solver existed yet). This is the
/// literal wiring §1's own architecture diagram calls for:
/// Engine -> Solver -> SolvedElectricalState -> Trace Engine.
void main() {
  test('physical trace is unaffected by an open switch; conducting/current-flow trace, fed the REAL '
      'solver output, correctly reflect it -- proving genuine solver->TraceEngine integration', () {
    final fuse = EngineeringNode(id: 'fuse', category: NodeCategory.fuse, displayName: 'Fuse', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
    final sw = EngineeringNode(id: 'switch', category: NodeCategory.switchNode, displayName: 'Switch', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
    final lamp = EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
    final battery = EngineeringNode(
      id: 'battery', category: NodeCategory.component, displayName: 'Battery',
      metadata: const {'v2Category': 'power'}, properties: const {'nominalVoltageV': 12.6},
      ports: const [Port(id: 'plus', name: '+'), Port(id: 'minus', name: '-')],
    );
    final ground = EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground', ports: const [Port(id: 'gnd', name: 'gnd')]);
    final graph = EngineeringGraph(id: 'g', nodes: {
      'battery': battery, 'fuse': fuse, 'switch': sw, 'lamp': lamp, 'ground': ground,
    }, relationships: {
      'w1': _wire('w1', 'battery', 'plus', 'fuse', 'in'),
      'w2': _wire('w2', 'fuse', 'out', 'switch', 'in'),
      'w3': _wire('w3', 'switch', 'out', 'lamp', 'in'),
      'w4': _wire('w4', 'lamp', 'out', 'ground', 'gnd'),
      'w5': _wire('w5', 'battery', 'minus', 'ground', 'gnd'),
    });

    ElectricalComponentBehavior? behaviorFor(EngineeringNode node) {
      if (node.id == 'fuse') return const InlinePassThroughElectricalComponentBehavior();
      if (node.id == 'switch') return const SwitchElectricalBehavior(switchId: 'switch');
      if (node.id == 'lamp') return const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 120);
      return null;
    }

    final solver = ElectricalSolver(behaviorResolver: behaviorFor);
    final traceEngine = TraceEngine(behaviorResolver: behaviorFor);
    final counter = ElectricalSolutionGenerationCounter();

    // ---- Switch OPEN: real solve, then real trace against it ----
    final openState = solver.solve(graph, const ElectricalOperatingContext(activeInputStates: {'switch': false}), generationCounter: counter);

    final physicalWhileOpen = traceEngine.trace(graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.physical);
    expect(physicalWhileOpen.componentIds, containsAll(['battery', 'fuse', 'switch', 'lamp']),
        reason: 'physical topology is unaffected by switch state, even when fed a solved state from an open switch');

    final conductingWhileOpen = traceEngine.trace(
      graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.conducting,
      solvedState: openState, operatingContext: const ElectricalOperatingContext(activeInputStates: {'switch': false}),
    );
    expect(conductingWhileOpen.generation, openState.generation, reason: 'the trace result carries the REAL solver\'s own generation');
    // The lamp's GROUND/return side legitimately stays conducting all the
    // way to battery.minus (the switch only gates the power feed, not the
    // return path) -- but no path reaching the battery's own POWER
    // terminal (battery.plus) specifically may be fully conducting while
    // the switch is open.
    final pathsReachingBatteryPlus =
        conductingWhileOpen.paths.where((p) => p.endTerminal == ProbePoint(nodeId: 'battery', portId: 'plus'));
    expect(pathsReachingBatteryPlus.every((p) => p.conductingState != ElectricalConductingState.conducting), isTrue,
        reason: 'the real, solver-reported open switch must block the power path to battery.plus');

    // ---- Switch CLOSED: real solve produces real current; current-flow trace reflects it ----
    final closedState = solver.solve(graph, const ElectricalOperatingContext(activeInputStates: {'switch': true}), generationCounter: counter);
    expect(closedState.generation.isNewerThan(openState.generation), isTrue);

    final currentFlowWhileClosed = traceEngine.trace(
      graph: graph, target: TraceTarget.component('battery'), mode: TraceMode.currentFlow,
      solvedState: closedState, operatingContext: const ElectricalOperatingContext(activeInputStates: {'switch': true}),
    );
    final toLamp = currentFlowWhileClosed.paths.where((p) => p.endTerminal.nodeId == 'lamp' && p.conductingState == ElectricalConductingState.conducting);
    expect(toLamp, isNotEmpty);
    final realCurrentPath = toLamp.first;
    expect(realCurrentPath.current?.isValid, isTrue);
    expect(realCurrentPath.current?.value, closeTo(12.6 / 120, 1e-9),
        reason: 'the REAL Ohm\'s-law current the solver computed, read by the trace engine unmodified');
    expect(currentFlowWhileClosed.diagnostics.map((d) => d.code), contains(TraceDiagnosticCode.currentFlowing));
  });
}
