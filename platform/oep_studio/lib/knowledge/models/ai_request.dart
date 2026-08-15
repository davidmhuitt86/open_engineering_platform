/// One request built by `PromptService` for an `AiProvider`
/// (Work Package 016 STUDIO-TASK-000046: "AIRequest"). Ephemeral —
/// kept only as the active `AiConversation`'s own request, never
/// persisted with the Knowledge Session (mirrors `CommitPlan`'s own
/// derived-not-stored precedent) — everything worth keeping long-term
/// about the analysis this request produced is already captured on the
/// resulting `AiSuggestion`s themselves (provider id, model id,
/// timestamp — see `docs/AI_PROVIDER_ARCHITECTURE.md` § Persistence).
///
/// [systemPrompt]/[userPrompt] are plain text — this is the *entire*
/// contract between Studio and a provider ("No hidden prompts"): a
/// provider implementation only ever sees these two strings, never a
/// `SourceMaterial`/`EngineeringEntity`/`EngineeringContext` object
/// directly, keeping every provider implementation fully decoupled
/// from Studio's own domain model.
class AiRequest {
  const AiRequest({
    required this.id,
    required this.systemPrompt,
    required this.userPrompt,
    required this.sourceId,
    required this.referencedEntityIds,
    required this.referencedContextIds,
    required this.evidenceLabels,
    required this.createdTime,
  });

  final String id;
  final String systemPrompt;
  final String userPrompt;

  /// The `SourceMaterial.id` this request's evidence was drawn from.
  final String sourceId;

  /// The `EngineeringEntity.id`s this request's prompt referenced —
  /// for traceability only (`PromptService` builds this list; a
  /// provider never sees the ids themselves, only [userPrompt]'s text).
  final List<String> referencedEntityIds;

  /// The `EngineeringContext.id`s this request's prompt referenced.
  final List<String> referencedContextIds;

  /// A short, human-readable label per referenced entity/context id
  /// (e.g. an entity's normalized value, a context's title) — lets the
  /// AI Review Workspace's "Supporting Evidence" display remain
  /// meaningful even if the underlying evidence is later removed, and
  /// gives `MockAiProvider` real text to build a suggestion's name/
  /// reasoning from without depending on Studio's domain model classes.
  final Map<String, String> evidenceLabels;

  final DateTime createdTime;
}
