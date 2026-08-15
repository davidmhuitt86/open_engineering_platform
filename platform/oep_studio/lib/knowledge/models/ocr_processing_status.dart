/// A Source Material's OCR processing state (Work Package 013
/// Connection Manager: "OCR state"). Ephemeral — describes whether a
/// background OCR run is currently in flight for a source, never
/// persisted (persisting "processing" across an application restart
/// would be meaningless; a fresh launch always starts idle and
/// re-evaluates the cache — see `docs/OCR_PIPELINE.md` § OCR Cache).
enum OcrProcessingStatus {
  /// No OCR result exists yet for this source and no run is in flight.
  notProcessed,

  /// A run is currently in flight (`OcrPipelineService.processSource`).
  processing,

  /// Every page has a valid, up-to-date cached result.
  completed,

  /// The most recent run failed (e.g. Tesseract is not installed, or a
  /// page could not be rendered) — see [OcrPageResult].
  failed,
}
