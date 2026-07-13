import 'package:engineering_engine/engineering_engine.dart';

/// A small ignition-circuit-shaped sample graph, expressed through the
/// Engineering Node/Relationship schema (SDD-027) — written from scratch
/// for this demo, not copied from the reference implementation.
///
/// battery -> ignition switch -> module -> ignition coil -> lamp -> ground
/// with a direct battery -> ground return path.
EngineeringGraph buildSeedGraph() {
  final builder = GraphBuilder(id: 'demo-ignition-circuit')
    ..addNode(
      id: 'battery',
      category: NodeCategory.component,
      displayName: 'Battery',
      symbolId: 'battery',
    )
    ..addNode(
      id: 'ignition_switch',
      category: NodeCategory.switchNode,
      displayName: 'Ignition Switch',
      symbolId: 'spst_switch',
    )
    ..addNode(
      id: 'module',
      category: NodeCategory.module,
      displayName: 'Control Module',
      symbolId: 'generic_module',
    )
    ..addNode(
      id: 'coil',
      category: NodeCategory.component,
      displayName: 'Ignition Coil',
      symbolId: 'ignition_coil',
    )
    ..addNode(
      id: 'lamp',
      category: NodeCategory.component,
      displayName: 'Indicator Lamp',
      symbolId: 'lamp',
    )
    ..addNode(
      id: 'ground',
      category: NodeCategory.ground,
      displayName: 'Chassis Ground',
      symbolId: 'ground',
    )
    ..connect('battery', 'ignition_switch',
        id: 'r_battery_switch', type: RelationshipType.suppliesPower)
    ..connect('ignition_switch', 'module',
        id: 'r_switch_module', type: RelationshipType.connectedTo)
    ..connect('module', 'coil', id: 'r_module_coil', type: RelationshipType.controls)
    ..connect('coil', 'lamp',
        id: 'r_coil_lamp', type: RelationshipType.suppliesPower)
    ..connect('lamp', 'ground', id: 'r_lamp_ground', type: RelationshipType.grounds)
    ..connect('battery', 'ground',
        id: 'r_battery_ground', type: RelationshipType.grounds);

  return builder.build();
}
