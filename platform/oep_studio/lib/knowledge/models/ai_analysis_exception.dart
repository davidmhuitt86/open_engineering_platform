/// An AI analysis failure (Work Package 016) — a provider failure
/// (`AiResponse.success == false`) or a successful response whose
/// [AiSuggestionParser] could not parse into valid suggestions.
/// Studio-only, distinct from `FoundationBridgeException` (nothing
/// here ever reaches Foundation) and from `KnowledgeValidationException`
/// (this is a provider/parsing failure, not a form-validation rule) —
/// translated into a professional message the same way every other
/// external-process/parsing failure in this codebase already is
/// (`OcrProcessingException`, `TesseractTsvParser`'s own
/// `FormatException` handling).
class AiAnalysisException implements Exception {
  const AiAnalysisException(this.message);

  final String message;

  @override
  String toString() => 'AiAnalysisException: $message';
}
