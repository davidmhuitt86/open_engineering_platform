import 'dart:io';

import '../../interfaces/export_provider.dart';
import '../shared/export_request.dart';
import '../shared/export_result.dart';
import 'diagram_png_renderer.dart';

/// AP-DS-004: diagram-drawing PNG export. `request.options` may carry
/// `'dpi'` (a `double`, defaults to 96 — treated as "1 layout unit = 1
/// px" at 96 dpi, matching the PDF/SVG renderers' 1:1 point mapping).
class PngExportProvider implements ExportProvider {
  static const String formatId = 'png';

  @override
  bool supports(String formatId) => formatId == PngExportProvider.formatId;

  @override
  Future<ExportResult> export(ExportRequest request) async {
    if (!supports(request.formatId)) {
      return ExportResult.failure('Unsupported export format: ${request.formatId}');
    }
    final dpi = (request.options['dpi'] as num?)?.toDouble() ?? 96.0;

    final bytes = await DiagramPngRenderer.render(
      request.graph,
      layout: request.layout,
      dpi: dpi,
    );

    if (request.destinationPath != null) {
      final file = File(request.destinationPath!);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return ExportResult.ok(outputPath: request.destinationPath);
    }
    return ExportResult.ok(bytes: bytes);
  }
}
