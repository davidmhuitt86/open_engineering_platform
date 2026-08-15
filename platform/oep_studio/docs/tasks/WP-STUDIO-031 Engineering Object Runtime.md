# WP-STUDIO-031 — Engineering Object Runtime

Repository: `projects/platform/oep_studio`

## Objective

Implement the Engineering Object Runtime as the shared runtime responsible for loading, caching, observing, and coordinating Engineering Objects for every Studio, reusing the existing Repository architecture rather than redesigning it.

## 1. Architecture Review

- **Where Engineering Objects actually live today**: `EngineeringObjectSummary`/`RelationshipSummary` (`lib/core/models/`) mirror `oep_object_info_t`/`oep_relationship_info_t` (`oep_api.h`) field-for-field, decoded by `FoundationBridge` (the FFI boundary, Work Package 002) from the native `OEP_Runtime`. `FoundationRuntimeNotifier` (`FoundationServiceState.objectList`/`relationshipList`) is the Repository's Current Object List/Current Relationship List (Work Package 004/006) — fetched by `_refreshRepositoryData` on open/close/refresh, nowhere else. This is "the Repository" this Work Package must not redesign, and it is untouched here: no change to `FoundationBridge`, `EngineeringObjectSummary`, `RelationshipSummary`, or any `FoundationRuntimeNotifier` method.
- **Who already reads this data, and how**: only Knowledge/Repository-area widgets (`ObjectsPage`, `PropertyInspectorPanel`, the Repository/Relationship Explorer pages) `ref.watch(foundationRuntimeServiceProvider)` directly — appropriate, since those pages *are* about that state. But three separate Platform-level navigation call sites also needed to look an object or relationship up **by id**, and each did its own linear scan rather than sharing one lookup:
  - `explorer_navigation.dart`'s `goToObject`/`goToRelationship` — a private `_findById<T>` helper, called once each.
  - `unified_navigation.dart`'s `goToKnowledgeObject` — its own inline `.where((o) => o.objectId == id).firstOrNull`, not reusing `_findById`.
  - `unified_navigation.dart`'s `goToValidationResult` — `.any((o) => o.objectId == subjectId)`, a third independent scan.
  - `unified_navigation.dart`'s `goToKnowledgeRelationship` — a fourth independent scan, over `relationshipList` this time.

  This is real, concrete duplicated object-loading/lookup logic (task 9's target), not a hypothetical — four call sites, three of them not even sharing the one existing helper meant to prevent exactly this.
- **What "Engineering Object Runtime" should and shouldn't be**: given "keep the Runtime lightweight," "avoid unnecessary abstractions," and "do not redesign Engineering Objects/the Repository," the correct scope is an O(1)-by-id **read layer** over the two lists `FoundationRuntimeNotifier` already owns and fetches — not a second fetch path, not a new task queue, not a rewrite of `EngineeringObjectSummary`.

## 2. EngineeringObjectRuntime

New file: [lib/core/objects/engineering_object_runtime.dart](lib/core/objects/engineering_object_runtime.dart). Fetches nothing itself and has no `open`/`close`/`refresh` method — those stay exactly where they are, in `FoundationRuntimeNotifier`. Fed via one method, `updateFromFoundationState(FoundationServiceState)`, called from `StudioShell`'s existing Foundation Bridge listener (§7).

## 3. Runtime Cache

Rebuilds three lookup structures (`Map<String, EngineeringObjectSummary>` by `objectId`, `Map<String, RelationshipSummary>` by `relationshipId`, and a `Map<String, List<RelationshipSummary>>` multimap by object id for both source and target sides) only when `objectList`/`relationshipList` actually changed **by reference** (`identical`) since the last call — the far more frequent unrelated `FoundationServiceState` changes (AI suggestions, OCR status, selection, search) are a no-op here, since `copyWith` reuses the same list reference when neither field is being replaced. This is the "lightweight caching" this Work Package asks for: no polling, no diffing by value, no rebuild on every Foundation state tick.

## 4. Object Observation

`Stream<void> get changes`, fired only after the cache has already been rebuilt — the same read-after-write guarantee `OperationManager.changes`/`ActivityLog.changes`/`NotificationCenter.changes` (WP-STUDIO-030) already established, so a listener (a future Studio widget) always sees already-consistent state. No per-object stream was added — a single `changes` broadcast, like every other Platform singleton's, is sufficient for a widget to `setState` in response; per-id streams would be an abstraction this Work Package's own "avoid unnecessary abstractions" requirement argues against.

## 5. Relationship Helpers

`relationshipsInvolving(objectId)` — every relationship where `objectId` is the source or the target (a relationship with `sourceObjectId == targetObjectId` is listed once, not twice). This is the one cross-object query Studios need that a flat `relationships` list doesn't answer directly, and the one genuinely new capability this Work Package adds — nothing analogous existed before this Work Package.

## 6. Runtime API for Studios

The Runtime's public surface **is** the Studio-facing API — no separate wrapper class, per "avoid unnecessary abstractions": `objects`/`relationships` (raw passthrough), `objectById`/`hasObject`/`relationshipById` (O(1) lookup), `objectsInCategory(category)` (a parameterized counterpart to `FoundationServiceState.objectsInSelectedCategory`, for a Studio that isn't Knowledge Studio's own "currently selected category" concept), and `relationshipsInvolving(objectId)`. `static final instance`, injectable `PlatformEventBus` for test isolation — same convention as `OperationManager`/`ActivityLog`/`NotificationCenter`.

## 7. Studio Integration

`StudioShell`'s existing WP-STUDIO-030 `ref.listenManual(foundationRuntimeServiceProvider, ...)` bridge (previously named `_ocrBridge`, calling only `_publishOcrOperations`) was renamed to `_foundationBridge`, calling a new `_handleFoundationStateChange(previous, next)` that runs **both** `_publishOcrOperations(previous, next)` (unchanged) and `EngineeringObjectRuntime.instance.updateFromFoundationState(next)` — one listener, two independent diffs off the same already-delivered `next`, rather than a second, redundant subscription on the same provider. `StudioShell` also gained an injectable `EngineeringObjectRuntime?` constructor parameter, matching its existing `eventBus`/`workspaceManager` test-isolation pattern.

## 8. Platform Integration

- **EventBus**: a new `EngineeringObjectEvent` (`objectCount`, `relationshipCount`) is published whenever the cache actually rebuilds — including a `0`/`0` event when a repository closes.
- **ActivityLog**: extended with a fourth subscription, `EngineeringObjectEvent` → "Repository objects loaded: N objects, M relationships" or "Repository objects cleared." Same "observe an already-published fact" pattern as its other three subscriptions (WP-STUDIO-030) — no review-specific or object-specific code added to `ActivityLog` beyond one `switch`.
- **OperationManager**: not integrated — reviewed and found not applicable. Repository object/relationship enumeration is a synchronous FFI call (`bridge.listObjects()`/`bridge.listRelationships()`), not a long-running background operation; there is nothing with a start/finish worth tracking as an `Operation`.
- **NotificationCenter**: not integrated — reviewed and found not applicable. `EngineeringObjectRuntime` is a plain Dart class off the widget tree with no `BuildContext`, and there is no new user-facing failure state here beyond what `FoundationRuntimeNotifier.lastError` (untouched) already surfaces through its own existing error handling.
- **WorkspaceManager**: not integrated — reviewed and found not applicable. Engineering Objects belong to the Repository, a concept orthogonal to Diagram/Knowledge workspace dirty-state and recovery (WP-STUDIO-029). The one existing Diagram↔Repository cross-reference (`unified_navigation.dart`'s `_selectCorrespondingDiagramNode`, matching a diagram node's `repositoryObjectId`) is unchanged — it's a Diagram-node lookup, not an Engineering Object lookup, and was correctly left alone.
- **SessionManager**: not integrated — reviewed and found not applicable, for the same reason as `WorkspaceManager`: `SessionManager.listAll` aggregates Knowledge Curation Sessions and Diagram workspaces (per-Studio *documents*), not the Repository's object/relationship data, which has no session or document concept of its own.

## 9. Cleanup

- `explorer_navigation.dart`'s `goToObject`/`goToRelationship` now call `EngineeringObjectRuntime.instance.objectById`/`.relationshipById` instead of the file's own private `_findById<T>` helper, which is now deleted (no remaining callers).
- `unified_navigation.dart`'s `goToKnowledgeObject`, `goToKnowledgeRelationship`, and `goToValidationResult` now call `EngineeringObjectRuntime.instance.objectById`/`.relationshipById`/`.hasObject` instead of each doing its own inline linear scan over `objectList`/`relationshipList`.
- No other duplicated object-loading logic was found; `FoundationRuntimeNotifier`'s own fetch/refresh logic, `ObjectsPage`'s use of `objectsInSelectedCategory`, and `PropertyInspectorPanel`'s direct `foundationRuntimeServiceProvider` reads were all left exactly as they were — none of them duplicate a *lookup*, they each read the Repository's own state for the one page that's actually about that state.

## 10. Validation Results

- `flutter analyze`: 0 issues in any changed/new file (2 pre-existing, unrelated informational lints in `foundation_runtime_service.dart`, unchanged from prior Work Packages' baseline).
- `flutter test`: **437/437 passed** (424 prior + 13 new; 2 pre-existing unrelated skips):
  - `test/engineering_object_runtime_test.dart` (11): empty-before-first-update, cache population, treating a `null` list as empty rather than stale, `objectsInCategory` filtering, `relationshipsInvolving` for both source and target sides (including the self-relationship case), the reference-identity no-op guarantee, read-after-write `changes` ordering, `EngineeringObjectEvent` publication (both the loaded and the `0`/`0` cleared case), and the singleton.
  - `test/activity_log_test.dart` (+2): `EngineeringObjectEvent` recorded as a "loaded" entry with both counts, and as a "cleared" entry when both counts are zero.
  - The full pre-existing suite passed unchanged, confirming the `explorer_navigation.dart`/`unified_navigation.dart`/`StudioShell` refactors introduced no regressions.
- `flutter build windows`: succeeded.
- Consistent with WP-STUDIO-030's testing discipline: `EngineeringObjectRuntime` was tested with plain `test()` and an injected `PlatformEventBus`, constructing `FoundationServiceState` fixtures directly rather than through any widget tree or real Foundation Bridge — no new `testWidgets` test was added for `StudioShell`'s renamed/extended bridge; it was verified via `flutter analyze`, `flutter build windows`, and the existing `studio_shell_events_test.dart` (which already exercises `StudioShell`'s `ref.listenManual` bridges) passing unchanged.

## 11. Documentation

This file; doc comments added to `EngineeringObjectRuntime` and its public methods, `EngineeringObjectEvent` in `platform_event.dart`, `ActivityLog`'s class comment (fourth subscription), and `StudioShell`'s class/method comments explaining the renamed `_handleFoundationStateChange` bridge.

## 12. Recommendations for WP-STUDIO-032

- **A visible Object/Relationship browsing surface built on the Runtime** — `EngineeringObjectRuntime.objectsInCategory`/`relationshipsInvolving` are ready to back a cross-Studio "related objects" panel (e.g. shown from Diagram Studio or Acquisition, not just Knowledge Studio's own Object Explorer); none was built here, since no new UI was requested beyond what already existed.
- **Revisit `goToKnowledgeObject`'s candidate-vs-object dual lookup if Knowledge Candidates ever converge with Engineering Objects** — today `goToKnowledgeObject` checks `EngineeringObjectRuntime.instance.objectById(id)` first, then falls back to a `KnowledgeCandidate` linear scan; if a future Work Package gives `FoundationServiceState.candidates` its own Runtime-style cache (a real, separate concern — Knowledge Candidates are not Engineering Objects, see this Work Package's own §1), that fallback scan could be simplified too, but doing so here would have been exactly the kind of unrequested redesign this Work Package's requirements warn against.
- **If a genuine background Engineering Object write path is ever added** (e.g. committing a Knowledge Candidate to the Repository as a new object, already partly modeled by `CommitPlanService`/`CommitReport`), that is the point at which `OperationManager` integration would become genuinely applicable — not before.
- Per this Work Package's own instruction, no further Work Package should begin without new authorization, and no commit has been made.
