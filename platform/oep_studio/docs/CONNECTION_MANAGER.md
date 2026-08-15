# Connection Manager

Introduced in Work Package 002 (as the Studio Service owning Runtime
State and Repository State), formalized in Work Package 003 (Current
Selection), extended in Work Package 004 (Repository Statistics,
Current Object List), extended again in Work Package 005 (Current
Search Query/Results, Current Relationship Selection), again in Work
Package 006 (Current Relationship List; Current Search Query/Results
now live), and again in Work Package 007 (Current Knowledge Curation
Session, Current Proposals, Current Proposal Selection — see
`docs/KNOWLEDGE_STUDIO.md`).

Implemented by `lib/core/services/foundation_runtime_service.dart`
(`FoundationRuntimeNotifier` / `foundationRuntimeServiceProvider`) and
`lib/core/services/foundation_runtime_state.dart`
(`FoundationServiceState`). No rename occurred across work packages —
this document describes the same class under the architectural name
Work Package 003 introduced for it.

---

## Responsibilities

Per Work Package 007:

* Current Runtime
* Current Repository
* Repository Statistics
* Current Object List
* Current Relationship List
* Current Search Query
* Current Search Results
* Current Knowledge Curation Session
* Current Proposals
* Current Selection (of an object, a relationship, *or* a proposal — mutually exclusive)

Current Knowledge Curation Session/Proposals are Studio-only state
(never backed by Foundation — see `docs/KNOWLEDGE_STUDIO.md`) but are
still owned by this same Connection Manager rather than a separate
service, per Work Package 007's Architecture Rules: *"The Connection
Manager owns session state."*

The Connection Manager is the **only** place in Studio that holds a
[`FoundationBridge`](FOUNDATION_BRIDGE.md) instance. Every feature —
Dashboard, Repository Explorer, Object Explorer, Relationship
Explorer, Search Workspace, Property Inspector, Status Bar — reaches
Foundation exclusively through this provider:

```
Repository Explorer / Object Explorer / Relationship Explorer /
Search Workspace / Dashboard / Status Bar
                              ↓
                       Connection Manager
                              ↓
                       Foundation Bridge
                              ↓
                        Public C API
                              ↓
                     Foundation Runtime
```

Widgets never construct or call a `FoundationBridge` directly, and
never call an `oep_api.h` function directly — verified by grep: only
`foundation_bridge.dart` imports `oep_api_bindings.dart` /
`oep_api_native_types.dart`.

## State Ownership

`FoundationServiceState` is immutable; every mutation goes through
`FoundationRuntimeNotifier`, which replaces `state` wholesale via
`copyWith`. Fields:

| Field | Owned since | Meaning |
|---|---|---|
| `phase` | WP002 | Bridge connection lifecycle: connecting / connected / error |
| `runtimeState` | WP002 | Mirrors `oep_runtime_state_t` exactly (Uninitialized → Shutdown) |
| `foundationVersion` / `apiVersion` / `abiVersion` | WP002 | From `oep_foundation_version()` / `oep_api_version()` / `oep_abi_version()` |
| `repositoryStatus` | WP002 | Mirrors `oep_repository_status_t` (Current Repository) |
| `repositoryStatistics` | WP004 | Mirrors `oep_repository_statistics_t`; `null` if never fetched or the last fetch failed |
| `objectList` | WP004 | Every object in the repository (Current Object List); `null` if never fetched or the last fetch failed — distinct from an empty (non-null) list, which means "fetched successfully, repository has zero objects" |
| `relationshipList` | WP006 | Every relationship in the repository (Current Relationship List), via `oep_relationship_store_list`; same `null`-means-"not fetched/failed" vs. empty-means-"genuinely zero" distinction as `objectList` |
| `lastError` | WP002 | Most recent translated `FoundationBridgeException`, if any |
| `selectedCategory` | WP003 | The Repository Explorer category currently selected (Current Selection) |
| `selectedObject` | WP003 | The Object Explorer row currently selected. Mutually exclusive with `selectedRelationship` (WP005) |
| `selectedRelationship` | WP005 | The Relationship Explorer row currently selected (Current Relationship Selection). Mutually exclusive with `selectedObject` |
| `searchQuery` | WP005 | The Search Workspace's Current Search Query, `''` when idle |
| `searchResults` | WP005/WP006 | The Search Workspace's Current Search Results, via `oep_search_repository`/`oep_search_objects`/`oep_search_relationships` since WP006; `null` means "not searched, or the last search attempt failed" — always set together with `searchQuery` on success, so a non-empty query with `null` results shouldn't occur in steady state |
| `knowledgeSession` | WP007 | The active Knowledge Curation Session (Current Knowledge Curation Session), `null` until one is created. Studio-only, entirely in-memory — never backed by Foundation |
| `proposals` | WP007 | Manual Engineering Review proposals within `knowledgeSession` (Current Proposals); always empty when `knowledgeSession` is `null` |
| `selectedProposal` | WP007 | The Engineering Review proposal currently selected, if any. Mutually exclusive with `selectedObject`/`selectedRelationship` |

`objectsInSelectedCategory` (a getter, not a stored field) derives the
Object Explorer's visible list from `objectList` filtered by
`selectedCategory`, propagating `null` (not-yet-loaded/failed)
through rather than treating it as empty.

Selection and repository-scoped data are cleared automatically
whenever what they refer to becomes stale:

* Opening a (possibly different) repository clears `selectedCategory`,
  `selectedObject`, `selectedRelationship`, `repositoryStatistics`,
  `objectList`, `relationshipList`, `searchQuery`, and `searchResults`,
  then immediately re-fetches Repository Statistics, the Current
  Object List, and the Current Relationship List for the newly opened
  repository.
* Closing the repository clears the same set.
* Selecting a new category clears `selectedObject` (it belonged to the
  previous category's list).
* Selecting an object, a relationship, or a proposal clears the other
  two — the Property Inspector shows exactly one of Object mode,
  Relationship mode, or Proposal mode at a time (Work Package 005:
  *"The Property Inspector shall automatically switch between Object
  mode and Relationship mode"*; Work Package 007 extends the same rule
  to Proposal mode). See `docs/KNOWLEDGE_STUDIO.md` § State Ownership
  for the Property Inspector's full mode-selection order, including
  its Session-mode fallback.

`knowledgeSession`/`proposals`/`selectedProposal` are **not** cleared
by opening or closing a repository — a Knowledge Curation Session's
assigned repository (`KnowledgeSession.repositoryName`, a plain string
the engineer types) is independent of whatever Foundation repository
happens to be open elsewhere in Studio (see `docs/KNOWLEDGE_STUDIO.md`).

## Foundation Interaction

`openRepository` calls, in order: `bridge.openRepository`,
`bridge.getRepositoryStatus` (both must succeed or the whole call
throws), then `bridge.getRepositoryStatistics`, `bridge.listObjects`,
and `bridge.listRelationships` (each independently non-fatal — see
Enumeration Workflow in `FOUNDATION_BRIDGE.md`). `selectCategory`/
`selectObject`/`selectRelationship`/`clearObjectSelection`/
`clearRelationshipSelection`/`clearSearch` are pure local state
mutations — none call Foundation (for object/category/relationship
selection this is because `objectList`/`relationshipList` already
carry full detail). `search(query, {scope})` is the one method here
that *does* call Foundation (`oep_search_repository`/`oep_search_objects`/
`oep_search_relationships`, per `scope`) — see § Error Handling below
for how its failure mode differs from every other method here.

`createKnowledgeSession`/`advanceKnowledgeSession`/`addProposal`/
`editProposal`/`acceptProposal`/`rejectProposal`/`deleteProposal`/
`selectProposal`/`clearProposalSelection` (Work Package 007) are also
all pure local state mutations, for the strongest possible reason:
there is no Foundation call to make at all for Studio-only session
state (see `docs/KNOWLEDGE_STUDIO.md`). They validate through
`KnowledgeSessionService` and throw `KnowledgeValidationException` —
never `FoundationBridgeException` — on invalid input.

## Lifecycle

1. **Construction** — `FoundationRuntimeNotifier.build()` runs once,
   on first read of `foundationRuntimeServiceProvider` (in practice,
   at app startup — `StudioStatusBar` and the Dashboard both read it
   immediately). It synchronously attempts to create and initialize a
   `FoundationBridge`, returning either a `connected` or `error`
   state directly as its build result (see the "Riverpod
   `Notifier.build()`" pitfall documented in
   `IMPLEMENTATION_STATUS.md` — this is *why* `build()` must return
   the outcome rather than assign `state` and return separately).
2. **Steady state** — `openRepository` additionally fetches Repository
   Statistics, the Current Object List, and the Current Relationship
   List (Work Packages 004/006) after the open itself succeeds; every
   other method (`closeRepository`, `selectCategory`, `selectObject`/
   `selectRelationship`, `clearObjectSelection`/`clearRelationshipSelection`,
   `search`/`clearSearch`) mutates `state` via `copyWith`.
   Foundation-calling methods rethrow `FoundationBridgeException` for
   their primary action so the calling workflow can show a dialog
   immediately, in addition to `lastError` being available to any
   other observer.
3. **Teardown** — `ref.onDispose(_disposeBridge)` shuts the Runtime
   down (best-effort — a `FoundationBridgeException` during shutdown
   is swallowed, since the process is tearing down regardless) and
   releases the native handle via `FoundationBridge.dispose()`.

## Error Handling

Per Work Package 006, relationship retrieval and search fail
differently:

* **Relationship retrieval failure** degrades silently, like object
  enumeration: `relationshipList` becomes `null`, and the Relationship
  Explorer renders an informative "couldn't be loaded" message
  (distinct from "No Relationships Found", which means the fetch
  succeeded and the repository genuinely has none) — see
  `_RelationshipsCouldNotBeLoaded` in `relationships_page.dart`.
* **Search failure** rethrows `FoundationBridgeException` from
  `FoundationRuntimeNotifier.search()`, so `SearchPage` can show
  `showFoundationErrorDialog` — a professional dialog, not a silent
  empty state, per *"If search fails: Display a professional error
  dialog"*. `searchQuery`/`searchResults` are left unchanged on
  failure (only `lastError` updates), so a failed search doesn't wipe
  out whatever the Search Workspace was previously showing.

## Missing Public API

Per Work Packages 005/006: *"If additional Public API functionality is
required: Document the requirement. Do not implement it."* Relationship
enumeration and repository search — the two gaps Work Package 005
documented here — are both resolved as of Work Package 006 (Foundation
Work Package 013): `oep_relationship_store_list`, `oep_search_repository`,
`oep_search_objects`, and `oep_search_relationships` now exist and are
consumed (see `docs/FOUNDATION_BRIDGE.md` § Extension (Work Package 006)).
What remains unexposed:

* Repository/object/relationship **creation, editing, and deletion**
  remain entirely unexposed — every work package through 006 has been
  read-only by design (Dashboard's "Create Repository" button is still
  a placeholder for the same reason it was in Work Package 002).
* `oep_object_store_get_by_id`, `oep_relationship_store_get_by_id`,
  `oep_relationship_type_to_string`, and `oep_match_location_to_string`
  are exposed and bindable but unused — `objectList`/`relationshipList`
  already carry full detail for every row, so no code path needs a
  single-item lookup, and Studio decodes type/location labels through
  its own Dart enums (`RelationshipType.fromNative`,
  `SearchMatchLocation.fromNative`) rather than calling Foundation's
  `_to_string` helpers.
