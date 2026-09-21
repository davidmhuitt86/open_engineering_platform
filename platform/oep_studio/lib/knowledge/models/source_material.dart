import 'document_orientation.dart';
import 'source_material_type.dart';

/// A piece of engineering evidence attached to a Knowledge Curation
/// Session (Work Package 008 STUDIO-TASK-000016 Source Metadata:
/// "UUID, Original File Name, Local Path, Import Date, Added By").
///
/// Studio copies the file into the session's own storage directory at
/// attach time (`docs/KNOWLEDGE_SESSION_FORMAT.md` § Source Material
/// Storage) rather than referencing the originally-picked path, so a
/// session remains self-contained and the original file may be moved
/// or deleted without breaking it. [localPath] is that managed copy's
/// path — what Work Package 008's Error Handling calls out as
/// "Missing source files" refers to this managed copy going missing
/// (e.g. the session directory was tampered with outside Studio), not
/// the original file the engineer picked.
class SourceMaterial {
  const SourceMaterial({
    required this.id,
    required this.originalFileName,
    required this.localPath,
    required this.type,
    required this.sizeBytes,
    required this.importDate,
    required this.addedBy,
    this.extractionOrientation = DocumentOrientation.deg0,
  });

  final String id;
  final String originalFileName;
  final String localPath;
  final SourceMaterialType type;
  final int sizeBytes;
  final DateTime importDate;
  final String addedBy;

  /// Persistent Extraction Orientation: the coordinate frame (OCR, entities,
  /// evidence regions) recorded for this source. The stored file is never
  /// rewritten. Omitted from JSON when 0; missing means 0.
  final DocumentOrientation extractionOrientation;

  SourceMaterial withExtractionOrientation(DocumentOrientation orientation) => SourceMaterial(
    id: id,
    originalFileName: originalFileName,
    localPath: localPath,
    type: type,
    sizeBytes: sizeBytes,
    importDate: importDate,
    addedBy: addedBy,
    extractionOrientation: orientation,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalFileName': originalFileName,
    'localPath': localPath,
    'type': type.name,
    'sizeBytes': sizeBytes,
    'importDate': importDate.toIso8601String(),
    'addedBy': addedBy,
    if (extractionOrientation != DocumentOrientation.deg0) 'extractionOrientation': extractionOrientation.degrees,
  };

  factory SourceMaterial.fromJson(Map<String, dynamic> json) {
    return SourceMaterial(
      id: json['id'] as String,
      originalFileName: json['originalFileName'] as String,
      localPath: json['localPath'] as String,
      type: SourceMaterialType.values.byName(json['type'] as String),
      sizeBytes: json['sizeBytes'] as int,
      importDate: DateTime.parse(json['importDate'] as String),
      addedBy: json['addedBy'] as String,
      extractionOrientation: DocumentOrientation.fromDegrees(json['extractionOrientation'] as int? ?? 0),
    );
  }
}
