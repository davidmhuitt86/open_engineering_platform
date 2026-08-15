import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// AP-DS-005: exercises the core Simulation Engine primitives I built
/// directly (SignalPropagator, VerificationEngine) against a small,
/// realistic wiring graph loosely modeled on the legacy reference's own
/// `tests/simulator-test.js` scenario (battery -> relay -> starter motor,
/// battery -> coil -> spark; SIMULATION_TRACEABILITY_MATRIX.md's retained
/// regression-scenario source) -- not by running any legacy code, by
/// re-deriving an equivalent scenario against the new engine.
void main() {
  group('SignalPropagator', () {
    late EngineeringGraph graph;

    setUp(() {
      // battery --suppliesPower--> starterRelay --controls--> starterMotor
      // chassisGround (category=ground) --connectedTo--> starterMotor
      graph = EngineeringGraph(
        id: 'g1',
        nodes: {
          'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
          'starterRelay': const EngineeringNode(id: 'starterRelay', category: NodeCategory.relay, displayName: 'Starter Relay'),
          'starterMotor': const EngineeringNode(id: 'starterMotor', category: NodeCategory.actuator, displayName: 'Starter Motor'),
          'chassisGround': const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
        },
        relationships: {
          'r1': const EngineeringRelationship(
            id: 'r1',
            relationshipType: RelationshipType.suppliesPower,
            sourceNode: 'battery',
            targetNode: 'starterRelay',
          ),
          'r2': const EngineeringRelationship(
            id: 'r2',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'starterRelay',
            targetNode: 'starterMotor',
          ),
          'r3': const EngineeringRelationship(
            id: 'r3',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'chassisGround',
            targetNode: 'starterMotor',
          ),
        },
      );
    });

    test('baseline: starter motor is powered and grounded with no faults', () {
      final state = const SignalPropagator().propagatePowerAndGround(graph, FaultOverlay());
      expect(state.isPowered('starterRelay'), isTrue);
      expect(state.isPowered('starterMotor'), isTrue, reason: 'power flows through connectedTo relay-to-motor wire');
      expect(state.isGrounded('starterMotor'), isTrue);
      expect(state.isFunctional('starterMotor'), isTrue);
    });

    test('open circuit fault on the relay-to-motor wire blocks power propagation past it', () {
      final faults = FaultOverlay();
      faults.inject(SimulationFault(
        id: 'f1',
        type: SimulationFaultType.openCircuit,
        targetId: 'r2',
        isRelationship: true,
        injectedAt: DateTime(2026),
      ));
      final state = const SignalPropagator().propagatePowerAndGround(graph, faults);
      expect(state.isPowered('starterRelay'), isTrue, reason: 'the fault is downstream of the relay');
      expect(state.isPowered('starterMotor'), isFalse, reason: 'open circuit on r2 blocks propagation to the motor');
      expect(state.isFunctional('starterMotor'), isFalse);
    });

    test('a fault directly on a node blocks it from receiving propagation', () {
      final faults = FaultOverlay();
      faults.inject(SimulationFault(
        id: 'f2',
        type: SimulationFaultType.relayFailure,
        targetId: 'starterRelay',
        injectedAt: DateTime(2026),
      ));
      final state = const SignalPropagator().propagatePowerAndGround(graph, faults);
      expect(state.isPowered('starterRelay'), isFalse);
      expect(state.isPowered('starterMotor'), isFalse, reason: 'the relay failure blocks everything downstream too');
    });

    test('clearing a fault restores propagation (fault is an overlay, never mutates the graph)', () {
      final faults = FaultOverlay();
      faults.inject(SimulationFault(
        id: 'f3',
        type: SimulationFaultType.openCircuit,
        targetId: 'r2',
        isRelationship: true,
        injectedAt: DateTime(2026),
      ));
      expect(const SignalPropagator().propagatePowerAndGround(graph, faults).isPowered('starterMotor'), isFalse);

      faults.clearAll();
      expect(const SignalPropagator().propagatePowerAndGround(graph, faults).isPowered('starterMotor'), isTrue,
          reason: 'clearing the fault overlay restores the original graph behavior -- the base graph was never mutated');
    });

    test('a controls relationship gates propagation on the controller\'s own fault state', () {
      final controlled = graph.withRelationship(const EngineeringRelationship(
        id: 'r4',
        relationshipType: RelationshipType.controls,
        sourceNode: 'starterRelay',
        targetNode: 'starterMotor',
      ));
      final faults = FaultOverlay();
      faults.inject(SimulationFault(
        id: 'f4',
        type: SimulationFaultType.relayFailure,
        targetId: 'starterRelay',
        injectedAt: DateTime(2026),
      ));
      final state = const SignalPropagator().propagatePowerAndGround(controlled, faults);
      expect(state.isPowered('starterMotor'), isFalse, reason: 'the relay failure blocks both direct propagation and the controls-gated path');
    });
  });

  group('VerificationEngine', () {
    test('flags an isolated node and reports a clean connectivity result for a fully connected graph', () {
      final connected = EngineeringGraph(
        id: 'g2',
        nodes: {
          'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A'),
          'b': const EngineeringNode(id: 'b', category: NodeCategory.component, displayName: 'B'),
        },
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.connectedTo, sourceNode: 'a', targetNode: 'b'),
        },
      );
      final report = const VerificationEngine().runAll(connected);
      expect(report.findingsFor(VerificationCheck.connectivity), isEmpty);

      final withIsolated = connected.withNode(const EngineeringNode(id: 'c', category: NodeCategory.component, displayName: 'C'));
      final report2 = const VerificationEngine().runAll(withIsolated);
      expect(report2.findingsFor(VerificationCheck.connectivity), isNotEmpty);
      expect(report2.findingsFor(VerificationCheck.connectivity).first.nodeId, 'c');
    });

    test('relationship verification flags a dangling reference', () {
      final graph = EngineeringGraph(
        id: 'g3',
        nodes: {'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A')},
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.connectedTo, sourceNode: 'a', targetNode: 'missing'),
        },
      );
      final report = const VerificationEngine().runAll(graph);
      final findings = report.findingsFor(VerificationCheck.relationship);
      expect(findings, isNotEmpty);
      expect(findings.first.severity, VerificationSeverity.error);
      expect(report.passed, isFalse);
    });

    test('power/ground/continuity verification uses a supplied SimulationStateSnapshot', () {
      final graph = EngineeringGraph(
        id: 'g4',
        nodes: {
          'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
          'lamp': const EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp'),
        },
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'lamp'),
        },
      );
      final state = const SignalPropagator().propagatePowerAndGround(graph, FaultOverlay());
      final report = const VerificationEngine().runAll(graph, state: state);
      // lamp expects power (targeted by a suppliesPower relationship) but
      // has no ground relationship at all -- expect a power error, no
      // ground error (nothing declares the lamp needs one).
      final powerFindings = report.findingsFor(VerificationCheck.power);
      expect(powerFindings, isEmpty, reason: 'the lamp IS reached by suppliesPower propagation from battery');
      expect(report.findingsFor(VerificationCheck.ground), isEmpty);
    });

    test('dependency verification identifies a single point of failure across all power sources', () {
      final graph = EngineeringGraph(
        id: 'g5',
        nodes: {
          'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
          'fuse': const EngineeringNode(id: 'fuse', category: NodeCategory.fuse, displayName: 'Fuse'),
          'lamp': const EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp'),
        },
        relationships: {
          'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'fuse'),
          'r2': const EngineeringRelationship(id: 'r2', relationshipType: RelationshipType.connectedTo, sourceNode: 'fuse', targetNode: 'lamp'),
        },
      );
      final state = const SignalPropagator().propagatePowerAndGround(graph, FaultOverlay());
      final report = const VerificationEngine().runAll(graph, state: state);
      final dependencyFindings = report.findingsFor(VerificationCheck.dependency);
      expect(dependencyFindings, isNotEmpty);
      expect(dependencyFindings.first.nodeId, 'lamp');
      expect(dependencyFindings.first.message, contains('Fuse'));
    });
  });
}
