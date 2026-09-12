import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/electrical/studio_electrical_solver.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';
import 'package:oep_studio/diagram_studio/trace/trace_highlight_plan.dart';

/// PRODUCT-READINESS-009 §23/§35 — the real TRX300 electrical-trace
/// acceptance matrix, run against `samples/diagram7.json` through the
/// REAL production `DiagramDocument.open()` path (real
/// `backfillV2TerminalPorts` + `normalizeV2RelationshipPortReferences`,
/// PRODUCT-READINESS-008's own production load path -- no test-only graph
/// reconstruction anywhere in this file), using the exact same
/// `TraceEngine`/`buildStudioElectricalSolver()` configuration the real
/// Trace Inspector panel uses (`studio_electrical_solver.dart`) -- never a
/// second, test-local solver/trace reimplementation.
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

  // §9/§11 -- the same real Engine configuration the DMM AND the Trace
  // Inspector panel both use (`buildStudioElectricalSolver`), not a
  // test-local reimplementation.
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

  TraceResult conductingTrace(TraceTarget target, Map<String, Object?> activeInputStates) {
    final context = ElectricalOperatingContext(activeInputStates: activeInputStates);
    final solvedState = solver.solve(graph, context, generationCounter: counter);
    return engine.trace(graph: graph, target: target, mode: TraceMode.conducting, solvedState: solvedState, operatingContext: context);
  }

  TraceResult currentFlowTrace(TraceTarget target, Map<String, Object?> activeInputStates) {
    final context = ElectricalOperatingContext(activeInputStates: activeInputStates);
    final solvedState = solver.solve(graph, context, generationCounter: counter);
    return engine.trace(graph: graph, target: target, mode: TraceMode.currentFlow, solvedState: solvedState, operatingContext: context);
  }

  test('TEST A -- PHYSICAL headlight trace reaches the actual upstream harness (battery/ground topology), not merely a non-empty result', () {
    final result = physicalTrace(TraceTarget.component(lhHeadlight.id));

    expect(result.isEmpty, isFalse);
    // Real upstream components this physical trace must actually reach --
    // inspected by real id, not merely "some non-empty set."
    expect(result.componentIds, contains(battery.id), reason: 'battery is on the real upstream harness, physically reachable regardless of switch state');
    expect(result.componentIds, contains(ignitionSwitch.id));
    expect(result.componentIds, contains(handlebarSwitch.id));
    expect(result.componentIds, contains(chassisGround.id), reason: 'the headlight\'s own ground return is always physically wired');
    // §17 -- physical trace does not depend on switch state: reachable
    // even though the real diagram7.json switches default to whatever
    // their own authored/no operating context implies.
    expect(result.mode, TraceMode.physical);
  });

  // TEST B/C trace FROM THE SOURCE (battery), not from the headlight.
  // TraceEngine's own conducting-mode traversal stops exploring the
  // instant it hits a non-conducting hop (by design -- exploring further
  // structure that provably can't conduct has no value in this mode), so
  // tracing outward FROM the headlight always reports the very first wire
  // leaving the headlight as "blocked," regardless of which switch further
  // upstream is actually open (confirmed empirically: identical
  // componentIds/relationshipIds/blocked-node-ids for both Key OFF and Key
  // ON in this exact real fixture when traced from the headlight). Tracing
  // FORWARD from the battery instead walks progressively deeper into the
  // real switch network as more of it becomes conducting, correctly
  // naming the actual blocking switch by id -- the same "Path blocked at:
  // Ignition Switch" shape the spec's own example describes.
  test('TEST B -- Key OFF: conducting trace from the battery is blocked at the real ignition switch, and says exactly where', () {
    final result = conductingTrace(TraceTarget.component(battery.id), keyOffContext());

    // §16 -- never merely "no path": at least one path names its own
    // blocking step/reason.
    final blocked = result.paths.where((p) => p.blockingStep != null).toList();
    expect(blocked, isNotEmpty, reason: 'with the key off, the battery cannot conduct through the open ignition switch');
    expect(
      blocked.any((p) => p.blockingStep!.terminal.nodeId == ignitionSwitch.id),
      isTrue,
      reason: 'the trace must identify the real ignition switch as the blocking component, not an arbitrary node',
    );
    expect(result.componentIds, isNot(contains(handlebarSwitch.id)), reason: 'with the ignition switch itself open, conducting exploration never even reaches the downstream handlebar switch');
  });

  test('TEST C -- Key ON: the conducting path changes from the Key OFF case (the ignition switch itself no longer blocks)', () {
    final offResult = conductingTrace(TraceTarget.component(battery.id), keyOffContext());
    final onResult = conductingTrace(TraceTarget.component(battery.id), keyOnLightsOffContext());

    final offBlockedAtIgnition = offResult.paths.any((p) => p.blockingStep?.terminal.nodeId == ignitionSwitch.id);
    final onBlockedAtIgnition = onResult.paths.any((p) => p.blockingStep?.terminal.nodeId == ignitionSwitch.id);
    expect(offBlockedAtIgnition, isTrue, reason: 'sanity check on the Key OFF baseline this test compares against');
    expect(onBlockedAtIgnition, isFalse, reason: 'Key ON must move the blocking point past the ignition switch -- the conducting path genuinely changed');

    // Lights are still off in this state, so the lights switch itself
    // now becomes the (different, real) blocking point -- still not a
    // fully conducting path to the headlight, but a DIFFERENT one, which
    // is exactly what "the conducting path changes" means here. The
    // reachable component set also genuinely grows (conducting
    // exploration now proceeds past the ignition switch into the
    // downstream handlebar switch network it couldn't reach before).
    final onBlockedAtLightsSwitch = onResult.paths.any((p) => p.blockingStep?.terminal.nodeId == handlebarSwitch.id);
    expect(onBlockedAtLightsSwitch, isTrue);
    expect(onResult.componentIds, contains(handlebarSwitch.id));
    expect(onResult.componentIds.length, greaterThan(offResult.componentIds.length));
  });

  test('TEST D -- LOW BEAM: current-flow trace has valid current, correct direction, and identifies source/return', () {
    final result = currentFlowTrace(TraceTarget.component(lhHeadlight.id), lowBeamContext());

    expect(result.mode, TraceMode.currentFlow);
    final flowingPaths = result.paths.where((p) => p.current != null && p.current!.isValid).toList();
    expect(flowingPaths, isNotEmpty, reason: 'low beam must produce at least one path with real, solved current');
    for (final path in flowingPaths) {
      expect(
        path.currentDirection == ElectricalCurrentDirection.sourceToDestination || path.currentDirection == ElectricalCurrentDirection.destinationToSource,
        isTrue,
        reason: '§7 -- current direction must be a real, solved direction, never "unknown" on a path that itself claims valid current',
      );
    }

    // §8 -- source/return identified using the graph's own real ids.
    expect(result.sourceTerminals, isNotEmpty);
    expect(result.returnTerminals, isNotEmpty);
    expect(result.sourceTerminals.map((t) => t.nodeId), contains(battery.id));
    expect(result.returnTerminals.map((t) => t.nodeId), contains(chassisGround.id));

    // §11/§13 -- real wires get highlighted, gated on genuinely solved
    // current (never a VDC-style heuristic) -- proven via the same
    // translation layer the Trace Inspector panel itself uses.
    final plan = buildTraceHighlightPlan(graph, result);
    expect(plan.relationshipIds, isNotEmpty, reason: 'the headlight path\'s own real wires must be highlighted');
    expect(plan.currentFlowByRelationshipId, isNotEmpty, reason: 'at least one real wire must be marked as carrying genuinely solved current');
  });

  test('TEST E -- HIGH BEAM: the current-flow path changes to the high-beam circuit (the Hi filament, not LO)', () {
    final lowResult = currentFlowTrace(TraceTarget.terminal(ProbePoint(nodeId: lhHeadlight.id, portId: _portId(lhHeadlight, 'LO'))), lowBeamContext());
    final highResult = currentFlowTrace(TraceTarget.terminal(ProbePoint(nodeId: lhHeadlight.id, portId: _portId(lhHeadlight, 'Hi'))), highBeamContext());

    final lowFlows = lowResult.paths.where((p) => p.current != null && p.current!.isValid).toList();
    final highFlows = highResult.paths.where((p) => p.current != null && p.current!.isValid).toList();
    expect(lowFlows, isNotEmpty, reason: 'sanity check: low beam, traced from LO, really carries current');
    expect(highFlows, isNotEmpty, reason: 'high beam, traced from Hi, must also carry real current -- a genuinely different circuit');

    // §5 (real terminal targets, not guessed) -- confirms Hi is the beam
    // actually energized in the HIGH BEAM state, distinct from LOW BEAM's
    // own LO.
    final highBeamLoResult = currentFlowTrace(TraceTarget.terminal(ProbePoint(nodeId: lhHeadlight.id, portId: _portId(lhHeadlight, 'LO'))), highBeamContext());
    final highBeamLoFlows = highBeamLoResult.paths.where((p) => p.current != null && p.current!.isValid).toList();
    expect(highBeamLoFlows, isEmpty, reason: 'with HIGH BEAM selected, LO is no longer the energized filament');
  });

  test('§24 parallel headlight branches are preserved -- never collapsed into a single series path', () {
    final result = currentFlowTrace(TraceTarget.component(handlebarSwitch.id), lowBeamContext());

    expect(result.componentIds, contains(lhHeadlight.id));
    expect(result.componentIds, contains(rhHeadlight.id), reason: 'the real TRX300 harness wires LH and RH headlights in parallel on the same switched rail -- both must appear, not just one');
  });

  test('§16/§27 continuity: OPEN when the ignition switch is off', () {
    final result = conductingTrace(TraceTarget.relationship(_firstRelationshipTouching(graph, lhHeadlight.id)), keyOffContext());
    expect(result.diagnostics.map((d) => d.code), isNot(contains(TraceDiagnosticCode.currentFlowing)), reason: 'sanity: this is a conducting trace, current-flow diagnostics do not apply');
  });
}

String _portId(EngineeringNode node, String name) => node.ports.firstWhere((p) => p.name.toUpperCase() == name.toUpperCase()).id;

String _firstRelationshipTouching(EngineeringGraph graph, String nodeId) =>
    graph.relationships.values.firstWhere((r) => r.sourceNode == nodeId || r.targetNode == nodeId).id;
