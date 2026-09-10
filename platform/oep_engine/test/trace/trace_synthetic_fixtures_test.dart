import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

/// A minimal switch behavior for tests: bridges `in`<->`out` only when
/// `context.activeInputStates[switchId] == true`. Overrides
/// [physicallyConnectableTerminalPairs] explicitly (the default falls back
/// to `conductingTerminalPairs(node, ElectricalOperatingContext.none)`,
/// which is empty for a switch with no active input at all — a switch
/// behavior must declare its own structural capacity, per PRODUCT-
/// READINESS-005 §29's own documented reasoning).
/// A plain inline pass-through component (an intact fuse, or any wire-like
/// 2-terminal part that is not itself state-gated) — always bridges its
/// own `in`<->`out`, in both physical and conducting modes.
class _TestInlinePassThroughBehavior extends ElectricalComponentBehavior {
  const _TestInlinePassThroughBehavior(this.componentId);
  final String componentId;

  @override
  bool appliesTo(EngineeringNode node) => node.id == componentId;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      {ElectricalTerminalPair('in', 'out')};

  @override
  ElectricalReading resistanceBetween(
          EngineeringNode node, String terminalA, String terminalB, ElectricalOperatingContext context) =>
      ElectricalReading.valid(0, unit: 'Ω');
}

class _TestSwitchBehavior extends ElectricalComponentBehavior {
  const _TestSwitchBehavior(this.switchId);
  final String switchId;

  @override
  bool appliesTo(EngineeringNode node) => node.id == switchId;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      context.activeInputStates[switchId] == true ? {ElectricalTerminalPair('in', 'out')} : const {};

  @override
  Set<ElectricalTerminalPair> physicallyConnectableTerminalPairs(EngineeringNode node) =>
      {ElectricalTerminalPair('in', 'out')};

  @override
  ElectricalReading resistanceBetween(
          EngineeringNode node, String terminalA, String terminalB, ElectricalOperatingContext context) =>
      conductingTerminalPairs(node, context).contains(ElectricalTerminalPair(terminalA, terminalB))
          ? ElectricalReading.valid(0, unit: 'Ω')
          : ElectricalReading.open();
}

EngineeringNode _twoTerminal(String id, {NodeCategory category = NodeCategory.component, Map<String, Object?> metadata = const {}}) {
  return EngineeringNode(
    id: id,
    category: category,
    displayName: id,
    metadata: metadata,
    ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')],
  );
}

EngineeringRelationship _wire(String id, String fromNode, String fromPort, String toNode, String toPort) {
  return EngineeringRelationship(
    id: id,
    relationshipType: RelationshipType.connectedTo,
    sourceNode: fromNode,
    targetNode: toNode,
    metadata: {'sourcePort': fromPort, 'targetPort': toPort},
  );
}

void main() {
  const engine = TraceEngine();

  group('A: simple source -> load -> ground', () {
    test('physical trace reaches the load and the ground sink', () {
      final battery = EngineeringNode(
        id: 'battery',
        category: NodeCategory.component,
        displayName: 'Battery',
        ports: const [Port(id: 'plus', name: '+'), Port(id: 'minus', name: '-')],
      );
      final lamp = _twoTerminal('lamp');
      final ground = EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground', ports: const [Port(id: 'gnd', name: 'gnd')]);

      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': battery,
        'lamp': lamp,
        'ground': ground,
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'lamp', 'in'),
        'w2': _wire('w2', 'lamp', 'out', 'ground', 'gnd'),
      });

      final result = engine.trace(graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.physical);

      expect(result.componentIds, containsAll(['battery', 'lamp', 'ground']));
      expect(result.relationshipIds, containsAll(['w1', 'w2']));
      expect(result.diagnostics.where((d) => d.code == TraceDiagnosticCode.targetNotFound), isEmpty);
    });

    test('source/return identification uses SolvedElectricalState roles, not hardcoded names', () {
      final battery = EngineeringNode(
        id: 'battery',
        category: NodeCategory.component,
        displayName: 'Battery',
        ports: const [Port(id: 'plus', name: '+'), Port(id: 'minus', name: '-')],
      );
      final lamp = _twoTerminal('lamp');
      final ground = EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground', ports: const [Port(id: 'gnd', name: 'gnd')]);
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': battery,
        'lamp': lamp,
        'ground': ground,
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'lamp', 'in'),
        'w2': _wire('w2', 'lamp', 'out', 'ground', 'gnd'),
      });

      final plus = ProbePoint(nodeId: 'battery', portId: 'plus');
      final gnd = ProbePoint(nodeId: 'ground', portId: 'gnd');
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: {
          plus: ElectricalTerminalState(
            terminal: plus, voltage: ElectricalReading.valid(12.6, unit: 'V'),
            current: ElectricalReading.unsupported(), isSourceTerminal: true,
          ),
          gnd: ElectricalTerminalState(
            terminal: gnd, voltage: ElectricalReading.valid(0, unit: 'V'),
            current: ElectricalReading.unsupported(), isReferenceTerminal: true,
          ),
        },
        branchStates: {
          'w1': ElectricalBranchState(
            branchId: 'w1', sourceTerminal: plus, destinationTerminal: ProbePoint(nodeId: 'lamp', portId: 'in'),
            voltage: ElectricalReading.valid(12.6, unit: 'V'), voltageDrop: ElectricalReading.unsupported(),
            current: ElectricalReading.unsupported(), resistance: ElectricalReading.unsupported(),
            power: ElectricalReading.unsupported(), conductingState: ElectricalConductingState.conducting,
            currentDirection: ElectricalCurrentDirection.unknown, relationshipId: 'w1',
          ),
          'w2': ElectricalBranchState(
            branchId: 'w2', sourceTerminal: ProbePoint(nodeId: 'lamp', portId: 'out'), destinationTerminal: gnd,
            voltage: ElectricalReading.valid(0, unit: 'V'), voltageDrop: ElectricalReading.unsupported(),
            current: ElectricalReading.unsupported(), resistance: ElectricalReading.unsupported(),
            power: ElectricalReading.unsupported(), conductingState: ElectricalConductingState.conducting,
            currentDirection: ElectricalCurrentDirection.unknown, relationshipId: 'w2',
          ),
        },
      );

      final result = engine.trace(
        graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.conducting, solvedState: solved,
      );

      expect(result.sourceTerminals, {plus});
      expect(result.returnTerminals, {gnd});
    });
  });

  group('B/C: source -> fuse -> switch -> load -> ground', () {
    EngineeringGraph buildGraph() {
      final battery = EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery', ports: const [Port(id: 'plus', name: '+')]);
      final fuse = _twoTerminal('fuse', category: NodeCategory.fuse);
      final sw = _twoTerminal('switch', category: NodeCategory.switchNode);
      final lamp = _twoTerminal('lamp');
      final ground = EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground', ports: const [Port(id: 'gnd', name: 'gnd')]);
      return EngineeringGraph(id: 'g', nodes: {
        'battery': battery, 'fuse': fuse, 'switch': sw, 'lamp': lamp, 'ground': ground,
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'fuse', 'in'),
        'w2': _wire('w2', 'fuse', 'out', 'switch', 'in'),
        'w3': _wire('w3', 'switch', 'out', 'lamp', 'in'),
        'w4': _wire('w4', 'lamp', 'out', 'ground', 'gnd'),
      });
    }

    test('B: with no component behavior supplied at all, the engine never fabricates internal bridging '
        '(the conservative PRODUCT-READINESS-002 default) -- physical trace correctly stops at the first '
        'unmodeled inline component (the switch) rather than assuming it passes through', () {
      final graph = buildGraph();
      final result = engine.trace(graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.physical);
      expect(result.componentIds, contains('switch'), reason: 'reached via the plain wire to the switch\'s own terminal');
      expect(result.componentIds, isNot(contains('fuse')),
          reason: 'crossing the switch itself (in<->out) requires a real behavior -- never fabricated');
    });

    test('B: with real behaviors supplied for both inline components, physical AND conducting (closed) '
        'both reach the battery/lamp/ground', () {
      final engineWithBehavior = TraceEngine(behaviorResolver: (node) {
        if (node.id == 'switch') return const _TestSwitchBehavior('switch');
        if (node.id == 'fuse') return const _TestInlinePassThroughBehavior('fuse');
        return null;
      });
      final graph = buildGraph();

      final physical = engineWithBehavior.trace(graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.physical);
      expect(physical.componentIds, containsAll(['battery', 'fuse', 'switch', 'lamp', 'ground']));

      final closedContext = ElectricalOperatingContext(activeInputStates: const {'switch': true});
      final plus = ProbePoint(nodeId: 'battery', portId: 'plus');
      final fuseIn = ProbePoint(nodeId: 'fuse', portId: 'in');
      final fuseOut = ProbePoint(nodeId: 'fuse', portId: 'out');
      final swIn = ProbePoint(nodeId: 'switch', portId: 'in');
      final swOut = ProbePoint(nodeId: 'switch', portId: 'out');
      final lampIn = ProbePoint(nodeId: 'lamp', portId: 'in');
      final lampOut = ProbePoint(nodeId: 'lamp', portId: 'out');
      final gnd = ProbePoint(nodeId: 'ground', portId: 'gnd');
      ElectricalBranchState conductingWire(String id, ProbePoint from, ProbePoint to) => ElectricalBranchState(
            branchId: id, sourceTerminal: from, destinationTerminal: to,
            voltage: ElectricalReading.valid(12.6, unit: 'V'), voltageDrop: ElectricalReading.unsupported(),
            current: ElectricalReading.unsupported(), resistance: ElectricalReading.unsupported(),
            power: ElectricalReading.unsupported(), conductingState: ElectricalConductingState.conducting,
            currentDirection: ElectricalCurrentDirection.unknown, relationshipId: id,
          );
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: {
          plus: ElectricalTerminalState(terminal: plus, voltage: ElectricalReading.valid(12.6, unit: 'V'), current: ElectricalReading.unsupported(), isSourceTerminal: true),
        },
        branchStates: {
          'w1': conductingWire('w1', plus, fuseIn),
          'w2': conductingWire('w2', fuseOut, swIn),
          'w3': conductingWire('w3', swOut, lampIn),
          'w4': conductingWire('w4', lampOut, gnd),
        },
      );

      final conducting = engineWithBehavior.trace(
        graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.conducting,
        solvedState: solved, operatingContext: closedContext,
      );
      final fullyConductingPaths = conducting.paths.where((p) => p.conductingState == ElectricalConductingState.conducting);
      expect(fullyConductingPaths, isNotEmpty);
      expect(fullyConductingPaths.first.endTerminal, anyOf(gnd, plus));
    });

    test('C: same circuit with the switch OPEN — physical complete, conducting BLOCKED at the switch', () {
      final engineWithBehavior = TraceEngine(behaviorResolver: (node) {
        if (node.id == 'switch') return const _TestSwitchBehavior('switch');
        if (node.id == 'fuse') return const _TestInlinePassThroughBehavior('fuse');
        return null;
      });
      final graph = buildGraph();
      final openContext = ElectricalOperatingContext(activeInputStates: const {'switch': false});

      final plus = ProbePoint(nodeId: 'battery', portId: 'plus');
      final fuseIn = ProbePoint(nodeId: 'fuse', portId: 'in');
      final fuseOut = ProbePoint(nodeId: 'fuse', portId: 'out');
      final swIn = ProbePoint(nodeId: 'switch', portId: 'in');
      ElectricalBranchState conductingWire(String id, ProbePoint from, ProbePoint to) => ElectricalBranchState(
            branchId: id, sourceTerminal: from, destinationTerminal: to,
            voltage: ElectricalReading.valid(12.6, unit: 'V'), voltageDrop: ElectricalReading.unsupported(),
            current: ElectricalReading.unsupported(), resistance: ElectricalReading.unsupported(),
            power: ElectricalReading.unsupported(), conductingState: ElectricalConductingState.conducting,
            currentDirection: ElectricalCurrentDirection.unknown, relationshipId: id,
          );
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: const {},
        branchStates: {
          'w1': conductingWire('w1', plus, fuseIn),
          'w2': conductingWire('w2', fuseOut, swIn),
        },
      );

      final physical = engineWithBehavior.trace(graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.physical);
      expect(physical.componentIds, contains('lamp'), reason: 'physical topology is unaffected by switch state');

      final conducting = engineWithBehavior.trace(
        graph: graph, target: TraceTarget.component('lamp'), mode: TraceMode.conducting,
        solvedState: solved, operatingContext: openContext,
      );
      final blocked = conducting.paths.where((p) => p.conductingState == ElectricalConductingState.open);
      expect(blocked, isNotEmpty);
      final blockedPath = blocked.first;
      expect(blockedPath.blockingStep, isNotNull);
      expect(blockedPath.blockingStep!.terminal.nodeId, 'switch', reason: '§17: the blocking element should be identifiable');
      expect(conducting.diagnostics.map((d) => d.code), contains(TraceDiagnosticCode.noConductingPath));
    });
  });
}
