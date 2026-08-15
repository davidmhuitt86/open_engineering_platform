# Unified Search

How the global `/search` page came to search both Foundation
(Repository/Object/Relationship) and the Engineering Engine (node/
relationship/symbol/annotation/layer) without merging or renaming
either side's existing `SearchResult` type (WORK_PACKAGE_025,
ENGINE-TASK-000121).

## Two pre-existing, unrelated `SearchResult` types

* `oep_studio/lib/core/models/search_result.dart` — decodes
  Foundation's native FFI search structs directly. Two kinds: `object`,
  `relationship`.
* `oep_engine/lib/core/search/search_result.dart` — the Engineering
  Engine's own `SearchProvider` result type. Five kinds: `node`,
  `relationship`, `symbol`, `annotation`, `layer`.

Both are already shipped and referenced elsewhere. Renaming or merging
either would ripple into already-working features for no benefit — the
work package only requires *one search page* that covers both, not one
result type.

## The wrapper: `UnifiedSearchResult`

`lib/core/models/unified_search_result.dart` introduces a new class
with two factories, `.fromFoundation(SearchResult)` and
`.fromEngine(SearchResult)` (the two `SearchResult` imports are
aliased `as foundation`/`as engine` inside this one file, so it is the
only file in Studio that ever has to disambiguate the two same-named
types), each producing a `UnifiedSearchResult` carrying:

```dart
class UnifiedSearchResult {
  final UnifiedSearchOrigin origin;             // foundation | engine
  final UnifiedSearchResultCategory category;    // see below
  final String id, label, objectTypeLabel, owningWorkspaceLabel, repositoryLocation;
  final foundation.SearchResult? foundationResult;
  final engine.SearchResult? engineResult;
}
```

This satisfies the work package's "Search results shall identify:
Object Type, Owning Workspace, Repository Location" requirement without
either source `SearchResult` type gaining a field it doesn't otherwise
need.

`UnifiedSearchResultCategory` is a brand-new, unambiguous seven-value
enum (`knowledgeObject`, `knowledgeRelationship`, `diagramNode`,
`diagramRelationship`, `symbol`, `annotation`, `layer`) computed once
at construction time from whichever source `SearchResultKind` produced
the result. Every other Studio file that consumes search results
(`unified_navigation.dart`'s `goToSearchResult`, `search_page.dart`)
switches on this one category — never on either wrapped
`SearchResultKind` directly — so no other file needs to import or
disambiguate the two same-named source enums.

## `UnifiedSearchService`

`lib/features/search/unified_search_service.dart` merges results
synchronously (both underlying `search()` calls are synchronous — this
is not a `Future`-returning method): Foundation's `search()` runs if a
repository is open, the Engine's `registry.search.search()` runs if a
diagram editing session is active, and both result lists are wrapped
and concatenated. Either source being unavailable degrades gracefully
to whatever the other one found — searching no longer requires a
repository to be open specifically (see "Behavior change" below).

## What changed in `search_page.dart`

* `_runSearch` calls `UnifiedSearchService.search` instead of reading
  Foundation's `searchResults` field directly; results are
  `List<UnifiedSearchResult>`.
* Result selection calls `goToSearchResult` (`shared/navigation/
  unified_navigation.dart`), which switches on `UnifiedSearchResultCategory`
  and dispatches to the correct existing navigation helper
  (`goToKnowledgeObject`, `goToKnowledgeRelationship`,
  `goToDiagramElement`, or — for `symbol`/`annotation`/`layer`, which
  have no standalone navigation target today, matching the
  Demonstration Host's own Search Panel precedent — a plain switch to
  Diagram Studio).
* The page's own ephemeral `_history` list was replaced by reading
  `engineeringProjectServiceProvider`'s shared `recentHistory`,
  filtered to `workspaceLabel == 'Search'` — history is no longer
  workspace-local (`docs/WORKSPACE_SYNCHRONIZATION.md`).

## Behavior change: a repository is no longer required

Before this work package, the Search Workspace showed a blocking "No
Repository Open" page whenever Foundation had no open repository,
regardless of whether a diagram was loaded. That gate was removed:
Shared Search should work with *either* a repository or a diagram
open, matching the work package's own framing of search as unified
across both. When neither is available, an inline informational note
is shown instead of a full-page block. Removing the gate also exposed
a previously-latent `RenderFlex` overflow in the controls row (the
scope dropdown's widest item, `'Search: Relationships'`, no longer had
its layout hidden behind the blocking gate) — fixed by shortening
dropdown item labels to just the scope name.

## Diagram Studio's own quick-search panel is unchanged

The in-canvas Search panel inside Diagram Studio (WORK_PACKAGE_024)
still searches only the active diagram directly through
`registry.search`, with no Foundation results — it is a
canvas-navigation convenience, not the unified search entry point.
Only the top-level `/search` page became unified.
