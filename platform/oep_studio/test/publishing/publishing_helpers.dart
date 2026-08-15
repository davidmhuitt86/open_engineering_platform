import 'package:engineering_engine/engineering_engine.dart';

/// Shared synthetic graph for AP-DS-004 publishing tests — mirrors
/// `oep_engine`'s own `test/publishing/report_generators_test.dart` fixture
/// (same node/relationship shapes), so results here can be sanity-checked
/// against that suite's own expected counts.
EngineeringGraph buildTestGraph() {
  return EngineeringGraph(
    id: 'g1',
    nodes: {
      'n1': const EngineeringNode(
        id: 'n1',
        category: NodeCategory.component,
        displayName: 'Ignition Relay',
        properties: {'manufacturer': 'Acme', 'manufacturerPartNumber': 'AR-100', 'quantity': 2},
      ),
      'n2': const EngineeringNode(
        id: 'n2',
        category: NodeCategory.connector,
        displayName: 'Main Connector',
        ports: [Port(id: 'p1', name: 'Pin 1'), Port(id: 'p2', name: 'Pin 2')],
      ),
      'n3': const EngineeringNode(id: 'n3', category: NodeCategory.wire, displayName: 'Wire Node'),
    },
    relationships: {
      'r1': const EngineeringRelationship(
        id: 'r1',
        relationshipType: RelationshipType.connectedTo,
        sourceNode: 'n1',
        targetNode: 'n2',
        metadata: {'wireColor': 'Red', 'wireGauge': '18AWG'},
      ),
    },
  );
}

DiagramLayoutState buildTestLayout() {
  return DiagramLayoutState.empty.copyWith(
    positions: {'n1': const Point2D(0, 0), 'n2': const Point2D(30, 40)},
    layers: {'harness1': const DiagramLayer(id: 'harness1', name: 'Engine Harness')},
    layerAssignments: {'n1': 'harness1', 'n2': 'harness1'},
  );
}
