import 'package:engineering_engine/engineering_engine.dart';

/// AP-DS-004: Engineering Report / Engineering Summary — a composite
/// document of genuinely diagram-derived facts, not filler. Deliberately
/// limited to: diagram identity, object/relationship counts (broken down
/// by category — real graph facts, computed once here and nowhere else
/// duplicated), and row counts from the six tabular reports (a rollup,
/// not the tables themselves — the tabular reports remain the place to
/// see the actual rows). This is NOT a copy of the Validation/Reasoning
/// Report content — it contains zero engineering-intelligence output,
/// only structural facts already present in the [EngineeringGraph] and
/// the tabular generators' own row counts.
class EngineeringSummary {
  final String title;
  final DateTime generatedAt;
  final int nodeCount;
  final int relationshipCount;
  final Map<String, int> nodesByCategory;
  final Map<String, int> tabularReportRowCounts;

  const EngineeringSummary({
    required this.title,
    required this.generatedAt,
    required this.nodeCount,
    required this.relationshipCount,
    required this.nodesByCategory,
    required this.tabularReportRowCounts,
  });

  static EngineeringSummary build(EngineeringGraph graph, DiagramLayoutState layout, {String title = 'Engineering Summary'}) {
    final byCategory = <String, int>{};
    for (final node in graph.nodes.values) {
      byCategory.update(node.category.name, (v) => v + 1, ifAbsent: () => 1);
    }
    final rowCounts = <String, int>{
      'Bill of Materials': BillOfMaterialsGenerator.generate(graph).rows.length,
      'Wire List': WireReportGenerator.generate(graph, layout).rows.length,
      'Connector Report': ConnectorReportGenerator.generate(graph).rows.length,
      'Harness Report': HarnessReportGenerator.generate(graph, layout).rows.length,
      'Relationship Report': RelationshipReportGenerator.generate(graph).rows.length,
      'Engineering Object Report': EngineeringObjectReportGenerator.generate(graph).rows.length,
    };
    return EngineeringSummary(
      title: title,
      generatedAt: DateTime.now(),
      nodeCount: graph.nodes.length,
      relationshipCount: graph.relationships.length,
      nodesByCategory: byCategory,
      tabularReportRowCounts: rowCounts,
    );
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# $title');
    buffer.writeln();
    buffer.writeln('_Generated ${generatedAt.toIso8601String()}_');
    buffer.writeln();
    buffer.writeln('## Diagram Structure');
    buffer.writeln();
    buffer.writeln('- Engineering Objects: $nodeCount');
    buffer.writeln('- Relationships: $relationshipCount');
    buffer.writeln();
    buffer.writeln('### Objects by Category');
    buffer.writeln();
    for (final entry in nodesByCategory.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
    buffer.writeln();
    buffer.writeln('## Deliverable Row Counts');
    buffer.writeln();
    for (final entry in tabularReportRowCounts.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value} row(s)');
    }
    return buffer.toString();
  }
}
