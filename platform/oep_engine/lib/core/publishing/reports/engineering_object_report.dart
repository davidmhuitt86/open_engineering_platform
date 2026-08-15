import '../../graph/models/engineering_graph.dart';
import 'tabular_report.dart';

/// AP-DS-004: generates an Engineering Object Report — one row per node,
/// independent of category (the general-purpose counterpart to
/// [BillOfMaterialsGenerator]'s orderable-parts-only scope).
class EngineeringObjectReportGenerator {
  static TabularReport generate(EngineeringGraph graph) {
    final rows = <Map<String, Object?>>[];
    for (final node in graph.nodes.values) {
      rows.add({
        'objectId': node.id,
        'name': node.displayName,
        'category': node.category.name,
        'repositoryObjectId': node.repositoryObjectId ?? '',
        'symbolId': node.symbolId ?? '',
        'portCount': node.ports.length,
        'evidenceLinkCount': node.evidenceLinks.length,
      });
    }
    return TabularReport(
      title: 'Engineering Object Report',
      generatedAt: DateTime.now(),
      columns: const ['objectId', 'name', 'category', 'repositoryObjectId', 'symbolId', 'portCount', 'evidenceLinkCount'],
      columnLabels: const {
        'objectId': 'Object ID',
        'name': 'Name',
        'category': 'Category',
        'repositoryObjectId': 'Repository ID',
        'symbolId': 'Symbol',
        'portCount': 'Ports',
        'evidenceLinkCount': 'Evidence Links',
      },
      rows: rows,
    );
  }
}
