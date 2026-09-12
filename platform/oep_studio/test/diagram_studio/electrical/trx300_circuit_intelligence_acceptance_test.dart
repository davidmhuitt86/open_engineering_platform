import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/electrical/studio_electrical_solver.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';
import 'package:oep_studio/diagram_studio/trace/circuit_search.dart';
import 'package:oep_studio/diagram_studio/trace/trace_highlight_plan.dart';

/// PRODUCT-READINESS-010 §37/§38 — the real TRX300 Circuit Intelligence
/// acceptance matrix (search + circuit discovery), against
/// `samples/diagram7.json` through the REAL production
/// `DiagramDocument.open()` path -- no test-only graph reconstruction --
/// using the exact same `buildStudioElectricalSolver()`/
/// `buildStudioTraceEngine()`/`searchCircuitEntities` the real UI uses.
void main() {
  late EngineeringGraph graph;
  late EngineeringNode battery;
  late EngineeringNode ignitionSwitch;
  late EngineeringNode handlebarSwitch;
  late EngineeringNode lhHeadlight;
  late EngineeringNode rhHeadlight;
  late EngineeringNode chassisGround;

  setUpAll(() async {
    final document = DiagramDocument();
    final result = await document.open('samples/diagram7.json');
    graph = result.graph;
    battery = graph.nodes.values.firstWhere((n) => n.displayName == 'Battery');
    ignitionSwitch = graph.nodes.values.firstWhere((n) => n.id == 'ignition-switch');
    handlebarSwitch = graph.nodes.values.firstWhere((n) => n.id == 'left-handlebar-switch');
    lhHeadlight = graph.nodes.values.firstWhere((n) => n.displayName == 'LH Headlight');
    rhHeadlight = graph.nodes.values.firstWhere((n) => n.displayName == 'RH Headlight');
    chassisGround = graph.nodes.values.firstWhere((n) => n.id == 'chassis-ground');
  });

  final solver = buildStudioElectricalSolver();
  final engine = buildStudioTraceEngine();
  final counter = ElectricalSolutionGenerationCounter();

  Map<String, Object?> keyOffContext() => {
        ignitionSwitch.id: {'power': 'off'},
        handlebarSwitch.id: {'lights': 'off', 'dimmer': 'lo', 'engineStop': 'run', 'starter': 'free'},
      };
  Map<String, Object?> keyOnLightsOffContext() => {
        ignitionSwitch.id: {'power': 'on'},
        handlebarSwitch.id: {'lights': 'off', 'dimmer': 'lo', 'engineStop': 'run', 'starter': 'free'},
      };
  Map<String, Object?> lowBeamContext() => {
        ignitionSwitch.id: {'power': 'on'},
        handlebarSwitch.id: {'lights': 'on', 'dimmer': 'lo', 'engineStop': 'run', 'starter': 'free'},
      };
  Map<String, Object?> highBeamContext() => {
        ignitionSwitch.id: {'power': 'on'},
        handlebarSwitch.id: {'lights': 'on', 'dimmer': 'hi', 'engineStop': 'run', 'starter': 'free'},
      };

  TraceResult physicalTrace(TraceTarget target) => engine.trace(graph: graph, target: target, mode: TraceMode.physical);
  TraceResult conductingTrace(TraceTarget target, Map<String, Object?> states) {
    final context = ElectricalOperatingContext(activeInputStates: states);
    final solved = solver.solve(graph, context, generationCounter: counter);
    return engine.trace(graph: graph, target: target, mode: TraceMode.conducting, solvedState: solved, operatingContext: context);
  }

  TraceResult currentFlowTrace(TraceTarget target, Map<String, Object?> states) {
    final context = ElectricalOperatingContext(activeInputStates: states);
    final solved = solver.solve(graph, context, generationCounter: counter);
    return engine.trace(graph: graph, target: target, mode: TraceMode.currentFlow, solvedState: solved, operatingContext: context);
  }

  // ---- A/B: search + locate ------------------------------------------

  test('TEST A/B -- Search "Headlight" returns the real component, and it resolves to the real diagram object', () {
    final results = searchCircuitEntities(graph: graph, layout: DiagramLayoutState.empty, symbols: SymbolLibrary(), query: 'Headlight');
    final headlightMatches = results.where((e) => e.isNode && (e.targetId == lhHeadlight.id || e.targetId == rhHeadlight.id));
    expect(headlightMatches, isNotEmpty);
    // §39 -- LH and RH BOTH share the substring "Headlight" in their real
    // names; both real, distinct objects must be represented.
    expect(headlightMatches.map((e) => e.targetId).toSet(), {lhHeadlight.id, rhHeadlight.id});
  });

  // ---- C: physical circuit --------------------------------------------

  test('TEST C -- Discover Physical circuit reaches the real upstream harness', () {
    final result = physicalTrace(TraceTarget.component(lhHeadlight.id));
    expect(result.isEmpty, isFalse);
    expect(result.componentIds, containsAll(<String>{battery.id, ignitionSwitch.id, handlebarSwitch.id, chassisGround.id}));
  });

  // ---- D/E: conducting circuit, Key OFF vs Key ON ----------------------

  test('TEST D -- Discover Conducting circuit with Key OFF: blocked at the real ignition switch', () {
    final result = conductingTrace(TraceTarget.component(battery.id), keyOffContext());
    final blocked = result.paths.where((p) => p.blockingStep != null);
    expect(blocked, isNotEmpty);
    expect(blocked.any((p) => p.blockingStep!.terminal.nodeId == ignitionSwitch.id), isTrue);
  });

  test('TEST E -- Discover Conducting circuit with Key ON: the conducting path genuinely changes', () {
    final off = conductingTrace(TraceTarget.component(battery.id), keyOffContext());
    final on = conductingTrace(TraceTarget.component(battery.id), keyOnLightsOffContext());
    expect(on.componentIds.length, greaterThan(off.componentIds.length));
    expect(on.paths.any((p) => p.blockingStep?.terminal.nodeId == ignitionSwitch.id), isFalse);
  });

  // ---- F/G: current-flow circuit, LOW/HIGH beam ------------------------

  test('TEST F -- Discover Current Flow with LOW BEAM: real solved current, direction, source/return', () {
    // A whole-COMPONENT target (not a single terminal) so the trace's own
    // terminal normalization seeds both the LO/HI (power) side AND the
    // GND (return) side -- a single-terminal target only ever explores
    // outward from that one terminal, so source/return identification
    // over BOTH ends of the circuit needs the component-level target
    // here, matching how PRODUCT-READINESS-009's own TEST D used it.
    final result = currentFlowTrace(TraceTarget.component(lhHeadlight.id), lowBeamContext());
    final flowing = result.paths.where((p) => p.current != null && p.current!.isValid);
    expect(flowing, isNotEmpty);
    expect(result.sourceTerminals.map((t) => t.nodeId), contains(battery.id));
    expect(result.returnTerminals.map((t) => t.nodeId), contains(chassisGround.id));

    final plan = buildTraceHighlightPlan(graph, result);
    expect(plan.currentFlowByRelationshipId, isNotEmpty);
  });

  test('TEST G -- Discover Current Flow with HIGH BEAM: the path changes to the Hi filament', () {
    final lowBeamOnLo = currentFlowTrace(TraceTarget.terminal(ProbePoint(nodeId: lhHeadlight.id, portId: _portId(lhHeadlight, 'LO'))), highBeamContext());
    final highBeamOnHi = currentFlowTrace(TraceTarget.terminal(ProbePoint(nodeId: lhHeadlight.id, portId: _portId(lhHeadlight, 'Hi'))), highBeamContext());
    expect(lowBeamOnLo.paths.where((p) => p.current != null && p.current!.isValid), isEmpty, reason: 'LO is not energized in HIGH BEAM');
    expect(highBeamOnHi.paths.where((p) => p.current != null && p.current!.isValid), isNotEmpty, reason: 'Hi is energized in HIGH BEAM');
  });

  // ---- H: parallel branches ---------------------------------------------

  test('TEST H -- LH/RH parallel branches are preserved in the discovered circuit', () {
    final result = currentFlowTrace(TraceTarget.component(handlebarSwitch.id), lowBeamContext());
    expect(result.componentIds, contains(lhHeadlight.id));
    expect(result.componentIds, contains(rhHeadlight.id));

    // §15 -- the branch tree itself must show a real split, never a
    // collapsed single series path.
    final tree = buildCircuitBranchTree(result.paths);
    bool hasRealBranch(List<CircuitBranchNode> nodes) {
      for (final n in nodes) {
        if (n.children.length > 1) return true;
        if (hasRealBranch(n.children)) return true;
      }
      return false;
    }

    expect(hasRealBranch(tree), isTrue);
  });

  // ---- I/J: source/return identification --------------------------------

  test('TEST I/J -- Battery + is identified as source, chassis ground as return', () {
    final result = currentFlowTrace(TraceTarget.component(lhHeadlight.id), lowBeamContext());
    expect(result.sourceTerminals.map((t) => t.nodeId), contains(battery.id));
    expect(result.returnTerminals.map((t) => t.nodeId), contains(chassisGround.id));
  });

  // ---- K: blocking diagnostics -------------------------------------------

  test('TEST K -- blocking switch diagnostics identify the real ignition switch, never "no path"', () {
    final result = conductingTrace(TraceTarget.component(battery.id), keyOffContext());
    final blocked = result.paths.where((p) => p.blockingStep != null).toList();
    expect(blocked, isNotEmpty);
    expect(blocked.first.blockingReason, isNotNull);
    expect(blocked.first.blockingStep!.terminal.nodeId, ignitionSwitch.id);
  });

  // ---- M: Fit Circuit region ----------------------------------------------

  test('TEST M -- the highlight plan\'s allNodeIds covers the real traced region for Fit Circuit', () {
    final result = physicalTrace(TraceTarget.component(lhHeadlight.id));
    final plan = buildTraceHighlightPlan(graph, result);
    expect(plan.allNodeIds, result.componentIds);
    expect(plan.allNodeIds, contains(battery.id));
  });

  // ---- §38 search test cases -----------------------------------------------

  test('§38 search cases resolve to the correct real engineering identity', () {
    Set<String> nodeIdsFor(String query) => searchCircuitEntities(graph: graph, layout: DiagramLayoutState.empty, symbols: SymbolLibrary(), query: query)
        .where((e) => e.isNode)
        .map((e) => e.targetId)
        .toSet();

    expect(nodeIdsFor('Battery'), contains(battery.id));
    // The real chassis-ground node's own displayName is "Chassis GND"
    // (confirmed directly in samples/diagram7.json) -- a DIFFERENT real
    // node ("Battery Chassis Ground") also exists and legitimately
    // matches the substring "Chassis Ground"; searching the real display
    // name is the correct way to resolve the specific node this test
    // means, not an assumed/guessed label (§39: distinguishing similarly-
    // named real objects is the whole point here).
    expect(nodeIdsFor('Chassis GND'), contains(chassisGround.id));

    final loResults = searchCircuitEntities(graph: graph, layout: DiagramLayoutState.empty, symbols: SymbolLibrary(), query: 'Headlight LO');
    expect(loResults.any((e) => e.isTerminal && e.terminalMatch!.terminal.nodeId == lhHeadlight.id && e.terminalMatch!.terminalName == 'LO'), isTrue);

    final hiResults = searchCircuitEntities(graph: graph, layout: DiagramLayoutState.empty, symbols: SymbolLibrary(), query: 'Headlight HI');
    expect(hiResults.any((e) => e.isTerminal), isTrue);
  });

  test('§40 a nonexistent search term returns no results, never throws', () {
    expect(searchCircuitEntities(graph: graph, layout: DiagramLayoutState.empty, symbols: SymbolLibrary(), query: 'zzz-nonexistent-zzz'), isEmpty);
  });
}

String _portId(EngineeringNode node, String name) => node.ports.firstWhere((p) => p.name.toUpperCase() == name.toUpperCase()).id;
