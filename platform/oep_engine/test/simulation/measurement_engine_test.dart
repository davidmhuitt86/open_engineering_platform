import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// WP-DS-005A: exercises MeasurementEngine directly, and through the
/// SimulationEngine facade's `measure()` — the sole path Diagram Studio's
/// Digital Multimeter uses to obtain a reading.
void main() {
  late EngineeringGraph graph;

  setUp(() {
    // battery(expectedValue=12.6V) --suppliesPower--> fuse --connectedTo--> lamp
    // chassisGround --connectedTo--> lamp
    graph = EngineeringGraph(
      id: 'g1',
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
        'r1': const EngineeringRelationship(id: 'r1', relationshipType: RelationshipType.suppliesPower, sourceNode: 'battery', targetNode: 'fuse'),
        'r2': const EngineeringRelationship(id: 'r2', relationshipType: RelationshipType.connectedTo, sourceNode: 'fuse', targetNode: 'lamp'),
        'r3': const EngineeringRelationship(id: 'r3', relationshipType: RelationshipType.connectedTo, sourceNode: 'chassisGround', targetNode: 'lamp'),
      },
    );
  });

  group('MeasurementEngine', () {
    test('continuity: connected points report continuous with a path', () {
      final result = const MeasurementEngine().measure(
        graph,
        FaultOverlay(),
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.continuity,
      );
      expect(result.reachable, isTrue);
      expect(result.continuous, isTrue);
      expect(result.path, ['battery', 'fuse', 'lamp']);
      expect(result.contributingRelationshipIds, ['r1', 'r2']);
    });

    test('continuity: an open-circuit fault on the path reports not continuous', () {
      final faults = FaultOverlay();
      faults.inject(SimulationFault(id: 'f1', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      final result = const MeasurementEngine().measure(
        graph,
        faults,
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.continuity,
      );
      expect(result.reachable, isFalse);
      expect(result.continuous, isFalse);
    });

    test('resistance reports 0 ohms when continuous, discloses no per-component modeling', () {
      final result = const MeasurementEngine().measure(
        graph,
        FaultOverlay(),
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.resistance,
      );
      expect(result.measuredValue, 0);
      expect(result.unit, 'Ω');
      expect(result.notes, contains('No per-component resistance'));
    });

    test('voltage DC reads the authored expectedValue when the probe point is powered', () {
      final result = const MeasurementEngine().measure(
        graph,
        FaultOverlay(),
        probeA: const ProbePoint(nodeId: 'lamp'),
        probeB: const ProbePoint(nodeId: 'chassisGround'),
        type: MeasurementType.voltageDc,
      );
      expect(result.reachable, isTrue);
      expect(result.measuredValue, 12.6);
      expect(result.expectedValue, 12.6);
      expect(result.difference, 0);
      expect(result.unit, 'V');
      expect(result.powerSourceId, 'battery');
      expect(result.notes, contains('authored expected value'));
    });

    test('voltage DC reads 0 when the probe point is unpowered due to a fault', () {
      final faults = FaultOverlay();
      faults.inject(SimulationFault(id: 'f2', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));
      final result = const MeasurementEngine().measure(
        graph,
        faults,
        probeA: const ProbePoint(nodeId: 'lamp'),
        probeB: const ProbePoint(nodeId: 'chassisGround'),
        type: MeasurementType.voltageDc,
      );
      expect(result.reachable, isFalse);
      expect(result.measuredValue, 0);
      expect(result.expectedValue, 12.6);
      expect(result.difference, -12.6);
    });

    test('groundPotential gates on ground reachability, not power', () {
      final result = const MeasurementEngine().measure(
        graph,
        FaultOverlay(),
        probeA: const ProbePoint(nodeId: 'lamp'),
        probeB: const ProbePoint(nodeId: 'chassisGround'),
        type: MeasurementType.groundPotential,
      );
      expect(result.reachable, isTrue);
      expect(result.groundSourceId, 'chassisGround');
    });

    test('capacitance/temperature are disclosed as unsupported placeholders, not fabricated readings', () {
      final result = const MeasurementEngine().measure(
        graph,
        FaultOverlay(),
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.capacitance,
      );
      expect(result.reachable, isFalse);
      expect(result.measuredValue, isNull);
      expect(result.notes, contains('future placeholder'));
    });
  });

  group('SimulationEngine.measure', () {
    test('produces a measurement scoped to the session\'s current fault state', () {
      final engine = SimulationEngine();
      final session = engine.createSession(graph, name: 'measure-test');

      final baseline = engine.measure(
        session.id,
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.continuity,
      );
      expect(baseline.continuous, isTrue);

      engine.injectFault(session.id, SimulationFault(id: 'f3', type: SimulationFaultType.openCircuit, targetId: 'r2', isRelationship: true, injectedAt: DateTime(2026)));

      final afterFault = engine.measure(
        session.id,
        probeA: const ProbePoint(nodeId: 'battery'),
        probeB: const ProbePoint(nodeId: 'lamp'),
        type: MeasurementType.continuity,
      );
      expect(afterFault.continuous, isFalse);
    });
  });
}
