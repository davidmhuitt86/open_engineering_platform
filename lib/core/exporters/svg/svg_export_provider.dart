import 'dart:convert';
import 'dart:io';

import '../../interfaces/export_provider.dart';
import '../../publishing/models/title_block.dart';
import '../shared/export_request.dart';
import '../shared/export_result.dart';
import 'diagram_svg_renderer.dart';

/// AP-DS-004: diagram-drawing SVG export. `request.options` may carry
/// `'titleBlock'` (a [TitleBlock]); layout comes from `request.layout`.
class SvgExportProvider implements ExportProvider {
  static const String formatId = 'svg';

  @override
  bool supports(String formatId) => formatId == SvgExportProvider.formatId;

  @override
  Future<ExportResult> export(ExportRequest request) async {
    if (!supports(request.formatId)) {
      return ExportResult.failure('Unsupported export format: ${request.formatId}');
    }
    final titleBlock = request.options['titleBlock'] as TitleBlock?;

    final svg = DiagramSvgRenderer.render(
      request.graph,
      layout: request.layout,
      titleBlock: titleBlock,
    );
    final bytes = utf8.encode(svg);

    if (request.destinationPath != null) {
      final file = File(request.destinationPath!);
      await file.parent.create(recursive: true);
      await file.writeAsString(svg);
      return ExportResult.ok(outputPath: request.destinationPath);
    }
    return ExportResult.ok(bytes: bytes);
  }
}
