import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/publishing/tabular_report_kind.dart';

import 'publishing_helpers.dart';

void main() {
  group('TabularReportKind', () {
    late final graph = buildTestGraph();
    late final layout = buildTestLayout();

    test('billOfMaterials dispatches to BillOfMaterialsGenerator', () {
      final report = TabularReportKind.billOfMaterials.generate(graph, layout);
      expect(report.rows.length, 2);
    });

    test('wireList dispatches to WireReportGenerator using layout', () {
      final report = TabularReportKind.wireList.generate(graph, layout);
      expect(report.rows, isNotEmpty);
    });

    test('connectorReport, harnessReport, relationshipReport, engineeringObjectReport all produce a report', () {
      for (final kind in [
        TabularReportKind.connectorReport,
        TabularReportKind.harnessReport,
        TabularReportKind.relationshipReport,
        TabularReportKind.engineeringObjectReport,
      ]) {
        final report = kind.generate(graph, layout);
        expect(report.title, isNotEmpty, reason: '$kind should produce a titled report');
      }
    });

    test('every kind has a distinct human label', () {
      final labels = TabularReportKind.values.map((k) => k.label).toSet();
      expect(labels.length, TabularReportKind.values.length);
    });
  });
}
