# OEP Surface / Tab Architecture Audit (AP-OEP-SURFACE-ARCHITECTURE-001)

**Status: DERIVED/PROPOSED — NOT RATIFIED.** This document does not
amend `OEP_ENGINEERING_CONSTITUTION.md`, `OEP_STUDIO_ARCHITECTURE.md`,
`OEP_INTERACTION_MODEL.md`, or any constitution. Every claim below is
tagged EXISTING (verified in code), DERIVED (a direct, evidence-based
generalization), PROPOSED (a recommendation requiring ratification), or
OPEN (genuinely undetermined by this audit). No production code was
modified to produce this document.

> **Implementation status update (DOCS-SYNC-001 reconciliation note, not
> a rewrite of this audit).** This document's §5 Surface Registry
> proposal was subsequently built — `lib/core/surfaces/surface_registry.dart`
> (`SurfaceRegistry`) is the current, canonical, app-wide Surface source,
> used identically by the sidebar, the "+" New Tab menu, and cross-Surface
> navigation (`AP-OEP-SURFACE-ARCHITECTURE-002/003`, `AP-OEP-WORKSPACE-SHELL-001`,
> `AP-OEP-WORKSPACE-UX-001`). Statements below describing the "+" menu as
> "only reachable from inside Diagram Studio today, not yet the app's
> primary entry point" (§7) or the Surface Registry as merely proposed
> (§5, §20) describe this document's own point in time, not current
> reality. The audit reasoning itself is left unchanged as the historical
> record that led to the current implementation.

---

## 1. Current navigation architecture (Phase 1)

**EXISTING**, traced directly:

- `StudioDestination` (`core/routing/studio_destination.dart`) — an
  enum of 17 values, each `(label, path, icon, selectedIcon)`. This is
  **A: application navigation** — a flat list, no hierarchy, no
  surface/tab concept of its own.
- `StudioRegistry` (`core/routing/studio_registry.dart`) — pairs each
  `StudioDestination` with a `StudioDescriptor` (`pageBuilder`,
  optional `settingsProvider`/`searchProvider`, `CapabilityDescriptor`
  list). `pageBuilder` signature is `Widget Function(BuildContext,
  GoRouterState)`. This is **A/B boundary**: it's still navigation
  (one destination → one page), but it's also the closest thing today
  to a "surface factory" — confirmed by direct reuse this session,
  where `WebSurfacesHostPage._nativeDestinationPage` had to
  re-implement a parallel switch over `StudioDestination` because
  `pageBuilder` requires a real `GoRouterState` a tab-embedded page
  doesn't have. **This is a real, current architectural seam**, not
  hypothetical — Phase 5 returns to it.
- `app_router.dart` — one `GoRouter` with one `ShellRoute` wrapping
  every destination in `StudioShell`. **A: application navigation**
  (routing), **G: partially legacy** — its own top comment documents a
  standing instruction ("revert before any real work") about `/diagram`
  needing special handling because WebView2 can't initialize under
  `flutter test`.
- `StudioShell` (`app/studio_shell.dart`) — the one persistent widget
  every route renders inside (confirmed: its `State` survives
  navigation, per the existing `didUpdateWidget` override and this
  session's own `_diagramStudioHost` preload work, which depends on
  that persistence). Contains a **Diagram-Studio-only carve-out**: when
  `selected == StudioDestination.diagram`, it returns a full-screen
  `Scaffold` with none of the Menu Bar/Toolbar/Ribbon/Breadcrumb
  Bar/Sidebar/Property Inspector — Diagram Studio "owns the full
  window" (its own doc comment, unchanged by this audit). This is
  **A + F**: it is the navigation shell, and it is what currently makes
  the sidebar contextual UI rather than global (it's absent for one
  specific destination).
- `WorkbenchSidebar` (`workbench/widgets/workbench_sidebar.dart`) —
  per its own code comment (read directly), "the app's single left
  nav, replacing the classic `StudioNavRail`," driven by
  `PerspectiveManager.instance` and the current `StudioDestination`.
  **OPEN**: this audit did not fully re-verify whether the items it
  renders are `Perspective`s (a `EngineeringWorkbenchPage`-native
  concept) or `StudioDestination`s wrapped to look like Perspectives —
  the file's own header comment states the two are "the same shared
  instance," but the exact mapping between "17 registered destinations"
  and "the Perspective list this sidebar iterates" was not traced item
  by item. Phase 7 marks this explicitly rather than asserting a
  precise answer.
- `WebSurface`/`WebSurfaceTabsController`/`WebSurfacesHostPage`
  (`web_surface/`) — **B: workspace/tab state** and **E: presentation
  technology**, detailed in Phase 2.
- `DiagramTab`/`DiagramTabsController`/`DiagramTabsStorage`
  (`diagram_studio/tabs/`) — **B: workspace/tab state**, but see the
  critical finding below: it is explicitly a *reference* system, not
  independent document state.
- **Not found as separate registered destinations** (confirmed this
  session via targeted research, not assumed): "Evidence" (a Knowledge
  Studio-internal model, `EvidenceRegion`/`EvidenceLink`), "Components"
  (does not exist as a concept anywhere), "Instruments" (a `Perspective`
  inside the retired-from-Nav-Rail `EngineeringWorkbenchPage`,
  `/diagram-classic` only, with no working session outside a
  Diagram-Studio-hosted `DiagramSimulationService`), "Simulation" (an
  internal Diagram Studio service, `DiagramSimulationService`, not a
  Studio), "AI Sessions" (Knowledge Studio's ephemeral, never-persisted
  `AiConversation`, not a Studio). These terms, present in this task's
  own prompt, do not correspond to registered OEP surfaces today — **G:
  they are internal concepts of Knowledge Studio/Diagram Studio/the
  retired Workbench, not independent navigation targets.**

## 2. Current Diagram Studio tab architecture (Phase 2)

**EXISTING**, and the single most important finding in this audit —
**there are two structurally different tab systems already in the
codebase, not one, and this task's own "+ menu" reference behavior
spans both:**

### 2a. `WebSurface` tabs (`WebSurfacesHostPage`) — genuinely independent state

- **New tab creation**: the "+" `PopupMenuButton` (added this session,
  `_TabStrip` in `web_surfaces_host_page.dart`) offers "New Diagram"
  plus every `StudioDestination` except `diagram`/`diagramClassic`.
  "New Diagram" calls `EngineeringProjectServiceNotifier.newDocument()`
  then activates/creates the Diagram Studio `WebSurface` tab. Every
  other menu item calls `_openNativeTab(destination)`.
- **Menu population**: a static, hand-written list in `_TabStrip`
  (`_nativeDestinations`) — **not** dynamically derived from
  `StudioRegistry.defaultRegistry` today. This is a real, concrete gap
  Phase 5 must address if a Surface Registry is adopted: two lists
  (the Nav Rail's and the "+" menu's) currently have to be kept in sync
  by hand.
- **Surface instantiation**: for a `StudioDestination`,
  `_WebSurfacesHostPageState._nativeDestinationPage` directly
  constructs the real page widget via a `switch` (bypassing
  `StudioDescriptor.pageBuilder`, which needs a `GoRouterState` this
  embedded context doesn't have). For Diagram Studio, the existing,
  unmodified `LegacyV2WebViewPage` is embedded directly. For a generic
  URL, `WebSurfaceView` owns its own `WebviewController`.
- **Context reception**: Diagram Studio's `WebSurface` tab receives
  document context by reading `diagramStudioControllerProvider`
  (Riverpod) directly — the tab itself carries no document reference;
  the document lives in `EngineeringProjectService`, one instance,
  Riverpod-global. Native destination tabs receive whatever context
  their own page already reads from Riverpod (e.g. Knowledge Studio
  reads `foundationRuntimeServiceProvider`) — **the tab wrapper adds no
  context of its own in either case.**
- **State retention**: every open tab (`WebSurface` or `_NativeTab`) is
  kept in one `IndexedStack` — non-visible children stay mounted, so a
  generic `WebSurfaceView`'s `WebviewController`/JS/navigation history,
  and V2's own in-page state, survive tab switches. Verified directly
  (this session built and tested this).
- **Activation/closing**: `_activate(id)`/`_close(id)`, unified this
  session across both `WebSurface` and `_NativeTab` via one
  `_activeTabId` field (previously `WebSurfaceTabsController.activeId`
  alone, which had no concept of a native tab id).
- **Persistence**: `WebSurfaceTabsStorage` (added this session) persists
  the `WebSurface` tab list + active id as one JSON file under
  `SettingsStorage.root()`, restored on next launch, with the Diagram
  Studio tab guaranteed present even if it wasn't in the saved set.
  **`_NativeTab`s are explicitly NOT persisted** (session-only) — a
  real, accepted, documented gap, not an oversight.
- **Multiple surfaces coexisting**: yes, structurally proven —
  Diagram Studio + a generic web tab + a native Knowledge Studio tab
  can all be open, each independently, right now.

### 2b. `DiagramTab` tabs (`diagram_studio/tabs/`) — reference-only, NOT independent

Direct quote, `diagram_tab.dart`'s own doc comment (load-bearing,
verified this session, not previously highlighted in any prior task's
findings this repo's history shows):

> "`EngineeringProjectState` holds exactly ONE live
> `DiagramDocument`/`EditingSession`... A `DiagramTab` is therefore a
> real, persisted REFERENCE to a document (path/title/pin/mode); at
> most one tab is 'active' at a time, and its content is what the
> single shared engine/session actually holds. Switching tabs goes
> through the existing, unmodified Open/Save/Close/dirty-check
> pipeline... never a second document model."

**This means "Diagram Studio's tabs," in the native-renderer-era sense
this task's reference behavior implicitly evokes, were never
independent sessions — they were a most-recently-used list of
paths/titles, switching which single shared session's content is
loaded.** This is architecturally distinct from `WebSurface` tabs,
which genuinely do hold independent per-tab state (WebviewController
instances). **A Surface/Tab architecture proposal must not conflate
these two — they currently obey different rules for a real reason
(one shared Engine session vs. N independent WebView instances), not
an inconsistency to "fix" by force.**

**Reusable vs. Diagram-Studio-specific** (Phase 2's explicit question):
- Reusable: the `IndexedStack`-keeps-state pattern; the
  persist-tab-list-as-JSON-under-`SettingsStorage.root()` pattern (used
  identically by both `DiagramTabsStorage` and the new
  `WebSurfaceTabsStorage`); the "+"-menu-as-`PopupMenuButton` UI
  pattern.
- Diagram-Studio-specific (do not generalize as-is): `DiagramTab`'s
  reference-only, single-shared-session model — this is a real
  limitation of `EngineeringProjectService`, not a template to copy.

## 3. Definition of Surface (Phase 3)

**DERIVED**, justified only by what's actually implemented (no field
included speculatively):

> An **OEP Surface** is a distinct, independently-identifiable unit of
> engineering work or reference content that can be opened as a tab: it
> has a stable identity (`id`), a human-readable `title`, a `type`
> (which presentation technology renders it — native Flutter,
> Legacy V2 WebView, or generic Web Surface), and a way to be
> instantiated as a widget. It does **not** own engineering data itself
> — it reads whatever context (a document, a session, nothing) already
> exists in the platform's own state (Riverpod providers,
> `EngineeringProjectService`, `FoundationRuntimeService`).

Minimum fields justified by evidence (§ existing `WebSurface` +
`_NativeTab`, unified):
- `id` — required; both existing models have one.
- `title` — required; both existing models have one (`WebSurface.title`
  static, `_NativeTab` derives it live from `destination.label`).
- `icon` — justified: `_TabChip` already renders one for every tab kind
  today (derived differently per kind, but always present).
- **`presentationTechnology`** — justified: this is exactly
  `WebSurfaceApplication` (`legacyV2`/`generic`) generalized to also
  cover "native Flutter," the third case `_NativeTab` already is.
- A **factory/instantiation function** — justified: both
  `_buildSurfaceContent` and `_nativeDestinationPage` are exactly this,
  just written as two separate `switch` statements today instead of one
  registry lookup.

Fields considered but **not** justified by current evidence (excluded,
per this task's explicit "do not automatically include all of these"):
- `context` as a first-class Surface field — **not evidenced**: no
  current Surface carries its own context object; every one reads
  ambient Riverpod state instead (§2a). Inventing a `context` field
  now would be speculative, not derived.
- `capabilities` on a per-Surface-instance basis — **partially
  evidenced** only at the `StudioDescriptor` level
  (`CapabilityDescriptor` list), never per-tab-instance. Not carried
  into either `WebSurface` or `_NativeTab` today.
- `persistence behavior`/`restoration behavior` as Surface-level
  fields — **evidenced only at the tab-collection level**
  (`WebSurfaceTabsStorage` decides what's persisted), not as a property
  a Surface itself declares. `_NativeTab`'s current "never persisted"
  is a decision made by the host page, not something `_NativeTab`
  itself expresses.

## 4. Definition of Tab (Phase 4)

**DERIVED.** Explicit distinctions, each grounded in what's actually
different in code today:

- **Engineering data** — lives in the Engine/`EngineeringProjectService`
  /`FoundationRuntimeService`. Never held by a tab or a Surface.
- **Document** — `DiagramDocument`, one live instance per
  `EngineeringProjectService`. A `DiagramTab` references it by
  `path`/`id`; it does not contain it.
- **Surface** — the *kind* of content (§3) — "Diagram Studio," "a
  generic web page," "Knowledge Studio embedded as a tab."
- **Surface instance** — one open occurrence of a Surface, with its own
  `id` and (for `WebSurface`/generic pages) genuinely independent
  runtime state (a `WebviewController`). This is what `WebSurface` and
  `_NativeTab` both already are.
- **Tab** — the UI-visible chip in the strip plus its place in the
  `IndexedStack`/activation/close bookkeeping. Today, a tab **is** a
  Surface instance for `WebSurface`/`_NativeTab` (one-to-one, no extra
  wrapper type) — but for `DiagramTab`, a tab is explicitly **only a
  reference** to the one shared document/session, not a Surface
  instance with its own state.

**Answering Phase 4's direct question** ("is a Tab a surface instance,
a reference to a surface, a session object, a presentation container,
or another existing concept?"): **it is currently both, inconsistently,
depending on which of the two existing tab systems you're looking at**
— a `WebSurface`/`_NativeTab` tab is a real Surface instance; a
`DiagramTab` is a reference only. **Any ratified Surface/Tab model must
either (a) explicitly accept this as two legitimate tab kinds with
different semantics, matching a browser's own distinction between "a
tab with its own page state" and "a tab that's just a bookmark to a
shared thing," or (b) fund the `EngineeringProjectService` redesign
required to make `DiagramTab` a real independent session too — which
this task explicitly puts out of scope (multi-document editing is a
separate, larger undertaking).**

**Preventing a second source of truth** (explicit requirement): already
achieved for both systems today, for different reasons — `WebSurface`
tabs never touch engineering data at all (Legacy V2's own bridge
already routes every mutation through the one authoritative Engine
command stack, per `DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`); a
`DiagramTab` structurally cannot diverge from the Engine's state
because it holds no state to diverge — it's a pointer. **No violation
found.**

## 5. Proposed Surface Registry (Phase 5)

**PROPOSED**, evaluated against the real gap found in §2a: today, two
lists exist that should be one — `StudioRegistry.defaultRegistry` (Nav
Rail + routing) and `_TabStrip._nativeDestinations` (the "+" menu,
hand-written, added this session). This is a real, live example of
exactly the duplication a Surface Registry would prevent — not a
hypothetical.

**Should it replace `StudioRegistry`?** No — evidenced by `StudioRegistry`
still owning things a Surface Registry has no evidenced need for
(routing/`GoRouterState`, `settingsProvider`, `searchProvider`).
**Should it sit above/alongside it?** Yes, DERIVED: a `SurfaceDefinition`
could wrap a `StudioDescriptor` (for native destinations) or a
`WebSurfaceApplication` (for Legacy V2/generic), giving the "+" menu
one real source instead of a parallel hand-maintained list — this
directly fixes the concrete duplication found in §2a, not a
speculative future benefit.

**Minimum architecture actually required** (not the full proposed
shape in this task's prompt — trimmed to what's evidenced):
- `id`, `title`, `icon` — justified, §3.
- A way to build the widget without a `GoRouterState` — justified: this
  is the exact problem `_nativeDestinationPage`'s parallel switch
  exists to solve today. A `SurfaceDefinition.build(BuildContext)`
  signature (no `GoRouterState`) would let `StudioRegistry` and a
  Surface Registry share one factory instead of two.
- **NOT justified by current evidence**: `context requirements` as a
  declared field (§3 — no Surface expresses this today);
  `capabilities` at the definition level beyond what
  `CapabilityDescriptor` already provides (would be a second,
  redundant capability system without a demonstrated gap the first one
  doesn't already cover).

**This document does not implement this model** — per the task's
explicit instruction, this is a "should we" determination, and the
answer is: **yes, sitting above `StudioRegistry` for native
destinations and above `WebSurfaceApplication` for web-backed ones,
with a deliberately small field set**, not a replacement of either.

## 6. Surface categories (Phase 6)

**DERIVED from actual registered functionality**, not assumed:

| Category | Status | Evidence |
|---|---|---|
| Engineering | CURRENT | Diagram Studio, Engineering Intelligence, Objects, Relationships, Graph — all operate on committed Engineering Objects/Relationships |
| Project | CURRENT | Project Explorer, Repository |
| Knowledge | CURRENT | Knowledge Studio (source ingestion, candidate review) |
| Acquisition | CURRENT | Engineering Acquisition — not named in this task's own suggested category list, but a real, distinct, registered destination that doesn't fit "Engineering" or "Project" cleanly |
| Validation | CURRENT | Validation destination |
| Exchange | CURRENT | Engineering Exchange (marketplace) |
| System | CURRENT | Settings, Search, Packages |
| AI | CURRENT, but not a Surface itself | Copilot is a registered destination; "AI Sessions" (§1) is Knowledge-Studio-internal, not its own category-worthy Surface |
| Evidence | **NOT A CATEGORY** — it's a Knowledge Studio-internal concept (§1), not a registered Surface | — |
| Instruments | **NOT A CATEGORY** — a Perspective inside the retired Workbench shell, no working standalone session (§1) | — |
| Simulation | **NOT A CATEGORY** — an internal Diagram Studio service (§1) | — |
| Reference | **UNKNOWN** — no current destination maps cleanly to this; this task's own suggested category, not evidenced by the registry | — |
| Components | **DOES NOT EXIST** in the codebase at all (§1) | — |

## 7. Sidebar migration matrix (Phase 7)

| Current Sidebar Function | Current Purpose | Proposed Surface/Context | Replacement | Keep? | Reason |
|---|---|---|---|---|---|
| Perspective/destination list (`WorkbenchSidebar`'s main list) | Primary navigation | Each item becomes a `SurfaceDefinition` in the "+" menu | The "+" menu (already exists, this session) | **Keep, dual-purpose** | Removing the sidebar before the "+" menu is proven at parity would violate the task's own "do not propose deleting the sidebar until its functional replacement has been demonstrated" instruction — the "+" menu is promising but only reachable from inside Diagram Studio today, not yet the app's primary entry point |
| Collapse/expand toggle | Density control | N/A — UI chrome, not a navigation concept | Itself | **Keep** | Pure UI affordance, no Surface-model relationship |
| Filter/search field (`_ExpandedSidebar`) | Narrow the destination list | Directly maps to Phase 14's "can surfaces be searched?" | A searchable "+" menu (PROPOSED, not built) | **Keep until replacement exists** | Real, working functionality today; the "+" menu has no search yet |
| `_OepMark`/"OEP" brand row | Branding | N/A | Itself | **Keep** | Not a navigation mechanism |
| Diagram-session-active-aware hiding of some destinations (`diagramSessionActive` param, confirmed passed into `WorkbenchSidebar`) | Contextual UI — hides irrelevant destinations while a diagram is open | Contextual UI, unchanged in shape | Itself, or an equivalent contextual filter on the "+" menu | **Keep** | This is exactly Phase 7's "F: contextual UI" case — a real, working contextual behavior, not obsolete |

**Sidebar retirement conclusion**: **not currently supportable** — the
"+" menu, as it exists today, is scoped to Diagram Studio's own page
(`WebSurfacesHostPage`) and is not reachable from, e.g., Knowledge
Studio. Retiring the sidebar would require the "+"-menu-equivalent (or
the sidebar itself) to be available from *every* Studio, which is an
unimplemented, unproven generalization — correctly out of this task's
scope to build.

## 8. Routing classification (Phase 8)

**DERIVED.** Every current route is **A: user-facing navigation
destination** (17 of 17) — none are purely internal/implementation
routes, deep-link-only, or explicitly marked temporary, **except**
`/diagram-classic`, which is **D: temporary compatibility route** by
its own code comment (kept solely to host the Instruments/Engineering
Perspectives until they're rehomed, not offered in the Nav Rail).

**Can a Surface exist independently of a route?** **Yes — already
proven**, not merely theoretical: every `_NativeTab` this session added
is exactly that — "Knowledge Studio embedded as a tab" has no route of
its own; it's the same `KnowledgeStudioPage` widget the `/knowledge`
route also builds, constructed directly without going through
`GoRouter` at all. **This is the strongest single piece of evidence in
this entire audit that a Surface is not the same thing as a route** —
it was proven by this session's own shipped code, not asserted.

## 9. Multiple-surfaces capability (Phase 9)

| Scenario | Classification | Evidence |
|---|---|---|
| 1. One document + one surface | IMPLEMENTED | Default Diagram Studio state |
| 2. One document + multiple surfaces | IMPLEMENTED | Diagram Studio `WebSurface` tab + a Knowledge Studio `_NativeTab`, both open, both able to read `EngineeringProjectService`'s one document independently, right now |
| 3. Multiple documents + one surface type | **ADAPTER REQUIRED** at best | `DiagramTab`'s reference-only model (§2b) means two "diagram tabs" today share one session — a second, genuinely independent document open simultaneously is not supported without the `EngineeringProjectService` redesign this task excludes |
| 4. Multiple documents + multiple surfaces | **ARCHITECTURE REQUIRED** | Depends on #3 first |
| 5. Same document open in multiple tabs | SUPPORTED BY EXISTING ARCHITECTURE, narrowly | Two `WebSurface`/`_NativeTab` tabs can both read the same one document (§ scenario 2) — but this is "two views of the one document," not "the same document opened as two independent editable copies" |
| 6. Same surface type opened twice | **ADAPTER REQUIRED** | `_openNativeTab`/`_openLegacyV2` both explicitly reuse-if-open rather than allow duplicates today — opening the same destination twice as two independent tabs is a deliberate current restriction, not a gap nobody considered |
| 7. Surface with no document | IMPLEMENTED | Settings, Search, Packages — none require a document |
| 8. Surface requiring a project | SUPPORTED BY EXISTING ARCHITECTURE | Repository/Objects/Relationships already gate on `EngineeringProjectState` |
| 9. Surface requiring a selected object | SUPPORTED BY EXISTING ARCHITECTURE | `PropertyInspectorPanel`'s entire design (§ AP-OEP-INTERACTION-MODEL-002 audit) already does this via `SelectionService`/`FoundationServiceState` |
| 10. Surface requiring a selected relationship | SUPPORTED BY EXISTING ARCHITECTURE | Same mechanism as #9, relationship selection is part of the same selection surface |

## 10. Tab lifecycle (Phase 10)

**EXISTING**, traced for both systems:

- **Create**: `WebSurface`/`_NativeTab` — object constructed, added to
  the in-memory list, `setState`. `DiagramTab` — `openTab()` creates a
  reference; no document is loaded yet.
- **Initialize**: `WebSurface` — `initState()` runs `_controller.
  initialize()`/`loadUrl` (real WebView2 cold start). `_NativeTab` —
  the page widget's own `initState`/Riverpod `build()` runs normally.
  `DiagramTab` — `EngineeringProjectNotifier.openDocument(path)` loads
  the referenced file into the one shared session.
- **Active/Inactive**: governed by `IndexedStack`'s index
  (`WebSurface`/`_NativeTab`) or `DiagramTabsState.activeTabId`
  (`DiagramTab`) — inactive `WebSurface`/`_NativeTab` content stays
  mounted (state retained); an inactive `DiagramTab` retains only its
  reference, since the shared session's content changes when a
  *different* tab becomes active.
- **Close → Dispose**: `WebSurface`/`_NativeTab` — removed from the
  list; `IndexedStack` no longer renders it, so its `State.dispose()`
  runs (WebviewController disposed for `WebSurface`). `DiagramTab` —
  `closeTab()` triggers the existing dirty-check pipeline
  (`_confirmDiscardChanges`) before removing the reference; the shared
  session itself is only actually torn down if no tab still references
  it.
- **Persistence**: `WebSurface` tabs — `WebSurfaceTabsStorage`, on every
  mutation. `_NativeTab` — never (§2a). `DiagramTab` —
  `DiagramTabsStorage`, including a `recentlyClosed` list `WebSurface`
  tabs have no equivalent of.
- **Unsaved work on close**: `DiagramTab`'s existing dirty-check
  pipeline is unchanged and authoritative; `WebSurface`/`_NativeTab`
  tabs have no independent "unsaved work" concept of their own (any
  unsaved document state lives in the one shared
  `EngineeringProjectService`, gated by the same pipeline regardless of
  which tab triggered the close).
- **Project change / app restart**: `WebSurface` tabs restore from
  disk (§2a); `_NativeTab`s do not (reset to empty, § accepted gap);
  `DiagramTab`s restore from `DiagramTabsStorage` independently of
  `WebSurfaceTabsStorage` — **two separate restore mechanisms run at
  boot today, not one.**

## 11. Context model (Phase 11)

**EXISTING mechanism found, no new one needed**: Riverpod itself is
already the de facto context mechanism — `diagramStudioControllerProvider`,
`engineeringProjectServiceProvider`, `foundationRuntimeServiceProvider`,
`acquisitionSelectionProvider` each expose exactly the context types
this task's prompt lists (project, document, engineering object,
relationship, evidence item) as `ref.watch`-able state, already
consumed uniformly by `PropertyInspectorPanel` regardless of which
Studio is active (confirmed directly, AP-OEP-INTERACTION-MODEL-002).
**No global context system needs inventing** — a Surface's "context
requirement" (§3, explicitly excluded from the model as a declared
field) is better expressed as "which Riverpod provider(s) this
Surface's own widget reads," which is already how every current Surface
gets its context, with zero exceptions found.

## 12. Presentation technology (Phase 12)

**EXISTING**, confirmed and extended this session: `WebSurfaceApplication`
(`legacyV2`/`generic`) is joined by a third, unnamed-but-real case —
"native Flutter," which `_NativeTab` already is. **DERIVED**: a
`PresentationTechnology` enum (`native`/`legacyV2WebView`/`genericWeb`)
generalizes cleanly from what exists — no invention required. **Can
multiple presentation technologies implement the same Surface?**
Evidenced conceptually (Diagram Studio's own history: native Flutter
renderer → Legacy V2 WebView, per `DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`
§19, confirmed the Studio identity outlived the technology swap) but
**not currently implemented as a live choice** — today, each
`StudioDestination`/`WebSurfaceApplication` has exactly one
presentation technology at a time, never two coexisting
implementations of the same Surface. This document does not propose
building that; it only confirms the distinction (Surface ≠ presentation
technology) already holds.

## 13. Document and Engine authority (Phase 13)

Chain verified: **Tab → Surface → Controller/Service → Engineering
Document → OEP Engine.** No violation found, for either tab system —
§4's "preventing a second source of truth" analysis applies identically
here. **No duplicate document state, no duplicate selection authority,
no duplicate undo authority, no duplicate dirty-state authority** was
found in either `WebSurface`/`_NativeTab` tabs or `DiagramTab`s. The one
documented, narrower gap from this session's own recent work (not a
Surface/Tab architecture defect): a Command-Palette-triggered Undo
while Diagram Studio's `WebSurface` tab is open may leave V2's on-screen
module position stale until the next V2-originated action — a bridge
resync timing gap, not a second-authority violation (the Engine's own
undo state is never duplicated or contradicted).

## 14. New Tab menu architecture (Phase 14)

Answering each question against what's actually implemented today:

- **What appears?** Currently: "New Diagram" + a hand-written list of
  14 `StudioDestination`s (§2a) — not yet Registry-driven (§5's gap).
- **How is it categorized?** Not categorized today — one flat list,
  divider only between "New Diagram" and everything else.
- **What requires a document?** Only "New Diagram" implicitly (it calls
  `newDocument()`); every native destination tab opens regardless of
  document state, matching each destination's own existing behavior
  when reached via the Nav Rail.
- **What requires a project?** Not distinguished in the menu itself —
  a destination requiring a project (e.g. Objects) still opens as a
  tab; it shows its own existing "no project open" state, same as via
  the Nav Rail.
- **What can open multiple times?** Nothing today — every menu action
  reuses-if-open (§ scenario 6, Phase 9).
- **New tab vs. focus existing?** Always focus-if-open, never a true
  duplicate, for every current menu item.
- **Searchable?** No — PROPOSED, not built (§7's sidebar-parity gap).
- **Recently used?** No — not evidenced anywhere.
- **Extension-registerable?** No — Phase 17 addresses this directly.

## 15. Browser-like behavior assessment (Phase 15)

| Behavior | Status |
|---|---|
| Tab close | CURRENT |
| Restoration after restart | CURRENT (`WebSurface` tabs only — `_NativeTab`s excluded, § accepted gap) |
| Tab reorder | FUTURE |
| Close others / close to right | FUTURE |
| Reopen closed tab | CURRENT for `DiagramTab` (`recentlyClosed` list already exists), FUTURE for `WebSurface`/`_NativeTab` |
| Duplicate tab | NOT APPROPRIATE, per Phase 9 scenario 6's deliberate reuse-if-open design |
| Pin tab | CURRENT for `DiagramTab` (`pinned` field already exists, unused by `WebSurface`), FUTURE for `WebSurface`/`_NativeTab` |
| Tab search | FUTURE (§14) |
| Tab overflow | CURRENT — the strip already scrolls horizontally (`SingleChildScrollView`, this session's own spacing fix) |
| Keyboard navigation | FUTURE — not evidenced anywhere in the tab strip |
| Split view / compare view | FUTURE — no evidence anywhere; would be genuinely new work, not a generalization of anything existing |

## 16. Cross-Studio generalization (Phase 16)

| Destination | Classification |
|---|---|
| Diagram Studio | Already a Surface (reference implementation) |
| Knowledge Studio | Surface — already proven as a `_NativeTab` this session |
| Engineering Acquisition | Surface — same mechanism would apply, not yet exercised as a `_NativeTab` in practice but structurally identical to Knowledge Studio's case |
| Repository, Objects, Relationships, Search, Graph, Validation, Packages | Surface-eligible, same mechanism, unexercised |
| Engineering Intelligence | Surface-eligible; internally dashboard-shaped (§ AP-OEP-INTERACTION-MODEL-001 audit), which the Surface model doesn't preclude |
| Engineering Exchange | Surface-eligible |
| Copilot | Surface-eligible |
| Settings | Surface-eligible, already included in the "+" menu |
| Project Explorer | Surface-eligible |
| Evidence, Components, Instruments, Simulation, AI Sessions | **NOT surfaces** — confirmed not to exist as independent destinations at all (§1); they remain **F: contextual UI** (Evidence, AI Sessions — panels/dialogs inside Knowledge Studio) or **G: legacy/temporary infrastructure** (Instruments/Simulation, tied to the retired Workbench shell) |

## 17. Extension/plugin implications (Phase 17)

**No plugin/extension architecture exists today** — confirmed by
absence (no `plugin`/`extension` registration mechanism found anywhere
in `core/routing/` or elsewhere touched by this or prior audits this
session). `StudioRegistry.defaultRegistry` is a single, static,
hand-authored list; the "+" menu's `_nativeDestinations` is equally
static. **Minimum architectural requirement, if extension-registerable
Surfaces are ever wanted**: a registration API on the Surface Registry
proposed in §5 (e.g. `SurfaceRegistry.register(SurfaceDefinition)`,
called before the Nav Rail/"+" menu first builds) — genuinely new
infrastructure, not present in any form today, and explicitly not
built by this document.

## 18. Architectural consequences (Phase 18)

If §5's Surface Registry were adopted:

- `StudioDestination`/`StudioRegistry` — would gain a Surface Registry
  layered above/alongside them (§5), not be replaced.
- `StudioShell` — unaffected directly; still the one persistent shell.
- `WorkbenchSidebar` — its item list could source from the same
  Surface Registry the "+" menu uses, closing §7's duplication, but
  this is not required to adopt the Registry.
- `DiagramTabsController`/`WebSurfaceTabsController` — would remain
  two separate controllers (§2b's real semantic difference means they
  should not be merged) but could both consume `SurfaceDefinition`s
  from the same Registry for their respective "open a new one of these"
  menus.
- `app_router.dart`, project/document lifecycle, persistence, deep
  links, the command system, search, contextual inspectors — **none
  require modification** for the Registry itself to exist; all evidence
  above is additive.

## 19. Migration strategy (Phase 19)

Dependency-ordered, incremental, reusing existing infrastructure at
every step (per the task's explicit instruction):

1. **Extract a `SurfaceDefinition` list from the existing
   `StudioRegistry.defaultRegistry`** (a thin wrapper, not a rewrite) —
   closes §2a/§14's concrete duplication between the Nav Rail and the
   "+" menu's hand-written list.
2. **Point `_TabStrip`'s "+" menu at that extracted list** instead of
   its own hand-written `_nativeDestinations` — a small, low-risk
   change to code already built this session.
3. **Only then** consider whether `WorkbenchSidebar` should source from
   the same list (§7) — deliberately sequenced after step 2, since step
   2 is lower-risk (one menu, already isolated in
   `web_surfaces_host_page.dart`) than touching the app-wide sidebar.
4. **Only after** steps 1–3 are proven, evaluate persisting `_NativeTab`s
   (closing the accepted gap in §2a/§10) using the exact
   `WebSurfaceTabsStorage` pattern already built.
5. **Do not attempt** `DiagramTab`'s reference-only limitation (§2b,
   §9 scenarios 3–4) as part of this migration — it requires an
   `EngineeringProjectService` redesign this task explicitly excludes,
   and conflating it with the Registry work above would block low-risk
   progress on a large, separate undertaking.

**The sidebar is not proposed for deletion at any step above** — per
the task's explicit constraint, and because step 3 only reaches "should
source from the same list," not "should be removed."

## 20. Architectural decision (Phase 20)

**B — SUPPORTED WITH CONDITIONS.**

Not A (STRONGLY SUPPORTED), because: the "+" menu proposed as evidence
is real but scoped to one page (`WebSurfacesHostPage`) today, not
app-wide; two tab systems exist with genuinely different semantics that
a naive "unify everything" reading of this task's own architectural
hypothesis would incorrectly conflate; extension/plugin support does
not exist in any form.

Not C/D, because: the core mechanism (independent Surface instances in
an `IndexedStack`, reusable across Diagram Studio and at least one other
real Studio) is proven, working, tested code as of this session — not
speculative.

**Conditions for B**:
1. Adopt §5's Surface Registry as an additive layer, not a replacement
   of `StudioRegistry`.
2. Explicitly ratify that `DiagramTab`-style reference tabs and
   `WebSurface`/`_NativeTab`-style independent-instance tabs are both
   legitimate, distinct tab kinds — not a defect to unify.
3. Do not attempt multi-document editing (§9 scenarios 3–4) as part of
   adopting this model — it is a separate, larger, Engine-adjacent
   undertaking.
4. Do not retire the sidebar until the Registry-driven "+" menu is
   proven reachable from more than one Studio (§7, §19 step 3).

## 21. Files created

`platform/oep_studio/docs/OEP_SURFACE_ARCHITECTURE.md` (this document).
Confirmed via direct check that no file of this name existed before.

## 22. Files modified

None. No production source was changed to produce this audit.

## 23. Files deleted

None.

## 24. Tests/analyze results

Not applicable — no source files were touched. (This session's prior,
separate implementation work on `WebSurfacesHostPage`/native tabs was
already verified — 768/768 `oep_studio` tests passing, clean
`flutter analyze` — before this audit began; this audit itself required
no new verification since it made no code changes.)

## 25. Remaining open decisions

1. **`WorkbenchSidebar`'s exact Perspective-vs-`StudioDestination`
   relationship** (§1) — not fully traced this session; needed before
   §7's migration matrix can be executed with full confidence.
2. **List 1 vs. List 2 Studio-taxonomy authority** (carried over,
   unresolved, from `OEP_STUDIO_ARCHITECTURE.md` §15) — still blocks a
   fully authoritative Surface category list (§6) for any future,
   currently-unbuilt Studios.
3. Whether `_NativeTab` persistence (closing the accepted gap in §2a)
   is worth building before or after the Surface Registry extraction
   (§19 step 4 vs. steps 1–3) — a sequencing question, not resolved
   here.
4. Whether `DiagramTab`'s reference-only limitation should ever be
   funded as a real project — explicitly out of this task's scope to
   decide, only to document as a real constraint (§2b, §9, §20
   condition 3).

## 26. Recommended next package

A small, low-risk implementation package covering **only** Migration
Strategy steps 1–2 (§19): extract a `SurfaceDefinition` list from
`StudioRegistry.defaultRegistry` and point the existing "+" menu at it,
closing the one concrete, already-observed duplication this audit
found — without touching the sidebar, `DiagramTab`, or any Engine/
Foundation/Legacy V2 code.
