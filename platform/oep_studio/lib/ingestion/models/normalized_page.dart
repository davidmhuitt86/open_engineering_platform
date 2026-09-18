/// One page's structural location within a [NormalizedDocument]
/// (AP-INGEST-001 § 11: "Structural information shall retain source
/// location whenever available."). Deliberately minimal for the first
/// slice — sections/headings/tables/figures are AP-INGEST-001 § 11's
/// extensibility examples, not a requirement for TRX300 (a single-page,
/// no-embedded-text-layer scan whose only structural facts a generic PDF
/// parser can determine without guessing are its own page geometry).
class NormalizedPage {
  const NormalizedPage({
    required this.pageNumber,
    required this.widthPt,
    required this.heightPt,
    required this.rotationDegrees,
    this.embeddedText = '',
  });

  /// 1-based page number, matching `OcrPageResult.page`/`pdfrx`'s own
  /// convention.
  final int pageNumber;

  final double widthPt;
  final double heightPt;

  /// The PDF page's own `/Rotate`-equivalent value, as `pdfrx` reports it
  /// — 0/90/180/270. Note this is the *viewer-level* rotation flag, not
  /// necessarily the orientation of the scanned content itself (see
  /// `reference/ingestion/trx300/source/source_manifest.json`'s
  /// `knownQualityIssues`: TRX300's content is rotated 180° in the scan
  /// itself while its `/Rotate` flag is 0 — a distinction UIF's content
  /// extraction records as a diagnostic rather than silently correcting,
  /// since correcting it would require image analysis this slice does not
  /// implement).
  final int rotationDegrees;

  /// Text pdfrx's own embedded-text-layer extraction (`PdfPage.loadText`)
  /// found on this page, if any — content extraction distinct from OCR
  /// (AP-INGEST-001 § 12 draws this line explicitly: OCR reads a
  /// rendered image, this reads a PDF's embedded text objects). Empty for
  /// a purely-scanned/rasterized page such as TRX300's, which has no
  /// embedded text layer at all (confirmed by
  /// `source_manifest.json.hasEmbeddedTextLayer: false`).
  final String embeddedText;

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'widthPt': widthPt,
    'heightPt': heightPt,
    'rotationDegrees': rotationDegrees,
    'embeddedText': embeddedText,
  };

  /// Lossless round-trip counterpart to [toJson] (WP-INGEST-008 § 5).
  /// `widthPt`/`heightPt` are read via `num` first since JSON round-trips
  /// a whole-number double (e.g. `792.0`) back as an `int`.
  factory NormalizedPage.fromJson(Map<String, dynamic> json) => NormalizedPage(
    pageNumber: json['pageNumber'] as int,
    widthPt: (json['widthPt'] as num).toDouble(),
    heightPt: (json['heightPt'] as num).toDouble(),
    rotationDegrees: json['rotationDegrees'] as int,
    embeddedText: json['embeddedText'] as String? ?? '',
  );
}
