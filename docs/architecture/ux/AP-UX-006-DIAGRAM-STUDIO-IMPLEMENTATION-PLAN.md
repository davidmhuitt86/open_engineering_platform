# AP-UX-006 — OEP Diagram Studio Final Design-to-Code & Implementation Plan

**Status:** READ-ONLY architecture audit and implementation planning. No Flutter, Engine, rendering, Foundation, or database code was modified to produce this document.

**Baseline:** `7ee9583f8c826d46ac1015ac0e0b19b2f44aca35` (post `AP-UX-005-VISUAL-DESIGN-COMPLETION.md`). Verified via `git rev-parse HEAD`; matched exactly. `git status --short` showed only the same pre-existing unrelated working-tree material tracked since WP-CTRL-002 — untouched by this work package.

---

## 1. Mission Restated

`docs/architecture/ux/` is the active target UX architecture, not a competing redesign — this document does not reopen it. The shipped Flutter application (`AP-OEP-WORKSPACE-AS-PRIMARY-UI-001`) is the implementation baseline. This document maps every target Diagram Studio shell region to actual current code, classifies RETAIN/MODIFY/REPLACE/CREATE, establishes ownership boundaries (Studio host / Diagram Studio / Engine), sequences implementation into sectional work, defines the visual QA checkpoint for each section, and lists only the decisions that genuinely remain open. It does not implement code and does not begin `WP-UI-DS-001`.

---

## 2. Governing Documents (read for this pass)

`OEP-UX-ARCHITECTURE.md`, `design-system/OEP-DESIGN-TOKENS.md`, `design-system/OEP-SHELL-COMPONENTS.md`, `design-system/OEP-UI-RULES.md`, `implementation/OEP-UI-IMPLEMENTATION-RULES.md`, `implementation/OEP-UI-SECTIONAL-IMPLEMENTATION.md`, `implementation/OEP-VISUAL-QA-PROTOCOL.md`, `implementation/DS-GOLDEN-WORKSPACE-SPEC.md`, `implementation/WP-UI-DS-001-PROMPT.md`, `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md`, `AP-UX-004-TARGET-UX-ARCHITECTURE-COMPLETION.md`, `AP-UX-005-VISUAL-DESIGN-COMPLETION.md`, all render assets under `renders/oep-shell/` and `renders/diagram-studio/`, `.claude/skills/oep-ui/SKILL.md`, plus current-implementation documentation under `platform/oep_studio/docs/` including `DIAGRAM_STUDIO_V2_RENDERER_IMPLEMENTATION_PLAN.md`, `architecture/diagram_studio/DIAGRAM_STUDIO_CONSTITUTION.md`, `DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md`, `architecture/diagram_studio/ENGINEERING_WORKBENCH.md`, `DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md`, and the actual Flutter source under `platform/oep_studio/lib/`.

---

## 3. Critical Architectural Constraint — Confirmed Sound, RETAIN

The Engine/rendering boundary is real, already documented by the codebase's own frozen constitution, and is sound. `DIAGRAM_STUDIO_CONSTITUTION.md` §2–3 states the governing rule verbatim, ratified as constitutional: **"Studio orchestrates, Engine executes."** Concretely, as confirmed by direct code inspection this session:

```text
OEP Engine (platform/oep_engine, Dart package "engineering_engine")
   — EngineeringGraph (document/graph model)
   — EditingCommand / CommandHistory (the only path to mutation)
   — GraphViewPanel, SymbolNodeWidget, WirePainter, etc. (the actual canvas renderer — Engine-owned, not Studio-owned)
        ↓
DiagramStudioController (lib/diagram_studio/controller/diagram_studio_controller.dart)
   — the sole execution gateway: addNode, moveNodes, commands.undo/redo, markDirty, document lifecycle
        ↓
LegacyV2StateAdapter → LegacyV2BridgeTransport (lib/diagram_studio/webview/)
   — V2 id ↔ OEP node id mapping, coordinate conversion, loop-guard; the only layer that knows both vocabularies
        ↓
LegacyV2WebViewPage
   — hosts the actual visible diagram surface: an embedded, unmodified legacy V2 HTML/JS
     wiring-sim application (reference/legacy_wiring_sim_v2/eke-wiring-sim/), loaded via
     WebviewController.loadUrl('file://...')
        ↓
DiagramWithComparePane / _DiagramInstanceTab
   — Studio-side wrapper: adds the Compare/Analysis/DMM/Trace toggle row around LegacyV2WebViewPage
```

This is **RETAIN** in its entirety. This plan explicitly protects it: no target-shell work may duplicate `EngineeringGraph`, add a second command system, bypass `DiagramStudioController` for mutation, or reach `engine.editing.execute` directly from new shell code. A parallel, still-experimental native canvas renderer (`lib/diagram_studio/renderer/`, `V2CanvasHost` et al., per `DIAGRAM_STUDIO_V2_RENDERER_IMPLEMENTATION_PLAN.md`) exists behind a debug-only, default-`false` toggle (`_useV2CanvasDev`) inside the **separate, legacy** `DiagramStudioPage` — it is not part of the production Workspace path and this plan does not touch it or depend on it.

---

## 4/5. Current Implementation vs. Target Design — Summary of Investigation

Full evidence (file paths, line numbers, class responsibilities) was gathered by direct inspection of `platform/oep_studio/lib/` and is incorporated throughout §7–§13. Key finding, stated once here because it governs everything below:

**The production Diagram Workspace today has no persistent shell chrome at all.** `StudioShell`'s own doc comment (`lib/app/studio_shell.dart`) states verbatim that the Menu Bar/Toolbar/Ribbon/Breadcrumb Bar/Sidebar/Property Inspector/Output Panel/Status Bar it originally rendered were **removed** (`AP-OEP-WORKSPACE-AS-PRIMARY-UI-001`) in favor of a single tabbed `EngineeringWorkspacePage`. Its `build()` has exactly three `Scaffold` branches (`diagram` — dead/unreachable, `workspace` — effectively always active, fallback — never reached), none of which render an `appBar`, nav rail, or bottom bar. This confirms and sharpens AP-UX-003's original finding with exact code evidence.

A second, richer shell (`EngineeringWorkbenchPage`/`PerspectiveManager`/`WorkbenchSidebar`/`DockManager`, described at length in `ENGINEERING_WORKBENCH.md`) **was built and then explicitly retired** (`AP-OEP-WORKBENCH-RETIREMENT-001`) before this plan was written — its own file carries a "RETIRED" banner. This is HISTORICAL, not a competing target, and is not reused by this plan; it is recorded in §21 for completeness.

---

## 6. Target Diagram Studio Shell (restated, unchanged)

```text
Application Header      58px
Global Studio Bar        56px
Workspace Bar            42px
Context Navigation ─┬─ Main Engineering Surface ─┬─ Inspector
   (variable)        │                            │   (variable)
                      Toolbar (60px, full-width row below the split)
Status Bar               36px
```

No conflicting dimensions were found in any current implementation file (none of the current widgets hardcode a competing height for these regions, because none of these regions currently exist as persistent chrome). AP-UX-002/AP-UX-005 geometry stands ungoverned by any code-side counter-evidence.

---

## 7. Component Mapping Table

| Target Region | Target Responsibility | Current Implementation | Current Location | Action | Ownership | Dependencies | QA Checkpoint |
|---|---|---|---|---|---|---|---|
| Application Header | OEP identity, app-level controls, quiet, 58px | `OepStudioHeader` — but Diagram-Studio-scoped and responsive (72/60/48px), rendered only `if (activeTab.isDiagram)` | `lib/diagram_studio/header/oep_studio_header.dart`; call site `lib/workspace/engineering_workspace_page.dart:173,179` | MODIFY (repurpose scope) + CREATE (new app-global header) | Studio host | `StudioShell` (needs to become the host), design tokens | Section 02 — header visible above Global Studio Bar at fixed 58px in every Studio, not just Diagram |
| Global Studio Bar | Switch between 7 ratified Studios, per-Studio identity color on active | **NOT FOUND** as a persistent widget. Closest historical analog: retired `WorkbenchSidebar`'s WORKBENCH section (removed) | N/A (removed) | CREATE | Studio host | `StudioDestination` enum (needs pruning, §11), design tokens §2A | Section 03 — 56px bar, 7 destinations, Diagram Studio active state matches `global-studio-bar.svg` |
| Workspace Bar | Open-work tabs within active Studio, Studio-color inheritance | `_WorkspaceTabStrip` — real, working, but conflates Studio launching with workspace-tab management (§10) | `lib/workspace/engineering_workspace_page.dart` (`_WorkspaceTabStrip`, height hardcoded `36` at the widget's height constant) | MODIFY | Studio host | `WorkspaceTabsController`, `WorkspaceTabsStorage` | Section 04 — 42px (was 36px — geometry correction), tabs still function identically, "+" menu now only lists open-work items, not Studios |
| Context Navigation | Workspace-scoped contextual tree (structure → context → view) | **NOT FOUND**. No breadcrumb/context-nav widget exists anywhere in `lib/` | N/A | CREATE | Diagram Studio | Active `DiagramDocument`/`EngineeringGraph` (read-only projection), `DiagramStudioController` | Section 05 — matches `context-navigation.svg`; selecting a tree node updates Inspector without touching global nav |
| Toolbar | Studio-specific actions, full-width row, global `oep.accent` only | `DiagramWithComparePane`'s 28px toggle row (Analysis/Compare/DMM/Trace) — functions as a toolbar but is not a named/reusable `Toolbar` widget, and is only 28px tall vs. the 60px target | `lib/diagram_studio/compare/diagram_with_compare_pane.dart` (rows ~146–207, annotated `AP-DIAGRAM-TOOLBAR-STATIC-001` in comments) | MODIFY (extract + regeometry) | Diagram Studio | `DiagramStudioController` commands (undo/redo etc.), Legacy V2 toggle hooks | Section 07 — 60px full-width row below the 3-column split, existing Analysis/Compare/DMM/Trace actions preserved and regrouped per `toolbar.svg` |
| Main Engineering Surface | Real wiring-diagram canvas, Engine-owned | `LegacyV2WebViewPage` (via `DiagramWithComparePane` for the primary tab, `_DiagramInstanceTab` for secondary tabs) — real, working, Engine-bridged | `lib/diagram_studio/webview/legacy_v2_webview.dart`; wrapper `lib/diagram_studio/compare/diagram_with_compare_pane.dart`; secondary-tab wrapper `lib/workspace/engineering_workspace_page.dart:382–404` | RETAIN (layout adaptation only) | Engine (rendering/model) + Diagram Studio (integration) | `LegacyV2BridgeTransport`, `LegacyV2StateAdapter`, `DiagramStudioController`, OEP Engine | Section 08 — same rendered diagram content, now fit into the center column between Context Nav and Inspector rather than filling the whole tab body |
| Inspector | Selected-object properties, contextual, oep.accent only | Scattered, feature-specific panels exist (`TraceInspectorPanel`, `engineering_relationship_properties.dart`'s Property Inspector), but no shared shell-level Inspector region | `lib/diagram_studio/trace/trace_inspector_panel.dart`; `lib/diagram_studio/inspector/engineering_relationship_properties.dart` | CREATE (shell region) + RETAIN (existing panel logic, reparented) | Diagram Studio | `GraphSelection` (Engine, read-only), existing per-kind property panels | Section 06 — matches `inspector.svg`; existing Trace/relationship-property panels now render inside this region instead of ad hoc placement |
| Status Bar | Concise status/context, non-dashboard | **NOT FOUND**. `StudioShell`'s own doc comment confirms it was removed | N/A (removed) | CREATE | Studio host (frame) + Diagram Studio (content) | Design tokens, active-Studio/workspace state | Section 09 — matches `status-bar.svg`; Ready/Studio/Workspace/Grid/Snap/Zoom/Repo fields populated from real state, not placeholders |

No entry above uses a vague "update the shell" statement; every action names the actual file/class it targets.

---

## 8. Explicit Current-vs-Target Analysis

| Region | A. Exists? | B. Satisfies target? | C. Reuse? | D. Ownership violation? | E. Smallest change |
|---|---|---|---|---|---|
| Application Header | PARTIAL (`OepStudioHeader`, Diagram-scoped) | NO | MODIFY + CREATE | No violation — it's simply scoped too narrowly today | Keep `OepStudioHeader`'s visual language (logo, divider, active-mark) but host a new app-global header in `StudioShell`; retire the per-tab conditional render |
| Global Studio Bar | NO | NO | CREATE | N/A (doesn't exist) | New widget hosted by `StudioShell`, backed by a pruned `StudioDestination`-derived list (§11) |
| Workspace Bar | YES (`_WorkspaceTabStrip`) | PARTIAL (works, wrong height, conflates Studio+workspace concerns) | MODIFY | Yes — see §10 | Change height token 36→42px; remove the "Diagram Studio"/"Browser" launch entries from its "+" menu once the Global Studio Bar exists to launch Studios instead |
| Context Navigation | NO | NO | CREATE | N/A | New widget, Diagram-Studio-owned, reading the active document's structure read-only through `DiagramStudioController`/`EngineeringGraph` accessors that already exist for the Inspector/selection path |
| Toolbar | PARTIAL (28px toggle row) | NO (wrong height/position/scope) | MODIFY | No violation — it's real Studio-owned presentation, just under-scaled | Extract the toggle row into a full 60px toolbar component; keep every existing action wired to the same handlers |
| Main Engineering Surface | YES (`LegacyV2WebViewPage`) | YES (content) / NO (layout — currently fills the whole tab body, not a bounded center column) | RETAIN | No violation — this is exactly the boundary §3 protects | Constrain `LegacyV2WebViewPage`'s `Expanded` to the new center column's bounds; no change to the widget's internals, bridge, or Engine calls |
| Inspector | PARTIAL (feature panels exist, no shell region) | NO | RETAIN (panels) + CREATE (region) | No violation | New region hosts the existing `TraceInspectorPanel`/property-panel widgets instead of their current ad hoc placement inside `DiagramWithComparePane`'s side pane |
| Status Bar | NO | NO | CREATE | N/A | New widget, Studio-host-owned frame + Diagram-Studio-supplied content (mirrors `OEP-SHELL-COMPONENTS.md` §9/§10 ownership split) |

---

## 9. StudioShell Analysis

`StudioShell` (`lib/app/studio_shell.dart`) currently provides **no persistent chrome** — confirmed by its own doc comment, not inferred. Its actual responsibilities today are: three bare `Scaffold` branches (diagram — dead route; workspace — the real path; fallback — unreachable), a `CallbackShortcuts` binding for the Command Palette, `StudioLifecycleEvent` publishing, three cross-cutting bridges (Acquisition progress, workspace/engineering-project state, Foundation/OCR state), `WorkspaceManager` init + silent crash recovery, and an unsaved-changes exit dialog.

**It should become the host for the target shell.** This is the natural seam: it already wraps every `Scaffold` and already owns app-wide concerns (shortcuts, lifecycle, bridges) that are conceptually "Studio host," not "Diagram Studio" or "Engine." Concretely:

- **Move into `StudioShell`:** Application Header, Global Studio Bar, Status Bar frame (the bar itself; its *content* is supplied by whichever Studio is active). These are genuinely app-global per `OEP-SHELL-COMPONENTS.md` §2/§3/§9.
- **Remain Studio-specific:** Workspace Bar (already lives in `EngineeringWorkspacePage`, correctly — it is workspace-navigation, not Studio-navigation, see §10), Context Navigation, Toolbar, Inspector — all Diagram-Studio-owned per the target's own region-ownership table.
- **Existing workspace-primary behavior (`EngineeringWorkspacePage` as the tabbed content host) should be RETAINED as the implementation mechanism beneath the new shell, not replaced.** The three existing `Scaffold` branches collapse to one meaningful case in practice already (`workspace`); nothing about adding header/Studio-bar/status-bar chrome around it requires rewriting tab management, persistence, or Studio launching — those move (§10), they are not rebuilt.

---

## 10. Workspace Tab Architecture — `_WorkspaceTabStrip`

Current behavior, from direct inspection: workspace instances are `WorkspaceTab` value objects (`id`, `surfaceId`, `title`, `icon`, `isDiagram`) held by `WorkspaceTabsController` and persisted via `WorkspaceTabsStorage` (`workspace_tabs.json`) — real, working, and reusable as-is. Studio *launching* and workspace *management* are currently **conflated in one control**: the tab strip's own "+" `PopupMenuButton` is simultaneously (a) the only way to open a new Diagram Studio instance or Browser tab, and (b) the only way to open any other registered surface (`SurfaceRegistry.all`, i.e. Knowledge/Acquisition/Repository/Objects/etc.) — all as flat "workspace tab" concepts, with no distinction between "switch to a different Studio" and "open another item inside the current Studio."

**This is the conflation the target architecture explicitly separates:** Global Studio Bar = navigate between Studios; Workspace Bar = manage open work inside the active Studio. The plan does not destroy `_WorkspaceTabStrip`'s reusable logic — it re-scopes its "+" menu. Concretely:

- The Global Studio Bar (new) becomes the only way to switch Studios (Home/Diagram Studio/EAM/Knowledge/Exchange/Instruments/Settings).
- The Workspace Bar's "+" menu loses its "Diagram Studio" and "🌐 Browser" entries (those become Studio Bar destinations/actions) and loses the flat `SurfaceRegistry.all` list (those surfaces become their own Studios or contextual views, not workspace-bar items) — it retains exactly what a Workspace Bar should manage: open documents/instances *within* the currently active Studio (e.g., multiple open diagrams within Diagram Studio).
- `WorkspaceTabsController`/`WorkspaceTabsStorage`/`WorkspaceTab` persistence format do not need to change shape for this — only which menu entries populate the "+" button, and which controller (a new, thin Studio-switch mechanism vs. the existing workspace-tab mechanism) each entry calls.

---

## 11. Studio Inventory (ratified, restated)

```text
Home
Diagram Studio
EAM
Knowledge Studio
Engineering Exchange
Instruments
Settings
```

Engineering Intelligence is **not** a Studio Bar destination (AP-UX-004 §5, AP-UX-005 §5) — it remains available as `engineeringIntelligence`, an internal-capability route, consumed contextually, never re-added to the Global Studio Bar.

**Current-code conflict this creates, recorded not silently resolved:** `StudioDestination` (`lib/core/routing/studio_destination.dart`) has 19 entries today, including `dashboard`, `projectExplorer`, `objects`, `relationships`, `graph`, `validation`, `packages`, `search`, `copilot`, `engineeringWorkbench`, `instrumentsWorkbench` — none of which map cleanly onto the 7-entry ratified inventory. This plan does **not** decide how each of those 12 extra destinations gets folded into the 7 Studios' contextual views (that is Studio-by-Studio design work outside Diagram Studio's own scope) — it only asserts that the **Global Studio Bar** built in Section 03 must expose exactly 7 entries, and that `StudioDestination`'s remaining values become internal routes/contextual destinations reachable from inside a Studio, not new Studio Bar buttons. This reconciliation for Studios other than Diagram Studio is out of scope for AP-UX-006 and is listed as a recommended follow-up in §24.

---

## 12. Diagram Studio Main Surface

Per §3/§8, the existing `LegacyV2WebViewPage` (wrapped by `DiagramWithComparePane` for the primary tab, `_DiagramInstanceTab` for secondary tabs) is retained unchanged in its internals. What changes is purely layout integration:

- **Retained unchanged:** `LegacyV2WebViewPage`, `LegacyV2BridgeTransport`, `LegacyV2StateAdapter`, `DiagramStudioController`, all OEP Engine calls, the Compare/Analysis/DMM/Trace panel logic itself (its *content*, not its current 28px-row *chrome*, which moves per §7).
- **Needs shell integration:** the `Expanded(child: LegacyV2WebViewPage())` currently sizes to the whole tab body; it must instead size to the new center column between Context Navigation and Inspector.
- **Needs layout adaptation:** `DiagramWithComparePane`'s toggle row (Analysis/Compare/DMM/Trace) moves out of the surface's own build tree and into the new Toolbar region (Section 07) — same handlers, same commands, different host widget.
- **Visual theming only:** none identified beyond what Section 07/08's token application naturally covers (no internal V2 webview restyling is in scope — it is explicitly frozen content per `DIAGRAM_STUDIO_CONSTITUTION.md` §4/§5).
- **Inspector ↔ Engine selection:** yes, directly reusable. The existing `_syncPropertyInspectorSelection`-style pattern (documented in `DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` §10, entries 97–98, for the separate legacy `DiagramStudioPage`) already demonstrates the exact mechanism the new Inspector region needs: translate `GraphSelection`/`EngineeringInspectable` into inspector content, read-only, no duplicate selection model. For the production `LegacyV2WebViewPage` path specifically, the equivalent bridge point is `LegacyV2StateAdapter`'s existing id-mapping — the new Inspector reads the Engine's live selection state the same way any other selection-driven UI would, through `DiagramStudioController`, never by inventing a second selection channel from the webview.
- **Context Navigation ↔ existing state:** yes. A read-only structural tree over the active document's `EngineeringGraph` (already exposed through `DiagramStudioController`) is sufficient — no new state model needed.
- **Toolbar ↔ existing Engine operations:** yes, directly. Every action currently in `DiagramWithComparePane`'s toggle row already calls existing, working handlers; the new Toolbar region invokes the same functions, it does not reimplement them.

Result: **NEW TARGET SHELL → existing authoritative Diagram Studio surface → existing Engine/rendering architecture**, exactly as required — not a new duplicate diagram architecture.

---

## 13. Header Analysis

`OepStudioHeader` (`lib/diagram_studio/header/oep_studio_header.dart`) should be **refactored**, not replaced wholesale and not adopted verbatim as the app-global header:

- Its **visual language** (OEP logo mark, vertical divider, active-mark SVG, two-line title/subtitle, responsive height at 72/60/48px) is a reasonable starting point for the new Application Header, but its **content** is Diagram/Simulation-view-swap-specific (`_ViewSwapControl`, "Diagram"/"Simulation" title swap) — that content does not belong in an app-global 58px header per `App Header with OEP Logo.png`'s reconciled target (identity + search + system status + user, no Studio-specific controls, per `OEP-SHELL-COMPONENTS.md` §2: "no Studio-specific navigation embedded here").
- **Recommended split:** a new, genuinely app-global header (hosted by `StudioShell`, fixed 58px, matching `App Header with OEP Logo.png` exactly) replaces `OepStudioHeader`'s role as "the header." `OepStudioHeader`'s Diagram/Simulation swap control is Diagram-Studio-specific chrome — it moves into the new Toolbar (Section 07) or Context Navigation region as a Diagram-Studio-owned control, not into the app header.
- Not invented: the exact target placement of the Diagram/Simulation swap control within Toolbar vs. Context Nav is a genuine small open question — flagged in §23, not decided here, since neither `toolbar.svg` nor `context-navigation.svg` explicitly depicts a Diagram/Simulation mode switch (this is Diagram-Studio-specific state the shared render scenario didn't need to show).

---

## 14. Design Token Migration

| Item | Current state | Target | Gap |
|---|---|---|---|
| `oep.bg` | `StudioColors.background = 0xFF0D1117` | `#0B0F14` | Close but not identical — needs reconciliation, not a redesign |
| `oep.surface.1` | `StudioColors.surface = 0xFF11161D` | `#111720` | Close but not identical |
| `oep.surface.2` | `StudioColors.surfaceRaised = 0xFF161C25` | `#151D27` | Close but not identical |
| `oep.border` | `StudioColors.border = 0xFF232B36` | `#2A3542` | Close but not identical |
| `oep.text.primary` | `StudioColors.textPrimary = 0xFFE6E9EE` | `#E7EDF4` | Close but not identical |
| `oep.text.secondary` | `StudioColors.textSecondary = 0xFF9AA5B1` | `#9AA8B7` | Close but not identical |
| `oep.accent` | `StudioColors.selection = 0xFF3B82F6` | `#2F81F7` | Close but not identical |
| `oep.success/warning/error` | `StudioColors.success/warning/error` (`0xFF22C55E`/`0xFFEAB308`/`0xFFEF4444`) | `#39B56B`/`#D9A441`/`#D95C5C` | Close but not identical |
| Geometry tokens (header/studiobar/workspacebar/toolbar/statusbar heights) | **Missing entirely** — `StudioColors` has no geometry constants at all | 58/56/42/60/36px | Must be added as new constants; nothing to migrate from |
| Typography tokens | `StudioTheme.dark`'s `textTheme` exists (Segoe UI family) but no named 18–20/14–16/12–13/10–11px scale matching `OEP-DESIGN-TOKENS.md` §4 | As specified | Partial — font family already correct, explicit scale not yet named |
| Per-Studio identity colors (`oep.studio.*`) | **Do not exist anywhere in code** | 7 hex values, closed set (AP-UX-002 §2A) | Must be added; zero collision risk since nothing currently uses per-Studio color |
| Global accent hardcoding | `OepStudioHeader` hardcodes `0xFF4C8DFF`/`0xFF22D3C7` (diagram/simulation view accents) directly, bypassing `StudioColors` | Should route through `oep.accent`/a Diagram-Studio-scoped token, not a literal | Reconcile at Section 02/07 |
| Other hardcoded colors found | `digital_multimeter_instrument_panel.dart` (60+ literals — deliberate "physical device skin," largely out of shell-migration scope), `analysis_results_panel.dart` (3 literals not routed through `StudioColors.warning/success`), `dashboard_page.dart` (1 literal, `0xFFB794F6`, no token equivalent exists) | N/A | These are Diagram-Studio/Dashboard content, not shell chrome — out of scope for this shell migration except where a Toolbar/Inspector-adjacent widget is directly reparented in Sections 06/07 |

**Recommendation: `StudioColors` should be BRIDGED, not replaced outright.** Add new `oep.*`-named static constants (matching `OEP-DESIGN-TOKENS.md` exactly, including the new geometry and per-Studio identity values) alongside the existing `StudioColors` members, then migrate call sites Studio-Bar/Workspace-Bar-first (where the color values genuinely differ and per-Studio identity is new), leaving already-close values (background/surface/border/accent) as a slower, lower-priority follow-up rename rather than a blocking rewrite. This avoids a flag-day rename across every file that already references `StudioColors.xxx correctly for its existing purpose.

**Global accent vs. Studio identity — enforced going forward:** every new region built in Sections 02–09 must use `oep.accent` for all generic interaction (Toolbar, Inspector, Status Bar, Context Nav active/focus states) and reserve the new `oep.studio.*` set exclusively for Global Studio Bar and Workspace Bar tabs — exactly the rule `global-studio-bar.svg`/`workspace-bar.svg`/`toolbar.svg` already demonstrate visually. No implementation section may expand Studio-identity color usage beyond those two regions without a further explicit design-owner decision (the open note already carried from AP-UX-002 §2A / AP-UX-005 §19 item 2).

---

## 15. Responsive Behavior

The 1920×1080 baseline is unblocked and should proceed first. Per AP-UX-005 §14/§19, Context Navigation/Inspector collapse-or-fixed-width behavior below 1920px, and Toolbar/Status Bar overflow behavior, are unresolved design-owner questions — evidenced concretely by `renders/responsive/1600x900-layout-pressure.svg` and `1280x800-layout-pressure.svg`.

**Can proceed without resolving responsive behavior:** all of Sections 01–10 (Design Tokens through Full Shell Integration) at the 1920×1080 reference size. Every region's target width (Context Nav 240–360px, Inspector 360–640px) has an unambiguous reference value at baseline size.

**Blocked until a design-owner decision is made:** Section 11 (Responsive Refinement) only. No drawers, overlays, collapsible rails, hamburger menus, automatic docking, or alternate navigation modes may be invented to fill this gap — none is authorized by any current document.

---

## 16. Ownership Matrix

| Responsibility | Studio Host | Diagram Studio | Engine | Foundation |
|---|---:|---:|---:|---:|
| Application shell (Header/Studio Bar/Status Bar frame) | ✓ | | | |
| Studio navigation | ✓ | | | |
| Workspace navigation (tabs within a Studio) | | ✓ (via shared `WorkspaceTabsController`) | | |
| Context navigation | | ✓ | | |
| Toolbar presentation | | ✓ | | |
| Diagram model (`EngineeringGraph`) | | | ✓ | |
| Diagram scene / rendering (`GraphViewPanel` et al., or the V2 webview surface) | | | ✓ | |
| Selection state (`GraphSelection`) | | | ✓ | |
| Editing operations (`EditingCommand`/`CommandHistory`) | | | ✓ | |
| Undo/redo | | | ✓ | |
| Validation | | | ✓ | |
| Rendering (pixels on screen for the diagram itself) | | | ✓ | |
| Inspector presentation (chrome/layout) | | ✓ | | |
| Inspector content (what fields exist for a selected entity) | | ✓ (reads Engine selection) | ✓ (defines the entity's real properties) | |
| Persistence — engineering data (documents, autosave) | | | ✓ (`DiagramDocument`) | |
| Persistence — UI/workspace state (tabs, panel layout) | ✓/Diagram Studio (split, see `DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` §1.2) | ✓ | | |
| Foundation Repository access | | | | ✓ (`FoundationBridge`, FFI) |

---

## 17. Implementation Dependency Graph

The proposed default order from `.claude/skills/oep-ui/SKILL.md`/`OEP-UI-SECTIONAL-IMPLEMENTATION.md` is used with one adjustment, explained below:

```text
Design Tokens / Theme Foundation
      ↓
Application Header           (Studio host — needs tokens only)
      ↓
Global Studio Bar             (Studio host — needs tokens + a pruned Studio list, §11)
      ↓
Workspace Bar re-scoping       (needs Global Studio Bar to exist, so "+" launch entries have somewhere to move to)
      ↓
Diagram Surface layout adaptation   (moved earlier than the skill's default — see reasoning below)
      ↓
Context Navigation
      ↓
Toolbar                        (needs the Surface's new bounds finalized, since Toolbar sits directly below it)
      ↓
Inspector
      ↓
Status Bar
      ↓
Full Shell Integration
      ↓
Responsive Refinement          (blocked, §15)
```

**Deviation from the skill's literal default order, and why:** the skill's generic sequence places "Primary Work Surface" at position 05, after Context Navigation. For Diagram Studio specifically, the Main Engineering Surface is the one region with a real, working, Engine-bridged implementation already in production (`LegacyV2WebViewPage`) — its layout-container change (fitting it into a bounded center column instead of the full tab body) is a **prerequisite** for both Context Navigation's right edge and Toolbar's full-width row below it to have a stable frame to measure against. Implementing Context Navigation or Toolbar geometry before the center column is finalized risks measuring against a moving target. This is a sequencing correction based on this Studio's actual dependency graph, not a deviation for its own sake.

---

## 18. Sectional Implementation Plan

### SECTION 01 — Design Tokens / Theme Foundation
- **Purpose:** Add the missing `oep.*` tokens (geometry + per-Studio identity + reconciled color values) alongside `StudioColors` without breaking existing call sites.
- **Files to create:** none required (extend `studio_colors.dart`), or a new sibling file (e.g. `oep_tokens.dart`) if the team prefers additive-not-mutating — either is compatible with this plan.
- **Files to modify:** `lib/core/theme/studio_colors.dart` (add geometry + Studio-identity constants); optionally `lib/core/theme/studio_theme.dart` if geometry constants should also surface through `ThemeData` extensions.
- **Files to retire:** none.
- **Classes/widgets affected:** `StudioColors` (additive only).
- **Dependencies:** none — first section.
- **Expected visual result:** none yet (tokens only).
- **Functional invariants:** no existing widget's rendered output changes.
- **Engine invariants:** none touched.
- **QA method:** code review + a compile check; no visual QA needed yet.
- **Freeze criteria:** every token in `OEP-DESIGN-TOKENS.md` §2/§2A/§3 has a corresponding named Dart constant.

### SECTION 02 — Application Header
- **Purpose:** Build the new app-global 58px header, hosted by `StudioShell`, matching `App Header with OEP Logo.png`.
- **Files to create:** a new widget, e.g. `lib/app/widgets/oep_application_header.dart`.
- **Files to modify:** `lib/app/studio_shell.dart` (host the new header above the existing `Scaffold` body); `lib/diagram_studio/header/oep_studio_header.dart` (strip Diagram/Simulation-swap-specific content out — see Section 07).
- **Files to retire:** none yet (old header's swap control is relocated in Section 07, not deleted in this section).
- **Classes/widgets affected:** `StudioShell`, `OepStudioHeader`, `EngineeringWorkspacePage` (stop conditionally rendering `OepStudioHeader` as "the" header).
- **Dependencies:** Section 01.
- **Expected visual result:** a fixed 58px header present in every Studio, not just Diagram.
- **Functional invariants:** existing Diagram/Simulation swap control still exists and still works (temporarily still rendered from its old location until Section 07 relocates it).
- **Engine invariants:** none.
- **QA method:** run the app, capture 1920×1080, compare header region only against `App Header with OEP Logo.png` and the composite `oep-diagram-studio-shell.svg`'s header slice.
- **Freeze criteria:** header geometry/content match; visible in Diagram Studio, EAM, Home, and Settings alike.

### SECTION 03 — Global Studio Bar
- **Purpose:** Build the new 56px Studio Bar with the 7-entry ratified inventory.
- **Files to create:** e.g. `lib/app/widgets/oep_global_studio_bar.dart`.
- **Files to modify:** `lib/app/studio_shell.dart` (host it below the header); a new, small Studio-list source derived from (not replacing) `StudioDestination` — see §11's note that only 7 of the 19 current destinations become Studio Bar entries.
- **Files to retire:** none (§11's reconciliation of the other 12 destinations is out of scope here).
- **Classes/widgets affected:** `StudioShell`.
- **Dependencies:** Section 01, Section 02 (visually stacks below it).
- **Expected visual result:** matches `global-studio-bar.svg` — Diagram Studio active in its identity blue, other 6 Studios present.
- **Functional invariants:** navigating via the new bar must resolve to the same routes `StudioDestination`/`GoRouter` already handle.
- **Engine invariants:** none.
- **QA method:** capture and compare against `global-studio-bar.svg`; verify each of the 7 tabs actually navigates.
- **Freeze criteria:** all 7 Studios reachable; Engineering Intelligence absent; active-state color correct per Studio.

### SECTION 04 — Workspace Bar
- **Purpose:** Re-scope `_WorkspaceTabStrip`'s "+" menu now that Global Studio Bar exists; correct height 36→42px.
- **Files to modify:** `lib/workspace/engineering_workspace_page.dart` (`_WorkspaceTabStrip` height constant and "+" `PopupMenuButton` contents).
- **Files to retire:** none — `openDiagramTab`/`SurfaceRegistry`-backed entries are removed from this specific menu, not deleted from the codebase (Studio Bar now owns launching Studios).
- **Classes/widgets affected:** `_WorkspaceTabStrip`, `EngineeringWorkspacePage`.
- **Dependencies:** Section 03 (Studio Bar must exist as the new home for Studio-launch entries).
- **Expected visual result:** matches `workspace-bar.svg` — Diagram Studio identity color, open-document tabs only.
- **Functional invariants:** `WorkspaceTabsController`/`WorkspaceTabsStorage` persistence format unchanged; existing open tabs restore correctly.
- **Engine invariants:** none.
- **QA method:** capture and compare against `workspace-bar.svg`; open/close/reopen multiple Diagram documents, confirm tab persistence still works.
- **Freeze criteria:** 42px height; only in-Studio work items appear in the tab strip and its "+" menu.

### SECTION 05 — Diagram Surface Integration (moved ahead per §17)
- **Purpose:** Constrain `LegacyV2WebViewPage`'s bounds to the future center column, without touching its internals.
- **Files to modify:** `lib/diagram_studio/compare/diagram_with_compare_pane.dart` (layout container only), `lib/workspace/engineering_workspace_page.dart` (`_DiagramInstanceTab`, `_WorkspaceContent` layout).
- **Files to retire:** none.
- **Classes/widgets affected:** `DiagramWithComparePane`, `_DiagramInstanceTab`.
- **Dependencies:** Sections 01–04 (needs the header/Studio Bar/Workspace Bar heights finalized to compute remaining vertical space correctly).
- **Expected visual result:** same diagram content, now bounded to a known center-column rectangle (full width temporarily, until Sections 06/08 add side columns).
- **Functional invariants:** every existing bridge/adapter call, gesture, and Engine command continues to work unchanged.
- **Engine invariants:** zero — this section touches layout containers only, never `LegacyV2BridgeTransport`/`LegacyV2StateAdapter`/`DiagramStudioController`/Engine code.
- **QA method:** run the app, verify the diagram renders identically to before this section, confirm no interaction regression (drag, select, undo/redo, Compare/Analysis/DMM/Trace toggles).
- **Freeze criteria:** diagram surface occupies exactly the bounds it will keep once Context Nav/Inspector are added; zero functional regression.

### SECTION 06 — Context Navigation
- **Purpose:** Build the new left-column widget, workspace-scoped, per `context-navigation.svg`.
- **Files to create:** e.g. `lib/diagram_studio/shell/diagram_context_navigation.dart`.
- **Files to modify:** the layout container from Section 05 (add the left column).
- **Classes/widgets affected:** none pre-existing reused directly; reads document structure via `DiagramStudioController`'s existing accessors.
- **Dependencies:** Section 05 (needs the surface's left edge fixed).
- **Expected visual result:** matches `context-navigation.svg` structurally (exact tree content will differ per real document, that's expected).
- **Functional invariants:** selecting a tree node updates the (not-yet-built, Section 07's sibling Section 08) Inspector once it exists; does not alter Engine selection semantics — it may set selection through the same channel any other selection UI would use.
- **Engine invariants:** read-only projection of `EngineeringGraph`; no new mutation path introduced.
- **QA method:** capture and compare against `context-navigation.svg`; verify tree reflects the real open document.
- **Freeze criteria:** 240–360px column present, workspace-scoped (changes when the active workspace changes, not when the active Studio changes).

### SECTION 07 — Toolbar
- **Purpose:** Extract `DiagramWithComparePane`'s 28px toggle row into a full 60px, full-width toolbar per `toolbar.svg`; relocate `OepStudioHeader`'s Diagram/Simulation swap control here (or to Context Nav — open question, §23).
- **Files to create:** e.g. `lib/diagram_studio/shell/diagram_toolbar.dart`.
- **Files to modify:** `lib/diagram_studio/compare/diagram_with_compare_pane.dart` (remove the inline toggle row), `lib/diagram_studio/header/oep_studio_header.dart` (remove `_ViewSwapControl` once relocated).
- **Classes/widgets affected:** `DiagramWithComparePane`, `OepStudioHeader`.
- **Dependencies:** Section 05 (sits directly below the finalized center column, per the "full-width row below the 3-column split" rule).
- **Expected visual result:** matches `toolbar.svg`'s grouped, monochrome structure — using this Studio's real actions (Analysis/Compare/DMM/Trace, undo/redo, etc.) instead of the generic File/Edit/View placeholder groups shown in the render.
- **Functional invariants:** every action fires the exact same handler it fired before relocation.
- **Engine invariants:** none — presentation relocation only.
- **QA method:** capture and compare against `toolbar.svg`'s geometry/grouping pattern (not its exact labels, which were generic placeholders); functionally exercise every relocated action.
- **Freeze criteria:** 60px full-width row; `oep.accent`-only coloring; zero functional regression versus the pre-relocation toggle row.

### SECTION 08 — Inspector
- **Purpose:** Build the new right-column shell region per `inspector.svg`, reparenting existing property-panel logic into it.
- **Files to create:** e.g. `lib/diagram_studio/shell/diagram_inspector.dart`.
- **Files to modify:** the layout container (add the right column); `lib/diagram_studio/trace/trace_inspector_panel.dart` and `lib/diagram_studio/inspector/engineering_relationship_properties.dart` (reparent into the new region rather than their current ad hoc placement).
- **Classes/widgets affected:** `TraceInspectorPanel`, the relationship-properties inspector, `DiagramWithComparePane` (loses its old side-pane slot for these, since they now live in the shell-level Inspector).
- **Dependencies:** Section 05 (needs the right edge fixed), Section 06 (selection-to-inspector wiring pattern should be consistent with Context Nav's read model).
- **Expected visual result:** matches `inspector.svg` structurally; real selected-object data populates it.
- **Functional invariants:** every existing inspector capability (trace diagnostics, relationship properties) remains reachable and functionally identical.
- **Engine invariants:** reads `GraphSelection` read-only; no new mutation path.
- **QA method:** capture and compare against `inspector.svg`; select various entity kinds, confirm the correct existing panel content appears.
- **Freeze criteria:** 360–640px column present; existing inspector panels fully reparented with no functionality lost.

### SECTION 09 — Status Bar
- **Purpose:** Build the new 36px status bar, frame owned by `StudioShell`, content supplied by the active Studio, per `status-bar.svg`.
- **Files to create:** e.g. `lib/app/widgets/oep_status_bar.dart` (frame) + a Diagram-Studio content provider.
- **Files to modify:** `lib/app/studio_shell.dart` (host the bar).
- **Dependencies:** Sections 01–08 (last chrome region; benefits from every other region's real state — active Studio/workspace, selection, grid/snap — already being wired).
- **Expected visual result:** matches `status-bar.svg`; Ready/Studio/Workspace/Grid/Snap/Zoom/Repo fields reflect real state, not the render's placeholder values.
- **Functional invariants:** none pre-existing to preserve (this region did not exist).
- **Engine invariants:** read-only status display.
- **QA method:** capture and compare against `status-bar.svg`; verify each field updates live (e.g. zoom level changes when the diagram is zoomed).
- **Freeze criteria:** 36px bar present in every Studio; Diagram-Studio-specific fields correct when Diagram Studio is active.

### SECTION 10 — Full Shell Integration
- **Purpose:** Run the complete assembled shell at 1920×1080 and validate all 8 regions together.
- **Files:** none new — integration/verification only.
- **QA method:** full `OEP-VISUAL-QA-PROTOCOL.md` pass against `oep-diagram-studio-shell.svg` (the composite), P0/P1/P2 classification, fix P0/P1, document remaining P2.
- **Freeze criteria:** matches the completion criteria in `WP-UI-DS-001-PROMPT.md` Step 4/5 exactly.

### SECTION 11 — Responsive Refinement
- **Status:** BLOCKED (§15/§23). No files, no implementation, until a design-owner decision resolves Context Nav/Inspector collapse behavior and Toolbar/Status Bar overflow behavior.

---

## 19. Visual QA Strategy

Each section above states its own checkpoint; the shared method (per `OEP-UI-SECTIONAL-IMPLEMENTATION.md` §3–§6 and `OEP-VISUAL-QA-PROTOCOL.md`) is:

```text
Implement one section
      ↓
Hot-reload the live Windows app (already running per .claude/skills/oep-ui/SKILL.md)
      ↓
Capture full 1920×1080 application window
      ↓
Compare against: (a) that section's specific reference render, (b) the full oep-diagram-studio-shell.svg composite for placement
      ↓
Inspect geometry (height/width against §6's pixel values), typography, spacing, active/inactive states, ownership (did this section touch Engine code? — it must not)
      ↓
Classify differences P0/P1/P2 per OEP-VISUAL-QA-PROTOCOL.md
      ↓
Fix P0/P1, recapture; document remaining P2
      ↓
FREEZE the section (do not casually modify it in a later section)
      ↓
Proceed to next section; re-verify all previously frozen sections still render correctly
```

---

## 20. Do Not Rebuild What Already Works

Explicitly RETAIN: Engine integration (`platform/oep_engine`, all of it), diagram scene generation and rendering (`GraphViewPanel`/`WirePainter`/etc., Engine-owned), the Legacy V2 webview bridge chain (`LegacyV2WebViewPage`→`LegacyV2BridgeTransport`→`LegacyV2StateAdapter`→`DiagramStudioController`), all existing diagram editing commands (`EditingCommand`/`CommandHistory`), `WorkspaceTabsController`/`WorkspaceTabsStorage` (workspace state persistence — reused, only its "+" menu contents change), `DiagramDocument`/autosave/recovery persistence, `SurfaceRegistry`'s existing per-surface page mapping (Home routing via `HomeDashboardPage` stays exactly as-is — this plan does not touch Home). This is a controlled UI architecture migration: eight sections of chrome added around a working application, not a rewrite of OEP Studio.

---

## 21. Legacy Identification

| Item | Classification | Basis |
|---|---|---|
| `LegacyV2WebViewPage` + bridge chain | **ACTIVE** — retain, this is the current production diagram surface | Direct code inspection, live call chain from `EngineeringWorkspacePage` |
| `DiagramStudioController`, OEP Engine (`platform/oep_engine`) | **ACTIVE** — retain | Constitution + composition-boundary docs, direct inspection |
| `_WorkspaceTabStrip` / `WorkspaceTabsController` / `WorkspaceTabsStorage` | **ACTIVE BUT MIGRATE** — retain behavior, change which menu entries it exposes (§10) | Direct inspection |
| `OepStudioHeader` | **ACTIVE BUT MIGRATE** — retain visual language, narrow its scope, relocate its swap control (§13) | Direct inspection |
| `StudioShell` | **ACTIVE BUT MIGRATE** — retain as host, add chrome it currently lacks (§9) | Direct inspection, own doc comments |
| `EngineeringWorkbenchPage` / `PerspectiveManager` / `WorkbenchLayoutManager` / `WorkbenchCommandManager` / `WorkbenchThemeManager` / `WorkbenchStatusBar` / `WorkbenchSidebar`'s WORKBENCH section / `workbench_perspectives.dart` / retired Perspective objects / `StudioNavRail` / `/diagram-classic` | **HISTORICAL** — no runtime use, already removed per `AP-OEP-WORKBENCH-RETIREMENT-001` | `ENGINEERING_WORKBENCH.md`'s own "RETIRED" banner |
| Legacy `DiagramStudioPage` (`lib/diagram_studio/workspaces/diagram_studio_page.dart`, 3590 lines) and its own in-progress Wave 2 refactor (`DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md`) | **UNKNOWN — requires verification** | The composition-boundary document (dated before this plan) describes it as still addressed by name from `studio_shell.dart` and `workbench/perspectives/diagram_perspective.dart`; but `ENGINEERING_WORKBENCH.md`'s retirement note says the Workbench's own "Diagram Perspective" was already removed even earlier, replaced by the Legacy V2 bridge. Whether `DiagramStudioPage` itself is still reachable by any current route, or is now fully superseded by `LegacyV2WebViewPage`'s direct integration into `EngineeringWorkspacePage`, was not resolved by this pass's evidence and should be verified by a direct route-reachability check (e.g. grep every `GoRoute`/`StudioDestination.diagram` builder) before any file in this area is touched |
| Native V2 canvas renderer (`lib/diagram_studio/renderer/`, `V2CanvasHost` et al.) | **ACTIVE BUT EXPERIMENTAL** — real code, gated behind a default-`false` debug toggle, not on the production path this plan targets | `DIAGRAM_STUDIO_V2_RENDERER_IMPLEMENTATION_PLAN.md` |
| `digital_multimeter_instrument_panel.dart`'s hardcoded hex palette | **ACTIVE** — retain as-is; it is deliberate "physical device" skin, not shell chrome, out of this migration's scope | Direct inspection |

No code was deleted or modified to produce this classification.

---

## 22. Risk Register

| ID | Risk | Evidence | Impact | Mitigation | Blocks Implementation? |
|---|---|---|---|---|---|
| R-001 | `DiagramStudioPage`/legacy Workbench reachability is genuinely unclear (see §21 UNKNOWN item) | Conflicting dates/claims between `DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` and `ENGINEERING_WORKBENCH.md` | Could cause an implementation agent to edit dead code, or miss a still-live route | Verify route reachability directly (grep `GoRoute`s, run the app and try `/diagram` and `/diagram-classic`) as the first step of Section 02, before any header work touches shared files | NO — verification is cheap and can happen inside Section 01/02's own inspection step |
| R-002 | Workspace/Studio navigation conflation (§10) could regress workspace-tab persistence if the "+" menu split is done carelessly | Direct inspection of `_WorkspaceTabStrip` | Users could lose the ability to reopen a Studio, or duplicate Studio launch paths could appear | Section 04 explicitly scopes to menu-contents only; `WorkspaceTabsController`/Storage untouched | NO |
| R-003 | Engine/UI boundary erosion — a future implementer adds a "convenience" direct `engine.*` call from new shell code | `DIAGRAM_STUDIO_CONSTITUTION.md` §3 rule 1, actively enforced today | Would create a second execution pathway, breaking undo/redo/dirty-tracking guarantees | Every new widget in Sections 02–09 must route through `DiagramStudioController` or read-only Engine accessors, never `engine.editing.execute` directly; call out in code review | NO (process risk, not a blocker) |
| R-004 | Renderer coupling — `LegacyV2WebViewPage` is a WebView, and WebView widgets can behave unpredictably inside complex Flutter layout (e.g. `Expanded`/`Row` resizing, clipping) | `DIAGRAM_STUDIO_V2_WEBVIEW_POC.md`/architecture docs describe known WebView-hosting constraints | Section 05's layout change (bounding the WebView to a center column instead of full tab body) could expose a resize/repaint bug not present today | Test Section 05 in isolation before adding Context Nav/Inspector columns; capture-and-compare after every resize-affecting change | NO, but flagged as the highest-risk single section |
| R-005 | Theme migration (§14) touching `StudioColors` call sites broadly could regress the multimeter instrument panel's deliberate device-skin literals if a blanket find-replace is attempted | Direct inspection — 60+ literals in one file | Visual regression in an unrelated, working, intentionally-skinned panel | Section 01 is additive only; no existing `StudioColors` values are renamed/removed in this plan | NO |
| R-006 | Responsive behavior — an implementer under schedule pressure invents a collapse rule to "just ship something" | AP-UX-005 §14/§19, explicit prohibition | Would violate the explicit design-owner-decision-required boundary and create rework | Section 11 is explicitly BLOCKED in this plan; do not authorize it without a design-owner decision | YES — for Section 11 only, not for Sections 01–10 |
| R-007 | Legacy Workbench artifacts (§21 HISTORICAL list) are mistaken for reusable shell infrastructure by a future implementer skimming old docs | `ENGINEERING_WORKBENCH.md` reads, at a glance, like a live architecture document until its "RETIRED" banner is noticed | Wasted effort attempting to resurrect retired code as the new shell host | This plan explicitly designates `StudioShell` (not `EngineeringWorkbenchPage`) as the shell host in §9; call this out prominently for the next implementation agent | NO |

---

## 23. Open Decisions

**OD-001**
- **Question:** Where does the Diagram/Simulation view-swap control (currently `OepStudioHeader`'s `_ViewSwapControl`) relocate — into the new Toolbar (Section 07) or into Context Navigation (Section 06)?
- **Why unresolved:** neither `toolbar.svg` nor `context-navigation.svg` depicts a mode-switch control; both renders used a single-mode (Diagram, not Simulation) scenario, since the shared design corpus never needed to show this Diagram-Studio-specific state.
- **Current evidence:** `OepStudioHeader`'s existing placement (top-right, header-level) is itself already wrong per the target (headers carry no Studio-specific controls, `OEP-SHELL-COMPONENTS.md` §2) — so "leave it where it is" is not an available option, only "which of the two new regions."
- **Options:** (a) Toolbar, grouped as its own section alongside Analysis/Compare/DMM/Trace; (b) Context Navigation, as a top-of-panel mode switch since it changes what the whole workspace shows.
- **Blocks:** the exact final layout of Section 07 (and, if (b), Section 06) — does not block starting either section, since both can be built with a placeholder slot and the control dropped in once decided.
- **Recommended decision owner:** design owner (visual/interaction judgment call, not an architecture question).

**OD-002**
- **Question:** Context Navigation / Inspector collapse, overlay, dock, or minimum-width behavior below 1920×1080.
- **Why unresolved:** carried unresolved from AP-UX-004 §20 and AP-UX-005 §19/§24; no document has ever specified it.
- **Current evidence:** `renders/responsive/1600x900-layout-pressure.svg` and `1280x800-layout-pressure.svg` show the Engineering Surface compressing to 680px and an unworkable 360px respectively if nothing collapses.
- **Options:** fixed minimum width with horizontal scroll, collapsible rail, overlay/flyout, docked-to-icon-only mode, or a decision that sub-1920 widths are simply out of scope for Diagram Studio.
- **Blocks:** Section 11 only.
- **Recommended decision owner:** design owner.

**OD-003**
- **Question:** Toolbar/Status Bar overflow behavior at reduced width (which groups/items get priority, which get an overflow menu).
- **Why unresolved:** newly surfaced by AP-UX-005's responsive schematics; no prior document addressed toolbar/status-bar behavior at any width other than 1920px.
- **Current evidence:** none beyond the two schematic renders' own annotations.
- **Options:** priority-ordered overflow menu (common desktop-app pattern), fixed truncation, or horizontal scroll within the bar.
- **Blocks:** Section 11 only.
- **Recommended decision owner:** design owner.

**OD-004**
- **Question:** Is the legacy `DiagramStudioPage` (`lib/diagram_studio/workspaces/diagram_studio_page.dart`) still reachable by any current route, or fully superseded?
- **Why unresolved:** this pass's evidence conflicts (see §21 UNKNOWN item / R-001); resolving it requires a direct route-reachability check, not further document reading.
- **Current evidence:** `DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` (says it's still addressed by name from `studio_shell.dart`) vs. `ENGINEERING_WORKBENCH.md` (says its Diagram Perspective wrapper was already removed, replaced by the Legacy V2 bridge, before the Workbench itself was also retired).
- **Options:** verify by grep/run; either confirm it dead (safe to ignore for this plan, already implied by the plan's own reliance on `EngineeringWorkspacePage`/`LegacyV2WebViewPage` as the real path) or confirm it live (would require re-scoping §21/§12 to account for a second, parallel Diagram Studio entry point).
- **Blocks:** nothing in Sections 01–10 as written (they target the confirmed-live `EngineeringWorkspacePage` path regardless of this answer) — but should be resolved before or during Section 02's own inspection step, out of engineering hygiene, not because it changes this plan's scope.
- **Recommended decision owner:** the implementing engineer, as a quick verification step (not a design-owner question).

No other genuinely open decisions were found. Every other question this document could have flagged was resolvable from existing repository evidence and was resolved above rather than left open.

---

## 24. Final Readiness Assessment

```text
Shell (StudioShell as host)         READY WITH CONSTRAINT — host confirmed, chrome must be added (Sections 02/03/09)
Header                              READY WITH CONSTRAINT — OD-001 affects final content, not start
Studio Bar                          READY — no blockers; §11's 12-destination reconciliation is future work, not a blocker for the 7-entry bar itself
Workspace Bar                       READY — re-scoping is mechanical or well-understood
Context Navigation                  READY WITH CONSTRAINT — OD-001 may add a slot
Toolbar                             READY WITH CONSTRAINT — OD-001 may add a slot
Diagram Surface                     READY — retained as-is, only container bounds change
Inspector                           READY — existing panels are known and reparenting is mechanical
Status Bar                         READY — no existing implementation to conflict with
Theme/Tokens                        READY — additive migration strategy defined (§14)
Engine Integration                  READY (RETAIN) — boundary confirmed sound, no changes needed or authorized
Responsive Behavior                 BLOCKED — OD-002/OD-003, Section 11 only
Visual QA                           READY — full protocol and per-section checkpoints defined (§18/§19)
Implementation Sequence             READY — §17/§18 fully sequenced
```

## IMPLEMENTATION START CONDITION

Before `WP-UI-DS-001` (revised to reflect this plan) begins:

1. This document (`AP-UX-006`) must be the implementing agent's required reading, replacing the original `WP-UI-DS-001-PROMPT.md`'s now-outdated "Read first" list and Step-1 inspection instructions (which predate this plan's evidence).
2. OD-004 (legacy `DiagramStudioPage` reachability) should be verified as a first quick step — it does not block starting, but should not be left open once implementation begins touching `studio_shell.dart`.
3. OD-001 (view-swap control placement) should be decided by the design owner before Section 06/07 reaches implementation, though Sections 01–05 can proceed without it.
4. Sections 01–10 may begin immediately in the order given in §17/§18. Section 11 must not begin until OD-002 and OD-003 are resolved by the design owner.
5. The live-application hot-reload workflow (`.claude/skills/oep-ui/SKILL.md`) must be used throughout — no section is complete on source-code inspection alone; each requires a real 1920×1080 capture compared against its named reference render.

---

## 25. Completion Criteria Check

- Entire target shell mapped to actual code: ✓ (§7)
- Every region has current implementation status: ✓ (§7/§8)
- Every region has explicit migration action: ✓ (§7)
- Ownership established: ✓ (§16)
- Engine/rendering boundaries documented: ✓ (§3/§12)
- Design-token migration mapped: ✓ (§14)
- Workspace/Studio navigation separation mapped: ✓ (§10)
- Legacy implementation classified: ✓ (§21)
- Implementation dependencies established: ✓ (§17)
- Sectional implementation order established: ✓ (§18)
- Visual QA checkpoints established: ✓ (§18/§19)
- Responsive blockers isolated: ✓ (§15/§23 OD-002/OD-003)
- Remaining design-owner decisions listed: ✓ (§23)
- `WP-UI-DS-001` revisable without repeating the architecture audit: ✓ — §7/§18 alone give an implementing agent file-level targets and section-by-section acceptance criteria

One item is marked UNKNOWN rather than resolved: OD-004 (legacy `DiagramStudioPage` reachability) — the missing evidence is a direct route-reachability check that requires running the application or exhaustively grepping every `GoRoute` registration, which this read-only documentation pass did not perform as a blocking step since it does not affect Sections 01–10's scope.

---

## 26. AAR

**What this document establishes that AP-UX-001 through AP-UX-005 did not:** exact file/class-level mapping between every target shell region and current Flutter code; a corrected, evidence-based understanding that the production Diagram surface is a Legacy V2 WebView bridge (not a native renderer, and not the separate, larger `DiagramStudioPage`/retired Workbench architecture); a concrete 11-section implementation sequence with per-section files/QA checkpoints; and a narrowed, four-item Open Decisions list (down from the broader unresolved-questions lists of prior APs, because most of what remained open at the architecture level was resolvable once real code was inspected).

**Ready for implementation:** Sections 01–10, in the order given, subject to OD-001/OD-004 being resolved opportunistically as implementation reaches the sections they touch.

**Not ready:** Section 11 (responsive refinement) — blocked on OD-002/OD-003, both genuine design-owner decisions this document does not manufacture.

**Explicitly not touched by this document:** any Flutter, Engine, rendering, Foundation, or database file. No code was modified. No implementation began.
