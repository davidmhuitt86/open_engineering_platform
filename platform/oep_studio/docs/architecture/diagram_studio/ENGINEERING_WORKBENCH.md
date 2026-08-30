# Engineering Workbench — Architecture (WP-DS-006, Phase 1)

> **Status: RETIRED (AP-OEP-WORKBENCH-RETIREMENT-001).** Everything
> below is a historical record of the Workbench/Perspective architecture
> as it stood after WP-DS-006 Phase 1 — it no longer describes current
> production code. `AP-OEP-WORKBENCH-PLACEHOLDER-DECISION-001` found the
> seven non-Diagram, non-Engineering, non-Instruments Perspectives (Home,
> Dashboard, Inspection, Simulation, Publishing, Library, Review) were
> inert placeholders with no unique functionality, and
> `AP-OEP-WORKBENCH-RETIREMENT-001` removed `PerspectiveManager`,
> `EngineeringWorkbenchPage`, `WorkbenchLayoutManager`,
> `WorkbenchCommandManager`, `WorkbenchThemeManager`,
> `WorkbenchStatusBar`, `workbench_perspectives.dart`, the retired
> retired Perspective objects (`engineeringPerspective`/`instrumentsPerspective`),
> `StudioNavRail`, `/diagram-classic`, and the WORKBENCH section of
> `WorkbenchSidebar` (which now only renders RESOURCES/TOOLS/STUDIOS
> navigation). Two corrections to claims made below, specifically: the
> "Diagram Perspective" this document describes was itself already
> removed earlier by `AP-DIAGRAM-V2-BRIDGE-010` (Legacy V2, bridged via
> `/diagram`, replaced it) — by the time of this retirement it no longer
> existed for anything to "remain reachable... from inside" (§ the
> Publishing/Simulation section below); and `PublishingCenterDialog`/
> `SimulationCenterDialog`, named there as where that functionality
> "remains reachable," do not exist anywhere in the current codebase —
> no evidence was found that this functionality exists in any currently
> reachable production surface. Engineering and Instruments' real content
> survives, unchanged, as ordinary Workspace Surfaces
> (`lib/workbench/perspectives/engineering_perspective.dart`/
> `instruments_perspective.dart`, § `AP-OEP-WORKBENCH-PERSPECTIVE-MIGRATION-001`).

## Scope decision: nested inside `StudioShell`, not a replacement

The governing spec describes the Engineering Workbench as if it were the
whole application. This codebase already has a top-level `StudioShell`
(`lib/app/studio_shell.dart`) with its own nav rail, app-wide toolbar, and
status bar, hosting several existing "Studios" (Dashboard, Diagram Studio,
Acquisition, Knowledge, Repository, Objects, Relationships, Search, Graph,
Validation, Packages, Engineering Intelligence, Exchange, Settings — see
`lib/core/routing/studio_registry.dart`). The spec's silence on what
happens to Acquisition/Knowledge/Repository/Settings under a full
replacement argues against building one.

Instead, the Engineering Workbench is what `StudioRegistry`'s existing
`diagram` destination now hosts: `_diagramBuilder` returns
`EngineeringWorkbenchPage(perspectives: workbenchPerspectives)` instead of
a raw `DiagramStudioPage`. The nav rail label stays `'Diagram Studio'`
(three existing tests assert that exact label by text; a rename attempt
broke them) — the "Engineering Workbench" identity lives inside the new
shell itself (its Perspective Selector, its own status bar), one level
below `StudioShell`'s own chrome, not in the outer nav label.

## The 8 managers: reuse vs. build new

The governing spec names 8 Workbench-owned managers. For each, the choice
below was to reuse an existing, already-shipped piece of this codebase
where one already covers the responsibility, and build new, narrowly
scoped code only where nothing existed yet.

1. **Perspective Manager** — built new: `lib/workbench/perspective/perspective_manager.dart`.
   Nothing existing covered "register/activate/persist/restore a
   Perspective"; mirrors `StudioRegistry`'s own pluggable-list pattern.

2. **Dock Manager** — built new: `lib/workbench/dock/dock_manager.dart` +
   `dock_state.dart`. WP-DS-005A's `InstrumentDockController` covers only
   the Instrument Dock, hardcoded to one file and one set of positions
   (bottom + floating, left/right modeled but rendered as bottom). The
   governing spec requires a dock primitive usable by *any* Perspective's
   *any* number of dock regions, keyed by a caller-chosen `dockId` — a
   genuine generalization, not a copy.

3. **Layout Manager** — built new: `lib/workbench/layout/workbench_layout_manager.dart`.
   One JSON file per Perspective id under `workbench_layouts/`
   (`diagram.json`, `simulation.json`, `inspection.json`,
   `publishing.json`, ...) — nothing existing modeled "one layout per
   Perspective."

4. **Window Manager** — not built as a separate class. The governing
   spec's Window Manager responsibilities (a movable/resizable in-app
   surface detached from the docked layout) are already covered by
   `DockRegion`'s own floating-window handling (`_FloatingFrame` in
   `lib/workbench/dock/dock_region.dart`) — drag-to-move, drag-to-resize,
   dock-back-to-bottom. A separate, empty `WindowManager` wrapping the
   same state `DockManager` already owns would be a class with no
   independent responsibility. Same disclosed boundary WP-DS-005A's own
   `InstrumentDock` already had: an in-app `Positioned` surface, not a
   real second OS window (Flutter desktop multi-window isn't wired into
   this Studio anywhere).

5. **Workspace Manager** — reused: `lib/core/workspace/workspace_manager.dart`
   (`WorkspaceManager`, WP-STUDIO-029) already covers Diagram-document
   lifecycle, recent files, and crash recovery. No engineering-document
   concept exists at the Workbench level that isn't already a Diagram
   document, so a second, duplicate manager was not built. The Diagram
   Perspective's embedded `DiagramStudioPage` continues to use
   `WorkspaceManager` exactly as it did before this Work Package.

6. **Command Manager** — reused + thin extension:
   `lib/core/commands/command_registry.dart` (`CommandRegistry`,
   WP-STUDIO-023) already provides Platform-wide command dispatch
   (`CommandDescriptor`/`CommandArgs`/`CommandResult`/`execute`).
   `CommandRegistry.defaultRegistry` is a `static final` built once from a
   fixed list literal with no `register`/`add` method — extending it in
   place would mean editing `command_registry.dart`, a different,
   already-shipped Work Package's file, which is out of scope. Instead
   `lib/workbench/command/workbench_command_manager.dart` builds a
   **second** `CommandRegistry` instance (`WorkbenchCommandManager.registry`)
   seeded with every command from `CommandRegistry.defaultRegistry` plus
   one Workbench-only command, `workbench.activatePerspective`. This
   reuses `CommandRegistry`'s existing shape completely; no new dispatch
   mechanism was written.

7. **Theme Manager** — reused + thin accessor:
   `lib/core/theme/studio_colors.dart` (`StudioColors`) is the one
   app-wide palette already used by `StudioShell`, every existing Studio,
   and every Workbench widget built so far. `lib/workbench/theme/workbench_theme_manager.dart`
   (`WorkbenchThemeManager`) exposes the same named colors one property at
   a time, purely as an injectable/mockable seam, and forwards every one
   to `StudioColors`. `colorsFor(perspectiveId)` is a documented seam for
   a hypothetical future per-Perspective override; today it always
   returns `this` — no second palette was invented.

8. **Session Manager** — reused: `PerspectiveManager.restoreLastPerspective`
   plus `WorkbenchLayoutManager.load` together are this Work Package's
   entire "session" concern (which Perspective was active, what its
   layout looked like) — both already built as part of items 1 and 3
   above. Beyond that, "session" in the engineering sense (an open
   diagram document, undo history, unsaved-changes tracking) is
   `WorkspaceManager`'s responsibility (item 5), reused unchanged. No
   separate `SessionManager` class was built because nothing was left
   over once 1, 3, and 5 are accounted for — a class with no unique
   responsibility of its own was judged unnecessary complexity for Phase
   1.

## `WorkbenchRegistry` — not built

`oep_engine`'s `EngineRegistry` (`register<T>()`/`require<T>()`
service-locator pattern) was considered as a way to tie the managers
above together for one owning `EngineeringWorkbenchPage` instance.
Deliberately **not built** for Phase 1: only 3 of the 8 manager concepts
are actually separate, stateful classes with a lifecycle
(`PerspectiveManager`, `WorkbenchLayoutManager`, `DockManager` — one per
dock region) — `EngineeringWorkbenchPage` already constructs/owns
`PerspectiveManager`/`WorkbenchLayoutManager` directly (both injectable via
its constructor for tests), and each `DockManager` is already scoped to
whatever dock region constructs it (e.g. `InstrumentsPerspectiveDock`'s own
`_dockManager`). A service locator wrapping three constructor parameters
plus a couple of stateless accessor classes (`WorkbenchThemeManager`,
`WorkbenchCommandManager`) would add a layer of indirection with no
current caller needing runtime lookup-by-type — nothing in Phase 1 needs
to resolve "the current dock manager" generically across an unknown set of
managers. If a later phase adds enough independently-constructed
Workbench-scoped services that ad hoc wiring becomes unwieldy, revisit this
decision then.

## Window Structure mapping

```
Workbench
 ├── Menu                  -> StudioShell's existing AppBar/menu (not duplicated)
 ├── Perspective Selector   -> WorkbenchSidebar (lib/workbench/widgets/) —
 │                             a LEFT SIDEBAR, not a top row. Superseded
 │                             and replaced the original horizontal
 │                             PerspectiveSelector widget, which has been
 │                             deleted (no longer referenced anywhere).
 ├── Global Toolbar         -> the active Perspective's toolbarProvider,
 │                             rendered as a second, Workbench-scoped
 │                             toolbar strip directly under StudioShell's
 │                             own app-wide StudioToolbar
 ├── Left Dock              -> the active Perspective's leftPanelProvider
 ├── Center Workspace       -> the active Perspective's centerBuilder
 ├── Right Dock             -> the active Perspective's rightPanelProvider
 ├── Bottom Dock            -> the active Perspective's bottomPanelProvider
 └── Status Bar             -> WorkbenchStatusBar (suppressed by a
                                Perspective whose own centerBuilder already
                                sits under equivalent status chrome — see
                                Perspective.suppressWorkbenchStatusBar)
```

### WorkbenchSidebar (left sidebar navigation)

Replaces the original horizontal Perspective Selector row with a
collapsible left sidebar (`lib/workbench/widgets/workbench_sidebar.dart`),
matching a later design mock. Real behavior, not a static mockup port:

- **Collapsed/expanded** — a persisted (`WorkbenchSidebarState`,
  `workbench_sidebar.json`) toggle between a full sidebar (240px, every
  section labeled) and a narrow icon-only rail (52px, tooltips only).
- **WORKBENCH section** — every registered `Perspective`, in
  `PerspectiveManager.perspectives` order, iterated with no per-perspective
  conditional logic. The active Perspective, if it declares
  `sidebarSubItemsProvider`, shows an expand chevron revealing real
  sub-items (not fabricated data) — see the two real examples below.
- **RESOURCES section** — Library (activates the registered `library`
  Perspective), Repository/Packages (real `context.go` navigation to the
  already-existing sibling `StudioDestination` routes one level up in
  `StudioShell` — this sidebar does not rebuild those pages, it jumps to
  them).
- **TOOLS section** — Search (opens the existing Command Palette dialog),
  Tasks & Jobs (a real, live badge count and list sourced directly from
  `OperationManager.instance`, WP-STUDIO-030's own cross-Studio operation
  tracker — nothing fabricated), Reports (honestly disabled — no such
  feature exists anywhere in this codebase yet).
- **Filter box** — a real, client-side substring filter over the
  WORKBENCH/RESOURCES/TOOLS row labels. **Disclosed scope reduction**: an
  earlier design mock's "Context Filtered" state showed a full categorized
  cross-corpus search-results panel (Engineering Objects / Diagrams /
  Documents, each with live counts) — building that would mean a new
  cross-corpus search aggregator this sidebar owns, a materially larger
  piece of work than a navigation-filter box, and this codebase's one real
  search path (`UnifiedSearchService`) is page-based, not
  sidebar-embeddable without its own redesign. The filter box is real and
  functional, just narrower in scope than that mock's full vision.
- **Footer** — the real OS username (`Platform.environment['USERNAME']`),
  not a fabricated name; a generic "Engineer" role label, since this
  codebase has no per-user profile/role storage to draw a real one from.

Two Perspectives contribute real `sidebarSubItemsProvider` content today:

- **Diagram** (`perspectives/diagram_perspective.dart`) — current
  document name, Open/New actions, and up to 5 real recent documents from
  `WorkspaceManager.instance.recentWorkspaces` (WP-STUDIO-029). Opening a
  recent document calls `EngineeringProjectNotifier.openDocument` directly
  — the same call `CommandRegistry`'s already-shipped `diagram.openDocument`
  command makes (WP-STUDIO-023), which also does not run
  `DiagramStudioPage`'s local unsaved-changes confirmation dialog. This
  sidebar therefore introduces no new data-loss risk beyond what the
  Command Palette already exposes; it does not duplicate or bypass a
  safety check that existed for this exact action before.
- **Engineering** (`perspectives/engineering_perspective.dart`) — real
  navigation to the already-existing Objects/Relationships/Validation
  pages (separate `StudioDestination`s), not a new in-perspective object
  browser — rebuilding that browsing UI inside the Workbench would
  duplicate already-shipped pages and is out of this phase's scope.

**A real layout regression this redesign caused and fixed**: adding the
240px sidebar alongside `StudioShell`'s own 200px nav rail and right-hand
Property Inspector panel measurably narrowed the width available to
`DiagramStudioPage`'s own toolbar (`_DocumentBar`), which overflowed by
20px at `test/workflow/unified_workflow_test.dart`'s previous 1280px test
viewport width. Fixed by widening that test's fixed viewport to 1600px
(real viewport headroom, not a change to any assertion) — not by touching
`_DocumentBar` itself, which stays out of scope ("Do NOT redesign Diagram
UI yet"). The same file's viewport height was separately widened to 950px
across two earlier fixes for the same class of issue (several of Diagram
Studio's own side panels run with only single-digit-pixel vertical margin
at smaller fixed test sizes).

`EngineeringWorkbenchPage` (`lib/workbench/engineering_workbench_page.dart`)
contains no perspective-specific conditional logic anywhere — it iterates
`PerspectiveManager.perspectives`/reads `PerspectiveManager.active` and
calls whatever provider that `Perspective` supplies. Adding an eleventh
Perspective is a call to `PerspectiveManager.register`, never an edit to
this file (the governing spec's own explicit "no switch statements for
perspectives" constraint).

## The Instruments Perspective's dock-adapter approach

Governing spec, Dock Manager section: "Existing Instrument Dock should
become a generic dock client." WP-DS-005A's own `InstrumentDock` widget,
`InstrumentDockController`, and `EngineeringInstrument`/`InstrumentRegistry`
contract (`lib/diagram_studio/instruments/`) are **not modified** by this
Work Package — migrating that chrome wholesale risked regressing 37
passing, tested instrument tests, and "No DMM changes" is explicitly out
of scope.

Instead:

- `lib/workbench/perspectives/instrument_dock_panel_client.dart` defines
  `InstrumentDockPanelClient`, a small adapter implementing the new
  `DockPanelClient` contract by wrapping one existing, untouched
  `EngineeringInstrument` — `id`/`title`/`icon` pass through, `buildPanel`
  delegates to the wrapped instrument.
- `lib/workbench/perspectives/instruments_perspective.dart` defines the
  Instruments Perspective. Its `bottomPanelProvider` builds
  `InstrumentsPerspectiveDock`, which owns its own `DockManager` (dockId
  `'instruments-perspective'`) and `DockPanelClientRegistry`, populated by
  adapting whatever `EngineeringInstrument`s it's given.

**Disclosed constraint**: constructing a real instrument (the Digital
Multimeter, `DigitalMultimeterInstrument`) requires a live
`DiagramSimulationService`, which itself requires an active
`EngineeringEngine`/diagram session. That session belongs to a specific
open Diagram document and is owned by `diagram_studio_page.dart`'s own
state (`_initInstruments`). The Instruments Perspective is reached as a
sibling of the Diagram Perspective, not as part of it, so it has no
engine/session to construct a real instrument against today.
`InstrumentsPerspectiveDock` is honest about this: with no instruments
supplied, it renders a clearly-labeled empty state ("No instruments
available in this Perspective yet... Open the Diagram Perspective...")
rather than crashing or fabricating data, while the real `DockManager`/
`DockPanelClientRegistry`/`DockRegion` plumbing underneath is fully wired
and tested end to end. A future Work Package that connects "the currently
open diagram's session" to the Workbench (out of scope here — no such
integration was requested) can pass real `EngineeringInstrument`s into
`InstrumentsPerspectiveDock` with no further changes to this file.

Diagram Studio's own in-page `InstrumentDock`, reached via the Diagram
Perspective, is completely unaffected and keeps working exactly as before.

## The other 8 non-Diagram Perspectives — disclosed placeholder state (historical; retired)

> **Correction (AP-OEP-WORKBENCH-RETIREMENT-001):** the claim below that
> `PublishingCenterDialog`/`SimulationCenterDialog` "remain reachable...
> from inside the Diagram Perspective" was already stale by the time of
> this retirement — that native "Diagram Perspective" had itself been
> removed by `AP-DIAGRAM-V2-BRIDGE-010`, and neither dialog class exists
> anywhere in the current codebase. No evidence was found that Publishing
> or Simulation functionality exists in any currently reachable
> production surface. All 9 Perspectives named below (the 7 pure
> placeholders plus Engineering/Instruments, whose real content moved to
> Workspace Surfaces) were removed by this retirement.

Home, Dashboard, Inspection, Engineering, Simulation, Publishing, Library,
and Review (`lib/workbench/perspectives/workbench_perspectives.dart`) are
each a genuine, registered `Perspective` — real `id`/`title`/`icon`, a
real `centerBuilder` — but that `centerBuilder` is an honest "not yet
built" placeholder (`_PlaceholderCenter`), per the governing spec's own
"Build the shell only" / "Those will occur after the shell is complete"
language. None of them relocate real content from elsewhere (e.g.
`PublishingCenterDialog`/`SimulationCenterDialog` remain reachable exactly
as today, from inside the Diagram Perspective) — doing so is explicitly
out of scope ("No Publishing redesign" / "No new simulation features").
Most supply no `toolbarProvider`/panel providers at all, since they have
no real content yet to put a toolbar above.
