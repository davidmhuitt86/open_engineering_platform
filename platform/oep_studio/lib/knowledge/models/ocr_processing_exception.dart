/// An OCR pipeline failure (Work Package 013) — the engine is missing,
/// a page could not be rendered, or the OCR process itself failed.
/// Studio-only, distinct from `FoundationBridgeException` (nothing here
/// ever reaches Foundation) and from `KnowledgeValidationException`
/// (this is an I/O/external-process failure, not a form-validation
/// rule) — translated from raw `ProcessException`/`IOException` the
/// same way every other external failure in this codebase is, never
/// surfaced as a raw stack trace.
class OcrProcessingException implements Exception {
  const OcrProcessingException(this.message);

  final String message;

  @override
  String toString() => 'OcrProcessingException: $message';
}
