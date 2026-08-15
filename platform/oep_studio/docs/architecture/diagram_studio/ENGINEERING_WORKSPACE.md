# Diagram Studio — Engineering Intelligence Workspace

**Architecture Phase:** AP-DS-003. Covers the spec's Validation Integration / Analysis Integration / Reasoning Integration / Recommendation System documentation requirements in one coherent document, since all four are facets of the same integration mechanism.

## What changed

Diagram Studio is now an active Engineering Intelligence Workspace, not just a repository-backed editor. The engineer receives live validation, analysis, reasoning, and recommendation feedback while authoring — sourced exclusively from the Engineering Intelligence Platform (EIP), never computed locally.

## The one rule this phase enforces throughout

**No engineering logic exists anywhere in Diagram Studio.** Every validation rule, analysis algorithm, reasoning step, and recommendation originates from EIP, reached through exactly one class: `DiagramIntelligenceService` (`lib/diagram_studio/intelligence/diagram_intelligence_service.dart`). This class contains zero domain logic of its own — it is pure orchestration: sync the canvas graph to Foundation, keep one Knowledge Session alive, translate between canvas node ids and Foundation object ids, and forward every call to the appropriate `FoundationBridge`/EIP method. If a future reviewer ever finds validation/analysis/reasoning logic anywhere else in `oep_studio`, that is an architecture violation to be corrected, not a pattern to extend.

## The sync problem this phase had to solve

EIP operates on Foundation's real repository — Engineering Objects and Relationships — never on Diagram Studio's in-memory `EngineeringGraph` directly. But AP-DS-002 left the document bar's Open/Save wiring as a documented, real gap (local JSON remained the primary interactive path; repository persistence existed but wasn't wired to the user-facing Save button). Live feedback "while authoring" cannot wait for the user to have manually completed that still-missing Save flow.

**Resolution**: `DiagramRepositoryService` gained a second write path, `syncForIntelligence`, alongside the pre-existing `saveDiagram` — same transaction-wrapped create/update-and-decompose logic, but triggered automatically (debounced 800ms after edits, via `scheduleSync`) rather than only on explicit user Save. This creates and maintains a working, Foundation-backed shadow copy of the diagram specifically to feed EIP, independent of whatever the user's own Save/Save-As state is. The two paths share all their underlying logic (`_decomposeIntoObjects`/`_clearDecomposedObjects`) — this is not a second, divergent persistence mechanism, just a second trigger for the same one.

## Validation Integration

`DiagramIntelligenceService.validate({ValidationProfile profile})` → `FoundationBridge.eipValidate` → `ValidationEngine` (frozen since WP-EKE-005). Supports manual (`_validateNow()`, wired to a "Validate Now" toolbar button), automatic-after-edit (via `scheduleSync`'s debounce, triggered from every `_markDirty()` call site — ~30 of them, all mutating Engine Commands), and — because `scheduleSync` batches rapid edits into one sync — effectively background/incremental validation without a validation pass per keystroke. Findings are presented via `DiagramIntelligenceOverlay` (canvas error/warning markers, hover/tap-to-inspect) and the existing `diagram_validation_panel.dart` remains for the diagram's own local structural checks — a separate, pre-existing, still-valid system (AP-DS-001's `ENGINEERING_MODEL.md` already documented these as two different "validation" concepts sharing a name; this phase did not merge them, and that distinction remains real).

## Analysis Integration

`DiagramIntelligenceService.analyzeNode(nodeId)` → `FoundationBridge.eipAnalyze` → `AnalysisEngine` (Dependency/Impact/Reachability/Root-Cause, frozen since WP-EKE-006). Results render as a distinct glow/outline overlay on affected canvas nodes (`DiagramIntelligenceOverlay`, visually distinguishable from validation markers and normal selection) and in the embedded panels.

## Reasoning Integration

`DiagramIntelligenceService.reason({objective, startingNodeIds})` → `FoundationBridge.eipReason` → `ReasoningEngine` (frozen since WP-EKE-006). Conclusions/confidence/evidence are exactly what `OepWorkflowResult` + the EIP session already exposed to the pre-existing read-only `lib/engineering_intelligence/pages/reasoning_dashboard_page.dart` — this phase's panels reuse that same rendering, not a new one.

## Recommendation System

`DiagramIntelligenceService.recommendForNode(nodeId)` → `FoundationBridge.eipRecommend`. `RecommendationPanel` (`lib/diagram_studio/panels/recommendation_panel.dart`) presents whatever fields the underlying EIP call actually returns — supporting evidence, validation findings, related objects/rules, confidence — honestly limited to what `OepWorkflowResult`'s summary/object-id shape provides (a coarse text summary plus a related-object-id list), not an invented richer structure the API doesn't have.

## Engineering Explorer, Knowledge Graph, Query Console, Knowledge Sessions

Four more embedded panels (`engineering_explorer_panel.dart`, `knowledge_graph_panel.dart`, `query_console_panel.dart`, `knowledge_sessions_panel.dart`), each adapting the corresponding pre-existing read-only page from `lib/engineering_intelligence/pages/` (built WP-EKE-008) rather than reinventing rendering. `knowledge_sessions_panel.dart` is the one panel that takes `FoundationBridge` directly (not just `DiagramIntelligenceService`) — session lifecycle (create/resume/clone/close/list/export) is deliberately not wrapped by `DiagramIntelligenceService`, since that class exists to orchestrate diagram-scoped workflow calls, not general session administration.

## Selection synchronization

`objectIdFor`/`nodeIdFor` on `DiagramIntelligenceService` are the only translation point between canvas node ids and Foundation object ids. Every panel takes `onSelectNode` (canvas frames/selects the corresponding node) and `selectedNodeId` (canvas selection highlights the corresponding panel entry) — the same select+frame pattern already established for search results (`_goToSearchResult`) and reused, not reinvented, for this phase's five new panels plus the canvas overlay.

## Performance / asynchrony

Every `DiagramIntelligenceService` method is `async`/returns a `Future`; none are called synchronously inside a `build()` or gesture callback. Edits are debounced (800ms) into infrequent sync calls rather than one EIP round-trip per keystroke. **Honest disclosure, not glossed over**: the underlying FFI calls still execute synchronously on the calling isolate — this codebase has no precedent anywhere for cross-isolate `dart:ffi` dispatch, and introducing one was a materially larger change than this phase's scope. Responsiveness comes from debouncing and never blocking mid-frame, not from true parallelism. Real interactive-scale EIP latency under this design has not been benchmarked (the existing `PERFORMANCE_REPORT.md`'s headless-proxy limitation applies here too) — a real gap for a future phase to close with live profiling.

## Known limitations (disclosed, not hidden)

1. FFI-dependent code (`DiagramIntelligenceService`, all 5 panels, the overlay's live-data paths) cannot be exercised under `flutter test` — this codebase's established, disclosed limitation (no test loads the real native DLL). What IS tested: pure rendering logic given synthetic data, the overlay's coordinate-transform math, and shared widget behavior.
2. True async (cross-isolate FFI) was not attempted — see Performance section above.
3. The document-bar Open/Save gap AP-DS-002 left open remains open; `syncForIntelligence` works around it for the intelligence-feed purpose specifically, it does not close it.
4. `RecommendationPanel`'s field set is limited to what `OepWorkflowResult` actually returns, which is coarser than the spec's own bullet list (Supporting evidence/Validation findings/Related Objects/Related Rules/Confidence) might imply if read as requiring five independently-structured fields — see `recommendation_panel.dart`'s own code for exactly what's real vs. summarized text.
