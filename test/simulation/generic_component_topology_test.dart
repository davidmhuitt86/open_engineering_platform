import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// OEP Engineering Runtime -- Phase 13 (Generic Component Behavior &
/// Topology Switching): Part 29 Tests A-R. Proves that
/// [InputStateDefinition.topologyEffects] -- a plain, discrete
/// value -> blocked-relationship-set mapping, resolved by the same
/// unmodified [StateConditionResolver]/[SignalPropagator] -- is
/// sufficient to represent SPST, SPDT, and N-position switch behavior
/// with zero component-type-specific code anywhere in the engine
/// (no `if componentType == ...` exists in production code).
///
/// Fixture: a "GenericSwitch" component (Part 23) with three ports
/// (common/outputA/outputB) and two relationships (common->outputA,
/// common->outputB) -- purely generic naming, no automotive terms.
void main() {
  EngineeringGraph buildGraph() {
    return EngineeringGraph(
      id: 'g-topology-switching',
      nodes: {
        'source': const EngineeringNode(
          id: 'source',
          category: NodeCategory.component,
          displayName: 'Source',
          properties: {'expectedValue': 12.0, 'expectedUnit': 'V'},
        ),
        'genericSwitch': const EngineeringNode(
          id: 'genericSwitch',
          category: NodeCategory.component,
          displayName: 'Generic Switch',
          ports: [
            Port(id: 'common', name: 'Common', direction: PortDirection.input),
            Port(id: 'outputA', name: 'Output A', direction: PortDirection.output),
            Port(id: 'outputB', name: 'Output B', direction: PortDirection.output),
          ],
        ),
        'loadA': const EngineeringNode(
          id: 'loadA',
          category: NodeCategory.component,
          displayName: 'Load A',
          properties: {'expectedValue': 12.0, 'expectedUnit': 'V'},
        ),
        'loadB': const EngineeringNode(
          id: 'loadB',
          category: NodeCategory.component,
          displayName: 'Load B',
          properties: {'expectedValue': 12.0, 'expectedUnit': 'V'},
        ),
        // Two SEPARATE ground nodes, not one shared bus -- a single
        // shared ground node connected to both loads via `connectedTo`
        // would give the (correctly) undirected propagation BFS a real
        // backdoor path between loadA and loadB (source -> switch ->
        // loadB -> sharedGround -> loadA), defeating the switch's
        // blocking regardless of position. Real circuits avoid this by
        // design; this fixture must too, to isolate what this phase is
        // actually testing.
        'groundA': const EngineeringNode(id: 'groundA', category: NodeCategory.ground, displayName: 'Ground A'),
        'groundB': const EngineeringNode(id: 'groundB', category: NodeCategory.ground, displayName: 'Ground B'),
      },
      relationships: {
        'r_source_common': const EngineeringRelationship(
          id: 'r_source_common',
          relationshipType: RelationshipType.suppliesPower,
          sourceNode: 'source',
          targetNode: 'genericSwitch',
          metadata: {'targetPort': 'common'},
        ),
        'r_common_a': const EngineeringRelationship(
          id: 'r_common_a',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'genericSwitch',
          targetNode: 'loadA',
          metadata: {'sourcePort': 'outputA'},
        ),
        'r_common_b': const EngineeringRelationship(
          id: 'r_common_b',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'genericSwitch',
          targetNode: 'loadB',
          metadata: {'sourcePort': 'outputB'},
        ),
        'r_ground_a': const EngineeringRelationship(
          id: 'r_ground_a',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'groundA',
          targetNode: 'loadA',
        ),
        'r_ground_b': const EngineeringRelationship(
          id: 'r_ground_b',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'groundB',
          targetNode: 'loadB',
        ),
      },
    );
  }

  // SPST proof: a single relationship, a single boolean input -- the
  // Phase 10 mechanism, unchanged, retained under generic naming.
  const spstInput =
      InputStateDefinition(id: 'spst_input', label: 'SPST Input', targetRelationshipId: 'r_common_a');

  // SPDT proof: one discrete input, two positions, each blocking the
  // relationship the OTHER position uses -- authored entirely as data,
  // no engine-side "SPDT" concept.
  const spdtInput = InputStateDefinition(
    id: 'spdt_input',
    label: 'SPDT Input',
    valueType: InputValueType.discrete,
    topologyEffects: {
      'positionA': {'r_common_b'},
      'positionB': {'r_common_a'},
    },
  );

  group('Phase 13 -- Generic Component Behavior & Topology Switching', () {
    // --- Test A: Generic component definition -----------------------------------
    test('A: a component can define its relevant ports/relationships', () {
      final graph = buildGraph();
      final node = graph.nodes['genericSwitch']!;
      expect(node.ports.map((p) => p.id), ['common', 'outputA', 'outputB']);
      expect(graph.relationshipsForNode('genericSwitch').map((r) => r.id),
          containsAll(['r_source_common', 'r_common_a', 'r_common_b']));
    });

    // --- Test B/C: SPST OPEN / CLOSED --------------------------------------------
    test('B: SPST OPEN produces disconnected topology', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spstInput]);
      session.setInputState('spst_input', false);
      expect(session.state.isPowered('loadA'), isFalse);
    });

    test('C: SPST CLOSED produces connected topology', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spstInput]);
      expect(session.state.isPowered('loadA'), isTrue, reason: 'no input set yet -- unblocked baseline');
      session.setInputState('spst_input', true);
      expect(session.state.isPowered('loadA'), isTrue);
    });

    // --- Test D/E: SPDT POSITION A / POSITION B ------------------------------------
    test('D: SPDT POSITION A -- COM->A connected, COM->B disconnected', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA');
      expect(session.state.isPowered('loadA'), isTrue);
      expect(session.state.isPowered('loadB'), isFalse);
    });

    test('E: SPDT POSITION B -- COM->B connected, COM->A disconnected', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionB');
      expect(session.state.isPowered('loadB'), isTrue);
      expect(session.state.isPowered('loadA'), isFalse);
    });

    // --- Test F: Mutual exclusion --------------------------------------------------
    test('F: SPDT never connects both outputs simultaneously, in either position', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);

      session.setInputState('spdt_input', 'positionA');
      expect(session.state.isPowered('loadA') && session.state.isPowered('loadB'), isFalse);

      session.setInputState('spdt_input', 'positionB');
      expect(session.state.isPowered('loadA') && session.state.isPowered('loadB'), isFalse);
    });

    // --- Test G: DMM continuity --------------------------------------------------
    test('G: DMM continuity measurements follow topology state', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);

      session.setInputState('spdt_input', 'positionA');
      final toA = engine.measure(session.id,
          probeA: const ProbePoint(nodeId: 'source'), probeB: const ProbePoint(nodeId: 'loadA'), type: MeasurementType.continuity);
      final toB = engine.measure(session.id,
          probeA: const ProbePoint(nodeId: 'source'), probeB: const ProbePoint(nodeId: 'loadB'), type: MeasurementType.continuity);
      expect(toA.continuous, isTrue);
      expect(toB.continuous, isFalse);

      session.setInputState('spdt_input', 'positionB');
      final toA2 = engine.measure(session.id,
          probeA: const ProbePoint(nodeId: 'source'), probeB: const ProbePoint(nodeId: 'loadA'), type: MeasurementType.continuity);
      final toB2 = engine.measure(session.id,
          probeA: const ProbePoint(nodeId: 'source'), probeB: const ProbePoint(nodeId: 'loadB'), type: MeasurementType.continuity);
      expect(toA2.continuous, isFalse);
      expect(toB2.continuous, isTrue);
    });

    // --- Test H/I: Power / Ground propagation -----------------------------------
    test('H/I: power and ground propagation both follow topology state', () {
      const spdtGroundInput = InputStateDefinition(
        id: 'spdt_ground_input',
        label: 'SPDT Ground Input',
        topologyEffects: {
          'positionA': {'r_ground_b'},
          'positionB': {'r_ground_a'},
        },
      );
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput, spdtGroundInput]);

      session.setInputState('spdt_input', 'positionA');
      session.setInputState('spdt_ground_input', 'positionA');
      expect(session.state.isPowered('loadA'), isTrue);
      expect(session.state.isGrounded('loadA'), isTrue);
      expect(session.state.isFunctional('loadA'), isTrue);
      expect(session.state.isFunctional('loadB'), isFalse);
    });

    // --- Test J: Fault composition ------------------------------------------------
    test('J: topology state and faults remain independent', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA');
      expect(session.state.isPowered('loadA'), isTrue);

      session.injectFault(SimulationFault(
        id: 'f1',
        type: SimulationFaultType.openCircuit,
        targetId: 'r_common_a',
        isRelationship: true,
        injectedAt: DateTime.now(),
      ));
      expect(session.state.isPowered('loadA'), isFalse, reason: 'the fault on the A path blocks it too, independently of the switch position');

      session.clearFault('f1');
      expect(session.state.isPowered('loadA'), isTrue, reason: 'switch position alone -- positionA -- restores connectivity once the fault clears');

      // Changing position must not silently clear the fault, and
      // clearing the fault must not silently change position -- verify
      // by re-injecting on the B path while in position A (B is already
      // topology-blocked; the fault composes with, not replaces, that).
      session.injectFault(SimulationFault(
        id: 'f2',
        type: SimulationFaultType.openCircuit,
        targetId: 'r_common_b',
        isRelationship: true,
        injectedAt: DateTime.now(),
      ));
      session.setInputState('spdt_input', 'positionB');
      expect(session.state.isPowered('loadB'), isFalse, reason: 'the B path is now topology-selected but still fault-blocked -- fault survives the position change');
      expect(session.activeFaults.active.map((f) => f.id), contains('f2'));
    });

    // --- Test K: Replay -------------------------------------------------------------
    test('K: state transitions reproduce topology transitions on replay', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA');
      session.setInputState('spdt_input', 'positionB');
      expect(session.state.isPowered('loadB'), isTrue);
      expect(session.state.isPowered('loadA'), isFalse);

      session.reset();
      session.replay();
      expect(session.state.isPowered('loadB'), isTrue, reason: 'replay reproduces the identical final topology');
      expect(session.state.isPowered('loadA'), isFalse);
    });

    // --- Test L: Reset ----------------------------------------------------------------
    test('L: reset returns to baseline', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA');
      session.reset();
      expect(session.activeInputStates, isEmpty);
      expect(session.blockedRelationshipIds, isEmpty);
      expect(session.state.isPowered('loadA'), isTrue);
      expect(session.state.isPowered('loadB'), isTrue);
    });

    // --- Test M: Playback ---------------------------------------------------------------
    test('M: the current playback position determines topology', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA'); // event 0
      session.setInputState('spdt_input', 'positionB'); // event 1

      session.reset();
      session.step(); // after event 0
      expect(session.state.isPowered('loadA'), isTrue);
      expect(session.state.isPowered('loadB'), isFalse);

      session.step(); // after event 1
      expect(session.state.isPowered('loadA'), isFalse);
      expect(session.state.isPowered('loadB'), isTrue);
    });

    // --- Test N: Analysis consistency --------------------------------------------------
    test('N: Phase 11 analysis consumers remain consistent with topology state', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA');

      final view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(view.poweredDeviceIds, contains('loadA'));
      expect(view.unpoweredDeviceIds, contains('loadB'));

      final report = engine.simulationReport(session.id);
      expect(report.functionalNodeCount, greaterThan(0));
    });

    // --- Test O: Runtime/document separation --------------------------------------------
    test('O: changing component state does not dirty the engineering document', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final session = engine.createSession(graph, availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA');
      expect(session.graph, same(graph), reason: 'the engineering graph instance is never mutated');
    });

    // --- Test P: Persistence --------------------------------------------------------------
    test('P: topologyEffects round-trips through session export/import', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final original = engine.createSession(graph, availableInputStates: const [spdtInput]);
      original.setInputState('spdt_input', 'positionA');

      final exported = engine.exportSession(original.id);
      final imported = engine.importSession(exported, graph);

      expect(imported.availableInputStates.single.topologyEffects, spdtInput.topologyEffects);
      expect(imported.activeInputStates, {'spdt_input': 'positionA'});
      expect(imported.state.isPowered('loadA'), isTrue);
      expect(imported.state.isPowered('loadB'), isFalse);
      // The definition itself is session-runtime-persisted (via
      // export/import, Phase 9's existing mechanism) -- NOT written to
      // the EngineeringGraph/.oep package. Documented, not fabricated:
      // a component behavior definition intended to survive across
      // application restarts as part of the engineering DESIGN (not
      // just one runtime session) would require a `.oep`/graph-level
      // persistence contract this phase does not add (see Part 21).
    });

    // --- Test Q: Backward compatibility ---------------------------------------------------
    test('Q: existing Phase 10 relationship-targeted boolean input states continue to work unchanged', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spstInput, spdtInput]);
      session.setInputState('spst_input', false);
      expect(session.blockedRelationshipIds, contains('r_common_a'));
      // The SPDT input has not been set -- its topologyEffects contribute nothing.
      expect(session.blockedRelationshipIds, {'r_common_a'});
    });

    // --- Test R: No duplicate runtime -----------------------------------------------------
    test('R: SimulationSession and SimulationEngine identity remain unchanged', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [spdtInput]);
      session.setInputState('spdt_input', 'positionA');
      session.setInputState('spdt_input', 'positionB');
      expect(engine.getSession(session.id), same(session));
    });

    // --- Multi-position extensibility (Part 8) ---------------------------------------------
    test('multi-position: a third position proves the mechanism is not hard-coded to two states', () {
      const threePositionInput = InputStateDefinition(
        id: 'three_position_input',
        label: 'Three Position Input',
        topologyEffects: {
          'positionA': {'r_common_b'},
          'positionB': {'r_common_a'},
          'positionOff': {'r_common_a', 'r_common_b'},
        },
      );
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [threePositionInput]);

      session.setInputState('three_position_input', 'positionOff');
      expect(session.state.isPowered('loadA'), isFalse);
      expect(session.state.isPowered('loadB'), isFalse);

      session.setInputState('three_position_input', 'positionA');
      expect(session.state.isPowered('loadA'), isTrue);
      expect(session.state.isPowered('loadB'), isFalse);
    });
  });
}
