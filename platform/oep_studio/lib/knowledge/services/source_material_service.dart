import 'dart:io';

import '../models/knowledge_validation_exception.dart';
import '../models/source_material.dart';
import '../models/source_material_type.dart';
import 'knowledge_session_service.dart';
import 'knowledge_session_storage.dart';

/// File-system operations for Source Material (Work Package 008
/// STUDIO-TASK-000016). "No OCR. No parsing. This work package only
/// manages engineering evidence" — this service copies files and
/// records metadata; it never reads a source's *contents*.
abstract final class SourceMaterialService {
  /// Copies the file at [pickedFilePath] (from the native file picker)
  /// into [sessionId]'s managed `sources/` directory
  /// (`KnowledgeSessionStorage.sourcesDirectory`) and returns its
  /// [SourceMaterial] record. Throws [KnowledgeValidationException] —
  /// "Invalid source files" / a missing picked file — rather than a
  /// raw [IOException].
  static Future<SourceMaterial> attach({
    required String sessionId,
    required String pickedFilePath,
    required String addedBy,
  }) async {
    final originalFile = File(pickedFilePath);
    if (!originalFile.existsSync()) {
      throw const KnowledgeValidationException('The selected file could not be found.');
    }
    final originalFileName = originalFile.uri.pathSegments.last;
    final id = KnowledgeSessionService.generateId('source');
    final targetDir = KnowledgeSessionStorage.sourcesDirectory(sessionId);
    final targetPath = '${targetDir.path}${Platform.pathSeparator}${id}_$originalFileName';
    final int sizeBytes;
    try {
      await targetDir.create(recursive: true);
      await originalFile.copy(targetPath);
      sizeBytes = await File(targetPath).length();
    } on IOException catch (error) {
      throw KnowledgeValidationException('Couldn\'t attach "$originalFileName": ${error.toString()}');
    }
    return SourceMaterial(
      id: id,
      originalFileName: originalFileName,
      localPath: targetPath,
      type: SourceMaterialType.fromExtension(originalFileName),
      sizeBytes: sizeBytes,
      importDate: DateTime.now(),
      addedBy: addedBy,
    );
  }

  /// Copies an ingestion-produced [source]'s file (Universal Ingestion
  /// Framework, WP-INGEST-005) -- whose [SourceMaterial.localPath] still
  /// points at [ReferenceVaultAdapter]'s temporary materialization at the
  /// time this is called -- into [sessionId]'s managed `sources/`
  /// directory, exactly like [attach] except that [SourceMaterial.id] is
  /// preserved rather than regenerated: UIF-produced
  /// `OcrPageResult`/`EvidenceRegion`/`EngineeringEntity`/... records
  /// already reference [source]'s id via their own `sourceId` field (see
  /// `PdfIngestionParser.parse`), so minting a new id here the way
  /// [attach] does for a freshly-picked file would silently break every
  /// one of those links.
  ///
  /// Throws [KnowledgeValidationException] if [source]'s file no longer
  /// exists or the copy fails, mirroring [attach]'s own error handling.
  static Future<SourceMaterial> attachIngestedSource({
    required String sessionId,
    required SourceMaterial source,
  }) async {
    final originalFile = File(source.localPath);
    if (!originalFile.existsSync()) {
      throw const KnowledgeValidationException('The ingested source file could not be found.');
    }
    final targetDir = KnowledgeSessionStorage.sourcesDirectory(sessionId);
    final targetPath = '${targetDir.path}${Platform.pathSeparator}${source.id}_${source.originalFileName}';
    try {
      await targetDir.create(recursive: true);
      await originalFile.copy(targetPath);
    } on IOException catch (error) {
      throw KnowledgeValidationException('Couldn\'t attach "${source.originalFileName}": ${error.toString()}');
    }
    return SourceMaterial(
      id: source.id,
      originalFileName: source.originalFileName,
      localPath: targetPath,
      type: source.type,
      sizeBytes: source.sizeBytes,
      importDate: source.importDate,
      addedBy: source.addedBy,
      extractionOrientation: source.extractionOrientation,
    );
  }

  /// Removes a source's managed copy from disk (Work Package 008 Import
  /// Queue: implied by supporting attach/detach symmetry). Best-effort
  /// — a failure here shouldn't block removing the source from the
  /// session's list, since the in-memory/persisted record is the
  /// source of truth for what Studio considers "attached."
  static Future<void> removeFile(SourceMaterial source) async {
    final file = File(source.localPath);
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } on IOException {
      // Best-effort.
    }
  }

  /// Whether a source's managed file copy still exists on disk (Work
  /// Package 008 Error Handling: "Missing source files").
  static bool exists(SourceMaterial source) => File(source.localPath).existsSync();
}
