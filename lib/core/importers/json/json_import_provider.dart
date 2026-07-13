import 'dart:convert';
import 'dart:io';

import '../../graph/models/engineering_graph.dart';
import '../../interfaces/import_provider.dart';
import '../shared/import_request.dart';
import '../shared/import_result.dart';

/// Round-trip JSON import (Phase 1 scope). PDF/PNG/JPG/TIFF/SVG raster
/// import require OCR/vision pipelines and are Phase 2 (EKE migration)
/// work — see docs/EKE_MIGRATION.md, not yet created.
class JsonImportProvider implements ImportProvider {
  static const String formatId = 'json';

  @override
  bool supports(String formatId) => formatId == JsonImportProvider.formatId;

  @override
  Future<ImportResult> import(ImportRequest request) async {
    if (!supports(request.formatId)) {
      return ImportResult.failure('Unsupported import format: ${request.formatId}');
    }
    try {
      final String raw;
      if (request.bytes != null) {
        raw = utf8.decode(request.bytes!);
      } else if (request.sourcePath != null) {
        raw = await File(request.sourcePath!).readAsString();
      } else {
        return ImportResult.failure('No sourcePath or bytes provided.');
      }
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final graphJson = decoded['graph'] as Map<String, Object?>? ?? decoded;
      return ImportResult.ok(EngineeringGraph.fromJson(graphJson));
    } catch (e) {
      return ImportResult.failure('Failed to import JSON: $e');
    }
  }
}
