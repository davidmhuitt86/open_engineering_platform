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

ElectricalBranchState _conductingWire(String id, ProbePoint from, ProbePoint to, {ElectricalReading? current, ElectricalCurrentDirection direction = ElectricalCurrentDirection.unknown, ElectricalConductingState state = ElectricalConductingState.conducting}) {
  return ElectricalBranchState(
    branchId: id, sourceTerminal: from, destinationTerminal: to,
    voltage: ElectricalReading.valid(12.6, unit: 'V'), voltageDrop: ElectricalReading.unsupported(),
    current: current ?? ElectricalReading.unsupported(), resistance: ElectricalReading.unsupported(),
    power: ElectricalReading.unsupported(), conductingState: state, currentDirection: direction, relationshipId: id,
  );
}

void main() {
  const engine = TraceEngine();

  group('D: splice with two branches', () {
    test('tracing through the splice preserves both branches, not a flattened single wire', () {
      final source = EngineeringNode(id: 'source', category: NodeCategory.component, displayName: 'Source', ports: const [Port(id: 'out', name: 'out')]);
      final splice = EngineeringNode(
        id: 'splice', category: NodeCategory.component, displayName: 'Splice',
        metadata: const {'v2Category': 'splice'},
        ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b'), Port(id: 'c', name: 'c')],
      );
      final lamp = EngineeringNode(id: 'lampA', category: NodeCategory.component, displayName: 'Lamp A', ports: const [Port(id: 'in', name: 'in')]);
      final relay = EngineeringNode(id: 'relayB', category: NodeCategory.relay, displayName: 'Relay B', ports: const [Port(id: 'in', name: 'in')]);

      final graph = EngineeringGraph(id: 'g', nodes: {
        'source': source, 'splice': splice, 'lampA': lamp, 'relayB': relay,
      }, relationships: {
        'w1': _wire('w1', 'source', 'out', 'splice', 'a'),
        'w2': _wire('w2', 'splice', 'b', 'lampA', 'in'),
        'w3': _wire('w3', 'splice', 'c', 'relayB', 'in'),
      });

      final result = engine.trace(graph: graph, target: TraceTarget.component('splice'), mode: TraceMode.physical);
      expect(result.componentIds, containsAll(['source', 'splice', 'lampA', 'relayB']),
          reason: 'a splice bridges ALL its terminals -- both branches must be reachable');
      expect(result.spliceComponentIds, contains('splice'));
      // Two distinct branches from the splice, not one flattened path.
      final branchEndpoints = result.paths.map((p) => p.endTerminal.nodeId).toSet();
      expect(branchEndpoints, containsAll(['lampA', 'relayB', 'source']));
    });
  });

  group('E: connector with distinct pins', () {
    test('two wires on DIFFERENT connector pins are never bridged; same pin correctly meets', () {
      final left = EngineeringNode(id: 'left', category: NodeCategory.component, displayName: 'Left', ports: const [Port(id: 'out', name: 'out')]);
      final connector = EngineeringNode(
        id: 'conn', category: NodeCategory.connector, displayName: 'Connector',
        ports: const [Port(id: '1', name: '1'), Port(id: '2', name: '2')],
      );
      final right1 = EngineeringNode(id: 'right1', category: NodeCategory.component, displayName: 'Right 1', ports: const [Port(id: 'in', name: 'in')]);
      final right2 = EngineeringNode(id: 'right2', category: NodeCategory.component, displayName: 'Right 2', ports: const [Port(id: 'in', name: 'in')]);

      final graph = EngineeringGraph(id: 'g', nodes: {
        'left': left, 'conn': connector, 'right1': right1, 'right2': right2,
      }, relationships: {
        'w1': _wire('w1', 'left', 'out', 'conn', '1'),
        'w2': _wire('w2', 'conn', '1', 'right1', 'in'), // same pin (1) as w1 -- should meet
        'w3': _wire('w3', 'conn', '2', 'right2', 'in'), // different pin (2) -- should NOT be reachable from left
      });

      final result = engine.trace(graph: graph, target: TraceTarget.component('left'), mode: TraceMode.physical);
      expect(result.componentIds, contains('right1'), reason: 'same physical pin (1) — must be reachable');
      expect(result.componentIds, isNot(contains('right2')), reason: 'different pin (2) — must NOT be reachable via the connector');
      expect(result.connectorComponentIds, contains('conn'));
    });
  });

  group('F: multiple-terminal component', () {
    test('a battery\'s two terminals are traced independently, never collapsed to one node value', () {
      final battery = EngineeringNode(
        id: 'battery', category: NodeCategory.component, displayName: 'Battery',
        ports: const [Port(id: 'plus', name: '+'), Port(id: 'minus', name: '-')],
      );
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a')]);
      final ground = EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground', ports: const [Port(id: 'gnd', name: 'gnd')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': battery, 'load': load, 'ground': ground}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'load', 'a'),
        'w2': _wire('w2', 'battery', 'minus', 'ground', 'gnd'),
      });

      final result = engine.trace(graph: graph, target: TraceTarget.component('battery'), mode: TraceMode.physical);
      final plusPaths = result.paths.where((p) => p.startTerminal.portId == 'plus');
      final minusPaths = result.paths.where((p) => p.startTerminal.portId == 'minus');
      expect(plusPaths, isNotEmpty);
      expect(minusPaths, isNotEmpty);
      expect(plusPaths.first.endTerminal.nodeId, 'load');
      expect(minusPaths.first.endTerminal.nodeId, 'ground');
    });
  });

  group('G: parallel paths', () {
    test('two independent feeds to the same load are both represented', () {
      final source1 = EngineeringNode(id: 'source1', category: NodeCategory.component, displayName: 'Source 1', ports: const [Port(id: 'out', name: 'out')]);
      final source2 = EngineeringNode(id: 'source2', category: NodeCategory.component, displayName: 'Source 2', ports: const [Port(id: 'out', name: 'out')]);
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'source1': source1, 'source2': source2, 'load': load}, relationships: {
        'w1': _wire('w1', 'source1', 'out', 'load', 'a'),
        'w2': _wire('w2', 'source2', 'out', 'load', 'b'),
      });

      final result = engine.trace(graph: graph, target: TraceTarget.component('load'), mode: TraceMode.physical);
      final startNodes = result.paths.map((p) => p.startTerminal.nodeId).toSet();
      expect(startNodes, {'load'});
      final endNodes = result.paths.map((p) => p.endTerminal.nodeId).toSet();
      expect(endNodes, containsAll(['source1', 'source2']), reason: 'both parallel feeds must be representable');
    });
  });

  group('H/I: multiple source and return candidates', () {
    test('H: two reachable terminals both marked as sources are both reported', () {
      final s1 = EngineeringNode(id: 's1', category: NodeCategory.component, displayName: 'Source 1', ports: const [Port(id: 'out', name: 'out')]);
      final s2 = EngineeringNode(id: 's2', category: NodeCategory.component, displayName: 'Source 2', ports: const [Port(id: 'out', name: 'out')]);
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'s1': s1, 's2': s2, 'load': load}, relationships: {
        'w1': _wire('w1', 's1', 'out', 'load', 'a'),
        'w2': _wire('w2', 's2', 'out', 'load', 'b'),
      });
      final s1out = ProbePoint(nodeId: 's1', portId: 'out');
      final s2out = ProbePoint(nodeId: 's2', portId: 'out');
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: {
          s1out: ElectricalTerminalState(terminal: s1out, voltage: ElectricalReading.valid(12, unit: 'V'), current: ElectricalReading.unsupported(), isSourceTerminal: true),
          s2out: ElectricalTerminalState(terminal: s2out, voltage: ElectricalReading.valid(5, unit: 'V'), current: ElectricalReading.unsupported(), isSourceTerminal: true),
        },
        branchStates: {'w1': _conductingWire('w1', s1out, ProbePoint(nodeId: 'load', portId: 'a')), 'w2': _conductingWire('w2', s2out, ProbePoint(nodeId: 'load', portId: 'b'))},
      );
      final result = engine.trace(graph: graph, target: TraceTarget.component('load'), mode: TraceMode.conducting, solvedState: solved);
      expect(result.sourceTerminals, {s1out, s2out});
      expect(result.hasMultipleSources, isTrue);
      expect(result.diagnostics.map((d) => d.code), contains(TraceDiagnosticCode.multipleSources));
    });

    test('I: two reachable terminals both marked as returns are both reported', () {
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b')]);
      final g1 = EngineeringNode(id: 'g1', category: NodeCategory.ground, displayName: 'Ground 1', ports: const [Port(id: 'gnd', name: 'gnd')]);
      final g2 = EngineeringNode(id: 'g2', category: NodeCategory.ground, displayName: 'Ground 2', ports: const [Port(id: 'gnd', name: 'gnd')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'load': load, 'g1': g1, 'g2': g2}, relationships: {
        'w1': _wire('w1', 'load', 'a', 'g1', 'gnd'),
        'w2': _wire('w2', 'load', 'b', 'g2', 'gnd'),
      });
      final g1t = ProbePoint(nodeId: 'g1', portId: 'gnd');
      final g2t = ProbePoint(nodeId: 'g2', portId: 'gnd');
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: {
          g1t: ElectricalTerminalState(terminal: g1t, voltage: ElectricalReading.valid(0, unit: 'V'), current: ElectricalReading.unsupported(), isReferenceTerminal: true),
          g2t: ElectricalTerminalState(terminal: g2t, voltage: ElectricalReading.valid(0, unit: 'V'), current: ElectricalReading.unsupported(), isReferenceTerminal: true),
        },
        branchStates: {'w1': _conductingWire('w1', ProbePoint(nodeId: 'load', portId: 'a'), g1t), 'w2': _conductingWire('w2', ProbePoint(nodeId: 'load', portId: 'b'), g2t)},
      );
      final result = engine.trace(graph: graph, target: TraceTarget.component('load'), mode: TraceMode.conducting, solvedState: solved);
      expect(result.returnTerminals, {g1t, g2t});
      expect(result.hasMultipleReturns, isTrue);
    });
  });

  group('J/K: zero current vs. actual current direction', () {
    test('J: a closed, conducting path with current=0 is valid and NOT reported as open', () {
      final a = EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A', ports: const [Port(id: 'out', name: 'out')]);
      final b = EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B', ports: const [Port(id: 'in', name: 'in')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'a': a, 'b': b}, relationships: {'w1': _wire('w1', 'a', 'out', 'b', 'in')});
      final aOut = ProbePoint(nodeId: 'a', portId: 'out');
      final bIn = ProbePoint(nodeId: 'b', portId: 'in');
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: const {},
        branchStates: {'w1': _conductingWire('w1', aOut, bIn, current: ElectricalReading.valid(0, unit: 'A'), direction: ElectricalCurrentDirection.none)},
      );
      final result = engine.trace(graph: graph, target: TraceTarget.component('a'), mode: TraceMode.currentFlow, solvedState: solved);
      final path = result.paths.firstWhere((p) => p.endTerminal.nodeId == 'b');
      expect(path.conductingState, ElectricalConductingState.conducting, reason: 'zero current does not mean open');
      expect(path.current?.isValid, isTrue);
      expect(path.current?.value, 0);
      expect(path.currentDirection, ElectricalCurrentDirection.none);
    });

    test('K: an actual conducting path reports real current and direction, oriented to traversal order', () {
      final a = EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A', ports: const [Port(id: 'out', name: 'out')]);
      final b = EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B', ports: const [Port(id: 'in', name: 'in')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'a': a, 'b': b}, relationships: {'w1': _wire('w1', 'a', 'out', 'b', 'in')});
      final aOut = ProbePoint(nodeId: 'a', portId: 'out');
      final bIn = ProbePoint(nodeId: 'b', portId: 'in');
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: const {},
        branchStates: {
          'w1': _conductingWire('w1', aOut, bIn, current: ElectricalReading.valid(2.5, unit: 'A'), direction: ElectricalCurrentDirection.sourceToDestination),
        },
      );
      final result = engine.trace(graph: graph, target: TraceTarget.component('a'), mode: TraceMode.currentFlow, solvedState: solved);
      final path = result.paths.firstWhere((p) => p.endTerminal.nodeId == 'b');
      expect(path.current?.value, 2.5);
      expect(path.currentDirection, ElectricalCurrentDirection.sourceToDestination,
          reason: 'traversal order (a -> b) matches the branch\'s own source->destination orientation');
      expect(result.diagnostics.map((d) => d.code), contains(TraceDiagnosticCode.currentFlowing));
    });
  });

  group('L: faulted path', () {
    test('a fault on the branch is surfaced distinctly, not as a plain open or a fabricated value', () {
      final a = EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A', ports: const [Port(id: 'out', name: 'out')]);
      final b = EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B', ports: const [Port(id: 'in', name: 'in')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'a': a, 'b': b}, relationships: {'w1': _wire('w1', 'a', 'out', 'b', 'in')});
      final aOut = ProbePoint(nodeId: 'a', portId: 'out');
      final bIn = ProbePoint(nodeId: 'b', portId: 'in');
      final solved = SolvedElectricalState(
        generation: ElectricalSolutionGeneration(sequence: 0, solvedAt: DateTime(2024)),
        terminalStates: const {},
        branchStates: {
          'w1': _conductingWire('w1', aOut, bIn, current: ElectricalReading.fault(note: 'short-to-ground fault active')),
        },
      );
      final result = engine.trace(graph: graph, target: TraceTarget.component('a'), mode: TraceMode.currentFlow, solvedState: solved);
      final path = result.paths.firstWhere((p) => p.endTerminal.nodeId == 'b');
      expect(path.current?.state, ElectricalReadingState.fault);
      expect(path.current?.value, isNull);
    });
  });

  group('N: cyclic graph', () {
    test('a cycle terminates the trace safely and is reported as a diagnostic, not an infinite loop', () {
      final a = EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A', ports: const [Port(id: 'x', name: 'x'), Port(id: 'y', name: 'y')]);
      final b = EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B', ports: const [Port(id: 'x', name: 'x'), Port(id: 'y', name: 'y')]);
      final c = EngineeringNode(id: 'c', category: NodeCategory.component, displayName: 'C', ports: const [Port(id: 'x', name: 'x'), Port(id: 'y', name: 'y')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'a': a, 'b': b, 'c': c}, relationships: {
        'w1': _wire('w1', 'a', 'y', 'b', 'x'),
        'w2': _wire('w2', 'b', 'y', 'c', 'x'),
        'w3': _wire('w3', 'c', 'y', 'a', 'x'), // closes the loop back to a
      });
      final withBehaviors = TraceEngine(behaviorResolver: (node) => _CycleBridge(node.id));

      // Must terminate at all (the test itself would hang/timeout otherwise).
      final result = withBehaviors.trace(graph: graph, target: TraceTarget.component('a'), mode: TraceMode.physical);
      expect(result.diagnostics.map((d) => d.code), contains(TraceDiagnosticCode.cycleDetected));
    });
  });
}

/// A component that internally bridges its own two terminals -- needed to
/// make the cycle in the "N" test actually traversable at all (otherwise
/// the loop is broken by the same conservative default proven in the B/C
/// tests, and there'd be no cycle to detect in the first place).
class _CycleBridge extends ElectricalComponentBehavior {
  const _CycleBridge(this.componentId);
  final String componentId;

  @override
  bool appliesTo(EngineeringNode node) => node.id == componentId;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      {ElectricalTerminalPair('x', 'y')};

  @override
  ElectricalReading resistanceBetween(
          EngineeringNode node, String terminalA, String terminalB, ElectricalOperatingContext context) =>
      ElectricalReading.valid(0, unit: 'Ω');
}
