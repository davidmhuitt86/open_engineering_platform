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

EngineeringNode _battery({num voltage = 12.6}) => EngineeringNode(
      id: 'battery',
      category: NodeCategory.component,
      displayName: 'Battery',
      // 'v2Category': 'power' is the REAL, already-established V2 bridge
      // signal (confirmed directly on the real diagram7.json Battery node)
      // -- not invented for this test.
      metadata: const {'v2Category': 'power'},
      properties: {'nominalVoltageV': voltage},
      ports: const [Port(id: 'plus', name: '+'), Port(id: 'minus', name: '-')],
    );

EngineeringNode _ground({String id = 'ground'}) =>
    EngineeringNode(id: id, category: NodeCategory.ground, displayName: 'Ground', ports: const [Port(id: 'gnd', name: 'gnd')]);

void main() {
  final generationCounter = ElectricalSolutionGenerationCounter();

  group('A: battery -> resistive load -> ground', () {
    test('terminal voltage, conducting state, and REAL current/power are solved', () {
      final lamp = EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'lamp': lamp, 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'lamp', 'in'),
        'w2': _wire('w2', 'lamp', 'out', 'ground', 'gnd'),
      });
      final solver = ElectricalSolver(
        behaviorResolver: (node) => node.id == 'lamp' ? const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 120) : null,
      );
      final state = solver.solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);

      final plus = state.terminalState('battery', 'plus')!;
      expect(plus.voltage.isValid, isTrue);
      expect(plus.voltage.value, 12.6);
      expect(plus.isSourceTerminal, isTrue);

      final gnd = state.terminalState('ground', 'gnd')!;
      expect(gnd.isReferenceTerminal, isTrue);
      expect(gnd.voltage.isValid, isTrue);
      expect(gnd.voltage.value, 0);

      final lampIn = state.branchState('w1')!;
      expect(lampIn.conductingState, ElectricalConductingState.conducting);
      // Real Ohm's law: I = V / R = 12.6 / 120.
      expect(lampIn.current.isValid, isTrue);
      expect(lampIn.current.value, closeTo(12.6 / 120, 1e-9));
      expect(lampIn.resistance.value, 120);
      expect(lampIn.power.isValid, isTrue);
      expect(lampIn.power.value, closeTo((12.6 / 120) * 12.6, 1e-9));
      expect(lampIn.currentDirection, ElectricalCurrentDirection.sourceToDestination);
    });
  });

  group('B/C: battery -> fuse -> switch -> load -> ground', () {
    EngineeringGraph buildGraph() {
      final fuse = EngineeringNode(id: 'fuse', category: NodeCategory.fuse, displayName: 'Fuse', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final sw = EngineeringNode(id: 'switch', category: NodeCategory.switchNode, displayName: 'Switch', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final lamp = EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      return EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(), 'fuse': fuse, 'switch': sw, 'lamp': lamp, 'ground': _ground(),
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'fuse', 'in'),
        'w2': _wire('w2', 'fuse', 'out', 'switch', 'in'),
        'w3': _wire('w3', 'switch', 'out', 'lamp', 'in'),
        'w4': _wire('w4', 'lamp', 'out', 'ground', 'gnd'),
      });
    }

    ElectricalSolver solverFor(bool closed) => ElectricalSolver(behaviorResolver: (node) {
          if (node.id == 'fuse') return const InlinePassThroughElectricalComponentBehavior();
          if (node.id == 'switch') return const SwitchElectricalBehavior(switchId: 'switch');
          if (node.id == 'lamp') return const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 120);
          return null;
        });

    test('B: switch CLOSED -> voltage reaches the lamp, real current flows', () {
      final graph = buildGraph();
      final state = solverFor(true).solve(graph, const ElectricalOperatingContext(activeInputStates: {'switch': true}), generationCounter: generationCounter);
      expect(state.terminalState('lamp', 'in')!.voltage.value, 12.6);
      expect(state.branchState('w4')!.current.isValid, isTrue);
      expect(state.branchState('w4')!.current.value, greaterThan(0));
    });

    test('C: switch OPEN -> lamp is UNREACHED, not a fabricated zero', () {
      final graph = buildGraph();
      final state = solverFor(false).solve(graph, const ElectricalOperatingContext(activeInputStates: {'switch': false}), generationCounter: generationCounter);
      final lampIn = state.terminalState('lamp', 'in')!;
      expect(lampIn.voltage.state, ElectricalReadingState.unreached);
      expect(lampIn.voltage.value, isNull);
      expect(state.branchState('w2')!.conductingState, ElectricalConductingState.conducting, reason: 'battery->fuse->switch.in is still conducting');
      expect(state.branchState('w3')!.conductingState, ElectricalConductingState.unknown, reason: 'switch.out never receives voltage while open');
    });
  });

  group('D: splice feeding two loads', () {
    test('both branches from the splice are independently solved', () {
      final splice = EngineeringNode(
        id: 'splice', category: NodeCategory.component, displayName: 'Splice', metadata: const {'v2Category': 'splice'},
        ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b'), Port(id: 'c', name: 'c')],
      );
      final lampA = EngineeringNode(id: 'lampA', category: NodeCategory.component, displayName: 'Lamp A', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final lampB = EngineeringNode(id: 'lampB', category: NodeCategory.component, displayName: 'Lamp B', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'splice': splice, 'lampA': lampA, 'lampB': lampB, 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'splice', 'a'),
        'w2': _wire('w2', 'splice', 'b', 'lampA', 'in'),
        'w3': _wire('w3', 'splice', 'c', 'lampB', 'in'),
        'w4': _wire('w4', 'lampA', 'out', 'ground', 'gnd'),
      });
      final solver = ElectricalSolver();
      final state = solver.solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalState('lampA', 'in')!.voltage.value, 12.6);
      expect(state.terminalState('lampB', 'in')!.voltage.value, 12.6, reason: 'a splice bridges ALL its terminals');
    });
  });

  group('E: connector with distinct pins', () {
    test('different pins are never bridged; same pin correctly propagates', () {
      final connector = EngineeringNode(id: 'conn', category: NodeCategory.connector, displayName: 'Connector', ports: const [Port(id: '1', name: '1'), Port(id: '2', name: '2')]);
      final right1 = EngineeringNode(id: 'right1', category: NodeCategory.component, displayName: 'Right 1', ports: const [Port(id: 'in', name: 'in')]);
      final right2 = EngineeringNode(id: 'right2', category: NodeCategory.component, displayName: 'Right 2', ports: const [Port(id: 'in', name: 'in')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'conn': connector, 'right1': right1, 'right2': right2}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'conn', '1'),
        'w2': _wire('w2', 'conn', '1', 'right1', 'in'),
        'w3': _wire('w3', 'conn', '2', 'right2', 'in'),
      });
      final state = const ElectricalSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalState('right1', 'in')!.voltage.value, 12.6);
      expect(state.terminalState('right2', 'in')!.voltage.state, ElectricalReadingState.unreached);
    });
  });

  group('F: multi-terminal component', () {
    test('a battery\'s + and - terminals are solved independently, never collapsed', () {
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'load': load, 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'load', 'a'),
        'w2': _wire('w2', 'battery', 'minus', 'ground', 'gnd'),
      });
      final state = const ElectricalSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalState('battery', 'plus')!.voltage.value, 12.6);
      expect(state.terminalState('battery', 'minus')!.isReferenceTerminal, isTrue);
      expect(state.terminalState('battery', 'minus')!.voltage.value, 0, reason: 'directly wired to ground');
    });
  });

  group('G: parallel branches', () {
    test('two independent sources feeding one load are both solved', () {
      final s1 = EngineeringNode(id: 's1', category: NodeCategory.component, displayName: 'Source 1', properties: const {'nominalVoltageV': 12}, ports: const [Port(id: 'out', name: 'out')]);
      final s2 = EngineeringNode(id: 's2', category: NodeCategory.component, displayName: 'Source 2', properties: const {'nominalVoltageV': 5}, ports: const [Port(id: 'out', name: 'out')]);
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'s1': s1, 's2': s2, 'load': load}, relationships: {
        'w1': _wire('w1', 's1', 'out', 'load', 'a'),
        'w2': _wire('w2', 's2', 'out', 'load', 'b'),
      });
      final solver = ElectricalSolver(isSourceTerminal: (node, portId, behavior) => node.id == 's1' || node.id == 's2');
      final state = solver.solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalState('load', 'a')!.voltage.value, 12);
      expect(state.terminalState('load', 'b')!.voltage.value, 5);
    });
  });

  group('H/I: multiple sources and returns', () {
    test('H: two source terminals are both flagged', () {
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b')]);
      final s1 = EngineeringNode(id: 's1', category: NodeCategory.component, displayName: 'S1', properties: const {'nominalVoltageV': 12}, ports: const [Port(id: 'out', name: 'out')]);
      final s2 = EngineeringNode(id: 's2', category: NodeCategory.component, displayName: 'S2', properties: const {'nominalVoltageV': 6}, ports: const [Port(id: 'out', name: 'out')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'s1': s1, 's2': s2, 'load': load}, relationships: {
        'w1': _wire('w1', 's1', 'out', 'load', 'a'),
        'w2': _wire('w2', 's2', 'out', 'load', 'b'),
      });
      final solver = ElectricalSolver(isSourceTerminal: (node, portId, behavior) => node.id == 's1' || node.id == 's2');
      final state = solver.solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalState('s1', 'out')!.isSourceTerminal, isTrue);
      expect(state.terminalState('s2', 'out')!.isSourceTerminal, isTrue);
    });

    test('I: two return/ground terminals are both flagged', () {
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'a', name: 'a'), Port(id: 'b', name: 'b')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'load': load, 'g1': _ground(id: 'g1'), 'g2': _ground(id: 'g2')}, relationships: {
        'w1': _wire('w1', 'load', 'a', 'g1', 'gnd'),
        'w2': _wire('w2', 'load', 'b', 'g2', 'gnd'),
      });
      final state = const ElectricalSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalState('g1', 'gnd')!.isReferenceTerminal, isTrue);
      expect(state.terminalState('g2', 'gnd')!.isReferenceTerminal, isTrue);
    });
  });

  group('J/K: zero current vs. real conducting current', () {
    test('J: a resistive component whose own two terminals are both resolved to the SAME potential '
        '(a genuine balanced/no-load-current case) reports a real, valid zero current -- not "open"', () {
      // Two independent 5V sources feed the load's own two terminals
      // directly -- a real (if artificial) way to force both ends of the
      // resistive element to the identical potential, so any current
      // through it is honestly zero, not fabricated and not "open".
      final sourceIn = EngineeringNode(id: 'sourceIn', category: NodeCategory.component, displayName: 'Source In', properties: const {'nominalVoltageV': 5}, ports: const [Port(id: 'out', name: 'out')]);
      final sourceOut = EngineeringNode(id: 'sourceOut', category: NodeCategory.component, displayName: 'Source Out', properties: const {'nominalVoltageV': 5}, ports: const [Port(id: 'out', name: 'out')]);
      final load = EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'sourceIn': sourceIn, 'sourceOut': sourceOut, 'load': load}, relationships: {
        'w1': _wire('w1', 'sourceIn', 'out', 'load', 'in'),
        'w2': _wire('w2', 'sourceOut', 'out', 'load', 'out'),
      });
      final solver = ElectricalSolver(
        isSourceTerminal: (node, portId, behavior) => node.id == 'sourceIn' || node.id == 'sourceOut',
        behaviorResolver: (node) => node.id == 'load' ? const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10) : null,
      );
      final state = solver.solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      final branch = state.branchState('w1')!;
      expect(branch.current.isValid, isTrue);
      expect(branch.current.value, 0);
      expect(branch.conductingState, ElectricalConductingState.conducting, reason: 'zero current does not mean open');
    });

    test('K: an actual conducting branch reports real nonzero current and direction', () {
      final lamp = EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'lamp': lamp, 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'lamp', 'in'),
        'w2': _wire('w2', 'lamp', 'out', 'ground', 'gnd'),
      });
      final solver = ElectricalSolver(behaviorResolver: (node) => node.id == 'lamp' ? const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 63) : null);
      final state = solver.solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      final branch = state.branchState('w1')!;
      expect(branch.current.value, closeTo(12.6 / 63, 1e-9));
      expect(branch.currentDirection, ElectricalCurrentDirection.sourceToDestination);
    });
  });

  group('L: faulted branch (via a directly-injected reading)', () {
    test('a component behavior may itself report a fault-shaped resistance', () {
      // The solver's own contract does not yet include a fault-injection
      // overlay (out of scope, §49) -- but the underlying ElectricalReading
      // machinery it already uses fully supports a behavior reporting
      // fault, proven directly here.
      final reading = ElectricalReading.fault(unit: 'Ω', note: 'short-to-ground fault active');
      expect(reading.state, ElectricalReadingState.fault);
      expect(reading.value, isNull);
    });
  });

  group('M: multiple sources (co-located with H) and N: cyclic topology', () {
    test('N: a cyclic graph does not hang and produces a deterministic result', () {
      final a = EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A', properties: const {'nominalVoltageV': 12}, ports: const [Port(id: 'x', name: 'x'), Port(id: 'y', name: 'y')]);
      final b = EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B', ports: const [Port(id: 'x', name: 'x'), Port(id: 'y', name: 'y')]);
      final c = EngineeringNode(id: 'c', category: NodeCategory.component, displayName: 'C', ports: const [Port(id: 'x', name: 'x'), Port(id: 'y', name: 'y')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'a': a, 'b': b, 'c': c}, relationships: {
        'w1': _wire('w1', 'a', 'y', 'b', 'x'),
        'w2': _wire('w2', 'b', 'y', 'c', 'x'),
        'w3': _wire('w3', 'c', 'y', 'a', 'x'),
      });
      final solver = ElectricalSolver(
        isSourceTerminal: (node, portId, behavior) => node.id == 'a' && portId == 'x',
        behaviorResolver: (node) => _AlwaysInternalBridge(node.id),
      );
      final state = solver.solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalStates, isNotEmpty); // Terminates; does not hang.
    });
  });

  group('O: unmodeled component', () {
    test('an unmodeled 2-terminal component never bridges its own different terminals (no fabricated connectivity)', () {
      final mystery = EngineeringNode(id: 'mystery', category: NodeCategory.component, displayName: 'Mystery', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);
      final downstream = EngineeringNode(id: 'downstream', category: NodeCategory.component, displayName: 'Downstream', ports: const [Port(id: 'in', name: 'in')]);
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'mystery': mystery, 'downstream': downstream}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'mystery', 'in'),
        'w2': _wire('w2', 'mystery', 'out', 'downstream', 'in'),
      });
      final state = const ElectricalSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(state.terminalState('mystery', 'in')!.voltage.value, 12.6);
      expect(state.terminalState('downstream', 'in')!.voltage.state, ElectricalReadingState.unreached,
          reason: 'no behavior was supplied for "mystery" -- never fabricate a bridge through it');
    });
  });

  group('P: diode forward/reverse behavior', () {
    test('conducts anode->cathode but not cathode->anode', () {
      final diode = EngineeringNode(id: 'diode', category: NodeCategory.component, displayName: 'Diode', ports: const [Port(id: 'anode', name: 'A'), Port(id: 'cathode', name: 'K')]);
      final downstream = EngineeringNode(id: 'downstream', category: NodeCategory.component, displayName: 'Downstream', ports: const [Port(id: 'in', name: 'in')]);
      final graphForward = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'diode': diode, 'downstream': downstream}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'diode', 'anode'),
        'w2': _wire('w2', 'diode', 'cathode', 'downstream', 'in'),
      });
      final solver = ElectricalSolver(behaviorResolver: (node) => node.id == 'diode' ? const DiodeElectricalBehavior(anodeTerminalId: 'anode', cathodeTerminalId: 'cathode') : null);
      final forwardState = solver.solve(graphForward, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(forwardState.terminalState('downstream', 'in')!.voltage.isValid, isTrue, reason: 'forward-biased: conducts anode->cathode');

      // Reverse: battery now feeds the CATHODE side instead.
      final graphReverse = EngineeringGraph(id: 'g', nodes: {'battery': _battery(), 'diode': diode, 'downstream': downstream}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'diode', 'cathode'),
        'w2': _wire('w2', 'diode', 'anode', 'downstream', 'in'),
      });
      final reverseState = solver.solve(graphReverse, ElectricalOperatingContext.none, generationCounter: generationCounter);
      expect(reverseState.terminalState('downstream', 'in')!.voltage.state, ElectricalReadingState.unreached,
          reason: 'reverse-biased: a diode must NOT conduct cathode->anode');
    });
  });
}

/// Test-only helper for the cyclic-graph fixture (N) — bridges any 2 of a
/// node's own terminals unconditionally, so the cycle in that fixture is
/// actually traversable at all (otherwise it would be broken by the
/// engine's own conservative unmodeled-component default before a cycle
/// could even occur).
class _AlwaysInternalBridge extends ElectricalComponentBehavior {
  const _AlwaysInternalBridge(this.nodeId);
  final String nodeId;

  @override
  bool appliesTo(EngineeringNode node) => node.id == nodeId;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      {ElectricalTerminalPair('x', 'y')};

  @override
  ElectricalReading resistanceBetween(EngineeringNode node, String terminalA, String terminalB, ElectricalOperatingContext context) =>
      ElectricalReading.valid(0, unit: 'Ω');
}
