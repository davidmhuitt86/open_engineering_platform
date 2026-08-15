import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../publishing/reports/tabular_report.dart';

/// AP-DS-004: renders any [TabularReport] to a standalone PDF document —
/// the PDF counterpart to [TabularReportRenderer]'s CSV/Markdown output,
/// same "one renderer for all six tabular report types" design.
///
/// This is intentionally a document containing ONLY the table (title +
/// generated-timestamp + rows) — it does not embed a Title Block or
/// diagram drawing. Composing a table page together with a Title Block
/// and/or a diagram-drawing page is Studio-side work (`oep_studio`'s
/// print/export system), since only Studio can reach the Title Block
/// entry UI and the diagram-drawing renderer's page layout together;
/// this function is the reusable table-rendering primitive that
/// composition builds on, not the composition itself.
class TabularReportPdfRenderer {
  static pw.Document render(TabularReport report, {PdfPageFormat pageFormat = PdfPageFormat.a4}) {
    final doc = pw.Document();
    doc.addPage(buildPage(report, pageFormat: pageFormat));
    return doc;
  }

  /// The page widget alone, reusable by `DrawingPackagePdfRenderer`
  /// (AP-DS-004) to compose a report page into another [pw.Document]
  /// alongside the drawing page, without merging separate `PdfDocument`
  /// instances.
  static pw.MultiPage buildPage(TabularReport report, {PdfPageFormat pageFormat = PdfPageFormat.a4}) {
    // Very large reports (this phase's own performance requirement names
    // 100,000 Engineering Objects) are paginated automatically by
    // pw.MultiPage's own overflow handling below -- explicitly NOT
    // rendered as one unbounded pw.Table, which would hold the entire
    // rendered table in memory as one widget tree. pw.TableHelper.fromTextArray
    // inside a MultiPage still builds one row per data row, so this is a
    // correctness-scale (not yet a verified 100k-scale) implementation --
    // see this phase's own Performance documentation for the disclosed
    // gap between "handles pagination correctly" and "benchmarked at
    // 100,000 rows," which was not closed in this pass.
    return pw.MultiPage(
      pageFormat: pageFormat,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(report.title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated ${report.generatedAt.toIso8601String()}', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (context) => [
          if (report.rows.isEmpty)
            pw.Text('No rows.')
          else
            pw.TableHelper.fromTextArray(
              headers: report.columns.map(report.labelFor).toList(),
              data: [
                for (final row in report.rows) [for (final c in report.columns) (row[c] ?? '').toString()],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          if (report.notes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            for (final note in report.notes) pw.Text('Note: $note', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
        ],
    );
  }
}
