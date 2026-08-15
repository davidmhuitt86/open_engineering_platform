# Search Workspace

Implemented in Work Package 005 (STUDIO-TASK-000010) by
`lib/features/search/search_page.dart`, made live in Work Package 006
(STUDIO-TASK-000012). Consumes only the
[Connection Manager](CONNECTION_MANAGER.md) (`foundationRuntimeServiceProvider`)
— never the Foundation Bridge or Public C API directly, and never
performs searching independently or reorders Foundation's results.

---

## Status

As of Work Package 006, the Public C API exposes `oep_search_repository`,
`oep_search_objects`, and `oep_search_relationships` (Foundation Work
Package 013), and the Search Workspace calls them directly. A scope
selector (Repository / Objects / Relationships) chooses which one;
Repository is the default, matching `oep search`'s own default scope.

## Search Workflow

```
User types a query, picks a scope, clicks Search (or presses Enter)
  -> SearchPage._runSearch(query)
       -> FoundationRuntimeNotifier.search(query, scope: _scope)
            -> bridge.searchRepository/searchObjects/searchRelationships(...)
            -> on success: state.copyWith(searchQuery: query, searchResults: results)
            -> on failure: state.copyWith(lastError: error), rethrow
       -> on success, local: query pushed to the front of Search History
       -> on failure: showFoundationErrorDialog(...) (see § Error Handling)
  -> UI reads state.searchQuery/state.searchResults:
       hasSearched=false            -> "Search this repository" (idle)
       hasSearched=true, results==[] -> "No results for '<query>'"
       hasSearched=true, results=[…] -> results table (Icon/Name/Type/Score/Match Location)
```

`Clear` (both the button next to Search and the composed `clearSearch()`
call) resets `searchQuery` to `''` and `searchResults` to `null`,
returning the page to its idle state — distinct from "Clear History"
(below), which only clears the local history list, not the current
query/results.

## Search Scope

`SearchScope` (`lib/core/models/search_scope.dart`) is Search
Workspace presentation state, not Connection Manager state — like
Search History, it's local `SearchPage` state (`_scope`), not part of
`FoundationServiceState`; the Connection Manager's documented additions
for Work Package 006 are specifically Current Search Query/Results, not
*how* a search was scoped. `search(query, {scope})`'s `scope` parameter
only selects which `FoundationBridge` method gets called:

| Scope | Bridge method | Native function |
|---|---|---|
| Repository (default) | `searchRepository` | `oep_search_repository` |
| Objects | `searchObjects` | `oep_search_objects` |
| Relationships | `searchRelationships` | `oep_search_relationships` |

For Repository scope, `FoundationBridge.searchRepository` returns every
object hit followed by every relationship hit — each group in exactly
Foundation's own order, never interleaved or re-sorted by score,
matching `oep_repository_search_result_t`'s own two-list shape and `oep
search`'s CLI presentation ("Objects: ... / Relationships: ...").

## Error Handling

Per Work Package 006's rule (*"If search fails: Display a professional
error dialog"*), a failed search shows `showFoundationErrorDialog`
(the same dialog `dashboard_page.dart`'s Open Repository workflow
uses) rather than silently degrading — this is deliberately different
from relationship retrieval's failure mode (an informative empty-state
message; see `docs/CONNECTION_MANAGER.md` § Error Handling), because a
search is a direct, single user-initiated action with an obvious place
to show a dialog immediately, the same way opening a repository is.

## Relationship Workflow

See `docs/CONNECTION_MANAGER.md` § State Ownership and § Foundation
Interaction for how `selectedRelationship` is owned and how it
interacts with `selectedObject`. In brief: the Relationship Explorer
(`lib/features/relationships/relationships_page.dart`) is a separate
page from the Search Workspace, but both ultimately drive the same
Connection Manager selection state that the Property Inspector reads.

## Selection Lifecycle

Per Work Package 005/006: *"Selecting a result shall: Navigate to the
appropriate Explorer. Select the corresponding Object or Relationship.
Update the Property Inspector."* Implemented by
`lib/shared/navigation/explorer_navigation.dart`'s `goToObject`/
`goToRelationship`, shared with the Relationship Explorer's "Go To
Source"/"Go To Target":

```
User taps a SearchResult row (SearchPage._selectResult)
  -> if kind == object:
       goToObject(context, ref, result.id)
         -> look up result.id in the Current Object List
         -> notifier.selectCategory(object.category)
         -> notifier.selectObject(object)
         -> context.go(StudioDestination.objects.path)
  -> if kind == relationship:
       goToRelationship(context, ref, result.id)
         -> look up result.id in the Current Relationship List
         -> notifier.selectRelationship(relationship)
         -> context.go(StudioDestination.relationships.path)
```

Both lookups degrade to a no-op if the ID can't be found in the
already-fetched list (e.g. that list failed to load independently) —
Studio has nothing honest to navigate to or select in that case. Both
`selectObject`/`selectRelationship` already clear the other selection
(Work Package 005), so the Property Inspector's Object/Relationship
mode switch requires no further change here — it's written generically
against "whichever of `selectedObject`/`selectedRelationship` is
non-null," not against how that selection was made.

## Search History

Per Work Package 005: *"Maintain an in-memory search history during
the current Studio session. History shall not persist between
sessions."* Implemented as local `State` inside `_SearchPageState`
(`_history`, a `List<String>`, most-recent-first, deduplicated on
re-search) — **not** part of `FoundationServiceState`/the Connection
Manager, since it is Search Workspace presentation state, not
Foundation-derived state. Rebuilding the widget tree (e.g. hot reload)
or navigating away and back preserves history only because `SearchPage`
itself isn't recreated by `go_router`'s `ShellRoute`... in practice,
history is scoped to the `SearchPage` widget's lifetime, which for
this single-workspace shell effectively means "for as long as Studio
is running," consistent with "current Studio session."

"Previous Searches" clicking a row re-runs that exact query, using the
current scope selection (equivalent to typing it and pressing Search).
"Clear History" empties the local list only — it does not affect
`searchQuery`/`searchResults`.

## Navigation Behavior

The Search Workspace is reached via the Navigation Rail's "Search"
item (`StudioDestination.search`, unchanged since Work Package 001) or
indirectly by selecting a search result from within the Search page
itself (which then navigates *away* to Objects or Relationships, per §
Selection Lifecycle). Search never opens a floating window or a second
Primary Workspace, consistent with SDD-003/SDD-004's single-workspace
rule already followed by every other Explorer. Like the Relationship
and Object Explorers, the Search Workspace shows a "No Repository
Open" gate (with a button back to the Dashboard) when no repository is
open, since `oep_search_*` is only valid from `RepositoryOpen`.
