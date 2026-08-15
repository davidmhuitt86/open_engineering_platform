import 'dart:io';

import 'package:pdf/pdf.dart';

import '../../interfaces/export_provider.dart';
import '../../publishing/models/title_block.dart';
import '../shared/export_request.dart';
import '../shared/export_result.dart';
import 'diagram_pdf_renderer.dart';

/// AP-DS-004: diagram-drawing PDF export. `request.options` may carry:
/// - `'titleBlock'`: a [TitleBlock] to render in the sheet's title-block
///   region (omitted entirely if absent).
/// - `'pageFormat'`: a [PdfPageFormat] (defaults to A4).
///
/// Layout comes from `request.layout`, not `options` — see
/// [ExportRequest]'s doc comment for why layout was made a first-class
/// field rather than an options entry.
class PdfExportProvider implements ExportProvider {
  static const String formatId = 'pdf';

  @override
  bool supports(String formatId) => formatId == PdfExportProvider.formatId;

  @override
  Future<ExportResult> export(ExportRequest request) async {
    if (!supports(request.formatId)) {
      return ExportResult.failure('Unsupported export format: ${request.formatId}');
    }
    final titleBlock = request.options['titleBlock'] as TitleBlock?;
    final pageFormat = request.options['pageFormat'] as PdfPageFormat? ?? PdfPageFormat.a4;

    final doc = DiagramPdfRenderer.render(
      request.graph,
      layout: request.layout,
      titleBlock: titleBlock,
      pageFormat: pageFormat,
    );
    final bytes = await doc.save();

    if (request.destinationPath != null) {
      final file = File(request.destinationPath!);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return ExportResult.ok(outputPath: request.destinationPath);
    }
    return ExportResult.ok(bytes: bytes);
  }
}
