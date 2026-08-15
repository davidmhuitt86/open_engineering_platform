import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// OEP Engineering Runtime -- Phase 9 (Operating State & Input-State
/// Architecture): Part 27 Tests A-N against the real runtime layer
/// (`OperatingStateDefinition`/`InputStateDefinition`/
/// `SimulationSession.setOperatingState`/`.setInputState`/
/// `.activeOperatingStateId`/`.activeInputStates`), never a fabricated
/// stand-in. Test H (measurement consequence) is intentionally NOT
/// present here -- `SignalPropagator` does not yet consume operating/
/// input state (a confirmed, documented backend gap, Part 30), so no
/// test asserts a measurement changes with operating state; fabricating
/// one is exactly what Part 27 forbids.
void main() {
  EngineeringGraph buildGraph() {
    return EngineeringGraph(
      id: 'g-state',
      nodes: {
        'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
        'starterMotor':
            const EngineeringNode(id: 'starterMotor', category: NodeCategory.actuator, displayName: 'Starter Motor'),
        'chassisGround':
            const EngineeringNode(id: 'chassisGround', category: NodeCategory.ground, displayName: 'Chassis Ground'),
      },
      relationships: {
        'r1': const EngineeringRelationship(
          id: 'r1',
          relationshipType: RelationshipType.suppliesPower,
          sourceNode: 'battery',
          targetNode: 'starterMotor',
        ),
        'r2': const EngineeringRelationship(
          id: 'r2',
          relationshipType: RelationshipType.grounds,
          sourceNode: 'chassisGround',
          targetNode: 'starterMotor',
        ),
      },
    );
  }

  const keyOff = OperatingStateDefinition(id: 'key_off', name: 'Key Off / Engine Off');
  const keyOn = OperatingStateDefinition(id: 'key_on', name: 'Key On / Engine Off');
  const cranking = OperatingStateDefinition(id: 'cranking', name: 'Cranking');
  const headlightSwitch = InputStateDefinition(id: 'headlight', label: 'Headlight Switch');

  group('Phase 9 -- Operating State & Input-State Architecture', () {
    // --- Test A: State definition -----------------------------------------
    test('A: a real operating state can be represented', () {
      expect(keyOn.id, 'key_on');
      expect(keyOn.name, 'Key On / Engine Off');
      final json = keyOn.toJson();
      final restored = OperatingStateDefinition.fromJson(json);
      expect(restored.id, keyOn.id);
      expect(restored.name, keyOn.name);
    });

    // --- Test B: Stable identity --------------------------------------------
    test('B: state identity remains stable across a JSON round-trip', () {
      final restored = OperatingStateDefinition.fromJson(keyOn.toJson());
      expect(restored.id, keyOn.id);
    });

    // --- Test C: State activation --------------------------------------------
    test('C: a state can become active through setOperatingState', () {
      final engine = SimulationEngine();
      final session =
          engine.createSession(buildGraph(), availableOperatingStates: const [keyOff, keyOn, cranking]);
      expect(session.activeOperatingStateId, isNull, reason: 'no fabricated implicit default');
      session.setOperatingState('key_on');
      expect(session.activeOperatingStateId, 'key_on');
    });

    test('C2: setOperatingState rejects an id absent from availableOperatingStates', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableOperatingStates: const [keyOff, keyOn]);
      expect(() => session.setOperatingState('warp_speed'), throwsArgumentError);
    });

    // --- Test D: State observation --------------------------------------------
    test('D: the active state can be read by the runtime after multiple changes', () {
      final engine = SimulationEngine();
      final session =
          engine.createSession(buildGraph(), availableOperatingStates: const [keyOff, keyOn, cranking]);
      session.setOperatingState('key_off');
      session.setOperatingState('key_on');
      expect(session.activeOperatingStateId, 'key_on');
    });

    // --- Test E: State transition ----------------------------------------------
    test('E: a real sequence of transitions is recorded and observable in order', () {
      final engine = SimulationEngine();
      final session =
          engine.createSession(buildGraph(), availableOperatingStates: const [keyOff, keyOn, cranking]);
      session.setOperatingState('key_off');
      session.setOperatingState('key_on');
      session.setOperatingState('cranking');
      expect(session.activeOperatingStateId, 'cranking');
      final conditionEvents = session.history.where((e) => e.type == SimulationEventType.conditionChanged).toList();
      expect(conditionEvents.length, 3);
      expect(conditionEvents.map((e) => e.conditionValue), ['key_off', 'key_on', 'cranking']);
    });

    // --- Test F: Input state -------------------------------------------------
    test('F: a real input state can be represented and activated', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      expect(session.activeInputStates, isEmpty);
      session.setInputState('headlight', true);
      expect(session.activeInputStates, {'headlight': true});
    });

    test('F2: setInputState rejects an id absent from availableInputStates', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [headlightSwitch]);
      expect(() => session.setInputState('unknown_input', true), throwsArgumentError);
    });

    test('F3: operating state and input state are tracked independently', () {
      final engine = SimulationEngine();
      final session = engine.createSession(
        buildGraph(),
        availableOperatingStates: const [keyOff, keyOn],
        availableInputStates: const [headlightSwitch],
      );
      session.setOperatingState('key_on');
      session.setInputState('headlight', true);
      expect(session.activeOperatingStateId, 'key_on');
      expect(session.activeInputStates, {'headlight': true});
    });

    // --- Test G: Runtime bridge -------------------------------------------------
    test('G: operating state changes reach the simulation runtime (session/history/recompute)', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableOperatingStates: const [keyOff, keyOn]);
      final stateBefore = session.state;
      session.setOperatingState('key_on');
      // recompute() runs as part of every session mutation (see
      // SimulationSession._append) -- a fresh, real SimulationStateSnapshot
      // is produced, proving the condition change reached the runtime,
      // even though (Part 30, documented gap) SignalPropagator does not
      // yet vary its result based on that condition.
      expect(session.state, isNot(same(stateBefore)));
      expect(session.activeOperatingStateId, 'key_on');
    });

    // --- Test M: Reset --------------------------------------------------------
    test('M: reset returns operating/input state to unset, without discarding history', () {
      final engine = SimulationEngine();
      final session = engine.createSession(
        buildGraph(),
        availableOperatingStates: const [keyOff, keyOn],
        availableInputStates: const [headlightSwitch],
      );
      session.setOperatingState('key_on');
      session.setInputState('headlight', true);
      expect(session.activeOperatingStateId, 'key_on');

      session.reset();

      expect(session.activeOperatingStateId, isNull, reason: 'reset returns playback to position 0');
      expect(session.activeInputStates, isEmpty);
      expect(session.history.length, 2, reason: 'reset does not discard recorded history');

      session.replay();
      expect(session.activeOperatingStateId, 'key_on', reason: 'replay can step back through the same history');
    });

    // --- Test N: Identity -------------------------------------------------------
    test('N: duplicating a session carries the same availableOperatingStates, no fabricated defaults', () async {
      final engine = SimulationEngine();
      final original =
          engine.createSession(buildGraph(), availableOperatingStates: const [keyOff, keyOn, cranking]);
      original.setOperatingState('key_on');
      final duplicate = engine.duplicateSession(original.id);

      expect(duplicate.id, isNot(original.id), reason: 'a real, distinct session -- not a shared reference');
      expect(duplicate.availableOperatingStates.map((s) => s.id), original.availableOperatingStates.map((s) => s.id));
      expect(duplicate.activeOperatingStateId, 'key_on');

      // Mutating the duplicate must never affect the original's own
      // authoritative state (Part 26: one authoritative state PER
      // runtime, not a shared mutable reference across sessions).
      duplicate.setOperatingState('cranking');
      expect(duplicate.activeOperatingStateId, 'cranking');
      expect(original.activeOperatingStateId, 'key_on');
    });

    test('N2: export/import round-trips operating/input state definitions and active values', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final original = engine.createSession(
        graph,
        availableOperatingStates: const [keyOff, keyOn],
        availableInputStates: const [headlightSwitch],
      );
      original.setOperatingState('key_on');
      original.setInputState('headlight', true);

      final exported = engine.exportSession(original.id);
      final imported = engine.importSession(exported, graph);

      expect(imported.availableOperatingStates.map((s) => s.id), ['key_off', 'key_on']);
      expect(imported.availableInputStates.map((s) => s.id), ['headlight']);
      expect(imported.activeOperatingStateId, 'key_on');
      expect(imported.activeInputStates, {'headlight': true});
    });
  });
}
