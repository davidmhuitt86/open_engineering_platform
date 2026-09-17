/// The logical artifact classification vocabulary UIF uses to select a
/// parser (AP-INGEST-001 § 5.3 `VaultObjectInput.artifactType`,
/// WP-INGEST-001 § 6.1). Deliberately the same extensible taxonomy the
/// architecture document lists — this enum exists so parser selection has
/// something typed to switch on, not to define a new artifact ontology.
///
/// Only [pdf] has a working parser in this first vertical slice
/// (WP-INGEST-001 § 8.1: "For the first slice, implement only the parser
/// required for the TRX300 PDF. Do not create a large parser catalog.").
/// The remaining values exist so [ArtifactType.fromMimeType] can describe
/// an artifact UIF does not yet know how to parse, rather than needing a
/// separate "unsupported" sentinel.
enum ArtifactType {
  pdf,
  image,
  cad,
  officeDocument,
  csv,
  xml,
  json,
  yaml,
  engineeringLog,
  firmware,
  softwareArchive,
  audio,
  video,
  unknown;

  /// Identification (AP-INGEST-001 § 9): classifies a MIME type into the
  /// canonical artifact taxonomy. Descriptive only — "Identification is
  /// descriptive. It does not establish engineering truth."
  static ArtifactType fromMimeType(String mimeType) {
    final normalized = mimeType.trim().toLowerCase();
    return switch (normalized) {
      'application/pdf' => ArtifactType.pdf,
      'image/png' || 'image/jpeg' || 'image/tiff' || 'image/bmp' || 'image/webp' => ArtifactType.image,
      'text/csv' => ArtifactType.csv,
      'application/xml' || 'text/xml' => ArtifactType.xml,
      'application/json' => ArtifactType.json,
      'application/x-yaml' || 'text/yaml' => ArtifactType.yaml,
      _ => ArtifactType.unknown,
    };
  }
}
