import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// PRODUCT-READINESS-010 §12/§30/§31 — [CircuitSummary.derive] unit tests.
void main() {
  TracePath path({
    required List<TracePathStep> steps,
    ElectricalConductingState conductingState = ElectricalConductingState.conducting,
    ElectricalReading? current,
    TracePathStep? blockingStep,
    String? blockingReason,
  }) =>
      TracePath(
        pathId: steps.map((s) => '${s.terminal}${s.viaRelationshipId ?? ''}').join('>'),
        steps: steps,
        conductingState: conductingState,
        current: current,
        blockingStep: blockingStep,
        blockingReason: blockingReason,
      );

  TraceResult result({
    required List<TracePath> paths,
    Set<ProbePoint> sourceTerminals = const {},
    Set<ProbePoint> returnTerminals = const {},
    Set<String> componentIds = const {},
    Set<String> relationshipIds = const {},
    TraceMode mode = TraceMode.physical,
  }) =>
      TraceResult(
        target: TraceTarget.component('x'),
        mode: mode,
        generation: null,
        paths: paths,
        sourceTerminals: sourceTerminals,
        returnTerminals: returnTerminals,
        componentIds: componentIds,
        relationshipIds: relationshipIds,
        terminalsVisited: const {},
        spliceComponentIds: const {},
        connectorComponentIds: const {},
        diagnostics: const [],
      );

  test('§30 counts come straight from TraceResult, never estimated', () {
    final r = result(
      paths: [path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'a'))])],
      componentIds: {'a', 'b', 'c'},
      relationshipIds: {'w1', 'w2'},
    );
    final summary = CircuitSummary.derive(r);
    expect(summary.componentCount, 3);
    expect(summary.wireCount, 2);
    expect(summary.branchCount, 1);
  });

  test('§15 branchCount reflects every distinct TracePath, never collapsed', () {
    final r = result(paths: [
      path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'lh'))]),
      path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'rh'))]),
    ]);
    expect(CircuitSummary.derive(r).branchCount, 2);
  });

  test('a circuit with no blocked paths is not blocked, and its conducting state is real', () {
    final r = result(
      paths: [path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'a'))])],
      mode: TraceMode.conducting,
    );
    final summary = CircuitSummary.derive(r);
    expect(summary.isBlocked, isFalse);
    expect(summary.overallConductingState, ElectricalConductingState.conducting);
  });

  test('§16/§34 a circuit where every path is blocked is reported as blocked', () {
    const blockingStep = TracePathStep(terminal: ProbePoint(nodeId: 'switch'), viaRelationshipId: 'w1');
    final r = result(
      paths: [
        path(
          steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'a')), blockingStep],
          conductingState: ElectricalConductingState.open,
          blockingStep: blockingStep,
          blockingReason: 'Switch open',
        ),
      ],
      mode: TraceMode.conducting,
    );
    final summary = CircuitSummary.derive(r);
    expect(summary.isBlocked, isTrue);
    expect(summary.overallConductingState, ElectricalConductingState.open);
  });

  test('a mix of one conducting and one blocked branch is NOT reported as fully blocked', () {
    const blockingStep = TracePathStep(terminal: ProbePoint(nodeId: 'rh'), viaRelationshipId: 'w2');
    final r = result(paths: [
      path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'lh'))], conductingState: ElectricalConductingState.conducting),
      path(
        steps: const [blockingStep],
        conductingState: ElectricalConductingState.open,
        blockingStep: blockingStep,
      ),
    ]);
    final summary = CircuitSummary.derive(r);
    expect(summary.isBlocked, isFalse);
    expect(summary.overallConductingState, ElectricalConductingState.conducting);
  });

  test('an empty result (no paths at all) is blocked, never fabricated as conducting', () {
    final summary = CircuitSummary.derive(result(paths: const []));
    expect(summary.isBlocked, isTrue);
  });

  test('§31 current is populated only from a genuinely valid TracePath.current, never fabricated', () {
    final r = result(
      paths: [path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'a'))], current: ElectricalReading.valid(1.23, unit: 'A'))],
      mode: TraceMode.currentFlow,
    );
    expect(CircuitSummary.derive(r).current?.value, 1.23);
  });

  test('§31 an unsupported/invalid current is never surfaced as a value', () {
    final r = result(
      paths: [path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'a'))], current: ElectricalReading.unsupported())],
      mode: TraceMode.currentFlow,
    );
    expect(CircuitSummary.derive(r).current, isNull);
  });

  test('§13/§31 a genuinely valid solved source voltage is surfaced verbatim', () {
    const source = ProbePoint(nodeId: 'battery', portId: 'p');
    final graph = EngineeringGraph(id: 'g', nodes: {
      'battery': const EngineeringNode(
        id: 'battery',
        category: NodeCategory.component,
        displayName: 'Battery',
        metadata: {'v2Category': 'power'},
        properties: {'nominalVoltageV': 12.6},
        ports: [Port(id: 'p', name: '+')],
      ),
    }, relationships: const {});
    final solvedState = const ElectricalSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: ElectricalSolutionGenerationCounter());
    expect(solvedState.terminalStates[source]?.voltage.isValid, isTrue, reason: 'sanity check on the real solved fixture this test depends on');

    final r = result(paths: [path(steps: const [TracePathStep(terminal: source)])], sourceTerminals: {source});
    final summary = CircuitSummary.derive(r, solvedState: solvedState);
    expect(summary.sourceVoltage?.value, 12.6);
  });

  test('§13/§31 no solvedState supplied -> source voltage stays null, never guessed', () {
    const source = ProbePoint(nodeId: 'battery', portId: 'p');
    final r = result(paths: [path(steps: const [TracePathStep(terminal: source)])], sourceTerminals: {source});
    expect(CircuitSummary.derive(r).sourceVoltage, isNull);
  });

  test('§13/§31 an unreached/invalid solved source voltage is never surfaced as a fabricated value', () {
    const source = ProbePoint(nodeId: 'battery', portId: 'p');
    final graph = EngineeringGraph(id: 'g', nodes: {
      'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery', ports: [Port(id: 'p', name: '+')]),
    }, relationships: const {});
    final solvedState = const ElectricalSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: ElectricalSolutionGenerationCounter());
    expect(solvedState.terminalStates[source]?.voltage.isValid, isFalse, reason: 'sanity check: this component has no declared source voltage, so this really is unreached');

    final r = result(paths: [path(steps: const [TracePathStep(terminal: source)])], sourceTerminals: {source});
    expect(CircuitSummary.derive(r, solvedState: solvedState).sourceVoltage, isNull);
  });

  test('§13 source voltage is null (never guessed) when multiple sources are identified', () {
    final r = result(paths: [
      path(steps: const [TracePathStep(terminal: ProbePoint(nodeId: 'a'))]),
    ], sourceTerminals: {const ProbePoint(nodeId: 'a'), const ProbePoint(nodeId: 'b')});
    expect(CircuitSummary.derive(r).sourceVoltage, isNull);
  });
}
