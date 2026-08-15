import 'package:engineering_engine/engineering_engine.dart';

/// Shared synthetic graph for AP-DS-005 simulation tests — a minimal but
/// real circuit: a battery (power source) -> fuse -> lamp (device),
/// plus a chassis ground node grounding the lamp. Deliberately small
/// enough for a hand-verifiable expected result (lamp powered AND
/// grounded == functional), matching `publishing_helpers.dart`'s own
/// "small hand-verifiable fixture" precedent.
EngineeringGraph buildSimulationTestGraph() {
  return EngineeringGraph(
    id: 'sim-g1',
    nodes: {
      'battery': const EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery'),
      'fuse1': const EngineeringNode(id: 'fuse1', category: NodeCategory.fuse, displayName: 'Fuse 1'),
      'lamp': const EngineeringNode(id: 'lamp', category: NodeCategory.actuator, displayName: 'Lamp'),
      'chassis': const EngineeringNode(id: 'chassis', category: NodeCategory.ground, displayName: 'Chassis Ground'),
    },
    relationships: {
      'r_supply': const EngineeringRelationship(
        id: 'r_supply',
        relationshipType: RelationshipType.suppliesPower,
        sourceNode: 'battery',
        targetNode: 'fuse1',
      ),
      'r_fuse_lamp': const EngineeringRelationship(
        id: 'r_fuse_lamp',
        relationshipType: RelationshipType.connectedTo,
        sourceNode: 'fuse1',
        targetNode: 'lamp',
      ),
      'r_ground': const EngineeringRelationship(
        id: 'r_ground',
        relationshipType: RelationshipType.connectedTo,
        sourceNode: 'chassis',
        targetNode: 'lamp',
      ),
    },
  );
}

DiagramLayoutState buildSimulationTestLayout() {
  return DiagramLayoutState.empty.copyWith(
    positions: {
      'battery': const Point2D(0, 0),
      'fuse1': const Point2D(120, 0),
      'lamp': const Point2D(240, 0),
      'chassis': const Point2D(240, 120),
    },
  );
}
