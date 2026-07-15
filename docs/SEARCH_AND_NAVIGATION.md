# Search & Navigation

WORK_PACKAGE_023, ENGINE-TASK-000104: "Implement Engineering search...
Search indexes Engineering Graph and Diagram Layout independently...
Navigation: Next Result, Previous Result, Zoom To Result, Select Result,
Center Result."

---

## Implementing a spec entry that was always there

SDD-026 already names a "Search Engine" and a public `SearchService`
("Responsible for: Engineering Graph Search, Symbol Search, Component
Search, Relationship Search, Circuit Search... Search is local to the
Engineering Graph") — it was simply never built in WP019–022. WP023
implements it for the first time. This is the **one** new
`EngineRegistry` entry this work package adds (`registry.search`) —
called out explicitly, since every other WP023 feature slots into an
existing container (Diagram Layout, ViewState, Selection).

## `SearchProvider` / `SearchService`

```dart
abstract class SearchProvider {
  List<SearchResult> search(EngineeringGraph graph, DiagramLayoutState layout, String query);
}

enum SearchResultKind { node, relationship, symbol, annotation, layer }

class SearchResult {
  final String id;
  final SearchResultKind kind;
  final String label;
  final String matchedField;
}
```

`search` takes the graph **and** the layout explicitly, rather than
assuming one implies the other — "indexes... independently" per spec —
and each result's `kind` records which side it came from.
`SearchService` (constructed with a `SymbolProvider`) does a
case-insensitive substring match over: node `displayName`/`category`/
`symbolId`; relationship `relationshipType`/`id`; symbol
`identifier`/`name`/`aliases` (delegated straight to the existing
`SymbolProvider.search` — no duplicate matching logic); annotation
`text`; layer `name`.

## Navigating a result set

"Next Result"/"Previous Result" need to track *which* result of the last
search is current — this is exactly the same category of runtime,
non-persisted, non-command state `NavigationService` already owns for
highlight paths (SDD-026 "Navigation Engine"), so it was added there
rather than invented as a new subsystem:

```dart
List<SearchResult> get searchResults;
SearchResult? get currentResult;
void setSearchResults(List<SearchResult> results); // resets to the first result
void nextResult();     // wraps around
void previousResult(); // wraps around
```

"Zoom To Result" / "Select Result" / "Center Result" are deliberately
**not** implemented as new engine methods — they are Demonstration Host
combinations of `currentResult` with the engine primitives that already
exist for exactly this purpose: `SelectionService.selectNode`/
`selectRelationship`/`selectAnnotation` and
`ViewStateService.centerSelection`. Duplicating that logic inside
`NavigationService` would just be a second implementation of "select and
center on this thing" to keep in sync with the first.

## Demonstration Host

The Search Panel dialog runs `registry.search.search(...)` on every
keystroke, feeds the results into `NavigationService.setSearchResults`,
and renders a result list with Next/Previous buttons; tapping a result
or pressing Next/Previous calls back into the host's `_goToSearchResult`,
which selects the matched object and (for nodes/annotations, which have
a position) centers the viewport on it.

## Verification

`test/search/search_service_test.dart`: matches across all five result
kinds (including symbol aliases via the existing `SymbolProvider.search`
delegation), plus empty-query and no-match cases.
`test/selection_navigation_test.dart`'s `NavigationService` group covers
`setSearchResults`/`nextResult`/`previousResult` wrap-around behavior and
the empty-list reset.
