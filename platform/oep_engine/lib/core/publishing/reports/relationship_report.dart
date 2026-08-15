import '../../graph/models/engineering_graph.dart';
import 'tabular_report.dart';

/// AP-DS-004: generates a Relationship Report — one row per
/// [EngineeringRelationship] in the graph, independent of type (unlike
/// [WireReportGenerator], which is scoped to `connectedTo` only).
class RelationshipReportGenerator {
  static TabularReport generate(EngineeringGraph graph) {
    final rows = <Map<String, Object?>>[];
    for (final relationship in graph.relationships.values) {
      final source = graph.nodes[relationship.sourceNode];
      final target = graph.nodes[relationship.targetNode];
      rows.add({
        'relationshipId': relationship.id,
        'type': relationship.relationshipType.name,
        'source': source?.displayName ?? relationship.sourceNode,
        'target': target?.displayName ?? relationship.targetNode,
        'repositoryRelationshipId': relationship.repositoryRelationshipId ?? '',
      });
    }
    return TabularReport(
      title: 'Relationship Report',
      generatedAt: DateTime.now(),
      columns: const ['relationshipId', 'type', 'source', 'target', 'repositoryRelationshipId'],
      columnLabels: const {
        'relationshipId': 'Relationship ID',
        'type': 'Type',
        'source': 'Source',
        'target': 'Target',
        'repositoryRelationshipId': 'Repository ID',
      },
      rows: rows,
    );
  }
}
