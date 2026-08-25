# OEP Workspace State & Restoration Readiness Audit

**AP-OEP-WORKSPACE-STATE-001** — audit-first package. No disk persistence,
serialization, or restoration was implemented. This document records
what exists today, what a future Workspace-session persistence layer
would need, and whether the architecture is ready for it.

> **Implementation status update (AP-OEP-WORKSPACE-PERSISTENCE-001, later
> package — DOCS-SYNC-001 reconciliation note, not a rewrite of the audit
> below).** The §7 schema this audit proposed-but-did-not-implement **has
> since been implemented**, essentially verbatim: `WorkspaceTabsController`
> now persists `{surfaces: [...], activeId}` via
> `lib/workspace/workspace_tabs_storage.dart` to
> `%APPDATA%/oep_studio/workspace_tabs.json`, restored once per app
> session. `activeProjectId`/`activeDocumentId` were correctly excluded,
> exactly as §7 concluded. Everything else this audit flagged as
> intentionally excluded (§2/§4) — Copilot conversation, Engine undo/
> redo, WebView/V2 internal state, multi-document/multi-project state —
> remains correctly unimplemented; no scope beyond §7's schema has been
> built. The reasoning below (§1–§6, §8–§9) is left unchanged as the
> historical record that justified this scope; only §7/§10's "not yet
> built" framing is now out of date, corrected here rather than rewritten
> in place.

## 1. Complete Workspace state inventory

| Component | State item | Classification |
|---|---|---|
| `WorkspaceTabsController` | `_tabs` (ordered `List<WorkspaceTab>`), `_activeId` | SESSION STATE |
| `WorkspaceTab` | `id` (deterministic: `'workspace-tab-$surfaceId'`), `surfaceId` | DERIVED STATE (id is a pure function of surfaceId — never needs storing itself) |
| `EngineeringWorkspacePage` | none of its own — reads `WorkspaceTabsController` (`ref.watch`) and `diagramStudioControllerProvider` (for the Diagram tab's live title) | PROVIDER STATE (no local state) |
| `StudioShell` | `_workspaceHost` (a fixed `EngineeringWorkspacePage()` reference, no data of its own), `_diagramStudioHost` (same, for Diagram) | EPHEMERAL UI STATE (widget-identity plumbing only, carries no restorable data) |
| `WorkbenchSidebar` | expand/collapse of the rail itself, scroll position of the nav list | EPHEMERAL UI STATE |
| Diagram Surface | `EngineeringProjectState.document` (`DiagramDocument`: graph, layout, metadata, dirty flag, `documentId`, file `path`) | DOCUMENT STATE |
| Diagram Surface | `EngineeringProjectState.selection` (`GraphSelection`: node/relationship/group/annotation id sets) | ENGINE STATE |
| Diagram Surface | `EngineeringProjectState.engineHost`/Engine's `CommandHistory` (undo/redo stacks) | ENGINE STATE |
| Diagram Surface (V2) | WebView navigation state, V2's own in-page JS/DOM state, zoom/pan, edit mode | SURFACE LOCAL STATE (owned entirely by the native WebView plugin instance) |
| `EngineeringProjectState.activeProject` | `EngineeringProject` (id, name, `diagramDocumentPath`, `knowledgeSessionId`) | DOCUMENT STATE |
| Knowledge Surface | `FoundationServiceState.selectedObject`/`selectedRelationship`/`selectedKnowledgeCandidate`/`knowledgeSession`/`candidates` | PROVIDER STATE |
| Acquisition Surface | `AcquisitionServiceState.selectedJobId`, jobs/downloads/verifications lists | PROVIDER STATE |
| Repository Surface | `_filterController` text, `_expanded`/`_historyExpanded` sets | SURFACE LOCAL STATE |
| Objects/Relationships Surfaces | `_query` (filter/sort/author fields) | SURFACE LOCAL STATE |
| Search Surface | `_controller` text, `_scope`, `_results` | SURFACE LOCAL STATE + EPHEMERAL UI STATE (`_results` is a point-in-time query result, not identity) |
| Graph Surface | `_filterController` text, `_filter` | SURFACE LOCAL STATE |
| Validation Surface | none of its own — reads `EngineeringProjectState.validationReport` | PROVIDER STATE (derived, recomputed on demand — see `DERIVED STATE` note below) |
| Engineering Intelligence Surface | `_tabController` (inner tab index) | SURFACE LOCAL STATE |
| Exchange Surface | `_section` (which of 5 panels), `ExchangeServiceState.selectedPackage`/`selectedPublisher` | SURFACE LOCAL STATE + PROVIDER STATE |
| Copilot Surface | `_exchanges` (full conversation), `_asking`, `_questionController` text | SURFACE LOCAL STATE |
| Settings Surface | `_searchController` text; `settingsControllerProvider` (`isModified`/unsaved edits) | SURFACE LOCAL STATE + PROVIDER STATE |
| Dashboard/ProjectExplorer/Packages Surfaces | none bespoke | PROVIDER STATE only |
| Any Surface's transient dialogs (e.g. Knowledge's session browser, evidence dialogs) | dialog open/closed, in-dialog form fields | EPHEMERAL UI STATE |

No universal context object was created to produce this table — each
row cites the actual owning class.

## 2. Minimum restorable Workspace state

| Item | Classification | Reason |
|---|---|---|
| Ordered list of open Surface IDs | **RESTORE REQUIRED** | Only place this exists is `WorkspaceTabsController`; nothing else can reconstruct "which tabs were open" |
| Active Surface ID | **RESTORE REQUIRED** | Same reasoning |
| Diagram tab presence | **RESTORE REQUIRED** | It's just one more entry in the same open-Surface-IDs list (the reserved `WorkspaceTab.diagramSurfaceId` sentinel) — no separate mechanism needed |
| Active Diagram document | **RECONSTRUCT FROM AUTHORITY** | `DiagramDocument.path` (if the document was ever saved) is enough — reopening that path restores `documentId`, graph, and layout via the document's own `fromJson`. An *unsaved* document falls back to the existing, separate autosave/recovery system (`DiagramDocument.findRecovery`), not something a Workspace schema should duplicate |
| Active project | **RESTORE OPTIONAL** | `EngineeringProject.id` is already a stable, file-backed identifier (`EngineeringProjectStorage.load(id)`) — restorable, but the Workspace can function with no active project (today's actual default state), so this is optional context, not a hard requirement |
| Selected objects/candidates/jobs/packages | **DO NOT RESTORE** | None of this is persisted today even independently of the Workspace (Foundation/Acquisition/Exchange selection all reset on every app restart already) — restoring it would require new persistence work in those runtime services first, out of this package's scope and not requested |
| Surface-local filters (Repository/Objects/Relationships/Graph/Search) | **RESTORE OPTIONAL** | Genuinely nice-to-have, genuinely small (a handful of strings/enums per Surface), but not required for the Workspace to be "restored" in any meaningful sense |
| Surface-local scroll positions | **DO NOT RESTORE** | No existing authority tracks these as data at all (they live purely in `ScrollController`/`Scrollable` internals) — restoring them would require adding new state tracking to every Surface, out of scope |
| Expanded/collapsed sections (Repository's category tree, sidebar) | **RESTORE OPTIONAL** | Same shape as filters — small, already a plain field, but not required |
| Copilot conversation | **RESTORE OPTIONAL** | A real, coherent, self-contained piece of state (`_exchanges`) — restorable in principle, but arguably *should* reset per session as a matter of product intent, not a technical requirement either way. Flagged, not decided, in this audit |
| Inner tab selections (Engineering Intelligence's `_tabController`) | **DO NOT RESTORE** | Cosmetic, no existing authority, trivial to lose without consequence |
| V2 zoom/pan/edit state | **DO NOT RESTORE** | Owned entirely by the WebView plugin instance — see Phase 4 |
| Search results | **DO NOT RESTORE** | A point-in-time query result, stale the instant it's reopened — restoring the *query text* (optional) is meaningfully different from restoring the *results* |
| Temporary dialogs/modals | **DO NOT RESTORE** | By definition transient; no existing authority, no product reason to resurrect a mid-flow dialog after a restart |
| Unsaved edits | **RECONSTRUCT FROM AUTHORITY** | Already handled by `DiagramDocument`'s own autosave/recovery mechanism (`findRecovery`), a separate, already-shipped system predating this audit — a Workspace schema should not duplicate it |
| Engine undo/redo state | **DO NOT RESTORE** | `CommandHistory`'s `_undoStack`/`_redoStack` (`oep_engine/lib/core/editing/command_history.dart`) are plain in-memory `List<EditingCommand>` with no `toJson`/serialization anywhere in the Engine — restoring them would require genuine Engine-level work, explicitly out of bounds for this package |

## 3. State authority matrix

| State | Canonical authority | Stable across restart? |
|---|---|---|
| Open Surface IDs / active Surface ID | `WorkspaceTabsController` (Riverpod, in-memory only today) | No persistence exists today — would need a new, small storage layer |
| Diagram document identity | `DiagramDocument.path` + `documentId` (round-trips through `toJson`/`fromJson`, confirmed by direct source read) | **Yes**, provided the document was saved to a path |
| Active project | `EngineeringProject.id`, `EngineeringProjectStorage` (file-per-project under `%APPDATA%/oep_studio/projects/<id>.json`) | **Yes** — already a real, shipped, file-backed identifier and load path |
| Foundation object/relationship selection | `EngineeringObjectRuntime`/`FoundationServiceState` | No — resets every launch already, independent of the Workspace |
| Acquisition/Exchange selection | Their own runtime notifiers | No — same reasoning |
| Diagram node/relationship ids | `EngineeringGraph.generateId(...)`, persisted inside the saved document's own graph JSON | **Yes**, but only meaningful in the context of a saved document — not a standalone Workspace-schema concern |
| Diagram undo/redo | `CommandHistory` (Engine) | No — no serialization exists |

## 4. Reconstruction audit, per Surface

| Surface | 1. Constructible from `SurfaceDefinition`? | 2. Provider state reconstructable? | 3. Stable identifier? | 4. Authority owns what's needed? | 5. State trapped only in a widget? |
|---|---|---|---|---|---|
| Diagram | Yes (`EngineeringWorkspacePage._buildTabContent`'s `isDiagram` branch, unconditional) | Yes — `engineeringProjectServiceProvider`/`diagramStudioControllerProvider` are app-wide singletons, already the sole authority regardless of tab state | Yes — `documentId`/`path` (§3) | Yes | No — WebView-internal state (zoom/pan/history) is the one thing genuinely trapped, but it is explicitly **not** something this audit recommends restoring (Phase 4) |
| Knowledge | Yes | Yes — `foundationRuntimeServiceProvider` | Partial — `KnowledgeSession.id` is stable, but nothing ties "the open Knowledge tab" to a specific session today (opening it just shows whatever the Foundation bridge currently has loaded) | Yes | No |
| Acquisition | Yes | Yes — `acquisitionRuntimeServiceProvider` | `AcquisitionJob.id` is a stable id, but not persisted as "the last selected job" anywhere | Yes | No |
| Repository | Yes | Yes | N/A — Repository has no entity of its own, only a live Foundation-connection view | Yes | No |
| Search | Yes | Trivially — Search has no restorable identity, only ephemeral query/results | N/A | Yes | No |
| Copilot | Yes | Partial — `_exchanges` is pure widget-local `State`, with **no** backing provider at all | N/A (a conversation has no id) | No — this is the one Surface whose substantive state (the conversation itself) exists *only* inside its widget, per the Phase 1 inventory (§1) and the earlier `AP-OEP-WORKSPACE-LIFECYCLE-001` Surface audit | **Yes — flagged** |
| Engineering Intelligence | Yes | Yes — reads `foundationRuntimeServiceProvider`; the inner `_tabController` index is cosmetic-only | N/A | Yes | No |
| Exchange | Yes | Yes — `exchangeRuntimeServiceProvider` | `ExchangePackage.id`/`Publisher.id` are stable (mirror Foundation wire shapes) but, like Acquisition, nothing persists "the last selected one" | Yes | No |

**The one real gap found**: Copilot's conversation history lives
exclusively in `_CopilotPageState._exchanges`, with no Riverpod provider
or other authority backing it. Every other Surface's substantive state
already has a real backing authority independent of whether it's
restored; Copilot does not. This does not block Workspace-tab-identity
restoration (Copilot would simply reopen with an empty conversation,
same as today's default state) — it only means the conversation itself
cannot be restored without first giving it a real state authority, which
this package does not do (unrequested, and outside "prove the
architecture" scope).

## 5. Persistence hazards

| State | Classification |
|---|---|
| Active WebView state (rendered content, DOM) | **intentionally ephemeral** — never serializable in principle |
| WebView navigation history | **intentionally ephemeral** — same reasoning; V2 always re-navigates to its one fixed entry URL on (re)creation regardless |
| V2 JavaScript state (in-page module/wire positions as V2 itself understands them) | **reconstructable** — `LegacyV2StateAdapter.initializeFromDocument()` already re-seeds V2 from the authoritative Engine graph on every fresh WebView creation; this is the existing, correct reconstruction path, not something a Workspace schema needs to touch |
| Engine undo stack | **requires architectural work** — no serialization exists in `oep_engine` at all; adding it is an Engine change, explicitly out of bounds here |
| In-flight AI requests (Copilot's `_asking`, any pending provider call) | **intentionally ephemeral** — a request that was mid-flight at shutdown has no meaningful "resume" semantics |
| Transient acquisition jobs (an in-progress download/verification) | **intentionally ephemeral** for the *in-memory progress state* — the underlying job's persisted record (via Acquisition's own storage) is unaffected either way; a Workspace schema restoring "Acquisition tab was open" does not need to know a job was mid-flight |
| Ephemeral search results | **intentionally ephemeral** (§2) |
| Modal/dialog state | **intentionally ephemeral** (§2) |
| Provider-owned runtime objects (`EngineeringEngine`, `WebviewController`, `LegacyV2BridgeTransport`) | **requires architectural work if ever "serialized" directly** — but this is a non-goal by construction: nothing in this audit proposes serializing an object, only identifiers a fresh instance can be reconstructed from |
| Unsaved document mutations | **reconstructable** — via the existing, separate autosave/recovery system (§2), not a Workspace-schema concern |

No hazard in this list requires a new mechanism to *avoid* a mistake —
the existing architecture already keeps every one of these correctly
out of any would-be identifier-only schema, because none of them are
identifiers.

## 6. Restoration dependency ordering

Derived from actual code dependencies (`engineering_project_service.dart`'s
`build()`/`ensureEngineStarted()`, `diagram_studio_controller_provider.dart`'s
`bootstrap()`, `StudioShell`'s own `_workspaceHost`/`_diagramStudioHost`
construction), not assumed:

```
1. Application startup (Flutter binding, Riverpod ProviderScope)
2. Foundation initialization (FoundationRuntimeNotifier — connects to a
   repository if one is configured; independent of any project/document)
3. Project restoration (EngineeringProjectStorage.load(id), IF an
   activeProjectId were to be restored — sets EngineeringProjectState.activeProject)
4. Engine/document restoration (ensureEngineStarted() + DiagramDocument
   load-from-path, IF the project names a diagramDocumentPath — this is
   already exactly how "opening a project" works today, unrelated to
   the Workspace)
5. StudioShell construction (_workspaceHost, _diagramStudioHost — both
   already unconditional and built once regardless of any restoration)
6. Workspace session restoration (WorkspaceTabsController.openSurface(...)
   for each restored surfaceId, in order, activating the restored
   activeSurfaceId last)
7. Surface construction (each restored tab's SurfaceDefinition.build(),
   or the reserved Diagram embedding — already happens lazily and
   automatically the moment step 6 populates the tab list; no separate
   step is actually needed)
8. Provider/context restoration — NOT a separate step: every Surface
   already reads its own provider state reactively (Foundation/
   Acquisition/Exchange/Engine); there is nothing to "restore" here
   beyond what steps 2-4 already produced
```

**No cycle was found.** Step 6 (Workspace tabs) depends on nothing from
step 3/4 (project/document) except that *if* a Diagram tab is restored,
opening it is safe regardless of whether a project/document was also
restored — `EngineeringProjectState.build()` already defaults to a
blank `DiagramDocument()` with no project, and the Diagram Surface
already renders correctly against that blank state today (confirmed:
this is the app's own default launch state right now). So step 6 could,
in principle, run independently of steps 3-4 succeeding, failing, or
being skipped entirely — there is no hard ordering *requirement*
between "which project is active" and "which Workspace tabs are open,"
only the loose, already-true-today ordering that Foundation/Engine
initialization (steps 2-4) must exist before any Surface that reads
them is actually built (step 7), which — since Riverpod providers are
lazily initialized on first read regardless of widget build order — is
already guaranteed by the framework, not something restoration ordering
needs to enforce by hand.

## 7. Proposed minimal session schema

A precedent for exactly this shape **already exists and ships today**:
`WebSurfaceTabsStorage` (`lib/web_surface/web_surface_tabs_storage.dart`)
persists `{surfaces: [...], activeId}` for Diagram Studio's own internal
Web Surface tab host, as one JSON file under `SettingsStorage.root()`,
loaded once on `WebSurfacesHostPage.initState()` and saved after every
tab mutation. It persists *identity only* (id/title/url), never page
state — exactly the boundary this audit recommends for the Workspace.

If restoration were implemented, the schema this audit would justify is:

```text
WorkspaceSession
    version
    openSurfaces: List<String>   // surfaceId, in tab-strip order;
                                  // WorkspaceTab.diagramSurfaceId is a
                                  // valid entry like any other
    activeSurfaceId: String?
```

`activeProjectId`/`activeDocumentId` are deliberately **not** included:
§2 classifies the active project as RESTORE OPTIONAL and the active
document as RECONSTRUCT FROM AUTHORITY — both already have their own
independent, pre-existing restoration paths (`EngineeringProjectStorage`,
`DiagramDocument.path`/`findRecovery`) that exist and would be exercised
by "opening a project" regardless of the Workspace, not something a
Workspace-tab schema should re-encode. Adding them here would duplicate
an existing authority rather than describe new information, which §6 of
this task's own instructions (Phase 6) explicitly warns against ("only
information that cannot be derived from existing authorities").

This schema is **not implemented** by this package — proposed only, per
the task's explicit instruction not to implement unless a small
implementation is required to *prove* the architecture. The existing
`WebSurfaceTabsStorage` already proves it; no further proof-of-concept
is needed.

> **Status update:** implemented as proposed by `AP-OEP-WORKSPACE-PERSISTENCE-001`
> — see `lib/workspace/workspace_tabs_storage.dart` and this document's
> own top-of-file note.

## 8. Multi-document implications

The current architecture has exactly one Engine/session authority, one
`EngineeringProjectState`, one Diagram Surface, and one document context
— confirmed throughout this audit and every prior Workspace package in
this series. A restored `WorkspaceSession` under the proposed schema
(§7) restores **the current session's tab identity**, not multiple
documents or projects: `openSurfaces` is a list of *Surface kinds*
(knowledge, acquisition, diagram, ...), each of which is a single,
shared, singleton view over the one active project/document — opening
"Diagram" twice is already structurally impossible (`WorkspaceTabsController`'s
one-tab-per-surfaceId policy), so there is no multi-document ambiguity
to resolve. Attempting to restore *multiple simultaneous documents/
projects* would require a fundamentally different Engine (multiple
`EngineHost`s, multiple `EngineeringProjectState`s, a document-scoped
rather than app-scoped `diagramStudioControllerProvider`) — a major
architecture change, correctly out of scope and not attempted here.

## 9. Prerequisites

None block restoring **Workspace tab identity** (§7's schema) — the
architecture is already sound for that scope, and a working precedent
(`WebSurfaceTabsStorage`) already ships in this codebase.

One prerequisite exists only if a *future* package wants to also restore
Copilot's conversation specifically (§4): Copilot would need a real
Riverpod-backed state authority (mirroring how every other Surface
already has one) before its conversation could be restored — today it's
`ConsumerStatefulWidget` local `State`, with nothing else to read from.
This is not a prerequisite for the Workspace-tab-identity schema itself,
only for that one optional enhancement.

## 10. Final readiness classification

**B — READY WITH PREREQUISITES**, scoped narrowly:

- The architecture is **READY (A)** for the minimal, justified scope
  established in §7 — open-Surface-identity + active-Surface-identity
  restoration — with a directly-reusable precedent already shipping in
  this codebase (`WebSurfaceTabsStorage`).
- It is only **READY WITH PREREQUISITES (B)** if a future package's
  ambition extends to restoring Copilot's conversation specifically,
  which needs a state-authority prerequisite first (§9).
- Restoring finer-grained per-Surface state (filters, scroll, selected
  object/job/package) is **RESTORE OPTIONAL**, not blocked by anything
  architectural — it is a scope decision, not a readiness gap.
- Restoring Engine undo/redo, WebView internals, or true multi-document
  support is **NOT READY (C)** and correctly out of bounds — each would
  require genuine Engine or architecture changes this audit's hard
  constraints already forbid attempting.

## Recommended next package

None proposed automatically — per this package's own instruction, no
persistence implementation begins until a future package explicitly
elects to build the §7 schema.

> **Status update:** that future package was `AP-OEP-WORKSPACE-PERSISTENCE-001`,
> completed. §10's classification (READY, narrowly scoped to §7) held —
> no prerequisite work was needed for the schema actually built.
