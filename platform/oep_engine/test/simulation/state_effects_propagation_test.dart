import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// OEP Engineering Runtime -- Phase 10 (Operating/Input State Effects →
/// Signal Propagation): Part 26 Tests A-N against the real vertical
/// slice -- a boolean [InputStateDefinition] with a
/// [InputStateDefinition.targetRelationshipId] genuinely blocks that
/// relationship in [SignalPropagator], through
/// [SimulationSession.setInputState], with real, changed
/// [MeasurementResult]s to prove it (Part 16's "most important
/// end-to-end validation").
///
/// Fixture (an automotive example used ONLY as test data, per Part 23 --
/// nothing in the engine/resolver/propagator knows the word
/// "headlight"):
///
///     battery --suppliesPower--> fuse --connectedTo(r_switch)--> lamp
///     chassisGround --connectedTo--> lamp
///
/// `headlight_switch` (a boolean InputStateDefinition) targets `r_switch`.
void main() {
  const headlightSwitch =
      InputStateDefinition(id: 'headlight_switch', label: 'Headlight Switch', targetRelationshipId: 'r_switch');

  EngineeringGraph buildGraph() {
    return EngineeringGraph(
      id: 'g-state-effects',
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
        'r3': const EngineeringRelationship(
          id: 'r3',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'chassisGround',
          targetNode: 'lamp',
        ),
      },
    );
  }

  group('Phase 10 -- Operating/Input State Effects -> Signal Propagation', () {
    // --- Test A: State activation ---------------------------------------------
    test('A: a real operating state can be activated and observed on the session', () {
      const keyOn = OperatingStateDefinition(id: 'key_on', name: 'Key On / Engine Off');
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableOperatingStates: const [keyOn]);
      session.setOperatingState('key_on');
      expect(session.activeOperatingStateId, 'key_on');
    });

    // --- Test B: Input activation -----------------------------------------------
    test('B: a real boolean input can be activated and observed on the session', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', true);
      expect(session.activeInputStates, {'headlight_switch': true});
    });

    // --- Test C: Condition resolution -------------------------------------------
    test('C: StateConditionResolver resolves exactly the relationships a false boolean input targets', () {
      const resolver = StateConditionResolver();
      final graph = buildGraph();
      expect(
        resolver.resolveBlockedRelationshipIds(graph, const [headlightSwitch], const {'headlight_switch': false}),
        {'r_switch'},
      );
      expect(
        resolver.resolveBlockedRelationshipIds(graph, const [headlightSwitch], const {'headlight_switch': true}),
        isEmpty,
        reason: 'true never blocks',
      );
      expect(
        resolver.resolveBlockedRelationshipIds(graph, const [headlightSwitch], const {}),
        isEmpty,
        reason: 'never-set input never blocks -- no fabricated default',
      );
    });

    // --- Test D/E: State effect + propagation ------------------------------------
    test('D/E: setting the input to false genuinely blocks propagation through the targeted relationship', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      expect(session.state.isFunctional('lamp'), isTrue, reason: 'before any input is set, propagation is unaffected');

      session.setInputState('headlight_switch', false);

      expect(session.state.isPowered('lamp'), isFalse, reason: 'r_switch is now blocked -- power cannot reach the lamp');
      expect(session.state.isFunctional('lamp'), isFalse);

      session.setInputState('headlight_switch', true);
      expect(session.state.isPowered('lamp'), isTrue, reason: 'setting it back to true unblocks propagation');
    });

    // --- Test F: DMM ------------------------------------------------------------
    test('F: a real MeasurementResult changes between state A and state B', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);

      final before = engine.measure(
        session.id,
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.continuity,
      );
      expect(before.continuous, isTrue, reason: 'State A: switch not yet opened, lamp circuit is continuous');

      session.setInputState('headlight_switch', false);

      final after = engine.measure(
        session.id,
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.continuity,
      );
      expect(after.continuous, isFalse, reason: 'State B: switch opened, the real DMM sees a real changed circuit -- not fabricated');
      expect(after.reachable, isFalse);
    });

    // --- Test G: Fault composition -----------------------------------------------
    test('G: state and fault block independently and compose deterministically', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);

      // Fault only.
      session.injectFault(SimulationFault(
        id: 'f1',
        type: SimulationFaultType.openCircuit,
        targetId: 'r3',
        isRelationship: true,
        injectedAt: DateTime.now(),
      ));
      expect(session.state.isGrounded('lamp'), isFalse, reason: 'the fault alone already blocks ground');
      expect(session.state.isPowered('lamp'), isTrue, reason: 'state has not blocked power yet');

      // State + fault together.
      session.setInputState('headlight_switch', false);
      expect(session.state.isGrounded('lamp'), isFalse, reason: 'fault still blocks ground');
      expect(session.state.isPowered('lamp'), isFalse, reason: 'state now also blocks power -- independently composed');

      // Clear the fault; state block remains.
      session.clearFault('f1');
      expect(session.state.isGrounded('lamp'), isTrue, reason: 'fault cleared, ground restored');
      expect(session.state.isPowered('lamp'), isFalse, reason: 'state block is independent of the fault -- still blocking power');
    });

    // --- Test H: Event history --------------------------------------------------
    test('H: input-state changes are represented by the existing conditionChanged event history', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false);
      final conditionEvents = session.history.where((e) => e.type == SimulationEventType.conditionChanged).toList();
      expect(conditionEvents.length, 1);
      expect(conditionEvents.single.conditionKey, 'input:headlight_switch');
      expect(conditionEvents.single.conditionValue, false);
    });

    // --- Test I: Replay -----------------------------------------------------------
    test('I: replay reproduces the exact same resulting simulation state', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false);
      final blockedSnapshot = session.state;
      expect(blockedSnapshot.isPowered('lamp'), isFalse);

      session.reset();
      expect(session.state.isPowered('lamp'), isTrue, reason: 'reset returns to the pre-state baseline');

      session.replay();
      expect(session.state.isPowered('lamp'), isFalse, reason: 'replay reproduces the identical blocked result');
    });

    // --- Test J: Reset --------------------------------------------------------------
    test('J: reset returns operating state, input state, faults, and propagation to baseline together', () {
      final engine = SimulationEngine();
      final session = engine.createSession(
        buildGraph(),
        availableOperatingStates: const [OperatingStateDefinition(id: 'key_on', name: 'Key On')],
        availableInputStates: const [headlightSwitch],
      );
      session.setOperatingState('key_on');
      session.setInputState('headlight_switch', false);
      session.injectFault(SimulationFault(
        id: 'f1',
        type: SimulationFaultType.openCircuit,
        targetId: 'r3',
        isRelationship: true,
        injectedAt: DateTime.now(),
      ));
      expect(session.state.isFunctional('lamp'), isFalse);

      session.reset();

      expect(session.activeOperatingStateId, isNull);
      expect(session.activeInputStates, isEmpty);
      expect(session.activeFaults.isEmpty, isTrue);
      expect(session.state.isFunctional('lamp'), isTrue, reason: 'propagation baseline is fully restored, not just the flags');
    });

    // --- Test N: Identity -----------------------------------------------------------
    test('N: no duplicate SimulationSession/SimulationEngine instances are created by state effects', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      session.setInputState('headlight_switch', false);
      expect(engine.getSession(session.id), same(session), reason: 'the one authoritative session, never a copy');
    });
  });
}
