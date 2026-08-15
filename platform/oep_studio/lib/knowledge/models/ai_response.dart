/// One provider's response to an `AiRequest` (Work Package 016
/// STUDIO-TASK-000046: "AIResponse"). Ephemeral, like `AiRequest` — see
/// that class's own doc comment for why this isn't persisted.
///
/// [rawText] is the provider's complete, unmodified output — kept
/// verbatim, never partially discarded, so a malformed or unexpected
/// response is always fully inspectable rather than silently
/// truncated ("No hidden state").
class AiResponse {
  const AiResponse({
    required this.requestId,
    required this.providerId,
    required this.modelId,
    required this.rawText,
    required this.receivedTime,
    required this.success,
    this.errorMessage,
    this.inputTokens,
    this.outputTokens,
    this.stopReason,
    this.rawMetadata,
  });

  final String requestId;
  final String providerId;
  final String modelId;
  final String rawText;
  final DateTime receivedTime;

  /// `false` if the provider itself failed (e.g. a real provider's
  /// network/timeout/rate-limit failure) — distinct from
  /// `AiSuggestionParser` later failing to parse a *successful*
  /// response's malformed content, which is a separate failure mode
  /// surfaced via `AiAnalysisException`.
  final bool success;

  final String? errorMessage;

  /// Token usage (Work Package 018 STUDIO-TASK-000059; Property
  /// Inspector: "Token Usage") — `null` for providers that don't report
  /// usage (`MockAiProvider` makes no real call, so has none to report).
  final int? inputTokens;
  final int? outputTokens;

  /// The provider's own reason the response ended (e.g. Anthropic's
  /// `stop_reason`: `"tool_use"`, `"end_turn"`, `"max_tokens"`) — `null`
  /// when not reported.
  final String? stopReason;

  /// Any further provider-specific response fields worth showing in the
  /// Property Inspector's "Response Metadata" section (e.g. Anthropic's
  /// own response `id`) — a generic bag so [AiResponse] itself stays
  /// provider-agnostic rather than growing an Anthropic-shaped field for
  /// every new provider.
  final Map<String, dynamic>? rawMetadata;
}
