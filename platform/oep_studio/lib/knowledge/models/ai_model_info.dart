/// Describes one AI model/provider combination (Work Package 016
/// STUDIO-TASK-000046: "AIModelInfo"). Purely descriptive metadata —
/// Studio never branches on [providerId] outside the provider
/// implementation itself ("No provider-specific logic outside provider
/// implementations").
class AiModelInfo {
  const AiModelInfo({
    required this.providerId,
    required this.modelId,
    required this.displayName,
    required this.description,
  });

  /// e.g. `'mock'` — identifies which `AiProvider` produced this
  /// metadata, for `AiProviderRegistry` lookup and for persisted
  /// `AiSuggestion.providerId`/`AiSuggestion.modelId` traceability.
  final String providerId;

  /// e.g. `'mock-deterministic-v1'`.
  final String modelId;

  /// e.g. `'Mock Deterministic Provider'` — shown in the AI Review
  /// Workspace's provider picker and the Property Inspector's
  /// "Provider Metadata" section.
  final String displayName;

  final String description;
}
