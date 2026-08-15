import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../graph/models/engineering_graph.dart';
import '../../interfaces/routing_provider.dart';
import '../../interfaces/symbol_provider.dart';
import '../../publishing/models/title_block.dart';
import '../../views/diagram/diagram_layout_state.dart';
import '../../views/diagram/diagram_scene.dart';
import '../shared/diagram_print_scene.dart';

/// AP-DS-004: renders one diagram sheet (nodes/symbols/wires) to a
/// [pw.Document] page, as true vector drawing commands (`pw.Canvas`) —
/// not a rasterized screenshot of the Flutter widget tree, so the output
/// stays crisp and scalable at any print size.
///
/// Scope note: a node's Symbol is drawn as a bordered box carrying its
/// `symbolId`/node id label, not the Symbol Library's actual SVG artwork.
/// The on-screen renderer (`SymbolNodeWidget`) resolves symbol artwork via
/// `flutter_svg` + `rootBundle` asset loading, which requires a live
/// Flutter binding; this package's export path is exercised from plain
/// Dart tests and is meant to also run headless (e.g. batch export), so it
/// does not depend on asset-bundle access. Wiring actual per-symbol vector
/// artwork into the PDF (via `pdf` package's own SVG-to-PDF support) is
/// disclosed, deferred follow-up work, not silently skipped.
class DiagramPdfRenderer {
  static pw.Document render(
    EngineeringGraph graph, {
    DiagramLayoutState? layout,
    SymbolProvider? symbols,
    RoutingProvider? routing,
    TitleBlock? titleBlock,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) {
    final doc = pw.Document();
    doc.addPage(buildPage(
      graph,
      layout: layout,
      symbols: symbols,
      routing: routing,
      titleBlock: titleBlock,
      pageFormat: pageFormat,
    ));
    return doc;
  }

  /// The page widget alone, reusable by [DrawingPackagePdfRenderer] to
  /// compose the drawing page into one multi-page [pw.Document] alongside
  /// report pages, without needing to merge separate [pw.Document]
  /// instances (fragile: page content streams reference objects — fonts
  /// etc. — registered against their own originating `PdfDocument`).
  static pw.Page buildPage(
    EngineeringGraph graph, {
    DiagramLayoutState? layout,
    SymbolProvider? symbols,
    RoutingProvider? routing,
    TitleBlock? titleBlock,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) {
    final scene = computePrintScene(graph, layout: layout, symbols: symbols, routing: routing);

    const margin = 24.0;
    final titleBlockHeight = titleBlock == null ? 0.0 : 110.0;
    final drawableWidth = pageFormat.width - margin * 2;
    final drawableHeight = pageFormat.height - margin * 2 - titleBlockHeight;

    final scale = _fitScale(scene, drawableWidth, drawableHeight);

    return pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(margin),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: drawableWidth,
              height: drawableHeight,
              child: pw.CustomPaint(
                size: PdfPoint(drawableWidth, drawableHeight),
                painter: (canvas, size) => _paintScene(canvas, scene, scale),
              ),
            ),
            if (titleBlock != null) ...[
              pw.SizedBox(height: 8),
              _buildTitleBlock(titleBlock, drawableWidth),
            ],
          ],
        );
      },
    );
  }

  static double _fitScale(DiagramScene scene, double width, double height) {
    if (scene.contentWidth <= 0 || scene.contentHeight <= 0) return 1;
    final sx = width / scene.contentWidth;
    final sy = height / scene.contentHeight;
    final scale = sx < sy ? sx : sy;
    return scale <= 0 ? 1 : (scale > 1 ? 1 : scale);
  }

  static void _paintScene(PdfGraphics canvas, DiagramScene scene, double scale) {
    // Wires first (drawn behind nodes), same paint order as the on-screen
    // renderer (WirePainter draws under SymbolNodeWidget's Stack).
    for (final wire in scene.wires) {
      if (wire.points.length < 2) continue;
      final color = wire.highlighted
          ? PdfColors.orange
          : (wire.selected ? PdfColors.blue : PdfColors.grey800);
      canvas
        ..setStrokeColor(color)
        ..setLineWidth(wire.highlighted || wire.selected ? 1.5 : 0.75)
        ..moveTo(wire.points.first.dx * scale, wire.points.first.dy * scale);
      for (final point in wire.points.skip(1)) {
        canvas.lineTo(point.dx * scale, point.dy * scale);
      }
      canvas.strokePath();
    }

    for (final node in scene.nodes) {
      final x = node.position.dx * scale;
      final y = node.position.dy * scale;
      final w = node.width * scale;
      final h = node.height * scale;
      final borderColor = node.highlighted
          ? PdfColors.orange
          : (node.selected ? PdfColors.blue : PdfColors.grey700);
      canvas
        ..setStrokeColor(borderColor)
        ..setLineWidth(1)
        ..drawRect(x, y, w, h)
        ..strokePath();

      final label = node.symbolId ?? node.nodeId;
      final font = canvas.defaultFont;
      if (font != null) {
        canvas.drawString(font, 7, label, x + 2, y + h - 10);
      }
    }
  }

  static pw.Widget _buildTitleBlock(TitleBlock block, double width) {
    pw.Widget cell(String label, String value) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(width: 0.5, color: PdfColors.grey600)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        );

    final dateStr = block.date == null ? '' : block.date!.toIso8601String().split('T').first;

    return pw.Container(
      width: width,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75, color: PdfColors.grey800)),
      child: pw.Column(
        children: [
          pw.Row(children: [
            cell('Company', block.company),
            cell('Project', block.project),
            cell('Drawing No.', block.drawingNumber),
            cell('Rev.', block.revision),
          ]),
          pw.Row(children: [
            cell('Engineer', block.engineer),
            cell('Approver', block.approver),
            cell('Date', dateStr),
            cell('Scale', block.scale),
          ]),
          pw.Row(children: [
            cell('Sheet', block.sheet),
            cell('Classification', block.classification),
            for (final entry in block.customFields.entries) cell(entry.key, entry.value),
          ]),
        ],
      ),
    );
  }
}
