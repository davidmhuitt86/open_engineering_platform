import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// OEP Engineering Runtime -- Phase 12 (Component/Port Input-State
/// Association Architecture): Part 24 Tests A-N. Verifies the second,
/// independent association mechanism [InputStateDefinition] now
/// supports -- [InputStateDefinition.targetObjectId]/[targetPortId] --
/// on the real vertical slice:
///
///     EngineeringNode (switchComponent, with two real Ports)
///           ↓
///     InputStateDefinition(targetObjectId: switchComponent, targetPortId: portOut)
///           ↓
///     activeInputStates
///           ↓
///     StateConditionResolver (now graph-aware)
///           ↓
///     blocked relationship (the one wired to portOut via metadata['sourcePort'])
///           ↓
///     SignalPropagator / MeasurementEngine / DMM
///
/// Fixture uses a generic "switchComponent" name, per Part 21 -- no
/// automotive terminology appears anywhere in this file or in the
/// production code it exercises.
void main() {
  EngineeringGraph buildGraph() {
    return EngineeringGraph(
      id: 'g-component-port-state',
      nodes: {
        'source': const EngineeringNode(
          id: 'source',
          category: NodeCategory.component,
          displayName: 'Source',
          properties: {'expectedValue': 12.0, 'expectedUnit': 'V'},
        ),
        'switchComponent': const EngineeringNode(
          id: 'switchComponent',
          category: NodeCategory.component,
          displayName: 'Switch Component',
          ports: [
            Port(id: 'portIn', name: 'In', direction: PortDirection.input),
            Port(id: 'portOut', name: 'Out', direction: PortDirection.output),
          ],
        ),
        'load': const EngineeringNode(
          id: 'load',
          category: NodeCategory.component,
          displayName: 'Load',
          properties: {'expectedValue': 12.0, 'expectedUnit': 'V'},
        ),
        'ground': const EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground'),
      },
      relationships: {
        'r_source_in': const EngineeringRelationship(
          id: 'r_source_in',
          relationshipType: RelationshipType.suppliesPower,
          sourceNode: 'source',
          targetNode: 'switchComponent',
          metadata: {'targetPort': 'portIn'},
        ),
        'r_out_load': const EngineeringRelationship(
          id: 'r_out_load',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'switchComponent',
          targetNode: 'load',
          metadata: {'sourcePort': 'portOut'},
        ),
        'r_ground': const EngineeringRelationship(
          id: 'r_ground',
          relationshipType: RelationshipType.connectedTo,
          sourceNode: 'ground',
          targetNode: 'load',
        ),
      },
    );
  }

  const componentInput = InputStateDefinition(
    id: 'switch_component_input',
    label: 'Switch Component Input',
    targetObjectId: 'switchComponent',
    targetPortId: 'portOut',
  );

  group('Phase 12 -- Component/Port Input-State Association Architecture', () {
    // --- Test A: Component identity ---------------------------------------------
    test('A: a real engineering component has a stable identity', () {
      final graph = buildGraph();
      expect(graph.nodes['switchComponent']!.id, 'switchComponent');
      expect(graph.nodes['switchComponent']!.id, graph.nodes['switchComponent']!.id, reason: 'identity is stable across reads');
    });

    // --- Test B: Port identity -----------------------------------------------------
    test('B: a real port can be unambiguously associated with its owner', () {
      final graph = buildGraph();
      final node = graph.nodes['switchComponent']!;
      final port = node.ports.firstWhere((p) => p.id == 'portOut');
      expect(port.id, 'portOut');
      // Ownership is established structurally (the port lives inside
      // this node's own `ports` list) -- confirmed by looking it up
      // only through the owning node, never through a global port
      // registry (none exists).
      expect(node.ports.map((p) => p.id), contains('portOut'));
    });

    // --- Test C: Input association --------------------------------------------------
    test('C: a runtime input can identify its intended component/port', () {
      expect(componentInput.targetObjectId, 'switchComponent');
      expect(componentInput.targetPortId, 'portOut');
      final restored = InputStateDefinition.fromJson(componentInput.toJson());
      expect(restored.targetObjectId, 'switchComponent');
      expect(restored.targetPortId, 'portOut');
    });

    // --- Test D: State activation ----------------------------------------------------
    test('D: changing the input state updates the runtime condition', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [componentInput]);
      session.setInputState('switch_component_input', false);
      expect(session.activeInputStates, {'switch_component_input': false});
    });

    // --- Test E/F: Component effect + connectivity effect --------------------------
    test('E/F: the component responds through StateConditionResolver, and connectivity changes correctly', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final session = engine.createSession(graph, availableInputStates: const [componentInput]);

      expect(session.blockedRelationshipIds, isEmpty, reason: 'before any input is set, nothing is blocked');
      expect(session.state.isPowered('load'), isTrue, reason: 'baseline: power reaches the load through the component');

      session.setInputState('switch_component_input', false);

      // Only the relationship wired to the targeted port (r_out_load) is
      // blocked -- NOT r_source_in, which is wired to a different port
      // on the same node. This proves port-level scoping, not just
      // whole-node blocking.
      expect(session.blockedRelationshipIds, {'r_out_load'});
      expect(session.state.isPowered('load'), isFalse, reason: 'blocking the port-specific relationship breaks power to the load');
      expect(session.state.isPowered('switchComponent'), isTrue, reason: 'the component itself is still powered on its input side');
    });

    // --- Test G: DMM ------------------------------------------------------------------
    test('G: the changed behavior is observable through the existing measurement path', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [componentInput]);

      final before = engine.measure(
        session.id,
        probeA: const ProbePoint(nodeId: 'source'),
        probeB: const ProbePoint(nodeId: 'load'),
        type: MeasurementType.continuity,
      );
      expect(before.continuous, isTrue);

      session.setInputState('switch_component_input', false);

      final after = engine.measure(
        session.id,
        probeA: const ProbePoint(nodeId: 'source'),
        probeB: const ProbePoint(nodeId: 'load'),
        type: MeasurementType.continuity,
      );
      expect(after.continuous, isFalse, reason: 'the real DMM observes the real, changed component/port-driven circuit');
    });

    // --- Test H: Fault composition ------------------------------------------------------
    test('H: component state effects and faults remain independent', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [componentInput]);

      session.injectFault(SimulationFault(
        id: 'f1',
        type: SimulationFaultType.openCircuit,
        targetId: 'r_ground',
        isRelationship: true,
        injectedAt: DateTime.now(),
      ));
      expect(session.state.isGrounded('load'), isFalse, reason: 'fault alone blocks ground');
      expect(session.state.isPowered('load'), isTrue, reason: 'component state has not blocked power yet');

      session.setInputState('switch_component_input', false);
      expect(session.state.isGrounded('load'), isFalse, reason: 'fault still blocks ground');
      expect(session.state.isPowered('load'), isFalse, reason: 'component state now also blocks power -- independently composed');

      session.clearFault('f1');
      expect(session.state.isGrounded('load'), isTrue, reason: 'fault cleared, ground restored');
      expect(session.state.isPowered('load'), isFalse, reason: 'component state block remains, independent of the fault');
    });

    // --- Test I: Replay -----------------------------------------------------------------
    test('I: the component state effect reproduces during replay', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [componentInput]);
      session.setInputState('switch_component_input', false);
      expect(session.state.isPowered('load'), isFalse);

      session.reset();
      expect(session.state.isPowered('load'), isTrue);

      session.replay();
      expect(session.state.isPowered('load'), isFalse, reason: 'replay reproduces the identical component-blocked result');
    });

    // --- Test J: Reset --------------------------------------------------------------------
    test('J: reset restores the deterministic baseline', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [componentInput]);
      session.setInputState('switch_component_input', false);
      session.reset();
      expect(session.activeInputStates, isEmpty);
      expect(session.blockedRelationshipIds, isEmpty);
      expect(session.state.isPowered('load'), isTrue);
    });

    // --- Test K: Playback -----------------------------------------------------------------
    test('K: state effects correspond to the current playback position', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [componentInput]);
      session.setInputState('switch_component_input', false); // event 0
      session.setInputState('switch_component_input', true); // event 1

      session.reset();
      session.step(); // after event 0
      expect(session.state.isPowered('load'), isFalse, reason: 'at position 1, component input is false -- blocked');

      session.step(); // after event 1
      expect(session.state.isPowered('load'), isTrue, reason: 'at position 2, component input is true -- connected');
    });

    // --- Test L: Runtime/document separation --------------------------------------------
    test('L: changing runtime state does not dirty the engineering document (no such mechanism exists here)', () {
      final engine = SimulationEngine();
      final graph = buildGraph();
      final session = engine.createSession(graph, availableInputStates: const [componentInput]);
      session.setInputState('switch_component_input', false);
      expect(session.graph, same(graph), reason: 'the engineering graph instance is never mutated by a runtime state change');
    });

    // --- Test M: No duplicate runtime -----------------------------------------------------
    test('M: the same authoritative simulation session/engine remains in use', () {
      final engine = SimulationEngine();
      final session = engine.createSession(buildGraph(), availableInputStates: const [componentInput]);
      session.setInputState('switch_component_input', false);
      expect(engine.getSession(session.id), same(session));
    });

    // --- Test N: Backward compatibility ----------------------------------------------------
    test('N: existing relationship-level input-state behavior remains intact alongside component/port targeting', () {
      const relationshipInput =
          InputStateDefinition(id: 'relationship_input', label: 'Relationship Input', targetRelationshipId: 'r_ground');
      final engine = SimulationEngine();
      final session = engine.createSession(
        buildGraph(),
        availableInputStates: const [componentInput, relationshipInput],
      );

      session.setInputState('relationship_input', false);
      expect(session.blockedRelationshipIds, {'r_ground'}, reason: 'relationship-targeted input still works exactly as Phase 10 left it');
      expect(session.state.isGrounded('load'), isFalse);
      expect(session.state.isPowered('load'), isTrue, reason: 'the component-targeted input has not been set, so it has no effect');

      session.setInputState('switch_component_input', false);
      expect(session.blockedRelationshipIds, {'r_ground', 'r_out_load'}, reason: 'both mechanisms compose in the same set');
    });
  });
}
