import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// OEP Engineering Runtime -- Phase 11 (Simulation Analysis Consistency):
/// Part 20 Tests A-O. Verifies every existing analysis/reporting entry
/// point (`PowerDistributionCalculator`, `DiagnosticsEngine`'s
/// fault/power/ground/simulation reports, `VerificationEngine`) agrees
/// with `SignalPropagator`/`MeasurementEngine` about which relationships
/// currently conduct -- using the SAME `SimulationSession.blockedRelationshipIds`
/// (no duplicated blocking logic anywhere).
///
/// Fixture (an automotive example used ONLY as test data, per Phase 10
/// Part 23):
///
///     battery --suppliesPower--> fuse --connectedTo(r_switch)--> lamp
///     chassisGround --connectedTo(r_ground)--> lamp
void main() {
  const headlightSwitch =
      InputStateDefinition(id: 'headlight_switch', label: 'Headlight Switch', targetRelationshipId: 'r_switch');

  EngineeringGraph buildGraph() {
    return EngineeringGraph(
      id: 'g-analysis-consistency',
      nodes: {
        'battery': const EngineeringNode(
          id: 'battery',
          category: NodeCategory.component,
          displayName: 'Battery',
          properties: {'expectedValue': 12.6, 'expectedUnit': 'V'},
        ),
        'fuse': const EngineeringNode(id: 'fuse', category: NodeCategory.fuse, displayName: 'Fuse'),
        'lamp': const EngineeringNode(
          id: 'lamp',
          category: NodeCategory.component,
          displayName: 'Lamp',
          properties: {'expectedValue': 12.6, 'expectedUnit': 'V'},
        ),
        'chassisGround': const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
      },
      relationships: {
        'r1': const EngineeringRelationship(
          id: 'r1',
          relationshipType: RelationshipType.suppliesPower,
          sourceNode: 'battery',
          targetNode: 'fuse',
        ),
        'r_switch': const EngineeringRelationship(
          id: 'r_switch',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'fuse',
          targetNode: 'lamp',
        ),
        'r_ground': const EngineeringRelationship(
          id: 'r_ground',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'chassisGround',
          targetNode: 'lamp',
        ),
      },
    );
  }

  SimulationFault openCircuitOn(String relationshipId) => SimulationFault(
        id: 'fault-$relationshipId',
        type: SimulationFaultType.openCircuit,
        targetId: relationshipId,
        isRelationship: true,
        injectedAt: DateTime.now(),
      );

  group('Phase 11 -- Simulation Analysis Consistency', () {
    // --- Test A/B: Power distribution baseline + state block -------------------
    test('A/B: PowerDistributionCalculator agrees with propagation before and after a state block', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);

      final before = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(before.poweredDeviceIds, contains('lamp'), reason: 'Test A: unblocked baseline is unchanged');

      session.setInputState('headlight_switch', false);
      final after = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(after.poweredDeviceIds, isNot(contains('lamp')), reason: 'Test B: state-blocked relationship changes power reachability');
      expect(after.unpoweredDeviceIds, contains('lamp'));
    });

    // --- Test C: Power distribution + fault --------------------------------------
    test('C: PowerDistributionCalculator still reflects fault-only blocking correctly', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.injectFault(openCircuitOn('r_switch'));
      final view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(view.unpoweredDeviceIds, contains('lamp'), reason: 'existing fault behavior remains correct');
    });

    // --- Test D: Power distribution + state + fault ------------------------------
    test('D: state and fault both independently block, and compose in PowerDistributionCalculator', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.injectFault(openCircuitOn('r_switch'));
      session.setInputState('headlight_switch', false);
      final view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(view.unpoweredDeviceIds, contains('lamp'));

      // Clear the fault; the state block alone must still block the lamp.
      session.clearFault('fault-r_switch');
      final afterClear = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(afterClear.unpoweredDeviceIds, contains('lamp'), reason: 'state block remains after the fault is cleared');
    });

    // --- Test E: Ground analysis --------------------------------------------------
    test('E: GroundReport reflects a state-blocked ground path the same way propagation does', () async {
      const groundSwitch =
          InputStateDefinition(id: 'ground_switch', label: 'Ground Switch', targetRelationshipId: 'r_ground');
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [groundSwitch]);

      final before = engine.groundReport(session.id);
      expect(before.reachableNodeIds, contains('lamp'));

      session.setInputState('ground_switch', false);
      final after = engine.groundReport(session.id);
      expect(after.reachableNodeIds, isNot(contains('lamp')), reason: 'state-blocked ground path becomes unreachable');
      expect(session.state.isGrounded('lamp'), isFalse, reason: 'agrees with real propagation');
    });

    // --- Test F: Simulation report -------------------------------------------------
    test('F: SimulationReport.functionalNodeCount reflects state-driven propagation', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      final before = engine.simulationReport(session.id);
      final beforeFunctional = before.functionalNodeCount;

      session.setInputState('headlight_switch', false);
      final after = engine.simulationReport(session.id);
      expect(after.functionalNodeCount, lessThan(beforeFunctional), reason: 'the lamp is no longer functional once state blocks it');
    });

    // --- Test G: Fault report -----------------------------------------------------
    test('G: FaultReport isolates fault-caused blocking from state-caused blocking', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false);
      session.injectFault(openCircuitOn('r_ground'));

      final report = engine.faultReport(session.id);
      expect(report.impacts, hasLength(1));
      // The fault only blocks ground (r_ground); the lamp is ALREADY
      // non-functional due to the state block on r_switch even without
      // this fault, so diffing "with this fault" vs. "without it" (both
      // computed at the SAME state-blocked baseline) correctly reports
      // the ground node as newly blocked by the fault specifically --
      // not conflating it with the pre-existing state effect.
      expect(report.impacts.single.blockedNodeIds, isNot(contains('lamp')),
          reason: 'the lamp was already non-functional due to state alone; the fault does not additionally block it once already blocked');
    });

    // --- Test H: Verification -----------------------------------------------------
    test('H: VerificationEngine (via SimulationSession.state) reports a state-blocked path as not powered/grounded', () async {
      final engine = SimulationEngine();
      final graph = EngineeringGraph(
        id: 'g-verify',
        nodes: {
          'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
          'lamp': const EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp'),
          'chassisGround': const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
        },
        relationships: {
          'r1': const EngineeringRelationship(
              id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'lamp'),
          'r2': const EngineeringRelationship(
              id: 'r2', relationshipType: RelationshipType.grounds, sourceNode: 'chassisGround', targetNode: 'lamp'),
        },
      );
      const lampSwitch = InputStateDefinition(id: 'lamp_switch', label: 'Lamp Switch', targetRelationshipId: 'r1');
      final session = engine.createSession(graph, availableInputStates: const [lampSwitch]);
      var report = engine.verify(session.id);
      expect(report.findingsFor(VerificationCheck.power), isEmpty, reason: 'powered baseline: no power finding');

      session.setInputState('lamp_switch', false);
      report = engine.verify(session.id);
      expect(report.findingsFor(VerificationCheck.power), isNotEmpty,
          reason: 'verification must not report continuity when the active state has opened the relationship');
    });

    // --- Test I: Replay -------------------------------------------------------------
    test('I: replay reproduces the same analysis result for power distribution', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false);
      final blocked = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(blocked.unpoweredDeviceIds, contains('lamp'));

      session.reset();
      session.replay();
      final replayed = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(replayed.unpoweredDeviceIds, contains('lamp'), reason: 'replay reproduces the identical analysis result');
    });

    // --- Test J: Reset ---------------------------------------------------------------
    test('J: analysis returns to baseline after reset', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false);
      session.reset();
      final view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(view.poweredDeviceIds, contains('lamp'), reason: 'baseline restored after reset');
    });

    // --- Test K: Playback --------------------------------------------------------------
    test('K: analysis reflects the current playback position, not just the latest event', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false); // event 0
      session.setInputState('headlight_switch', true); // event 1

      expect(session.state.isPowered('lamp'), isTrue, reason: 'at the latest position, the switch is closed again');

      session.reset();
      session.step(); // advance to just after event 0 (blocked)
      var view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(view.unpoweredDeviceIds, contains('lamp'), reason: 'at playback position 1 (after event 0 only), state = blocked');

      session.step(); // advance to just after event 1 (unblocked)
      view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(view.poweredDeviceIds, contains('lamp'), reason: 'at playback position 2 (after event 1), state = connected');
    });

    // --- Test L: State/fault independence -----------------------------------------------
    test('L: clearing the fault does not remove the state effect, and vice versa', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.injectFault(openCircuitOn('r_switch'));
      session.setInputState('headlight_switch', false);

      session.clearFault('fault-r_switch');
      expect(session.state.isPowered('lamp'), isFalse, reason: 'state block remains after fault is cleared');

      session.setInputState('headlight_switch', true);
      expect(session.state.isPowered('lamp'), isTrue, reason: 'both effects cleared -> lamp is powered again');
    });

    // --- Test M: Backward compatibility -------------------------------------------------
    test('M: an empty blocked set produces identical results to pre-Phase-10 behavior', () async {
      final engine = SimulationEngine();
      // No availableInputStates supplied at all -- session.blockedRelationshipIds
      // is always {} for the lifetime of this session.
      final session = engine.createSession(buildGraph());
      expect(session.blockedRelationshipIds, isEmpty);

      final view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);
      expect(view.poweredDeviceIds, contains('lamp'));

      final directCall = const PowerDistributionCalculator().compute(session.graph, session.activeFaults);
      expect(directCall.poweredDeviceIds, view.poweredDeviceIds, reason: 'the default {} param produces the identical result');
    });

    // --- Test N: DMM consistency ---------------------------------------------------------
    test('N: MeasurementEngine (DMM) and PowerDistributionCalculator agree about effective connectivity', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false);

      final dmmResult = engine.measure(
        session.id,
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.continuity,
      );
      final view = const PowerDistributionCalculator()
          .compute(session.graph, session.activeFaults, blockedRelationshipIds: session.blockedRelationshipIds);

      expect(dmmResult.continuous, isFalse);
      expect(view.unpoweredDeviceIds, contains('lamp'), reason: 'DMM continuity=false agrees with power distribution -- neither claims the path is live');
    });

    // --- Test O: No duplicate runtime -----------------------------------------------------
    test('O: no duplicate SimulationSession/SimulationEngine instances are created by any analysis call', () async {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      engine.faultReport(session.id);
      engine.powerReport(session.id);
      engine.groundReport(session.id);
      engine.simulationReport(session.id);
      engine.verify(session.id);
      expect(engine.getSession(session.id), same(session));
    });
  });
}
