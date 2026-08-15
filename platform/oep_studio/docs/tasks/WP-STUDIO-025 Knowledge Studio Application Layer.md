# WP-STUDIO-025 — Knowledge Studio Application Layer

Repository: `projects/platform/oep_studio`

## Objective

Bring Knowledge Studio to architectural parity with Diagram Studio and Engineering Acquisition Studio by introducing a centralized application layer, then register any real Knowledge Studio commands with the Command Framework (WP-STUDIO-023) so the Command Palette (WP-STUDIO-024) discovers them.

## 1. Architecture Review

**Finding: the centralized application layer already exists.** WP-STUDIO-023's architecture review concluded Knowledge Studio had "no Riverpod Notifier/Connection-Manager owning its session/candidate-review state" and registered zero commands from it. This Work Package's review found that conclusion incomplete, and corrects it:

- `FoundationRuntimeNotifier`/`FoundationRuntimeState` (`lib/core/services/foundation_runtime_service.dart`, ~2,600 lines) owns **all** of Knowledge Studio's domain state: `knowledgeSession`, `candidates`, `relationshipCandidates`, `aiSuggestions`, `evidenceLinks`, `procedureSteps`, `contexts`, `sourceMaterials`, the derived `commitPlan`, and more — plus every mutating operation on that state (`acceptKnowledgeCandidate`, `deleteKnowledgeCandidate`, `acceptAiSuggestion`, `duplicateKnowledgeSession`, `commitToFoundation`, dozens more).
- It is the **sole caller** of Knowledge Studio's stateless business-logic classes. A repo-wide search for direct instantiation of `KnowledgeSessionService`, `CommitPlanService`, `CommitTransactionService`, `AiAnalysisService`, `ContextDetectionService`, `EntityValidationService`, `KnowledgeGraphService`, `OcrPipelineService`, `ProvenanceService`, `SessionHealthService`, and others across `lib/knowledge/` returned **zero matches** — these are pure, stateless (`abstract final class` with only `static` methods, e.g. `CommitPlanService.computeCommitPlan(...)`) and are only ever invoked from inside `FoundationRuntimeNotifier`/`FoundationRuntimeState`.
- Every one of Knowledge Studio's 16 stateful dialogs/panels (`ai_review_workspace_dialog`, `commit_preview_panel`, `context_explorer_dialog`, `evidence_browser_dialog`, `knowledge_graph_dialog`, `procedure_builder_dialog`, `specification_editor_dialog`, `engineering_review_panel`, both candidate form dialogs, `new_session_dialog`, `session_browser_dialog`, `entity_review_workspace_dialog`, and the rest) was checked and **every one reads or calls `foundationRuntimeServiceProvider` exclusively** for business state/actions — verified by grep, not assumed. Their own local `setState` fields are legitimate, ephemeral view-only state (filter/sort/search text, a transient error message) rather than a duplicated copy of domain state.

**Conclusion**: Knowledge Studio already has a centralized controller and its UI already delegates to it — the *substance* of parity with Diagram Studio (`EngineeringProjectNotifier`) and Acquisition Studio (`AcquisitionRuntimeNotifier`) already exists. The one real gap was that Knowledge Studio's real, already-existing operations had never been exposed to the Command Framework — because WP-STUDIO-023 looked for a Knowledge-*Studio-scoped* Notifier and, not finding one, stopped short of checking whether Knowledge Studio's state was centralized somewhere else instead.

## 2. Controller/Runtime Implementation

**No new controller was created or extended with new methods** — per the Requirements ("do not invent new features," "do not duplicate existing architecture"), and because the existing `FoundationRuntimeNotifier` already provides everything needed. Creating a parallel `KnowledgeStudioNotifier` would have duplicated state that already lives in one place and would have required a much larger, riskier migration for no behavioral gain.

## 3. UI Refactor

**None was needed or performed.** Verified (§1) that every Knowledge Studio UI component already delegates business logic to `FoundationRuntimeNotifier`; there was no local-state/direct-service-call pattern to extract. This is a real finding (task 4 was already satisfied), not an omission.

## 4. Command Framework Integration

Five real, already-existing `FoundationRuntimeNotifier` methods were registered in [lib/core/commands/command_registry.dart](lib/core/commands/command_registry.dart), each a clean `Future<void>|void Function(String)` reachable via `ref.read(foundationRuntimeServiceProvider.notifier)`:

| Command id | Wraps | Capability |
|---|---|---|
| `knowledge.acceptCandidate` | `acceptKnowledgeCandidate(id)` | `knowledge.review` |
| `knowledge.rejectCandidate` | `rejectKnowledgeCandidate(id)` | `knowledge.review` |
| `knowledge.deleteCandidate` | `deleteKnowledgeCandidate(id)` | `knowledge.review` |
| `knowledge.acceptAiSuggestion` | `acceptAiSuggestion(id)` | `knowledge.aiAssistance` |
| `knowledge.rejectAiSuggestion` | `rejectAiSuggestion(id)` | `knowledge.aiAssistance` |

All five require an argument (a candidate or suggestion id) and were verified for graceful failure modes before registering: `accept/rejectKnowledgeCandidate`/`deleteKnowledgeCandidate`/`rejectAiSuggestion` silently no-op on an unknown id (matching `diagram.undo`'s existing no-op precedent); `acceptAiSuggestion` throws `KnowledgeValidationException` for an unknown or already-accepted suggestion, which `CommandRegistry.execute`'s existing `try`/`catch` already turns into `CommandOutcome.failure` — no new error handling was needed.

**Not registered**: `duplicateKnowledgeSession(id)`/`deleteKnowledgeSession(id)` are equally real and clean, but session lifecycle isn't covered by any of WP-STUDIO-022's four Knowledge capabilities (`sourceIngestion`/`aiAssistance`/`evidence`/`review`), all of which describe activity *within* a session rather than managing the session itself. `CommandRegistry.validate()` requires every `capabilityId` to resolve to a real, registered capability — stretching an existing one's meaning or adding a new one were both judged out of scope for this Work Package (see Recommendations).

## 5. Command Palette Auto-Discovery (task 6)

No changes to the Command Palette were needed — it already reads `CommandRegistry.defaultRegistry.commands`/`commandsForStudio`/`ownerOf`/`findCapability` generically (WP-STUDIO-024), so the five new commands appeared automatically. Verified with a new test searching "Knowledge Studio" in the palette and confirming `Accept Knowledge Candidate` is discoverable with zero palette code changes.

## 6. Validation Results

- `flutter analyze`: 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere).
- `flutter test`: **358/358 passed** (357 prior + 1 net new; 2 pre-existing unrelated skips). Updated `test/command_registry_test.dart`'s stale "Knowledge Studio has zero commands" assertion to the real 5; updated `test/command_palette_dialog_test.dart`'s hardcoded command count (13 → 18) and added a Knowledge-Studio-discovery search test.
- `flutter build windows`: succeeded.
- Confirmed no Studio was redesigned, no UI was redesigned, and no new architecture was duplicated — the diff is limited to `command_registry.dart` (5 new descriptors + 1 import) and two test files.

## 7. Recommendations for WP-STUDIO-026

- **`FoundationRuntimeNotifier` is a shared, multi-concern controller** — it owns Foundation's own repository-connection/search/audit state *and* the entirety of Knowledge Studio's domain state in one class. This is real technical debt (a single-responsibility violation, and the reason WP-STUDIO-023's review missed it as Knowledge Studio's controller in the first place) but splitting it is a large, high-risk refactor with a huge blast radius — out of scope here per "do not redesign any Studio." Worth a dedicated, carefully-scoped future Work Package if Foundation and Knowledge Studio's concerns need to evolve independently.
- **Session lifecycle commands** (`duplicateKnowledgeSession`, `deleteKnowledgeSession`) are real and clean but capability-less. Either add a `knowledge.sessionManagement` capability (extending WP-STUDIO-022) or fold session lifecycle under an existing capability's definition, then register these two commands.
- **`editAiSuggestion`/`ignoreContext`/`acceptContext`/`splitContext`/evidence-link operations** are further real, already-existing `FoundationRuntimeNotifier` methods not evaluated for command registration in this pass (scope was kept to the clearest, most review/AI-centric operations); a follow-up pass could extend coverage once the session-management capability question above is resolved.
- Per this Work Package's own instruction, do not begin another Work Package without authorization, and no commit has been made.
