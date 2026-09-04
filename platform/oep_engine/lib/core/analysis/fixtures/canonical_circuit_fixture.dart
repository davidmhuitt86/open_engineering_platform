import '../../graph/builders/graph_builder.dart';
import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../analysis_engine.dart';

/// The canonical `12 V source → 10 Ω resistor → reference node`
/// acceptance fixture (AP-EK-020 §"Canonical acceptance circuit" /
/// Phase 4), built through the existing [GraphBuilder]/[EngineeringGraph]
/// architecture — no parallel document identity model.
///
/// `resistanceOhms` defaults to 10.0 (the canonical value); tests use it
/// to build the "10 Ω → 20 Ω" document-mutation fixture (AP-EK-020 §39)
/// without duplicating the whole builder.
EngineeringGraph buildCanonicalCircuitGraph({
  double resistanceOhms = 10.0,
  double voltageVolts = 12.0,
}) {
  final builder = GraphBuilder(id: 'graph-circuit-12v-10ohm')
    ..addNode(
      id: 'source-1',
      category: NodeCategory.component,
      displayName: '12 V Source',
      metadata: const {
        'componentModelId': ElectricalCoreIds.voltageSourceModel,
      },
      properties: {
        'voltage': {'value': voltageVolts, 'unit': 'unit.volt'},
      },
    )
    ..addNode(
      id: 'resistor-1',
      category: NodeCategory.component,
      displayName: 'Resistor',
      metadata: const {'componentModelId': ElectricalCoreIds.resistorModel},
      properties: {
        'resistance': {'value': resistanceOhms, 'unit': 'unit.ohm'},
      },
    )
    ..addNode(
      id: 'ground-1',
      category: NodeCategory.ground,
      displayName: 'Reference Node',
      metadata: const {
        'componentModelId': ElectricalCoreIds.referenceNodeModel,
      },
    )
    ..connect('source-1', 'resistor-1', id: 'rel-source-resistor')
    ..connect('resistor-1', 'ground-1', id: 'rel-resistor-ground');

  return builder.build();
}
