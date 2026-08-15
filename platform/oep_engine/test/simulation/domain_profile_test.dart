import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// OEP Engineering Runtime -- Phase 14 (UI Layout Ratification): the
/// domain-profile data contract Phase 9 deferred. Verifies a real
/// profile round-trips through JSON and, once loaded, genuinely drives
/// a real session's operating/input states and simulation behavior --
/// the same generic `DiagramSimulationService.createSession(availableOperatingStates:,
/// availableInputStates:)` seam Phase 9-13 already established, not a
/// second mechanism.
void main() {
  const keyOff = OperatingStateDefinition(id: 'key_off', name: 'Key Off / Engine Off');
  const keyOn = OperatingStateDefinition(id: 'key_on', name: 'Key On / Engine Off');
  const keyCrank = OperatingStateDefinition(id: 'key_crank', name: 'Cranking');
  const keyRun = OperatingStateDefinition(id: 'key_run', name: 'Engine Running');

  const headlightSwitch =
      InputStateDefinition(id: 'headlight_switch', label: 'Headlight Switch', targetRelationshipId: 'r_switch');

  const profile = DomainProfile(
    id: 'trx300',
    name: 'TRX300',
    operatingStates: [keyOff, keyOn, keyCrank, keyRun],
    inputStates: [headlightSwitch],
  );

  EngineeringGraph buildGraph() {
    return EngineeringGraph(
      id: 'g-domain-profile',
      nodes: {
        'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
        'fuse': const EngineeringNode(id: 'fuse', category: NodeCategory.fuse, displayName: 'Fuse'),
        'lamp': const EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp'),
        'ground': const EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground'),
      },
      relationships: {
        'r1': const EngineeringRelationship(
            id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'fuse'),
        'r_switch': const EngineeringRelationship(
            id: 'r_switch', relationshipType: RelationshipType.connectedTo, sourceNode: 'fuse', targetNode: 'lamp'),
        'r3': const EngineeringRelationship(
            id: 'r3', relationshipType: RelationshipType.connectedTo, sourceNode: 'ground', targetNode: 'lamp'),
      },
    );
  }

  group('Phase 14 -- Domain Profile', () {
    test('a real profile round-trips through JSON', () {
      final json = profile.toJson();
      final restored = DomainProfile.fromJson(json);
      expect(restored.id, 'trx300');
      expect(restored.operatingStates.map((s) => s.id), ['key_off', 'key_on', 'key_crank', 'key_run']);
      expect(restored.inputStates.single.id, 'headlight_switch');
      expect(restored.inputStates.single.targetRelationshipId, 'r_switch');
    });

    test('loading a profile into a real session makes its operating states genuinely selectable', () {
      final engine = SimulationEngine();
      final session = engine.createSession(
        buildGraph(),
        availableOperatingStates: profile.operatingStates,
        availableInputStates: profile.inputStates,
      );

      expect(session.activeOperatingStateId, isNull);
      session.setOperatingState('key_run');
      expect(session.activeOperatingStateId, 'key_run');
      expect(() => session.setOperatingState('not_in_profile'), throwsArgumentError);
    });

    test('loading a profile makes its input states genuinely affect real propagation', () {
      final engine = SimulationEngine();
      final session = engine.createSession(
        buildGraph(),
        availableOperatingStates: profile.operatingStates,
        availableInputStates: profile.inputStates,
      );

      expect(session.state.isPowered('lamp'), isTrue);
      session.setInputState('headlight_switch', false);
      expect(session.state.isPowered('lamp'), isFalse, reason: 'the loaded profile input genuinely blocks propagation, not a fabricated UI-only flag');
    });

    test('a profile with no operating/input states is valid (an empty profile is honest, not an error)', () {
      const empty = DomainProfile(id: 'blank', name: 'Blank');
      final json = empty.toJson();
      final restored = DomainProfile.fromJson(json);
      expect(restored.operatingStates, isEmpty);
      expect(restored.inputStates, isEmpty);
    });
  });
}
