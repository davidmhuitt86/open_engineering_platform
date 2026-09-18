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

## Engineering Knowledge Engine Readiness (WP-EKE-009)

The Engineering Knowledge Engine (EKE) — Query (WP-EKE-003), Rules
(WP-EKE-004), Validation (WP-EKE-005), Analysis & Reasoning
(WP-EKE-006), and the Engineering Intelligence Platform (WP-EKE-007),
surfaced to Studio by the EKE pages under `lib/engineering_intelligence/`
(WP-EKE-008) — depends on two pieces of state cached on the
`FoundationBridge`'s native Runtime handle, not the repository itself:
the Runtime Graph (`FoundationBridge.loadEngineeringGraph`, WP-EKE-001)
and the Knowledge Graph (`FoundationBridge.buildKnowledgeGraph`,
WP-EKE-002). Before WP-EKE-009, every EKE page loaded/built these
itself, behind its own page-local `_graphLoaded`/`_graphReady` flag, on
first use. WP-EKE-009 made this one authoritative runtime lifecycle
instead:

```
Repository Open → Engineering Graph Load → Knowledge Graph Build → EKE Ready
```

**Ownership.** `FoundationServiceState.ekeReadiness`
(`EkeReadiness`/`EkeReadinessState`, in `foundation_runtime_state.dart`)
is the single authoritative EKE readiness value. It distinguishes:
`disconnected` (no Bridge), `repositoryClosed` (connected, no
Repository open), `graphNotLoaded` (Repository just opened / a
mutation invalidated the graph, initialization not yet started),
`initializing` (a load/build is in flight), `engineeringGraphLoaded`
(load succeeded, build not yet attempted/succeeded), `ready` (both
succeeded — the only state EKE pages may query against), and
`initializationFailed` (with `failedStage` and `failureMessage`
diagnostics preserved). No EKE page holds its own authoritative copy of
this state any more.

**Orchestration.** The actual `loadEngineeringGraph`/`buildKnowledgeGraph`
call sequence, and its ordering/failure rules, live in the pure,
FFI-free `EkeLifecycle` (`lib/core/services/eke_lifecycle.dart`) —
`FoundationRuntimeNotifier` remains the only caller of `FoundationBridge`
itself; `EkeLifecycle` just decides what `EkeReadiness` results from a
given load/build outcome, taking the two Bridge calls as closures so
this logic is unit-testable without a live native Runtime (see
`test/core/services/eke_lifecycle_test.dart`).

**Lifecycle wiring** (`FoundationRuntimeNotifier`,
`foundation_runtime_service.dart`):

* `openRepository` — after the existing Repository Statistics/Object
  List/Relationship List refresh, runs a full `EkeLifecycle.initialize`
  (Engineering Graph Load, then, only on success, Knowledge Graph
  Build). This is the ONE place the lifecycle originates from — never a
  page's `initState`.
* `closeRepository` — moves `ekeReadiness` to `repositoryClosed`; the
  closed Repository's graph is never presented as current again.
* `commitToFoundation` (Work Package 012, the one Repository-mutation
  path in Studio) — on a successful commit, after its own existing
  Object/Relationship List refresh, re-runs a full
  `EkeLifecycle.initialize` so newly committed objects are reflected;
  `ekeReadiness` moves through `initializing` first, so no consumer can
  observe a stale `ready` from before the commit.
* `ensureEkeReady()` — a defensive, idempotent entry point EKE pages
  call instead of loading/building the graph themselves: a no-op if
  already `ready` or already `initializing`, otherwise delegates to the
  same lifecycle `openRepository` uses. Exists for edge cases (e.g. a
  page mounted after a prior initialization failure), not as a second
  initialization path.
* `rebuildKnowledgeGraph()` — the explicit, user-requested refresh path
  (e.g. the Knowledge Graph Explorer's "Rebuild Graph" button): rebuilds
  the Knowledge Graph only (the Engineering Graph is assumed current)
  via `EkeLifecycle.rebuildKnowledgeGraphOnly`, still updating
  `ekeReadiness` rather than a page-local flag, and rethrows the
  original `FoundationBridgeException` on failure so existing callers'
  error handling is unaffected.

Every call above moves `ekeReadiness` to `initializing` *before*
calling into `EkeLifecycle` — both Bridge calls are synchronous FFI, so
this is the only way a fresh (re)initialization is ever distinguishable
from a stale prior `ready` by anything that reads state mid-call.

**Empty repository semantics.** `ekeReadiness.isReady` and
`objectList`/`repositoryStatistics` are independent concepts:
`objectList == []` (a Repository with genuinely zero objects) can, and
should, coexist with `ekeReadiness.state == ready` — successfully
loading and building an empty graph is still a successful
initialization. `objectList == null` (not fetched / fetch failed) and
`ekeReadiness.state != ready` (not initialized) are the two states that
actually mean "not usable yet," and they are tracked separately because
they can fail independently (Repository Statistics/Object/Relationship
List enumeration is non-fatal and best-effort; EKE initialization is
not).

**Repository switching.** `EkeReadiness.repositoryId` (the
`RepositoryStatus.repositoryId` the readiness value applies to) tags
every readiness value, so a value captured before a Repository switch
is distinguishable from the new Repository's own — `openRepository`
also resets `ekeReadiness` to `graphNotLoaded` synchronously, before
`_refreshRepositoryData`/`_runEkeInitialization` run, so no
intermediate read can observe the previous Repository's `ready` while
the new one is opening.

**EKE consumer pages** (`analysis_dashboard_page.dart`,
`engineering_explorer_page.dart`, `knowledge_graph_explorer_page.dart`,
`query_console_page.dart`, `reasoning_dashboard_page.dart`,
`recommendation_panel_page.dart`, `validation_dashboard_page.dart`)
no longer load/build the graph themselves. Each page's former
`_ensureGraph`/`_ensureGraphLoaded` now only calls
`FoundationRuntimeNotifier.ensureEkeReady()` (a defensive fallback) and
reads `FoundationServiceState.ekeReadiness`/`isEkeReady` for display —
they are consumers of the authoritative state, never independent
initialization authorities.

### Post-open Repository mutations invalidate the graph (WP-EKE-010)

WP-EKE-009 established `ekeReadiness.state == ready` to mean "the graph
is initialized." WP-EKE-010 tightens that invariant:
`EkeReadinessState.ready` means the Engineering Graph and Knowledge
Graph are synchronized with the **currently open Repository's actual
current content** — not merely "were once loaded." Concretely: **any
successful mutation of the currently open Foundation Repository
invalidates the cached EKE runtime graph and requires synchronization
before `ekeReadiness` may report `ready` again.**

Before WP-EKE-010, `commitToFoundation` (Work Package 012) was the only
Repository-mutation path that resynchronized EKE afterward. Other real
mutation paths — most concretely Exchange package installation
(`ExchangeRuntimeNotifier.installPackage` →
`FoundationBridge.installPackage`) — changed Repository content without
ever invalidating/resynchronizing the graph, leaving `ekeReadiness.state
== ready` true while the cached graph was actually stale.

**`FoundationRuntimeNotifier.repositoryMutationOccurred()`** is the one
new public entry point this work package adds, at the Repository/runtime
boundary (not Exchange-specific): any caller that just successfully
mutated the currently open Repository calls it afterward. It is a thin
wrapper reusing the exact same authoritative lifecycle every other entry
point above uses — `_runEkeInitialization(bridge, fullReload: true)` — so
there is still exactly one lifecycle, one cache, one authoritative
`ekeReadiness` value. A no-op if no Repository is open. Never rolls back
the Repository mutation itself if resynchronization fails — the
Repository stays authoritative regardless of EKE cache-sync outcome; a
failed sync lands on `initializationFailed` with diagnostics, from which
a later `ensureEkeReady()` (or another `repositoryMutationOccurred()`
call) can recover through the same lifecycle.

Wired call sites (WP-EKE-010):

* `ExchangeRuntimeNotifier.installPackage()` (`lib/exchange/services/exchange_runtime_service.dart`)
  — calls `repositoryMutationOccurred()` after a successful
  `_installIntoFoundation`/`FoundationBridge.installPackage`. Exchange
  reaches Foundation only through this one clean public method — never
  `EkeLifecycle`, `FoundationBridge` graph methods, or
  `FoundationRuntimeNotifier` internals directly.
* `PackageManagerPage._installFromPath()` (`lib/features/packages/package_manager_page.dart`)
  — the local (non-Exchange) "Install Package" action; same
  `FoundationBridge.installPackage` mutation, same fix.
* `commitDiagramToRepository()` (`lib/diagram_studio/bridge/diagram_repository_commit_action.dart`)
  — Diagram Studio's "Commit to Repository" action creates real
  Engineering Objects/Relationships via `EngineGraphCommitService`; calls
  `repositoryMutationOccurred()` alongside its existing
  `refreshRepository()` call (which only refreshes the Current
  Object/Relationship List for display — a separate concern from EKE
  graph synchronization).

`commitToFoundation` was re-verified during this work package's audit and
already calls `_runEkeInitialization(fullReload: true)` exactly once, on
success only — it was not changed.

**Diagram Intelligence exception (unchanged, documented).**
`DiagramIntelligenceService.sync()` (`lib/diagram_studio/intelligence/diagram_intelligence_service.dart`)
performs its own `_bridge.loadEngineeringGraph()`/`_bridge.buildKnowledgeGraph()`
calls after syncing a shadow Diagram object into the Repository, entirely
outside the `FoundationRuntimeNotifier` lifecycle described above. This
was already flagged by WP-EKE-009's own after-action report and
WP-EKE-FOLLOWUP-001's audit as "not yet UI-wired," and WP-EKE-010's own
audit re-confirmed that is still true:
`DiagramStudioController.intelligence` (the only field of type
`DiagramIntelligenceService`) is declared but never constructed/assigned
anywhere in production code, so this path is unreachable from any UI and
causes no observable `ekeReadiness` inconsistency today. Left
intentionally unchanged, per this work package's own scope — see
`test/core/services/eke_010_repository_mutation_sync_test.dart`'s
"TEST-EKE-010-010" group. Wiring `DiagramIntelligenceService` into the UI
in a future work package will need to either route its sync through
`FoundationRuntimeNotifier.repositoryMutationOccurred()` or otherwise
reconcile it with this same authoritative `ekeReadiness` value — it must
not become a second, independently-tracked readiness signal.

### Acceptance closure: real consumption, failed switches, empty Repositories (WP-EKE-011)

WP-EKE-011 closed the two findings (AP-EKE-012-F1, AP-EKE-012-F2) blocking
acceptance of the EKE runtime lifecycle built across WP-EKE-009/
WP-EKE-FOLLOWUP-001/WP-EKE-010.

**F1 — real EKE consumption, not just graph construction.**
`test/exchange_rc1_e2e_test.dart`'s WP-EKE-010 assertion block (real
Exchange install → real `repositoryMutationOccurred()` → real graph
load/build → `ekeReadiness.state == ready`) proved graph
*construction*, not that any EKE operation *consumes* the result. This
work package extended that same test — no second native harness — with
a further block that runs a real, graph-dependent
`FoundationBridge.executeQuery(category: QueryCategory.object,
primaryObjectId: ...)` call (the exact production API
`query_console_page.dart` calls, gated by the same `EkeConsumerGate`
every EKE consumer page uses) against the object id
(`'aaaaaaaa-0000-4000-8000-000000000001'`, the fixture's "Harness"
Component) the Exchange install just created, and asserts the result
contains that id — a deterministic, identity-level assertion tied to
content this test's own fresh temp Repository just received, not a
count that could coincidentally match.

**Empty-Repository acceptance.** The same file gained
`TEST-EKE-011-008`: opening a genuine, never-installed-into temp
Repository through the real DLL reaches `ekeReadiness.state == ready`
(not a special "empty" state), `bridge.getObjectCount() == 0`, and a
real `executeQuery` against it returns an empty result set without
throwing or being blocked — proving the "empty ≠ not ready" invariant
documented above against the real native library, not only as intent.

**F2 — failed Repository switch cannot leave stale state.**
`FoundationRuntimeNotifier.openRepository()`'s pre-fix `catch` block
only recorded `lastError` on a failed open — when Repository A was
already open and a switch to Repository B failed (B never opens, but A
was already closed by `openRepository`'s own pre-close step per its own
documented contract), `state` kept representing Repository A as open
and possibly still `ready`, even though the Runtime itself had nothing
open. The fix: the `catch` block now resynchronizes `state` from
`FoundationBridge.state` (the Runtime's own ground truth for what is
actually open after the failed attempt) — clearing
`repositoryStatus`/`objectList`/`relationshipList`/`repositoryStatistics`
and moving `ekeReadiness` to `repositoryClosed` — instead of leaving any
field representing a Repository the Bridge no longer backs. The
invariant this closes: **`ekeReadiness.state == ready` is only ever
valid when a currently-open Repository's current graph has actually
been loaded/built** — a failed open/switch must never leave either the
Repository state or `ekeReadiness` claiming otherwise.

Proven against the real native DLL in
`test/core/services/eke_011_repository_switch_test.dart`
(`TEST-EKE-011-003` through `-007`): Repository A ready → a switch to a
genuinely nonexistent Repository path fails → `ekeReadiness` is not
`ready` and stale A state is cleared → the Foundation connection itself
stays usable (not degraded to the error phase) → a later valid open
still reaches `ready` → and, separately, a *successful* switch (A ready
→ B opens successfully) still reaches a fresh `ready` for B, proving the
fix did not regress the ordinary switch path and that a prior failure
never poisons a later attempt.

**Unit vs. native integration verification, stated explicitly.** Three
kinds of coverage exist for this lifecycle, and are labeled as such in
each test file:

* **Pure/unit** — `eke_lifecycle_test.dart`,
  `eke_010_repository_mutation_sync_test.dart`'s "model tests" group,
  and `eke_011_repository_switch_test.dart`'s `EkeConsumerGate`
  re-verification group: no Bridge, no native DLL, no Riverpod.
* **Notifier/service integration (no native Bridge)** —
  `eke_010_repository_mutation_sync_test.dart`'s consumer-integration
  group and the source-inspection groups in both that file and
  `eke_011_repository_switch_test.dart`: real `FoundationRuntimeNotifier`
  wiring, but exercising only the "no Repository open"/static-source
  branches.
* **Real native Foundation integration** — `exchange_rc1_e2e_test.dart`
  (all tests, including the new F1/empty-Repository blocks) and
  `eke_011_repository_switch_test.dart`'s "real native Repository
  switch" group: the actual, unmodified `oep_foundation_bridge.dll`,
  real FFI calls, real temp-directory Repositories. Both skip (never
  fake) if the DLL cannot be loaded in a given environment, and fail
  loudly (never skip) if it loads but is stale/incompatible — see
  `exchange_rc1_e2e_test.dart`'s own top-level doc comment.

**Diagram Intelligence — re-verified, still unreachable.** WP-EKE-011's
own audit re-confirmed `DiagramStudioController.intelligence` is still
declared but never constructed anywhere in production code — the
exception documented above still holds unchanged; no new work was
needed or done here.

**Mutation-path re-audit.** WP-EKE-011 repeated the search for every
Repository-mutating `FoundationBridge` call site
(`createObject`/`updateObject`/`updateObjectContent`/`deleteObject`/
`createRelationship`/`deleteRelationship`/`installPackage`/
`createDiagram`/`createObjectInDiagram`/`createRelationshipInDiagram`/
`beginTransaction`/`commitTransaction`). No new unsynchronized path was
found: the three WP-EKE-010 call sites above remain the only live
Repository-mutating paths and all still call
`repositoryMutationOccurred()`; `DiagramRepositoryService`'s own
create/update/delete methods are reachable only through the still-
unreachable `DiagramIntelligenceService`; and the various
`createEipSession`/`createReasoningSession`/`createValidationSession`
calls across the EKE consumer pages create in-memory analysis-engine
sessions, not persisted Repository content, so they need no
synchronization. `commitToFoundation` was re-confirmed to call
`_runEkeInitialization` exactly once on success, and Exchange was
re-confirmed to never touch `EkeLifecycle`/`FoundationBridge` graph
methods or `FoundationRuntimeNotifier` internals directly (source
inspection, `TEST-EKE-011-009/010/011`).

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
