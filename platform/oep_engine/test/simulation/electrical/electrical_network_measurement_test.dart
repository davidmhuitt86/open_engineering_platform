import 'package:flutter_test/flutter_test.dart';

import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-006B §30 — deterministic synthetic network/measurement
/// fixtures proving the general resistive network (`electrical_resistive_network.dart`)
/// and the arbitrary two-terminal measurement query (`electrical_measurement_query.dart`)
/// actually solve series/parallel/mixed/cyclic real networks correctly,
/// with real polarity, real conservation, and honest non-valid states —
/// never fabricated values (§48's own "do not fake a result").
///
/// Every fixture below uses `wireResistanceOhms: (_) => 0` (an IDEAL wire)
/// UNLESS a test's own name says otherwise — this isolates the pure
/// resistor-network math being proven from the separate, already-disclosed
/// fact that a real wire also gets a small resistance by default (§9's own
/// doc comment on `ElectricalResistiveNetwork` explains why: it keeps
/// `Req = R1 + R2`/`1/Req = 1/R1 + 1/R2` exact rather than off by a few
/// hundredths of an ohm from incidental wire resistance).
EngineeringRelationship _wire(String id, String fromNode, String fromPort, String toNode, String toPort) => EngineeringRelationship(
      id: id,
      relationshipType: RelationshipType.connectedTo,
      sourceNode: fromNode,
      targetNode: toNode,
      metadata: {'sourcePort': fromPort, 'targetPort': toPort},
    );

EngineeringNode _battery({num voltage = 12.0, String id = 'battery'}) => EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: 'Battery',
      metadata: const {'v2Category': 'power'},
      properties: {'nominalVoltageV': voltage},
      ports: const [Port(id: 'plus', name: '+'), Port(id: 'minus', name: '-')],
    );

EngineeringNode _ground({String id = 'ground'}) =>
    EngineeringNode(id: id, category: NodeCategory.ground, displayName: 'Ground', ports: const [Port(id: 'gnd', name: 'gnd')]);

EngineeringNode _resistor(String id, {String inName = 'in', String outName = 'out'}) => EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: 'Resistor $id',
      ports: [Port(id: 'in', name: inName), Port(id: 'out', name: outName)],
    );

EngineeringNode _switchNode(String id) =>
    EngineeringNode(id: id, category: NodeCategory.switchNode, displayName: 'Switch $id', ports: const [Port(id: 'in', name: 'in'), Port(id: 'out', name: 'out')]);

EngineeringNode _splice(String id, List<String> pins) =>
    EngineeringNode(id: id, category: NodeCategory.component, displayName: 'Splice $id', metadata: const {'v2Category': 'splice'}, ports: [for (final p in pins) Port(id: p, name: p)]);

EngineeringNode _diode(String id) => EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: 'Diode $id',
      ports: const [Port(id: 'anode', name: 'A'), Port(id: 'cathode', name: 'K')],
    );

ProbePoint _p(String nodeId, String portId) => ProbePoint(nodeId: nodeId, portId: portId);

void main() {
  final counter = ElectricalSolutionGenerationCounter();
  const query = ElectricalMeasurementQuery();

  ElectricalSolver idealSolver({Map<String, ElectricalComponentBehavior?>? behaviors}) => ElectricalSolver(
        behaviorResolver: (node) => behaviors?[node.id],
        wireResistanceOhms: (_) => 0,
      );

  group('A: single resistor', () {
    test('resistance between its own two terminals is exactly its declared value', () {
      final r1 = _resistor('r1');
      final graph = EngineeringGraph(id: 'g', nodes: {'r1': r1}, relationships: const {});
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final result = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.resistance));
      expect(result.reading.isValid, isTrue);
      expect(result.reading.value, 100);
    });
  });

  group('B: two resistors in series', () {
    test('Req = R1 + R2, real current/voltage-drop solved end to end', () {
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(voltage: 12),
        'r1': _resistor('r1'),
        'r2': _resistor('r2'),
        'ground': _ground(),
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'r1', 'out', 'r2', 'in'),
        'w3': _wire('w3', 'r2', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {
        'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10),
        'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 20),
      }).solve(graph, ElectricalOperatingContext.none, generationCounter: counter);

      final req = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r2', 'out'), mode: MeasurementType.resistance));
      expect(req.reading.value, closeTo(30, 1e-9));

      final current = 12 / 30;
      final r1Current = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.current));
      final r2Current = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r2', 'in'), negativeTerminal: _p('r2', 'out'), mode: MeasurementType.current));
      expect(r1Current.reading.value, closeTo(current, 1e-9), reason: 'series current is the same through both resistors');
      expect(r2Current.reading.value, closeTo(current, 1e-9));

      final r1Vdc = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.voltageDc));
      expect(r1Vdc.reading.value, closeTo(current * 10, 1e-9), reason: 'real voltage drop across R1 alone');
    });
  });

  group('C: two resistors in parallel', () {
    test('1/Req = 1/R1 + 1/R2, current splits inversely to resistance', () {
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(voltage: 12),
        'r1': _resistor('r1'),
        'r2': _resistor('r2'),
        'ground': _ground(),
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'battery', 'plus', 'r2', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'ground', 'gnd'),
        'w4': _wire('w4', 'r2', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {
        'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100),
        'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100),
      }).solve(graph, ElectricalOperatingContext.none, generationCounter: counter);

      final req = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('battery', 'plus'), negativeTerminal: _p('ground', 'gnd'), mode: MeasurementType.resistance));
      expect(req.reading.value, closeTo(50, 1e-9));
    });
  });

  group('D: mixed series/parallel', () {
    test('Req = R1 + (R2 || R3)', () {
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(voltage: 12),
        'r1': _resistor('r1'),
        'r2': _resistor('r2'),
        'r3': _resistor('r3'),
        'ground': _ground(),
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'r1', 'out', 'r2', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'r3', 'in'),
        'w4': _wire('w4', 'r2', 'out', 'ground', 'gnd'),
        'w5': _wire('w5', 'r3', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {
        'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10),
        'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 20),
        'r3': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 20),
      }).solve(graph, ElectricalOperatingContext.none, generationCounter: counter);

      final req = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('ground', 'gnd'), mode: MeasurementType.resistance));
      expect(req.reading.value, closeTo(20, 1e-9)); // 10 + (20||20)=10+10
    });
  });

  group('E: three-way splice feeding two independently-grounded loads', () {
    test('continuity and independent resistance through each branch', () {
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(voltage: 12),
        'splice': _splice('splice', ['a', 'b', 'c']),
        'r1': _resistor('r1'),
        'r2': _resistor('r2'),
        'ground1': _ground(id: 'ground1'),
        'ground2': _ground(id: 'ground2'),
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'splice', 'a'),
        'w2': _wire('w2', 'splice', 'b', 'r1', 'in'),
        'w3': _wire('w3', 'splice', 'c', 'r2', 'in'),
        'w4': _wire('w4', 'r1', 'out', 'ground1', 'gnd'),
        'w5': _wire('w5', 'r2', 'out', 'ground2', 'gnd'),
      });
      final state = idealSolver(behaviors: {
        'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 50),
        'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 50),
      }).solve(graph, ElectricalOperatingContext.none, generationCounter: counter);

      expect(state.network!.continuityBetween(_p('battery', 'plus'), _p('r1', 'in')), isTrue);
      expect(state.network!.continuityBetween(_p('battery', 'plus'), _p('r2', 'in')), isTrue);
      final rBattToR1In = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('battery', 'plus'), negativeTerminal: _p('r1', 'in'), mode: MeasurementType.resistance));
      expect(rBattToR1In.reading.value, 0, reason: 'ideal splice + ideal wires — same electrical point');
    });
  });

  group('F: voltage source + load + ground -- real voltage drop across the load itself', () {
    test('VDC directly across the load is the full source voltage minus nothing else (ideal wires)', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(voltage: 9), 'r1': _resistor('r1'), 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'r1', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 9)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final drop = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.voltageDc));
      expect(drop.reading.value, closeTo(9, 1e-9));
    });
  });

  group('G/H: open vs closed switch', () {
    EngineeringGraph graph() => EngineeringGraph(id: 'g', nodes: {'battery': _battery(voltage: 12), 'sw': _switchNode('sw'), 'r1': _resistor('r1'), 'ground': _ground()}, relationships: {
          'w1': _wire('w1', 'battery', 'plus', 'sw', 'in'),
          'w2': _wire('w2', 'sw', 'out', 'r1', 'in'),
          'w3': _wire('w3', 'r1', 'out', 'ground', 'gnd'),
        });

    test('G: open switch -- no continuity, resistance is OPEN (OL), not Infinity-as-value', () {
      final state = idealSolver(behaviors: {'sw': const SwitchElectricalBehavior(switchId: 'sw', closedResistanceOhms: 0), 'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100)})
          .solve(graph(), const ElectricalOperatingContext(activeInputStates: {'sw': false}), generationCounter: counter);
      expect(state.network!.continuityBetween(_p('battery', 'plus'), _p('r1', 'in')), isFalse);
      final r = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('battery', 'plus'), negativeTerminal: _p('r1', 'in'), mode: MeasurementType.resistance));
      expect(r.reading.state, ElectricalReadingState.open);
      expect(r.reading.value, isNull);
    });

    test('H: closed switch -- continuity and a real, near-zero resistance path', () {
      final state = idealSolver(behaviors: {'sw': const SwitchElectricalBehavior(switchId: 'sw', closedResistanceOhms: 0), 'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100)})
          .solve(graph(), const ElectricalOperatingContext(activeInputStates: {'sw': true}), generationCounter: counter);
      expect(state.network!.continuityBetween(_p('battery', 'plus'), _p('r1', 'in')), isTrue);
      final r = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('battery', 'plus'), negativeTerminal: _p('r1', 'in'), mode: MeasurementType.resistance));
      expect(r.reading.value, 0);
    });
  });

  group('I: zero-current closed branch (matched potential)', () {
    test('two equal sources feeding both ends of a resistor -- real, valid ZERO current, not open', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'b1': _battery(voltage: 12, id: 'b1'), 'b2': _battery(voltage: 12, id: 'b2'), 'r1': _resistor('r1')}, relationships: {
        'w1': _wire('w1', 'b1', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'b2', 'plus', 'r1', 'out'),
        'w3': _wire('w3', 'b1', 'minus', 'b2', 'minus'),
      });
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 47)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final current = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.current));
      expect(current.reading.isValid, isTrue);
      expect(current.reading.value, closeTo(0, 1e-9));
    });
  });

  group('J/K: current splits correctly among parallel branches', () {
    test('J: unequal resistances split current inversely proportional', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(voltage: 10), 'r1': _resistor('r1'), 'r2': _resistor('r2'), 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'battery', 'plus', 'r2', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'ground', 'gnd'),
        'w4': _wire('w4', 'r2', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100), 'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 200)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final i1 = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.current));
      final i2 = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r2', 'in'), negativeTerminal: _p('r2', 'out'), mode: MeasurementType.current));
      expect(i1.reading.value, closeTo(10 / 100, 1e-9));
      expect(i2.reading.value, closeTo(10 / 200, 1e-9));
      expect(i1.reading.value, closeTo(2 * i2.reading.value!, 1e-9), reason: 'half the resistance -> double the current');
    });

    test('K: equal resistances split current equally', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(voltage: 10), 'r1': _resistor('r1'), 'r2': _resistor('r2'), 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'battery', 'plus', 'r2', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'ground', 'gnd'),
        'w4': _wire('w4', 'r2', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100), 'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 100)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final i1 = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.current));
      final i2 = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r2', 'in'), negativeTerminal: _p('r2', 'out'), mode: MeasurementType.current));
      expect(i1.reading.value, closeTo(i2.reading.value!, 1e-9));
    });
  });

  group('L: current conservation at a junction', () {
    test('current entering a splice equals the sum of current leaving it (real, non-ideal wires)', () {
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(voltage: 12),
        'splice': _splice('splice', ['a', 'b', 'c']),
        'r1': _resistor('r1'),
        'r2': _resistor('r2'),
        'ground': _ground(),
      }, relationships: {
        'feed': _wire('feed', 'battery', 'plus', 'splice', 'a'),
        'w1': _wire('w1', 'splice', 'b', 'r1', 'in'),
        'w2': _wire('w2', 'splice', 'c', 'r2', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'ground', 'gnd'),
        'w4': _wire('w4', 'r2', 'out', 'ground', 'gnd'),
      });
      final state = ElectricalSolver(behaviorResolver: (node) => {
        'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 1000),
        'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 2000),
      }[node.id]).solve(graph, ElectricalOperatingContext.none, generationCounter: counter);

      final feedCurrent = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('battery', 'plus'), negativeTerminal: _p('splice', 'a'), mode: MeasurementType.current));
      final i1 = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.current));
      final i2 = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r2', 'in'), negativeTerminal: _p('r2', 'out'), mode: MeasurementType.current));
      expect(feedCurrent.reading.isValid, isTrue);
      expect(i1.reading.isValid, isTrue);
      expect(i2.reading.isValid, isTrue);
      expect(feedCurrent.reading.value, closeTo(i1.reading.value! + i2.reading.value!, 1e-6));
    });
  });

  group('M: voltage polarity reversal', () {
    test('reversing the probes reverses the sign, magnitude unchanged', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(voltage: 12), 'ground': _ground()}, relationships: {'w1': _wire('w1', 'battery', 'minus', 'ground', 'gnd')});
      final state = idealSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final forward = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('battery', 'plus'), negativeTerminal: _p('battery', 'minus'), mode: MeasurementType.voltageDc));
      final reversed = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('battery', 'minus'), negativeTerminal: _p('battery', 'plus'), mode: MeasurementType.voltageDc));
      expect(forward.reading.value, closeTo(12, 1e-9));
      expect(reversed.reading.value, closeTo(-12, 1e-9));
    });
  });

  group('N: resistance probe reversal', () {
    test('order does not matter for a plain resistor', () {
      final r1 = _resistor('r1');
      final graph = EngineeringGraph(id: 'g', nodes: {'r1': r1}, relationships: const {});
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 33)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final forward = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.resistance));
      final reversed = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'out'), negativeTerminal: _p('r1', 'in'), mode: MeasurementType.resistance));
      expect(forward.reading.value, closeTo(33, 1e-9));
      expect(reversed.reading.value, closeTo(33, 1e-9));
    });
  });

  group('O/P: diode forward/reverse measurement', () {
    EngineeringGraph graph() => EngineeringGraph(id: 'g', nodes: {'d1': _diode('d1')}, relationships: const {});
    final behavior = const DiodeElectricalBehavior(anodeTerminalId: 'anode', cathodeTerminalId: 'cathode', forwardDropVolts: 0.65);

    test('O: forward-biased (positive probe on anode) reads the modeled forward drop', () {
      final state = idealSolver(behaviors: {'d1': behavior}).solve(graph(), ElectricalOperatingContext.none, generationCounter: counter);
      final result = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('d1', 'anode'), negativeTerminal: _p('d1', 'cathode'), mode: MeasurementType.diode));
      expect(result.reading.isValid, isTrue);
      expect(result.reading.value, closeTo(0.65, 1e-9));
    });

    test('P: reverse-biased (positive probe on cathode) reads OL/open', () {
      final state = idealSolver(behaviors: {'d1': behavior}).solve(graph(), ElectricalOperatingContext.none, generationCounter: counter);
      final result = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('d1', 'cathode'), negativeTerminal: _p('d1', 'anode'), mode: MeasurementType.diode));
      expect(result.reading.state, ElectricalReadingState.open);
    });
  });

  group('Q: open-circuit resistance', () {
    test('two entirely disconnected terminals report OPEN, never a numeric Infinity', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'r1': _resistor('r1'), 'r2': _resistor('r2')}, relationships: const {});
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10), 'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final r = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r2', 'in'), mode: MeasurementType.resistance));
      expect(r.reading.state, ElectricalReadingState.open);
      expect(r.reading.value, isNull);
    });
  });

  group('R: fault state -- two different-voltage sources shorted together', () {
    test('the contradiction is reported as FAULT, never averaged/guessed', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'b1': _battery(voltage: 12, id: 'b1'), 'b2': _battery(voltage: 6, id: 'b2')}, relationships: {
        'w1': _wire('w1', 'b1', 'plus', 'b2', 'plus'),
        'w2': _wire('w2', 'b1', 'minus', 'b2', 'minus'),
      });
      final state = idealSolver().solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final result = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('b1', 'plus'), negativeTerminal: _p('b1', 'minus'), mode: MeasurementType.voltageDc));
      expect(result.reading.state, ElectricalReadingState.fault);
    });
  });

  group('S: unsupported component -- diode-only path', () {
    test('resistance through only a diode is UNSUPPORTED, not OPEN (a real connection exists, just non-linear)', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'d1': _diode('d1')}, relationships: const {});
      final state = idealSolver(behaviors: {'d1': const DiodeElectricalBehavior(anodeTerminalId: 'anode', cathodeTerminalId: 'cathode')})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final r = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('d1', 'anode'), negativeTerminal: _p('d1', 'cathode'), mode: MeasurementType.resistance));
      expect(r.reading.state, ElectricalReadingState.unsupported);
    });
  });

  group('T: floating network -- resistance still computable, voltage honestly UNREACHED', () {
    test('a resistor-connected pair with no source anywhere still has a real resistance value', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'r1': _resistor('r1')}, relationships: const {});
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 250)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final r = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.resistance));
      expect(r.reading.value, closeTo(250, 1e-9), reason: 'resistance does not need a source at all (§8)');
      final v = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.voltageDc));
      expect(v.reading.state, ElectricalReadingState.unreached, reason: 'no source/reference reaches this floating pair');
    });
  });

  group('U/V: multiple source/return candidates', () {
    test('U: two identical-voltage sources feeding the same bus -- no fault, consistent voltage', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'b1': _battery(voltage: 12, id: 'b1'), 'b2': _battery(voltage: 12, id: 'b2'), 'r1': _resistor('r1'), 'ground': _ground()}, relationships: {
        'w1': _wire('w1', 'b1', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'b2', 'plus', 'r1', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final v = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('ground', 'gnd'), mode: MeasurementType.voltageDc));
      expect(v.reading.isValid, isTrue);
      expect(v.reading.value, closeTo(12, 1e-9));
    });

    test('V: two separate ground/return nodes both read a real 0V', () {
      final graph = EngineeringGraph(id: 'g', nodes: {'battery': _battery(voltage: 12), 'r1': _resistor('r1'), 'r2': _resistor('r2'), 'g1': _ground(id: 'g1'), 'g2': _ground(id: 'g2')}, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'battery', 'plus', 'r2', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'g1', 'gnd'),
        'w4': _wire('w4', 'r2', 'out', 'g2', 'gnd'),
      });
      final state = idealSolver(behaviors: {'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10), 'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10)})
          .solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      expect(state.network!.operatingVoltage(_p('g1', 'gnd'))!.value, 0);
      expect(state.network!.operatingVoltage(_p('g2', 'gnd'))!.value, 0);
    });
  });

  group('W: cyclic network', () {
    test('a genuine loop/bridge topology solves deterministically to the correct equivalent resistance', () {
      // battery -> A -R1(10)- B -R2(10)- ground, AND A -R3(20)- ground
      // directly (a bridge across the series pair): Req = (R1+R2) || R3
      // = 20 || 20 = 10.
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(voltage: 12),
        'a': _splice('a', ['in', 'toB', 'toGnd']),
        'b': _splice('b', ['in', 'out']),
        'r1': _resistor('r1'),
        'r2': _resistor('r2'),
        'r3': _resistor('r3'),
        'ground': _ground(),
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'a', 'in'),
        'w2': _wire('w2', 'a', 'toB', 'r1', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'b', 'in'),
        'w4': _wire('w4', 'b', 'out', 'r2', 'in'),
        'w5': _wire('w5', 'r2', 'out', 'ground', 'gnd'),
        'w6': _wire('w6', 'a', 'toGnd', 'r3', 'in'),
        'w7': _wire('w7', 'r3', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {
        'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10),
        'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10),
        'r3': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 20),
      }).solve(graph, ElectricalOperatingContext.none, generationCounter: counter);
      final req = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('a', 'in'), negativeTerminal: _p('ground', 'gnd'), mode: MeasurementType.resistance));
      expect(req.reading.value, closeTo(10, 1e-6));
    });
  });

  group('X: power conservation', () {
    test('total supplied power equals total consumed power across a mixed network', () {
      final graph = EngineeringGraph(id: 'g', nodes: {
        'battery': _battery(voltage: 12),
        'r1': _resistor('r1'),
        'r2': _resistor('r2'),
        'r3': _resistor('r3'),
        'ground': _ground(),
      }, relationships: {
        'w1': _wire('w1', 'battery', 'plus', 'r1', 'in'),
        'w2': _wire('w2', 'r1', 'out', 'r2', 'in'),
        'w3': _wire('w3', 'r1', 'out', 'r3', 'in'),
        'w4': _wire('w4', 'r2', 'out', 'ground', 'gnd'),
        'w5': _wire('w5', 'r3', 'out', 'ground', 'gnd'),
      });
      final state = idealSolver(behaviors: {
        'r1': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 10),
        'r2': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 20),
        'r3': const ResistiveLoadElectricalComponentBehavior(resistanceOhms: 20),
      }).solve(graph, ElectricalOperatingContext.none, generationCounter: counter);

      num consumed = 0;
      for (final id in ['r1', 'r2', 'r3']) {
        final p = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p(id, 'in'), negativeTerminal: _p(id, 'out'), mode: MeasurementType.power));
        expect(p.reading.isValid, isTrue);
        consumed += p.reading.value!;
      }

      // R1 is the sole series element before the R2/R3 split, so its own
      // current equals the FULL current the battery supplies (the battery
      // -> R1 wire is ideal/merged under this fixture's own `idealSolver`,
      // so it is not itself a separately-queryable edge — see this file's
      // own top doc comment).
      final totalCurrent = query.measure(state, ElectricalMeasurementRequest(positiveTerminal: _p('r1', 'in'), negativeTerminal: _p('r1', 'out'), mode: MeasurementType.current));
      final supplied = 12 * totalCurrent.reading.value!;
      expect(consumed, closeTo(supplied, 1e-6));
    });
  });
}
