import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import 'tabular_report.dart';

/// AP-DS-004: generates a Connector Report — one row per pin/port on every
/// `NodeCategory.connector` node.
///
/// **Disclosed data-model limitation, not silently worked around**: this
/// platform's Engineering Graph connects NODES, not individual PORTS
/// (`EngineeringRelationship` has no source/target port fields — see
/// `engineering_relationship.dart`). "Pin Usage"/"Unused Pins" can
/// therefore only be reported at node granularity (does this connector
/// node participate in any relationship at all), not true per-pin
/// connectivity. This report states that limitation in its own `notes`
/// rather than fabricating a per-pin "connected" column the data doesn't
/// support.
class ConnectorReportGenerator {
  static TabularReport generate(EngineeringGraph graph) {
    final rows = <Map<String, Object?>>[];
    for (final node in graph.nodes.values) {
      if (node.category != NodeCategory.connector) continue;
      final nodeHasAnyRelationship =
          graph.relationships.values.any((r) => r.sourceNode == node.id || r.targetNode == node.id);
      if (node.ports.isEmpty) {
        rows.add({
          'connector': node.displayName,
          'pin': '',
          'pinType': '',
          'pinDirection': '',
          'usage': nodeHasAnyRelationship ? 'node has connections' : 'unused',
          'location': node.properties['location'] ?? '',
        });
        continue;
      }
      for (final port in node.ports) {
        rows.add({
          'connector': node.displayName,
          'pin': port.name,
          'pinType': port.type,
          'pinDirection': port.direction.name,
          'usage': nodeHasAnyRelationship ? 'node has connections' : 'unused',
          'location': node.properties['location'] ?? '',
        });
      }
    }

    return TabularReport(
      title: 'Connector Report',
      generatedAt: DateTime.now(),
      columns: const ['connector', 'pin', 'pinType', 'pinDirection', 'usage', 'location'],
      columnLabels: const {
        'connector': 'Connector',
        'pin': 'Pin',
        'pinType': 'Type',
        'pinDirection': 'Direction',
        'usage': 'Usage',
        'location': 'Location',
      },
      rows: rows,
      notes: const [
        'The Engineering Graph connects nodes, not individual pins — "Usage" reflects whether the connector node '
            'as a whole participates in any relationship, not true per-pin connectivity.',
      ],
    );
  }
}
