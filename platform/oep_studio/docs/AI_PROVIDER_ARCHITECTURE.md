# AI Provider Architecture

Introduced in Work Package 016 (STUDIO-TASK-000046 AI Provider
Architecture, STUDIO-TASK-000047 Prompt Construction Service,
STUDIO-TASK-000048 AI Review Infrastructure, STUDIO-TASK-000049 Mock AI
Provider). Establishes the complete, provider-independent AI
infrastructure Knowledge Studio's AI-assisted authoring runs on. Work
Package 016 shipped it **without integrating any production AI
provider** — only `MockAiProvider`, a deterministic, in-process
implementation with zero I/O. As of Work Package 018, `AnthropicProvider`
is a real, production `AiProvider` implementation using Anthropic's
Messages API — see `docs/ANTHROPIC_PROVIDER.md` for its own
authentication/credential-storage/prompt-execution/error-handling detail;
this document covers the provider-independent architecture both
providers share.

Validates SDD-022 (Artificial Intelligence Architecture, frozen):
"Studio shall communicate only with AIProvider... No Workspace
component shall depend upon provider-specific APIs... Prompt generation
belongs entirely within the AI Analysis Service... AI shall never
automatically: Create Knowledge Candidates... API credentials shall
never be persisted inside Knowledge Sessions."

For Engineering Entities/Contexts (the deterministic evidence this
layer consumes), see `docs/ENGINEERING_ENTITY_EXTRACTION.md`/
`docs/ENGINEERING_CONTEXT.md`. For the surrounding workspace layout and
Connection Manager ownership pattern, see `docs/KNOWLEDGE_STUDIO.md`.

---

## Provider Abstraction

```dart
abstract class AiProvider {
  AiModelInfo get modelInfo;
  Future<AiResponse> complete(AiRequest request);
}
```

The *entire* contract between Studio and any AI provider — one method,
two plain-data types. A provider receives only [AiRequest]'s plain-text
`systemPrompt`/`userPrompt` strings, **never** a `SourceMaterial`/
`EngineeringEntity`/`EngineeringContext` object directly. This is what
makes "No provider-specific logic outside provider implementations"
structurally true rather than merely a convention: a provider *cannot*
depend on Studio's domain model even if it wanted to, because it is
never given one.

```dart
class AiRequest {
  final String id;
  final String systemPrompt, userPrompt;
  final String sourceId;
  final List<String> referencedEntityIds, referencedContextIds;
  final Map<String, String> evidenceLabels;  // id -> short human-readable label
  final DateTime createdTime;
}

class AiResponse {
  final String requestId, providerId, modelId;
  final String rawText;       // the provider's complete, unmodified output
  final DateTime receivedTime;
  final bool success;
  final String? errorMessage;
  // Work Package 018 — populated by real providers that report them;
  // null for MockAiProvider, which makes no real call.
  final int? inputTokens, outputTokens;
  final String? stopReason;
  final Map<String, dynamic>? rawMetadata;
}

class AiConversation {
  final AiRequest request;
  final AiResponse? response;
}

class AiModelInfo {
  final String providerId, modelId, displayName, description;
}
```

`AiConversation` bundles one request/response pair — the Connection
Manager's "AI Review State," exposed verbatim in the AI Review
Workspace's "Prompt" section, satisfying "No hidden prompts" literally:
an engineer can always see the exact text sent and the exact text
received, not a summary or reconstruction of it.

---

## Provider Registry

```dart
class AiProviderRegistry {
  AiProvider? providerFor(String providerId);
  List<AiModelInfo> get availableModels;
  static final AiProviderRegistry defaultRegistry =
      AiProviderRegistry([MockAiProvider(), AnthropicProvider()]);
}
```

The single place Studio looks up a provider by id (STUDIO-TASK-000046:
"AIProviderRegistry"). Adding a future real provider (OpenAI, Gemini,
Ollama, LM Studio, OpenRouter — SDD-022's own named list) means
registering one more entry in `defaultRegistry`'s constructor list;
nothing in the Connection Manager, the AI Review Workspace, or
`AiAnalysisService` changes — proven for real in Work Package 018, whose
entire integration point for `AnthropicProvider` was exactly this one
extra entry.

---

## Mock AI Provider

`MockAiProvider` (STUDIO-TASK-000049) is deterministic in the strict
sense: **a pure function of the request's own content** — the same
`AiRequest` always produces byte-identical `AiResponse.rawText` — not
"a canned string regardless of input." Makes zero network calls;
`complete` is `async` only to satisfy the `AiProvider` interface's
signature (which must accommodate a future real provider's genuine
network latency), not because it awaits anything.

One suggestion is generated per referenced Engineering Context (the
richer evidence unit); if a source has no detected contexts yet, one is
generated per referenced Engineering Entity instead; a source with
neither produces **zero** suggestions — the honest answer when there is
no deterministic evidence to reason about, the same "nothing to
report" precedent `ContextDetectionService`/
`EngineeringEntityExtractionService` already established for empty
input, rather than the mock fabricating a placeholder suggestion out of
nothing.

Each suggestion's candidate type is derived from a simple, explicit,
guaranteed-stable hash of the evidence's own id (`codeUnits.fold`) —
deliberately **not** `String.hashCode`, whose exact algorithm is not
part of the Dart language specification, keeping "deterministic" a
verifiable property of this provider rather than an SDK implementation
detail. The response is real, well-formed JSON matching
`PromptService`'s own requested contract (see below), produced via
`jsonEncode`, round-trippable through `AiSuggestionParser` — this is
what lets the Mock Provider exercise the *entire* pipeline (`PromptService`
→ `AiProvider` → `AiSuggestionParser` → `AiSuggestion`) end to end,
proving the abstraction genuinely works, without any network
dependency.

---

## Prompt Service

`PromptService.buildCandidateSuggestionRequest` (pure —
STUDIO-TASK-000047: "Prompt generation shall use: OCR, Engineering
Entities, Engineering Contexts... Prompt construction belongs entirely
inside services... Widgets shall never construct prompts") is the
*only* place in Studio that builds prompt text. `AiAnalysisService`
calls it; a provider only ever receives the resulting `AiRequest`'s two
plain strings.

Builds a `systemPrompt` (a fixed, replaceable template — SDD-022:
"Prompt templates shall remain replaceable" — describing the
assistant's role and required JSON output format) and a `userPrompt`
(the source's filename, an OCR text excerpt, every Engineering Context
with its child-entity summary, every Engineering Entity, and every
existing Knowledge Candidate's name). Existing Candidates are included
per SDD-022's own permissive "AI may consume: ... Existing Knowledge
Candidates" — so the model can be asked to avoid suggesting an exact
duplicate of something already curated.

The required response contract, stated directly in the system prompt:

```json
{"suggestions": [{
  "type": "component|procedure|specification|tool|material|fluid|warning|measurement|image|document",
  "name": "...", "description": "...", "confidence": 0.0-1.0,
  "reasoning": "...", "supportingEntityIds": ["..."], "supportingContextIds": ["..."]
}]}
```

With no evidence at all (no OCR text, no entities, no contexts), the
prompt says so honestly ("no OCR text available," "none detected yet")
rather than fabricating placeholder content — a real provider given
this prompt has no invented facts to reason from, matching "Never
invent facts not present in the evidence."

`AiSuggestionParser` (pure) parses a provider's raw response text
against this exact contract — deliberately strict: a malformed or
incomplete response throws `AiAnalysisException` immediately rather
than attempting a lenient best-effort parse, which would risk
fabricating a suggestion's content from ambiguous input. Every required
field (`type`, `name`, `confidence`, `reasoning`) is validated; an
unrecognized `type` string is rejected rather than silently coerced;
confidence is clamped into `0.0`–`1.0`.

---

## Review Workflow

`AiSuggestionStatus` is `pending | accepted | edited | rejected |
deferred` (STUDIO-TASK-000048) — deliberately its own, fifth vocabulary,
distinct from `EngineeringEntityStatus`/`EngineeringContextStatus`'s
`pending`/`accepted`/`ignored`. An AI suggestion is *interpretive*, not
deterministically extracted, and can genuinely be wrong in ways an
engineer needs to *correct* — hence `edited`, with no equivalent on the
deterministic Entity/Context models.

* **Accept** — creates a real Knowledge Candidate via the existing
  `addKnowledgeCandidate`, using the suggestion's effective (edited, if
  present, else AI-original) type/name/description. The *only* path
  from an AI Suggestion to a Knowledge Candidate — "No AI-generated
  Knowledge Candidates" means never *automatically*; this explicit
  engineer action is exactly what that rule permits, the same
  distinction Work Package 014 already established for accepting an
  Engineering Entity.
* **Edit** — sets `editedType`/`editedName`/`editedDescription`
  *without ever overwriting* the AI's own original
  `suggestedType`/`suggestedName`/`suggestedDescription` — the original
  suggestion remains fully inspectable alongside the correction ("No
  hidden state"). A subsequent Accept uses the edited values.
* **Reject** — flips status only; "Rejected suggestions remain
  available for auditing," never deleted, the same non-destructive
  precedent `ignoreEntity`/`ignoreContext` already established.
* **Defer** — flips status only; "not now, revisit later," distinct
  from a considered rejection.

The AI Review Workspace (`lib/knowledge/workspaces/ai_review_workspace_dialog.dart`)
is a dialog scoped to one Source Material — every AI Suggestion is
analyzed from one source's own evidence — mirroring the Entity Review
Workspace's/Context Explorer's own identical scoping choice, opened
from a new "AI Suggestions" toolbar button on the OCR Layer Viewer.
Shows Suggested Type/Name/Description/Confidence/Reasoning/Supporting
Evidence per row, a provider picker, a "Run Analysis" button, and
status filter/sort/search.

---

## Persistence

`AiSuggestion` — the persisted Workspace artifact — carries everything
SDD-022's own "AI Session Persistence" names: "Suggestion, Reasoning,
Confidence, Provider, Model, Timestamp, Review Status," plus a
`sourceFingerprint` (see below) and the edited-value fields.
`KnowledgeSessionRecord.aiSuggestions` round-trips through
`session.json` exactly like `engineeringContexts`/`engineeringEntities`
before it — backward-compatible default `[]`, no migration needed.
`KnowledgeSessionService.buildDuplicate` carries it over **unchanged**,
for the same reason: the duplicate's copied source files are
byte-identical, so the fingerprint still matches.

**`AiRequest`/`AiResponse`/`AiConversation` are deliberately *not*
persisted** — kept ephemeral as the Connection Manager's
`currentAiConversation` (the most recent analysis run only), not
written to `session.json`. Everything SDD-022 actually asks to be
persisted is already captured on the resulting `AiSuggestion`s
themselves; storing the full prompt/response text for every historical
analysis run indefinitely would be pure duplication with no
architectural requirement behind it. This is also where SDD-022's
"API credentials shall never be persisted inside Knowledge Sessions"
is trivially satisfied: since no provider in this work package uses
credentials at all (Mock needs none, and no real provider is
integrated), there is nothing credential-shaped anywhere near
`AiRequest`/`AiResponse` to begin with, and the ephemeral-only design
of these objects means a future real provider's own connection details
(read from wherever that provider chooses — outside this architecture's
concern) never flow into the request/response objects Studio persists.

**Re-analysis only when evidence changes.** `AiSuggestion.sourceFingerprint`
is a SHA-256 of the source's combined OCR fingerprint plus a sorted
signature of every entity's/context's own id and content
(`AiAnalysisService.computeCombinedFingerprint`) — a change to any
entity's normalized value or any context's title/page range changes
this fingerprint even if the underlying OCR bytes did not, since AI
analysis reasons over entities/contexts, not OCR text directly. If a
source's combined fingerprint is unchanged, `AiAnalysisService.analyzeForSource`
returns the existing suggestions completely untouched — preserving
accept/edit/reject/defer status — without calling the provider at all
("Re-analysis shall occur only when deterministic engineering evidence
changes," SDD-022). This is a whole-source cache-reuse contract, the
same one Work Package 015 established for Engineering Contexts, applied
one layer up.

### Connection Manager

`FoundationServiceState.aiSuggestions` (persisted), `selectedAiSuggestion`
(the eleventh mutually-exclusive selection field — every pre-existing
`select*` method now also clears it), `currentAiProviderId` (ephemeral,
defaults to `'mock'`), `currentAiConversation` (ephemeral), and
`aiProcessingStatus` (ephemeral, mirrors `ocrProcessingStatus`'s exact
shape). Derived getters: `aiSuggestionsForSource(sourceId)`,
`supportingEntitiesFor(suggestionId)`/`supportingContextsFor(suggestionId)`.

`runAiAnalysisForSource` requires an active session and at least one
successful OCR result — but, like context detection, does **not**
require prior entity/context extraction: analysis over OCR text alone
is still valid.

**Work Package 018** added three more coordination fields, all pure
UI/coordination state, never settings content or a credential:
`aiConnectionStatus` (`AiConnectionStatus`, defaults `notTested`),
`aiConnectionMessage` (`String?`), `currentAiModel` (`String?` — the
model actually used by the most recent request, distinct from
`AiSettings.modelId`, the *configured* model), and
`activeAiRequestSourceId` (`String?`). `testAiConnection({providerId})`
and `cancelActiveAiRequest({providerId})` resolve a provider through
`AiProviderRegistry` exactly like `runAiAnalysisForSource` does, and use
`provider is TestableAiProvider`/`provider is CancellableAiProvider` to
discover the optional capability without ever referencing
`AnthropicProvider` (or any other concrete provider) by name.

---

## Architectural Observations

* **No production AI provider is integrated in this work package by
  explicit instruction** — the entire architecture (interface, registry,
  prompt service, review workflow, persistence) is built and proven end
  to end using only `MockAiProvider`. A future work package integrating
  a real provider (OpenAI/Anthropic/Gemini/Ollama/LM Studio/OpenRouter)
  needs only to implement `AiProvider` and register it — no change to
  `AiAnalysisService`, the Connection Manager, the AI Review Workspace,
  or the Property Inspector.
* **"Accept creates a Knowledge Candidate" is a judgment call, grounded
  in SDD-022's own naming, not explicitly restated by this work
  package's own reauthored task list.** STUDIO-TASK-000048 ("AI Review
  Infrastructure") only names the five review states without literally
  saying what Accept produces. Resolved non-blockingly: SDD-022's own
  "Outputs" section names "Knowledge Candidate Suggestions" — a
  suggestion *for* a Knowledge Candidate — and this work package's own
  Objective explicitly reads "No AI-generated Knowledge Candidates" as
  "not automatically," the same distinction Work Package 014 already
  established for Engineering Entities (a Context, by contrast, never
  becomes a Candidate at all, per Work Package 015's own explicit
  Architecture Rules — so "does accepting X produce a Candidate" is
  genuinely type-specific across this codebase, not a fixed rule, and
  each work package's own text is what decides it).
* **The four-part confidence breakdown (Overall/Evidence/Entity/Context)
  named in the original, pre-reauthored version of this work package
  was dropped from the reauthored task list** (STUDIO-TASK-000049 is now
  "Mock AI Provider," not "AI Confidence Review") — `AiSuggestion` keeps
  a single `confidence: double`, the AI's own self-reported number, per
  SDD-022's own simpler "Confidence" output. Not reintroduced, since
  implementing a requirement a superseding revision of the same work
  package removed would be scope creep, not fidelity to the spec.
* **`AiRequest`/`AiResponse`/`AiConversation` are ephemeral by design,
  not persisted** — see § Persistence for the full reasoning. This
  mirrors `CommitPlan`'s own precedent (Work Package 012): a derived,
  in-memory-only object, recomputed/regenerated rather than stored,
  when nothing in the frozen architecture requires otherwise.
* **Work Package 018 proved the "no production provider" boundary was
  genuinely provider-independent**, not just true in the absence of a
  real implementation: registering `AnthropicProvider` required zero
  changes to `AiAnalysisService`, `PromptService`,
  `AiSuggestionParser`, the AI Review Workspace's review workflow, or
  the Connection Manager's existing AI methods — only one new registry
  entry, plus the additive Property Inspector/Settings/Connection
  Manager extensions documented in `docs/ANTHROPIC_PROVIDER.md`.
