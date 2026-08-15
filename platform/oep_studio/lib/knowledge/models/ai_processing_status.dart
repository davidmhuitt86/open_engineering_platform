/// A Source Material's AI analysis state (Work Package 016 Connection
/// Manager: "AI Processing State"). Ephemeral — mirrors
/// `OcrProcessingStatus`'s exact shape and reasoning: a fresh launch
/// always starts idle and re-evaluates from persisted `AiSuggestion`s
/// rather than persisting "analyzing" across a restart.
enum AiProcessingStatus {
  /// No AI analysis has been run yet for this source.
  notAnalyzed,

  /// `AiAnalysisService.analyzeForSource` is currently in flight.
  analyzing,

  /// Analysis completed successfully — `AiSuggestion`s exist for this
  /// source's current evidence.
  completed,

  /// The most recent analysis attempt failed (a provider failure or a
  /// malformed response that could not be parsed).
  failed,
}
