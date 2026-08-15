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
