import 'dart:convert';
import 'dart:io';

import '../../interfaces/export_provider.dart';
import '../shared/export_request.dart';
import '../shared/export_result.dart';

/// Round-trip JSON export (Phase 1 scope). PDF/SVG/PNG/OEP Package export
/// are future work (SDD-026).
class JsonExportProvider implements ExportProvider {
  static const String formatId = 'json';

  @override
  bool supports(String formatId) => formatId == JsonExportProvider.formatId;

  @override
  Future<ExportResult> export(ExportRequest request) async {
    if (!supports(request.formatId)) {
      return ExportResult.failure('Unsupported export format: ${request.formatId}');
    }
    final envelope = {'schemaVersion': 1, 'graph': request.graph.toJson()};
    final encoded = const JsonEncoder.withIndent('  ').convert(envelope);
    if (request.destinationPath != null) {
      final file = File(request.destinationPath!);
      await file.parent.create(recursive: true);
      await file.writeAsString(encoded);
      return ExportResult.ok(outputPath: request.destinationPath);
    }
    return ExportResult.ok(bytes: utf8.encode(encoded));
  }
}
