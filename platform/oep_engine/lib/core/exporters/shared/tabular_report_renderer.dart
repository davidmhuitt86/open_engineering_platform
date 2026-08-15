import '../../publishing/reports/tabular_report.dart';

/// AP-DS-004: renders any [TabularReport] (BOM/Wire/Connector/Harness/
/// Relationship/Object Report — every one of this phase's tabular
/// deliverables) to CSV or Markdown. One renderer for all six report
/// types, per `tabular_report.dart`'s own "one shape, one renderer"
/// design note.
///
/// CSV is hand-rolled (RFC 4180 quoting: a field is quoted, with internal
/// quotes doubled, if it contains a comma, quote, or newline) rather than
/// depending on a package — CSV is a small, well-specified format with no
/// meaningful implementation risk, unlike PDF generation (see
/// `pubspec.yaml`'s own comment on why `pdf` WAS added as a dependency).
class TabularReportRenderer {
  static String toCsv(TabularReport report) {
    final buffer = StringBuffer();
    buffer.writeln(report.columns.map((c) => _csvField(report.labelFor(c))).join(','));
    for (final row in report.rows) {
      buffer.writeln(report.columns.map((c) => _csvField(row[c])).join(','));
    }
    return buffer.toString();
  }

  static String _csvField(Object? value) {
    final text = (value ?? '').toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String toMarkdown(TabularReport report) {
    final buffer = StringBuffer();
    buffer.writeln('# ${report.title}');
    buffer.writeln();
    buffer.writeln('_Generated ${report.generatedAt.toIso8601String()}_');
    buffer.writeln();
    if (report.rows.isEmpty) {
      buffer.writeln('_No rows._');
      return buffer.toString();
    }
    buffer.writeln('| ${report.columns.map(report.labelFor).join(' | ')} |');
    buffer.writeln('| ${report.columns.map((_) => '---').join(' | ')} |');
    for (final row in report.rows) {
      buffer.writeln('| ${report.columns.map((c) => _markdownCell(row[c])).join(' | ')} |');
    }
    if (report.notes.isNotEmpty) {
      buffer.writeln();
      for (final note in report.notes) {
        buffer.writeln('> $note');
      }
    }
    return buffer.toString();
  }

  static String _markdownCell(Object? value) => (value ?? '').toString().replaceAll('|', '\\|').replaceAll('\n', ' ');
}
