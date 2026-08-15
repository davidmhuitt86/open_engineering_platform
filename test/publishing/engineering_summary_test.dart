import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/publishing/engineering_summary.dart';

import 'publishing_helpers.dart';

void main() {
  test('EngineeringSummary.build counts nodes/relationships/categories and rollups tabular reports', () {
    final summary = EngineeringSummary.build(buildTestGraph(), buildTestLayout());

    expect(summary.nodeCount, 3);
    expect(summary.relationshipCount, 1);
    expect(summary.nodesByCategory['component'], 1);
    expect(summary.nodesByCategory['connector'], 1);
    expect(summary.nodesByCategory['wire'], 1);
    expect(summary.tabularReportRowCounts['Bill of Materials'], 2);
  });

  test('toMarkdown renders every section without fabricating engineering-intelligence content', () {
    final summary = EngineeringSummary.build(buildTestGraph(), buildTestLayout());
    final markdown = summary.toMarkdown();

    expect(markdown, contains('Diagram Structure'));
    expect(markdown, contains('Objects by Category'));
    expect(markdown, contains('Deliverable Row Counts'));
    expect(markdown, isNot(contains('validation')));
    expect(markdown, isNot(contains('reasoning')));
  });
}
