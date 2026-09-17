/// Normalized document metadata (AP-INGEST-001 § 10, WP-INGEST-001
/// § 18/TEST-004). Only fields a generic PDF parser can determine without
/// guessing are populated for TRX300 — `title`/`author`/`publicationDate`
/// etc. remain `null` rather than being fabricated, since this PDF was
/// produced by "Microsoft: Print To PDF" from a scan and carries none of
/// that in a form a generic parser can read (see
/// `source_manifest.json.pdfProducer`/`pdfCreator: null`).
///
/// "Metadata extracted during ingestion must remain distinguishable from
/// immutable acquisition metadata" (AP-INGEST-001 § 10) — this class is
/// that distinguishable, UIF-derived side; [VaultObjectInput.immutableMetadataSnapshot]
/// remains the untouched acquisition-time side, and [IngestionResult]
/// keeps both as separate fields rather than merging them.
class NormalizedMetadata {
  const NormalizedMetadata({
    this.title,
    this.author,
    this.organization,
    this.publicationDate,
    this.revision,
    this.keywords = const [],
    this.productFamily,
    this.manufacturer,
    this.documentIdentifiers = const [],
    this.language,
    this.documentType,
    required this.pageCount,
    required this.sourceFileName,
    required this.sizeBytes,
    required this.mimeType,
    required this.contentHash,
  });

  final String? title;
  final String? author;
  final String? organization;
  final String? publicationDate;
  final String? revision;
  final List<String> keywords;
  final String? productFamily;
  final String? manufacturer;
  final List<String> documentIdentifiers;
  final String? language;
  final String? documentType;

  final int pageCount;
  final String sourceFileName;
  final int sizeBytes;
  final String mimeType;
  final String contentHash;

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'organization': organization,
    'publicationDate': publicationDate,
    'revision': revision,
    'keywords': keywords,
    'productFamily': productFamily,
    'manufacturer': manufacturer,
    'documentIdentifiers': documentIdentifiers,
    'language': language,
    'documentType': documentType,
    'pageCount': pageCount,
    'sourceFileName': sourceFileName,
    'sizeBytes': sizeBytes,
    'mimeType': mimeType,
    'contentHash': contentHash,
  };
}
