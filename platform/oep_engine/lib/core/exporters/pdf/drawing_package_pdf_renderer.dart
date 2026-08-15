import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../graph/models/engineering_graph.dart';
import '../../interfaces/routing_provider.dart';
import '../../interfaces/symbol_provider.dart';
import '../../publishing/models/title_block.dart';
import '../../publishing/reports/tabular_report.dart';
import '../../views/diagram/diagram_layout_state.dart';
import '../shared/tabular_report_pdf_renderer.dart';
import 'diagram_pdf_renderer.dart';

/// AP-DS-004: "Drawing Package" / "Installation Package" / "Service
/// Package" generation, scoped honestly to what this platform's document
/// model actually supports.
///
/// The spec names these as multi-sheet drawing-set deliverables. This
/// platform's document model is single-diagram — there is no multi-sheet
/// / Drawing Set concept (confirmed frozen, disclosed limitation from
/// AP-DS-001, see `docs/architecture/diagram_studio/DOCUMENT_MODEL.md`).
/// This renderer does NOT retrofit multi-sheet support. What it actually
/// produces is: **one diagram drawing page, plus a selected set of
/// tabular report pages** (BOM/Wire/Connector/Harness/Relationship/
/// Engineering Object), concatenated into a single multi-page PDF
/// document. That is the entire scope — callers and downstream docs
/// should describe this as "one diagram + selected reports," not as a
/// true multi-sheet drawing set.
class DrawingPackagePdfRenderer {
  static pw.Document render(
    EngineeringGraph graph, {
    DiagramLayoutState? layout,
    SymbolProvider? symbols,
    RoutingProvider? routing,
    TitleBlock? titleBlock,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    List<TabularReport> reports = const [],
  }) {
    // Building every page (drawing + reports) into one `pw.Document` via
    // `addPage`, rather than rendering separate `pw.Document`s and trying
    // to merge their raw page objects afterward — a page's content stream
    // references objects (fonts etc.) registered against the specific
    // `PdfDocument` it was built in, so splicing `PdfPage`s across
    // documents post-hoc is fragile. `DiagramPdfRenderer.buildPage` /
    // `TabularReportPdfRenderer.buildPage` expose the page/MultiPage
    // widgets precisely so this composition can happen at the `addPage`
    // level instead.
    final doc = pw.Document();
    doc.addPage(DiagramPdfRenderer.buildPage(
      graph,
      layout: layout,
      symbols: symbols,
      routing: routing,
      titleBlock: titleBlock,
      pageFormat: pageFormat,
    ));
    for (final report in reports) {
      doc.addPage(TabularReportPdfRenderer.buildPage(report, pageFormat: pageFormat));
    }
    return doc;
  }
}
