import 'ocr_word.dart';

/// OCR output for one page of one Source Material (Work Package 013
/// STUDIO-TASK-000034/000037). "OCR results remain attached to Source
/// Material" — this is the unit that persists with the Knowledge
/// Session (`KnowledgeSessionRecord.ocrPageResults`) and the unit the
/// cache invalidates at ([sourceFingerprint]).
///
/// A single-page image Source Material (PNG/JPG/TIFF) always produces
/// exactly one [OcrPageResult] with [page] `1`. A PDF Source Material
/// produces one per page, matching `pdfrx`'s own 1-based
/// `PdfPage.pageNumber` — the same convention `EvidenceRegion.page`
/// already uses.
class OcrPageResult {
  const OcrPageResult({
    required this.sourceId,
    required this.page,
    required this.words,
    required this.imageWidth,
    required this.imageHeight,
    required this.sourceFingerprint,
    required this.engineVersion,
    required this.processedTime,
    required this.success,
    this.errorMessage,
  });

  /// The [SourceMaterial.id] this result belongs to.
  final String sourceId;

  /// 1-based page number.
  final int page;

  /// Every recognized word on this page, already in reading order (see
  /// [OcrWord.readingOrder]). Empty for a blank page or a failed run —
  /// see [success].
  final List<OcrWord> words;

  /// The pixel dimensions of the image OCR actually ran against —
  /// needed to size the OCR Layer Viewer's overlay/placeholder canvas
  /// for a source type Studio cannot itself preview (see
  /// `docs/OCR_PIPELINE.md` § Architectural Observations, the TIFF
  /// preview gap). Not the *display* size — [OcrWord.boundingBox] is
  /// already a resolution-independent fraction of this.
  final int imageWidth;
  final int imageHeight;

  /// A SHA-256 hex digest of the Source Material file's bytes at the
  /// moment this result was produced (`docs/OCR_PIPELINE.md` § OCR
  /// Cache). Compared against the file's *current* content on every
  /// cache-validity check ([OcrCacheService.isCacheValid]) — a mismatch
  /// means the file changed since OCR last ran, and this result must be
  /// recomputed. Content-based, not file-system-metadata-based (size/
  /// mtime), specifically so duplicating a session (a byte-for-byte
  /// file copy, `File.copy`) does not spuriously invalidate a cache that
  /// is, in fact, still perfectly valid.
  final String sourceFingerprint;

  /// e.g. `"Tesseract 5.4.0.20240606"` — which OCR engine/version
  /// produced this result, for the Property Inspector's "OCR metadata"
  /// (Work Package 013 Property Inspector requirement) and so a
  /// future engine change is visible in already-cached data rather than
  /// silently indistinguishable from it.
  final String engineVersion;

  final DateTime processedTime;

  /// `false` if this page could not be processed (e.g. the page failed
  /// to render, or the OCR engine process exited non-zero) — [words] is
  /// always empty in that case and [errorMessage] explains why. A
  /// failed page still gets a stored, dated record (mirroring
  /// `CommitReport`'s "the report still exists even on failure") rather
  /// than being silently omitted, so re-opening the OCR Layer Viewer
  /// shows *why* a page has no text instead of looking unprocessed.
  final bool success;
  final String? errorMessage;

  /// The mean of every word's [OcrWord.confidence] on this page, or `0`
  /// for an empty/failed page (`docs/OCR_PIPELINE.md` § Confidence
  /// Model — the same honest-zero convention `CommitPlan.mergeOperationCount`
  /// and others in this codebase already use for "nothing to average").
  double get averageConfidence {
    if (words.isEmpty) return 0;
    return words.map((word) => word.confidence).reduce((a, b) => a + b) / words.length;
  }

  /// Reconstructs readable text from [words] — a newline between
  /// consecutive words on different [OcrWord.lineIndex] values, a
  /// single space otherwise. Never stored; always derived, so nothing
  /// about persistence depends on this exact joining rule.
  String get plainText {
    if (words.isEmpty) return '';
    final buffer = StringBuffer(words.first.text);
    for (var i = 1; i < words.length; i++) {
      buffer.write(words[i].lineIndex != words[i - 1].lineIndex ? '\n' : ' ');
      buffer.write(words[i].text);
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'page': page,
    'words': words.map((word) => word.toJson()).toList(),
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'sourceFingerprint': sourceFingerprint,
    'engineVersion': engineVersion,
    'processedTime': processedTime.toIso8601String(),
    'success': success,
    'errorMessage': errorMessage,
  };

  factory OcrPageResult.fromJson(Map<String, dynamic> json) {
    final wordsJson = json['words'] as List<dynamic>? ?? const [];
    return OcrPageResult(
      sourceId: json['sourceId'] as String,
      page: json['page'] as int,
      words: [for (final entry in wordsJson) OcrWord.fromJson(entry as Map<String, dynamic>)],
      imageWidth: json['imageWidth'] as int,
      imageHeight: json['imageHeight'] as int,
      sourceFingerprint: json['sourceFingerprint'] as String,
      engineVersion: json['engineVersion'] as String,
      processedTime: DateTime.parse(json['processedTime'] as String),
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
