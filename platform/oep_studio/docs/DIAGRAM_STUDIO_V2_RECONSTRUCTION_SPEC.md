# Wiring Simulator V2 Reconstruction Specification

**Document ID:** AP-DIAGRAM-000
**Status:** Wave 0 — Preconditions. Specification only. No implementation authorised by this document.
**Companion document:** `docs/DIAGRAM_STUDIO_RECONSTRUCTION_AUDIT.md` (AP-DIAGRAM-001)
**Reference implementation:** `reference/legacy_wiring_sim_v2/eke-wiring-sim/`

---

## 1. Purpose and Authority

### 1.1 Purpose

This document is the implementation contract for reconstructing OEP Diagram Studio so that its UI and observable interaction behaviour match the existing Wiring Simulator V2 (EKE) reference implementation.

It exists to remove ambiguity. Every value in it is either extracted from V2 source, extracted from OEP source, or explicitly marked `UNSPECIFIED BY V2`. Nothing here is designed, improved, or inferred.

### 1.2 Authority model

| Domain | Authority |
|---|---|
| Visual appearance, layout, interaction behaviour, keyboard model | **Wiring Simulator V2 source** |
| Engineering graph, layout truth, selection truth, viewport truth, routing, validation, simulation, measurement, commands, persistence operations | **OEP Engineering Engine** |
| Repository, audit, object identity | **OEP Foundation** |
| Translation between the two | **Future Studio Controller** (does not yet exist) |

### 1.3 Scope

**In scope:** documenting what V2 does; documenting what OEP already considers authoritative; stating what the future OEP Diagram Studio must present or do at the boundary between them.

**Out of scope:** implementation; controller design beyond stated responsibilities; any change to Engine or Foundation; resolving the conflicts catalogued in §29.

### 1.4 What this document does not specify

- It does not design a new UI. Where V2 has no answer, the answer is `UNSPECIFIED BY V2`.
- It does not improve V2. Known V2 limitations (no undo, single selection, no layers, no multi-document) are recorded as-is.
- It does not resolve V2/OEP conflicts. §29 documents them and assigns escalation.
- It does not specify the Controller's internal design — only the behaviour required at its boundary.

### 1.5 The three-category rule

Every substantive subsection separates:

- **A. V2 BEHAVIOR** — what the reference implementation actually does, with file and value citations.
- **B. OEP ENGINE BEHAVIOR** — what OEP already treats as authoritative.
- **C. RECONSTRUCTION REQUIREMENT** — what the future Studio must do.

These are never merged. Where A and B are irreconcilable, C states the conflict and defers to §29.

---

## 2. Canonical V2 Reference

### 2.1 Location

```
reference/legacy_wiring_sim_v2/eke-wiring-sim/
```

### 2.2 Files inspected for this specification

| File | Lines | Establishes |
|---|---|---|
| `index.html` | 838 | Layout, DOM structure, control inventory, inline SVG multimeter, modals, overlays, script load order |
| `css/main.css` | 675 | **Complete token system (both themes)**, all component styling, animations, z-order |
| `css/editor.css` | 1 | Empty (`/* editor.css — additional overrides can go here */`) |
| `css/modules.css`, `wires.css`, `inspector.css`, `meter.css` | 8–9 each | **Placeholders only.** All rules served by `main.css` |
| `js/app.js` | 302 | Global state, keyboard map, theme, panel manager, search, tracer panel, context menu dispatch |
| `js/diagram/renderer.js` | 359 | Card building, pan/zoom/touch, minimap, wire routing, wire drawing, flow animation |
| `js/diagram/viewport.js` | 32 | **Placeholder** — documents intended extraction; logic remains in `renderer.js` |
| `js/diagram/module-renderer.js`, `wire-renderer.js`, `label-renderer.js` | 18–27 | **Placeholders** — document intended extraction only |
| `js/diagram/path-highlighter.js` | 82 | Power/ground/circuit/charging path highlighting via `tracedWires` |
| `js/editor/selection-manager.js` | 30 | Wire selection semantics |
| `js/editor/module-editor.js` | 319 | Module drag, edit-mode toggle, module drawer, presets, add/delete/edit modals |
| `js/editor/wire-editor.js` | 152 | Terminal clicks, wire mode, wire creation, deletion, wire properties modal |
| `js/editor/routing-editor.js` | 46 | Route-edit mode lifecycle, route reset |
| `js/editor/clipboard.js` | 17 | **Placeholder** — not implemented |
| `js/editor/undo-redo.js` | 56 | `UndoRedoStack` class defined; **never instantiated or wired** |
| `js/ui/sidebar.js` | 362 | Sidebar tabs, inspector render, meter SVG sync, lead wires, pop-out/dock, rubber-band zoom |
| `js/ui/inspector.js` | 127 | Wire inspector panel, module info panel |
| `js/ui/meter-panel.js` | 146 | Key position, meter mode, lead modes, LCD update, bulb update |
| `js/ui/notifications.js` | 18 | Toast |
| `js/ui/graph-inspector.js` | 97 | Developer graph/validation panel |
| `js/ui/toolbar.js`, `dialogs.js` | — | Referenced in `docs/architecture.md`; **not present in the source tree and not loaded by `index.html`** |
| `js/core/bootstrap.js` | 117 | Startup sequence and subsystem init order |
| `js/core/app-context.js` | 87 | `EKE` runtime context object |
| `js/swpack.js` | 242 | Handlebar switch pack state, reading overrides, indicators, schematics |
| `js/storage/vehicle-loader.js` | 124 | Vehicle data loading (`file://` bundle vs `http://` fetch) |
| `js/storage/project-saver.js` | 34 | `saveLayout()`, `exportSVG()` |
| `js/storage/project-loader.js` | 30 | `loadLayoutFile()`, `onLayoutFile()` |
| `js/storage/autosave.js`, `import-export.js` | — | Listed in `architecture.md`; **not present / not loaded** |
| `js/diagnostics/circuit-tracer.js` | ~80 | Connected sub-graph tracing |
| `js/utils/colors.js` | 116 | Category colours, wire colour codes, wire colour names |
| `js/utils/geometry.js` | 112 | SVG path, collinear cleanup, movable segments, exit point, label point, snap |
| `js/graph/*`, `js/knowledge/*`, `js/simulation/*`, `js/simulator/*`, `js/diagnostics/*` | — | Electrical model — **not UI**; inspected only where UI reads from them |
| `docs/architecture.md` | 195 | Intended layering and layer-access rules |
| `diagrams/trx300/*.json` | — | Data shapes (`modules.json`, `wires.json`, `layout.json`, `measurements.json`) |

### 2.3 Which files establish what

| Concern | Authoritative V2 file(s) |
|---|---|
| **Layout** | `index.html` (structure), `css/main.css` (`#topbar-wrap`, `#main-area`, `#left-sidebar`, `#viewport`) |
| **Styling** | `css/main.css` — **sole source**; the four split CSS files are empty placeholders |
| **Rendering** | `js/diagram/renderer.js` — **sole source**; the three split renderer files are placeholders |
| **Interaction** | `js/editor/*` (selection, module, wire, routing), `js/ui/sidebar.js` (rubber-band zoom), `js/app.js` (keyboard, panels) |
| **State** | `js/app.js` (globals), `js/core/app-context.js` (`EKE`), `js/swpack.js` (switch state) |
| **Persistence** | `js/storage/project-saver.js`, `project-loader.js`, `vehicle-loader.js`; `localStorage` in `js/app.js` (theme, panel geometry) |
| **Simulation** | `js/swpack.js` (reading overrides), `diagrams/trx300/measurements.json` (authored readings), `js/simulation/*` (solvers, not UI-connected in the shipped path) |
| **Instruments** | `index.html` (inline SVG meter), `js/ui/meter-panel.js`, `js/ui/sidebar.js` (`_syncMeter`, `drawLeadWires`) |

### 2.4 Source precedence

1. **Actual V2 source** — including placeholder status. A file that documents an intention but contains no code establishes *nothing* except that the intention was unrealised.
2. **Existing OEP architecture and the audit.**
3. **Explicitly documented requirements.**

Where `docs/architecture.md` describes a file that does not exist or is a placeholder (`ui/toolbar.js`, `ui/dialogs.js`, `storage/autosave.js`, `simulator/voltage-engine.js`), the architecture document is **aspirational and non-authoritative**. Only shipped code establishes behaviour.

---

## 3. OEP Architectural Constraints

### 3.1 Frozen components

**`oep_foundation` is frozen.** No schema, API, or repository-interface change.

**`oep_engine` is frozen.** This includes `oep_engine/lib/views/widgets/` — `GraphViewPanel`, `SymbolNodeWidget`, `WirePainter`, `AnnotationWidget`, `GridPainter`, `GuidesPainter`, `ConnectionPreviewPainter`, `ResizeHandles`, `WireEditHandles`, `ReconnectHandle`, `OriginIndicator`. These are presentation code living in the Engine package; the reconstruction **stops importing them** and does not edit, move, or delete them. The Engine's own Demonstration Host continues to consume them.

### 3.2 Engine authority

The Engine remains the authoritative source of: engineering graph, engineering objects, relationships, diagram layout truth, selection truth, viewport truth, routing, validation, simulation, measurement, commands, persistence operations.

### 3.3 Target stack

```
OEP Engine
    ↓  DiagramScene / immutable view data
Studio Controller / Adapter
    ↓  view models + intent callbacks
V2-compatible presentation
    ↓  gestures
V2-compatible interaction system
```

### 3.4 The boundary

**"DiagramScene in, Engine Commands out."**

| Direction | Permitted payload |
|---|---|
| Engine → Presentation | Immutable value types: `DiagramScene`, `DiagramNodeVisual`, `DiagramWireVisual`, `ViewState`, `GraphSelection`, `ValidationReport`, `SimulationStateSnapshot`, `MeasurementResult`, `SearchResult`, `DomainProfile` |
| Presentation → Controller | Intent only (`onNodeTap(id)`, `onSegmentNudge(dir, large)`, `onToolModeChanged(mode)`) |
| Controller → Engine | Engine commands and service calls only |
| Never crosses | Flutter widgets, `BuildContext`, `Offset`/`Size`/`Matrix4`, theme tokens, panel state |

### 3.5 Command execution

Within Diagram Studio's own presentation layer, the Controller is the **only** object permitted to call `engine.editing.execute` — no widget or `State` in `diagram_studio/workspaces/` may call it directly. It centralises `markDocumentDirty()` and the debounced Intelligence sync, closing the hazard recorded in audit §9.4 (dirty tracking currently lives at ~30 call sites inside `diagram_studio_page.dart`).

This is a Diagram-Studio-scoped rule, not a claim that the Controller is the sole caller of `engine.editing.execute` anywhere in OEP. The global, cross-studio Contextual Command System (`core/context/contextual_command_definitions.dart`) executes its own Engine commands independently — it predates this boundary, serves every Studio, and remains intentionally outside it (see `DiagramStudioController`'s own doc comment, AP-DIAGRAM-W1-R1).

### 3.6 Persistence separation

Four categories remain separate, per audit §12.4:

| Category | OEP owner |
|---|---|
| Engineering data (graph + layout + metadata) | `DiagramDocument` |
| UI state (panel layout, visibility, sidebar tab, theme) | `DiagramWorkspaceState` |
| Temporary workspace state (open tabs, recently closed) | `DiagramTabsStorage` |
| User preferences (new-document defaults) | `DiagramStudioSettings` |

**V2 uses two separate persistence mechanisms, not a conflated one**: the downloaded layout file (`saveLayout()`) carries only engineering/layout-shaped content (`positions` + `wireRoutes` + user-created modules/wires), while `localStorage` carries only UI/theme/panel-state-shaped content (panel geometry, theme). These map cleanly onto OEP's first two categories respectively. **OEP's four-way separation above remains the authoritative architecture and must be preserved** — the reconstruction does not need to adopt or reconcile any V2 conflation, because none exists. See §29.6.

### 3.7 Explicit non-modification statement

> This reconstruction does **not** modify `oep_engine` or `oep_foundation`. Any requirement in this specification that appears to demand an Engine or Foundation change is, by definition, an unresolved conflict and must be routed through §29 as an architecture decision — not implemented.

---

## 4. Window and Workspace Geometry

### 4.1 A. V2 BEHAVIOR — overall window

**Source:** `index.html:19`, `css/main.css:95-97, 103-109, 502-522, 675`

Root: `<div style="display:flex;flex-direction:column;height:100%">`.

| Property | Value | Source |
|---|---|---|
| `html`, `body` height | `100%` | `main.css:96` |
| `html`, `body` overflow | `hidden` | `main.css:96` |
| `body` background | `var(--bg)` | `main.css:96` |
| `body` color | `var(--ink)` | `main.css:96` |
| `body` font-family | `'Courier New', monospace` | `main.css:96` |
| `body` font-size | `10px` | `main.css:97` |
| `touch-action` | `none` | `main.css:96` |
| Global reset | `*{box-sizing:border-box;margin:0;padding:0}` | `main.css:95` |

Vertical stack: `#topbar-wrap` (fixed height, `flex-shrink:0`) → `#main-area` (`flex:1 1 0`).
Horizontal stack inside `#main-area`: `#left-sidebar` (fixed 260 px) → `#viewport` (`flex:1`).

### 4.2 A. V2 BEHAVIOR — top bar

| Element | Property | Value |
|---|---|---|
| `#topbar-wrap` | display / direction | `flex` / `column` |
| | `flex-shrink` | `0` |
| | `border-bottom` | `2px solid var(--amber)` |
| | `background` | `var(--surf-0)` |
| `#topbar` (row 1) | `min-height` | `34px` |
| | `padding` | `4px 10px` |
| | `gap` | `6px` |
| | `font-size` | `9.5px` |
| | `letter-spacing` | `.08em` |
| | `text-transform` | `uppercase` |
| | `overflow-x` / `overflow-y` | `auto` / `hidden` |
| | `flex-wrap` | `nowrap` |
| | scrollbar | hidden (`::-webkit-scrollbar{display:none}`) |
| `#topbar-logo` | `font-size` / `weight` / `color` | `14px` / `900` / `var(--amber)` |
| | `margin-right` | `2px` |
| `#topbar-actions` (row 2) | `background` | `var(--surf-1)` |
| | `padding` | `4px 10px` |
| | `gap` | `4px` |
| | `flex-wrap` | `wrap` |
| | `border-top` | `1px solid var(--border-0)` |
| `.sep` | size | `1px × 18px`, `background var(--border-1)`, `flex-shrink:0` |
| `.sep` inside `#topbar-actions` | `height` | `16px` (override) |

**Row 1 never wraps and scrolls horizontally. Row 2 wraps.** Comment at `main.css:100-102`: row 2 "wraps, never gets clipped at high zoom."

### 4.3 A. V2 BEHAVIOR — left sidebar

| Property | Value | Source |
|---|---|---|
| `width` / `min-width` / `max-width` | `260px` (all three) | `main.css:513-515` |
| `background` | `var(--surf-1)` | `main.css:516` |
| `border-right` | `1.5px solid var(--border-1)` | `main.css:517` |
| `flex-shrink` | `0` | `main.css:521` |
| `overflow` | `hidden` | `main.css:520` |

**The sidebar is not resizable.** No splitter exists in the V2 source.

| Sub-element | Property | Value |
|---|---|---|
| `#sidebar-tabs` | `border-bottom` | `1.5px solid var(--border-1)` |
| `.sidebar-tab` | `flex` | `1` |
| | `background` | `var(--surf-0)` |
| | `font-size` / `weight` | `9px` / `700` |
| | `letter-spacing` | `.1em` |
| | `text-transform` | `uppercase` |
| | `padding` | `9px 4px` |
| | `border-bottom` | `2px solid transparent` |
| | `transition` | `color .15s, border-color .15s` |
| `.sidebar-tab:hover` | `color` | `var(--text-md)` |
| `.sidebar-tab.active` | `color` / `border-bottom-color` / `background` | `var(--amber)` / `var(--amber)` / `var(--surf-1)` |
| `.sidebar-pane` | default / active | `display:none` / `display:flex` |
| | `overflow-y` | `auto` |
| `.sidebar-pane-hd` | `padding` | `7px 10px` |
| | `background` | `var(--surf-0)` |
| | `border-bottom` | `1px solid var(--border-0)` |
| | `font-size` / `weight` / `letter-spacing` | `9px` / `700` / `.08em` |
| | `color` | `var(--text-lo)` |
| `.sidebar-pop-btn` | `border` / `radius` | `1px solid var(--border-1)` / `3px` |
| | `font-size` / `padding` | `11px` / `2px 5px` |
| | `transition` | `color .12s` |

### 4.4 A. V2 BEHAVIOR — diagram viewport and canvas

| Element | Property | Value |
|---|---|---|
| `#main-area` | `display` / `flex` / `min-height` / `overflow` | `flex` / `1 1 0` / `0` / `hidden` |
| `#viewport` | `flex` | `1 !important` |
| | `min-width` | `0 !important` |
| | `position` / `overflow` | `relative` / `hidden` |
| | `cursor` (default) | `grab` |
| `#scene` | `position` | `absolute`, `top:0`, `left:0` |
| | `transform-origin` | `0 0` |
| | `will-change` | `transform` |
| `#canvas` | **fixed size** | `1600px × 1000px` |
| | grid | two `linear-gradient`s, `background-size: 20px 20px` |
| | grid colour | `var(--canvas-grid)` |
| | `border` | `1.5px solid var(--canvas-border)` |
| | `border-radius` | `4px` |
| | `background-color` | `var(--canvas-bg)` |
| `#wire-layer` | `position` / size | `absolute` / `100% × 100%` |
| | `pointer-events` | **`none` — never changed** (`renderer.js:169-170` marks this CRITICAL) |
| | `overflow` | `visible` |

Cursor by mode: `#viewport` `grab` → `.panning` `grabbing` → `.edit-mode` `default` → `.wire-mode` `crosshair` → `.route-edit-mode` `default` → `.lead-place-mode` `crosshair !important`.

### 4.5 A. V2 BEHAVIOR — overlays, floating panels, status elements

Fixed-position surfaces and their exact geometry:

| Element | Position | Size | z-index |
|---|---|---|---|
| `#fp` (wire inspector pop-out) | `fixed`, JS-positioned | `width 320px`, `min-width 260px`, `min-height 200px` | 300 |
| `#mip` (module info panel) | `fixed`, JS-positioned | `width 290px`, `min 240×200`, `max-height 480px` | 500 |
| `#tracer` | `left:8px`, `top:50%`, `translateY(-50%)` | `width 200px`, `min 160×140` | 200 |
| `#swpack-panel` | `top:90px`, `left:50%`, `translateX(-50%)` | `width 540px`, `min 380×340`, `max-width 96vw` | 600 |
| `#mod-panel` | `right:0`, `top:var(--app-top-offset,68px)`, `bottom:0` | `width 0` → `240px` when `.open` | 200 |
| `#wep` (wire-edit status bar) | `left:50%`, `translateX(-50%)`, `bottom:16px` | content | 300 |
| `#srch` | `top:78px`, `left:50%`, `translateX(-50%)` | `width 300px` | 400 |
| `#legend` | `left:8px`, `bottom:10px` | content | 150 |
| `#minimap` | `right:10px`, `bottom:10px` | `150px × 90px` | 150 |
| `#kbh` | `right:10px`, `top:78px` | content | 100 |
| `#ctx` | JS-positioned at cursor | `min-width 160px` | 600 |
| `#toast` | `bottom:20px`, `left:50%`, `translateX(-50%)` | content | 999 |
| `.modal-bg` | `inset:0` | full | 500 |
| `.panel-menu` | JS: `top = btn.bottom+4`, `left = btn.left-140` | `min-width 170px` | 700 |
| `#graph-inspector` | `bottom:16px`, `left:16px` | `min 280px`, `max 360×420` | 9999 |
| `#zoom-box` | `absolute`, JS-positioned | drag rect | 50 |
| `.mod-card` | `absolute` in canvas | intrinsic | 10 (100 while `.dragging`) |
| `.t-dot.lead-r/.lead-b` | in card | — | 20 |

`#mod-panel` transition: `width .18s ease`.
`--app-top-offset` default `68px`; JS sets `#mod-panel.style.top = topbarWrap.offsetHeight` on boot and on `resize` (`app.js:294-296`, `bootstrap.js`).

### 4.6 A. V2 BEHAVIOR — responsive/sizing behaviour

- `#topbar` row 1: horizontal scroll, no wrap.
- `#topbar-actions` row 2: wraps to multiple lines.
- `#left-sidebar`: fixed 260 px; does not shrink or grow.
- `#viewport`: absorbs all remaining width (`flex:1`, `min-width:0`).
- `#canvas`: **fixed 1600 × 1000 px scene**; window size never changes it — only the transform changes.
- `window.resize` handler (`app.js:301`): `zReset(); drawWires(); updateMinimap();` — **the view refits on every resize**, discarding the user's pan/zoom.
- Floating panels are clamped on drag end: `left = clamp(0, vw-60)`, `top = clamp(0, vh-60)` (`app.js:221-225`). They are **not** re-clamped on window resize.

### 4.7 B. OEP ENGINE BEHAVIOR

- Scene size is **computed**, not fixed: `DiagramScene.contentWidth`/`contentHeight` from `DiagramView.render`.
- Viewport size is reported into the Engine via `ViewStateService.setViewportSize(w, h)`.
- Grid is Engine-owned (`GridSettings` on `ViewState`, `GridComputer.computeLines`), visibility and snap toggled through `ViewStateService`.
- Zoom/pan authority is `ViewState`; `TransformationController` mirrors it.
- The current Studio occupies the full window already (`studio_shell.dart:370` carve-out for `StudioDestination.diagram`).

### 4.8 C. RECONSTRUCTION REQUIREMENT

1. Reproduce the three-region geometry exactly: `topbar-wrap` (two rows, 2 px amber bottom border) / `left-sidebar` (260 px fixed) / `viewport` (fills remainder).
2. Reproduce every fixed-position surface's anchor, size and z-order from §4.5.
3. Canvas **content size comes from `DiagramScene`**, not a fixed 1600×1000. V2's fixed canvas is an artefact of its static dataset. Grid spacing of 20 px and the two-gradient rendering are reproduced; the extent is Engine-derived.
4. Cursor-by-mode mapping is reproduced exactly.
5. `#wire-layer`'s "pointer-events: none, never changed; children opt in individually" rule is reproduced as an explicit hit-testing invariant.
6. **Do not reproduce** refit-on-resize (`zReset()` on every window resize). It discards user viewport state, and OEP treats `ViewState` as authoritative and persisted. Recorded as a deliberate deviation — see §29.9.

---

## 5. Visual Design System

### 5.1 A. V2 BEHAVIOR — complete token table

**Source:** `css/main.css:6-93`. Both themes are complete and switched by the `data-theme` attribute on `<html>`.

| Token | Dark (`:root`, `[data-theme="dark"]`) | Light (`[data-theme="light"]`) | Role |
|---|---|---|---|
| `--ink` | `#f1f1ec` | `#1a1a1a` | Body text |
| `--bg` | `#e8e4dc` | `#eef0f2` | Document background |
| `--amber` | `#f59e0b` | `#b45309` | Primary accent |
| `--lcd-bg` | `#1a2e1a` | `#0d2410` | LCD background |
| `--lcd-fg` | `#39ff14` | `#16a34a` | LCD digits |
| `--purple` | `#7c3aed` | `#6d28d9` | Layout-edit accent |
| `--green` | `#15803d` | `#15803d` | Success / save |
| `--cyan` | `#22d3ee` | `#0e7490` | Focus / route-edit / module-select |
| `--cyan-dim` | `#0e7490` | `#0e7490` | Route-edit dim |
| `--red` | `#dc2626` | `#dc2626` | Error / red lead |
| `--red-dim` | `#7f1d1d` | `#fca5a5` | Destructive surface |
| `--surf-0` | `#0a0a0a` | `#ffffff` | Deepest surface (bars, headers) |
| `--surf-1` | `#141414` | `#f6f7f9` | Panel body |
| `--surf-2` | `#1c1c1c` | `#eceef1` | Input / row hover |
| `--surf-3` | `#262626` | `#e2e5ea` | Button face |
| `--surf-3-hover` | `#333333` | `#d6dae1` | Button hover |
| `--border-0` | `#2a2a2a` | `#d4d8de` | Subtle divider |
| `--border-1` | `#3a3a3a` | `#c2c7cf` | Standard border |
| `--border-2` | `#4a4a4a` | `#aab0bb` | Emphasised border |
| `--text-hi` | `#f5f5f4` | `#0f1115` | Primary text |
| `--text-md` | `#cbd5e1` | `#2b3340` | Secondary text |
| `--text-lo` | `#94a3b8` | `#4b5563` | Tertiary / labels |
| `--text-faint` | `#64748b` | `#6b7280` | Hint text |
| `--btn-text` | `#d4d4d4` | `#262b33` | Button label |
| `--btn-text-hover` | `#ffffff` | `#000000` | Button label hover |
| `--canvas-bg` | `#f5f2eb` | `#fbfaf6` | Diagram paper |
| `--canvas-border` | `#bbb` | `#9aa0a8` | Canvas edge |
| `--canvas-grid` | `rgba(0,0,0,.06)` | `rgba(0,0,0,.07)` | Grid lines |
| `--card-bg` | `#ffffff` | `#ffffff` | Module card face |
| `--card-ink` | `#0d0d0d` | `#0d0d0d` | Card text |
| `--card-border` | `#0d0d0d` | `#0d0d0d` | Card border |
| `--card-sub` | `#666` | `#555` | Card sub-label |
| `--card-tlbl` | `#444` | `#333` | Card title label |
| `--shadow-soft` | `0 1px 3px rgba(0,0,0,.4)` | `0 1px 3px rgba(0,0,0,.15)` | Card shadow |
| `--shadow-panel` | `0 8px 32px rgba(0,0,0,.65)` | `0 8px 28px rgba(0,0,0,.22)` | Floating panel |
| `--shadow-modal` | `0 4px 16px rgba(0,0,0,.6)` | `0 4px 14px rgba(0,0,0,.2)` | Modal |

**Count: 35 tokens × 2 themes = 70 declared values.**

### 5.2 A. V2 BEHAVIOR — hard-coded colours (not tokenised)

These appear literally in CSS/JS and are **not** theme-aware. They are part of the visual contract and must be reproduced.

| Colour | Usage |
|---|---|
| `#0891b2` | Wire-mode accent: `.tb-btn.wire-on`, `#wire-badge`, `#wep` border, `.mod-card.wire-src`, `.t-dot.wf`, wire preview line |
| `#10b981` | Traced-wire glow, `.t-dot.wh`, `#tr-title` |
| `#fde68a` | `.mod-card.wire-selected` middle ring |
| `#0f2a1c` | `.tr-w.act` background |
| `#0f2d1a` / `#15803d` / `#4ade80` | `.lm-btn.active` background / border / text |
| `#163d20` / `#265c34` / `#5fd986` | Add-terminal button surface / border / text |
| `#1c4d28` | Add-terminal hover |
| `#b45309` / `#991b1b` | `#toast.warn` / `#toast.err` |
| `#fca5a5` | `.fp-act.del`, `.ctx-i.danger`, `.lead-tag-r` |
| `#f87171` | `.term-del:hover`, validation error text |
| `#ef4444` | `.lr` (red lead label) |
| `#475569` / `#1e293b` | Black-lead pip fill / border; `.lead-btn-b` |
| `#7f1d1d` | `.lead-pip-r` border |
| `#164e63` / `#0c2231` / `#67e8f9` | `.sw-ind-active` border/background; `.swpack-btn.swpack-on` |
| `#fbbf24` | `.sw-ind-hi` label, cranking pulse, bulb glow |
| `#2a0808` | `.sw-ind-danger` background |
| `#78350f` | Cranking pulse base border |
| `#0f172a` / `#0c1829` / `#090f1a` / `#1e3a4a` / `#1e293b` / `#334155` / `#0f3460` / `#450a0a` | Switch-pack panel palette |
| `#8a97ab` / `#9aa7bb` / `#f1f5f9` / `#cbd5e1` / `#94a3b8` | Switch-pack text |
| `#22d3ee` / `rgba(34,211,238,.06)` | `#zoom-box` border / fill |
| `#0d1f0d` | `#lcd` border |
| `#2c9b2c` / `#22a022` / `#3a9c3a` | LCD secondary text |
| `#ff6b6b` | LCD `OPN` reading |
| `#c0281e`, `#8b1515`, `#1a0808`, `#0f0404`, `#7c1515`, `#d4a0a0`, `#e00` | Multimeter body SVG |
| `#fef9c3`, `#fffde7`, `#ca8a04`, `#d4d4d4` | Bulb card |
| `#e2e8f0`, `#475569`, `#94a3b8`, `#334155` | Connector card |
| `#fff` + `#b45309` + `#7c2d12` | Wire label chip fill / stroke / text |

### 5.3 A. V2 BEHAVIOR — category colours

**Source:** `renderer.js:17` (`CAT_CLR`), duplicated in `utils/colors.js:19-31` (`CAT_COLORS`). Values identical.

| Category | Hex |
|---|---|
| `indicator` | `#7c3aed` |
| `ignition` | `#dc2626` |
| `control` | `#2563eb` |
| `accessory` | `#ea580c` |
| `charging` | `#d97706` |
| `ground` | `#374151` |
| `lighting` | `#0891b2` |
| `switch` | `#059669` |
| `starter` | `#9333ea` |
| `power` | `#b45309` |
| `connector` | `#0e7490` |
| *(fallback)* | `#888` |

### 5.4 A. V2 BEHAVIOR — wire colour codes

**Source:** `renderer.js:18-19` (`HEX`, `CNAMES`), duplicated in `utils/colors.js:34-76`.

| Code | Hex | Name |
|---|---|---|
| `Bl` | `#1e293b` | Black |
| `Br` | `#7c2d12` | Brown |
| `R` | `#dc2626` | Red |
| `G` | `#15803d` | Green |
| `Gr` | `#9ca3af` | Gray |
| `Lg` | `#4ade80` | Lt Green |
| `Y` | `#ca8a04` | Yellow |
| `W` | `#94a3b8` | White |
| `Bu` | `#2563eb` | Blue |
| `Blu` | `#2563eb` | Blue |
| `O` | `#ea580c` | Orange |
| `P` | `#ec4899` | Pink |
| `—` | `#999` | — |
| *(unmatched)* | `#666` | code echoed |
| *(null/empty)* | `#888` | `—` |

Compound names (display only, no own hex): `P/W` Pink/White, `Y/R` Yellow/Red, `Bl/Y` Black/Yellow, `Blu/Y` Blue/Yellow, `Bl/W` Black/White, `Y/W` Yellow/White, `Lg/R` Lt Grn/Red, `G/R` Green/Red, `Br/R` Brown/Red, `Blu/R` Blue/Red.

**Resolution rules** (`renderer.js:20-21`):
- `h(code)`: exact match in `HEX`; else `HEX[code.split('/')[0]]`; else `#666`; empty → `#888`.
- `trH(code)` (stripe): if no `/`, `null`; else `HEX[substring after first '/']` or `null`.

### 5.5 A. V2 BEHAVIOR — typography scale

Every size found in `main.css`, ascending:

| Size | Applied to |
|---|---|
| `4px` | Connector-card pin label (inline, `renderer.js`) |
| `4.5px` | Bulb-card terminal label (inline) |
| `5.5px` | `.t-lbl` (terminal label); dial marks (SVG) |
| `6px` | `.mod-sub`; SVG jack sub-labels; lead probe glyph |
| `6.5px` | Wire label chip text (SVG) |
| `7px` | `.mod-label`; `.tr-ft`; LCD range (SVG) |
| `7.5px` | `#fp-hint`; `.mi-sb`; `#kbh`; `.sw-terminals`; `.lm-btn`; `.mip-wire-dest` |
| `8px` | `.fp-kb`; `.sr-type`; `.lg-lbl`; `.lead-tag`; `.lead-loc`; `.mip-term-color`; `.mip-wire-lbl`; `.cat-hd`; `.mip-section-hd`; `.sw-sub`; `.sw-pos-lbl`; `.sw-state-desc`; `#lcd-mode`; `#lcd-range`; `#lcd-note`; `.lead-mode-lbl`; `#wpm-tbl th` |
| `8.5px` | `.fpk`; `.m-btn`; `.fp-act`; `.form-lbl`; `.tr-lbl`; `#wep-cancel`; `.panel-menu-i`; `#add-term-btn` |
| `9px` | `.key-btn`; `.tb-btn`; `#theme-toggle`; `#zoom-display`; `#edit-badge`; `#wire-badge`; `.mbtn`; `.sidebar-tab`; `.sidebar-pane-hd`; `#si-info`; `.sr`; `.ctx-i`; `#mp-title`; `.mi-nm`; `.sw-pos`; `.mip-term-name`; `#meter-leads`; `#si-leads`; `#tr-title`; `.lead-place-btn`(10px) |
| `9.5px` | `#topbar`; `#fp-info`; `.fi`; `.fs`; `#wep-status`; `#toast` |
| `10px` | `body`; `#fp-title`; `.modal-ht`; `.sw-ind-icon`; `.lead-place-btn` |
| `10.5px` | `#srch-in` |
| `11px` | `#lcd-unit`; `.sidebar-pop-btn`; `.sw-name` |
| `12px` | `#mip-close` |
| `13px` | `.panel-menu-btn`; `.sw-pos-icon` |
| `14px` | `#topbar-logo`; `#tr-close` |
| `15px` | `#mp-close` |
| `16px` | `#fp-close`; `.modal-xb` |
| `27px` | `#lcd-val` (HTML LCD) |
| `30px` | `#m-lcd-val` (SVG LCD) |

**Weights used:** `600`, `700`, `800`, `900`. **Letter-spacing:** `.03em`, `.04em`, `.05em`, `.06em`, `.08em`, `.1em`, `.12em`, `.16em`.

### 5.6 A. V2 BEHAVIOR — radii, spacing, transitions, opacity

| Property | Values in use |
|---|---|
| `border-radius` | `1px` (`#mm-vp`, connector pin), `2px` (`.fp-kb`, `.m-btn`, `.fp-act`, `.lm-btn`, `.term-del`, `.tr-w`, `.mi-add`, `.lead-place-btn`, `.sw-ind`), `2px 0 0 2px` (`.cat-stripe`), `3px` (`.key-btn`, `.tb-btn`, `.mod-card`, `.fi`, `.fs`, `.mbtn`, `.sidebar-pop-btn`, `.sw-pos`, `#minimap`, `.sw-schematic`), `4px` (`#canvas`, `#toast`, `#ctx`, `#legend`, `#lcd`, `.panel-menu`, `#mip`), `5px` (`#srch`, `#swpack-panel`), `6px` (`#fp`, `#wep`, `#tracer`), `8px` (`.modal-box`), `50%` (all dots/pips), `14px` (meter body SVG `rx`) |
| Control padding | `3px 6px`, `3px 8px`, `4px 8px`, `4px 9px`, `4px 10px`, `5px 8px`, `5px 12px`, `7px 12px`, `9px 4px` |
| Panel padding | `6px 10px`, `7px 10px`, `8px 10px`, `9px 10px`, `10px 14px`, `12px 14px` |
| Transitions | `transform .1s, box-shadow .1s` (`.t-dot`), `all .1s` (`.lm-btn`), `background .1s` (`.mip-wire-link`), `fill .1s` (`.mbtn-rect`), `color .12s` (`.sidebar-pop-btn`), `all .12s` (`.sw-pos`), `all .15s` (`.sw-ind`), `background .15s` (`.mpm-dot`), `color .15s, border-color .15s` (`.sidebar-tab`), `width .18s ease` (`#mod-panel`), `opacity .3s` (`#toast`) |
| Opacity | `.1` (dimmed wire), `.35` (popped-out sidebar pane), `.72` (flow overlay stroke), `.85` (lead wire), `.92` (dragging card), `.94` (label chip fill), `.96` (`#kbh`), `.97` (`#legend`), `.04` (LCD scanlines), `.15` (meter sheen) |

### 5.7 A. V2 BEHAVIOR — control state matrix

| Control | Default | Hover | Active/Selected | Disabled | Focus |
|---|---|---|---|---|---|
| `.key-btn` | `surf-3` / `border-1` / `btn-text` | `surf-3-hover` / `btn-text-hover` | `amber` bg, `#0a0a0a` text, `amber` border, weight `800` | *UNSPECIFIED BY V2* | *UNSPECIFIED BY V2* |
| `.tb-btn` | `surf-3` / `border-1` / `btn-text` | `surf-3-hover` / `btn-text-hover` | `.edit-on` purple; `.wire-on` `#0891b2`; `.save-btn` green (persistent, not a state) | *UNSPECIFIED BY V2* | *UNSPECIFIED BY V2* |
| `.fp-kb` | `surf-3` / `border-1` / `text-md` | *UNSPECIFIED BY V2* | `amber` bg, `#0a0a0a` text, weight `800` | — | — |
| `.m-btn` | `surf-3` / `border-1` / `text-md` | *UNSPECIFIED BY V2* | `green` bg, `#fff`, green border | — | — |
| `.fp-act` | `surf-3` / `border-1` / `text-md` | `surf-3-hover` / `btn-text-hover` | `.route-on` `#0e7490` bg | — | — |
| `.fp-act.del` | `red-dim` border, `#fca5a5` | `red-dim` bg, `#fff` | — | — | — |
| `.lm-btn` | `surf-2` / `border-1` / `text-lo` | `surf-3` / `text-hi` / `border-2` | `#0f2d1a` bg, `#15803d` border, `#4ade80` | — | — |
| `.sidebar-tab` | `surf-0` / `text-lo` | `text-md` | `amber` text + 2 px amber underline + `surf-1` bg | — | — |
| `.mbtn` | `surf-3` / `border-1` / `text-md` | `surf-3-hover` / `btn-text-hover` | `.pri` purple bg | — | — |
| `.mbtn.pri` | purple | `#6d28d9` | — | — | — |
| `.ctx-i` | `text-md` | `surf-3` / `text-hi` | — | — | — |
| `.ctx-i.danger` | `#fca5a5` | `red-dim` bg / `#fff` | — | — | — |
| `.fi` / `.fs` | `surf-2` / `border-1` / `text-hi` | — | — | — | `border-color: var(--cyan)` |
| `.t-dot` | 7×7, 1.5 px `#0d0d0d` border | `scale(1.5)` | `.wf` cyan ring + `scale(1.6)`; `.wh` green ring + `scale(1.5)`; `.lead-r`/`.lead-b` + `scale(1.4)` | — | — |
| `.sw-pos` | `#1e293b` / `#334155` / `#94a3b8` | `#253347` / `#475569` / `#cbd5e1` | `#0f3460` / `#22d3ee` / `#67e8f9` + glow | — | — |
| `.sw-pos-danger` | as `.sw-pos` | `#7f1d1d` border | `#450a0a` / `#dc2626` / `#fca5a5` + glow | — | — |
| `.mi-add` | `#163d20` / `#265c34` / `#5fd986` | `#1c4d28` | — | — | — |
| `.lead-place-btn` | transparent / `border-1` / `text-lo` | `text-hi` / `border-2` | `.lead-btn-active`: cyan text, `#0e7490` border, `leadpulse 1s infinite` | — | — |

**`focus` is styled only for `.fi`/`.fs` (cyan border). No other control has a focus style. No control has a disabled style. There is no focus-visible ring anywhere in V2.**

### 5.8 B. OEP ENGINE BEHAVIOR

OEP uses `core/theme/studio_colors.dart` (`StudioColors`) — a single dark palette shared by every Studio. Diagram Studio additionally carries `_ImmersiveColors` (3 tokens: `surface0 #0A0A0A`, `surface1 #171717`, `amber #F59E0B`), a partial extraction of V2's `--surf-0`, `--surf-1`, `--amber`. Note `_ImmersiveColors.surface1` is `#171717`, which **does not match** V2's `--surf-1` of `#141414`.

### 5.9 C. RECONSTRUCTION REQUIREMENT

1. Produce a complete Diagram-Studio-scoped token set carrying **all 35 tokens in both themes** with the exact values in §5.1.
2. Carry the hard-coded colours in §5.2 as named constants; they are part of the contract.
3. Category colours (§5.3) must resolve from the **same source the module cards render from** — in OEP, `categoryStripeColor`. If OEP's mapping differs from §5.3, that is a conflict (see §29.10), not a licence to keep two tables.
4. Wire colour code → hex/name/stripe resolution (§5.4) requires a wire colour field in the OEP model. Where that field lives is unresolved — see §29.10.
5. Reproduce the typography scale, radii, transitions and opacity values exactly.
6. Reproduce the control state matrix. **V2's absence of focus and disabled styling is a documented gap, not a requirement to omit them** — OEP already disables toolbar controls contextually. Adding a disabled style is a permitted, documented deviation; adding a focus-visible style is required for keyboard operability and is likewise a documented deviation. Both recorded in §29.9.
7. Scope the token set to Diagram Studio. Do not modify shared `StudioColors`.

---

## 6. Top Bar

### 6.1 A. V2 BEHAVIOR — row 1 (`#topbar`), exact order

**Source:** `index.html:20-53`

| # | Control | Element | Label/Icon | Click behaviour | Shortcut | Side effects |
|---|---|---|---|---|---|---|
| 1 | Logo | `#topbar-logo` div | `TRX300` | none (static) | — | none |
| 2 | separator | `.sep` | — | — | — | — |
| 3 | KEY label | static span | `KEY` | none | — | — |
| 4 | Key Off | `.key-btn` | `Off`, `data-key="0"` | `setKey(0)` | `0` | sets `keyPos`, toggles `.active` on all `.key-btn`/`.fp-kb`, re-places leads if wire selected, `updateMeter()`, `updateBulbs()`, `drawWires()`, notifies Sidebar |
| 5 | Key On | `.key-btn` | `On`, `data-key="1"` | `setKey(1)` | `1` | same |
| 6 | Key Crank | `.key-btn` | `Crank`, `data-key="2"` | `setKey(2)` | `2` | same |
| 7 | Key Run | `.key-btn` | `Run`, `data-key="3"` | `setKey(3)` | `3` | same |
| 8 | separator | `.sep` | — | — | — | — |
| 9 | SWITCHES label | static span | `SWITCHES` | none | — | — |
| 10 | Switch indicators | `#sw-indicators` (4 `.sw-ind`) | lights 💡/beam 🔆/kill 🔑/start ⚡ | none (display only) | — | reflects `SWPACK.state` |
| 11 | Switch pack toggle | `#swpack-btn` `.tb-btn.swpack-btn` | `🕹 Switches` | `SWPACK.toggle()` | none | opens/closes `#swpack-panel`, toggles `.swpack-on` |
| 12 | separator | `.sep` | — | — | — | — |
| 13 | Edit badge | `#edit-badge` | `✦ LAYOUT EDIT` | none (display only) | — | `display:none` unless `editMode` |
| 14 | Wire badge | `#wire-badge` | `⚡ WIRE MODE` | none (display only) | — | `display:none` unless `wireMode` |

### 6.2 A. V2 BEHAVIOR — row 2 (`#topbar-actions`), exact order

**Source:** `index.html:54-73`

| # | Control | Label/Icon | Click behaviour | Shortcut | Side effects |
|---|---|---|---|---|---|
| 1 | Zoom display | `#zoom-display` text, e.g. `100%` | none | — | reflects `scale` |
| 2 | Zoom out | `−` `.tb-btn` | `zBy(-.15)` | none dedicated (Ctrl+wheel down) | `scale -= .15` clamped `[.15, 3]`, `applyT()`, `drawWires()` |
| 3 | Zoom in | `+` `.tb-btn` | `zBy(.15)` | none dedicated (Ctrl+wheel up) | `scale += .15` clamped, same |
| 4 | Fit | `Fit` `.tb-btn` | `zReset()` | `F` | recomputes scale to fit canvas in viewport (max `.9`), re-centres, `applyT()`, `drawWires()` |
| 5 | separator | `.sep` | — | — | — |
| 6 | Layout toggle | `#edit-btn` `.tb-btn`, text `✦ Layout`/`✦ Done` | `toggleEdit()` | `E` | see §8 |
| 7 | Wire toggle | `#wire-btn` `.tb-btn`, text `⚡ Wire`/`⚡ Done` | `toggleWireMode()` | `W` | see §8 |
| 8 | Add Module | `＋ Module` `.tb-btn` | `openModPanel()` | none | slides `#mod-panel` open, `renderModPanel()` |
| 9 | Find | `⌕ Find` `.tb-btn` | `toggleSearch()` | `/` or `?` | opens `#srch`, clears input, focuses it |
| 10 | Legend | `☰ Legend` `.tb-btn` | `toggleLegend()` | `L` | opens `#legend`, `buildLegend()` |
| 11 | separator | `.sep` | — | — | — |
| 12 | Save | `⬇ Save` `.tb-btn.save-btn` (green) | `saveLayout()` | none | downloads `trx300-layout.json` (`positions`, `wireRoutes`, user wires, user modules), toast |
| 13 | Load | `⬆ Load` `.tb-btn` | `loadLayoutFile()` | none | triggers hidden `#lfi` file input |
| 14 | *(hidden)* | `#lfi` `<input type=file accept=".json">` | `onLayoutFile(event)` on change | — | merges `positions`/`wireRoutes`/user wires/user modules into globals, `placeCards()`, `drawWires()`, `buildLegend()`, toast |
| 15 | Export SVG | `Export SVG` `.tb-btn` | `exportSVG()` | none | downloads `#wire-layer`'s `outerHTML` as `trx300-diagram.svg`, toast |
| 16 | separator | `.sep` | — | — | — |
| 17 | Theme toggle | `#theme-toggle`, icon `☾`/`☀` + label `Dark`/`Light` | `toggleTheme()` | none | flips `data-theme`, persists to `localStorage['wiring-sim-theme']`, re-renders wires |
| 18 | Shortcuts | `?` `.tb-btn` | `toggleKbh()` | `?` (same key as Find — see §29.9 conflict note in §24) | opens/closes `#kbh` |

### 6.3 A. V2 BEHAVIOR — tooltips, disabled/hover states

No control in `#topbar` or `#topbar-actions` has a `title` attribute — **no tooltips exist anywhere in the V2 top bar.** No control is ever disabled (no `disabled` attribute, no CSS `:disabled` rule referencing these classes). Hover state for every `.tb-btn`/`.key-btn` is uniform: `background: var(--surf-3-hover)`, `color: var(--btn-text-hover)` (`main.css:112,117`).

### 6.4 B. OEP ENGINE BEHAVIOR

OEP's toolbar surface is `toolbars/diagram_toolbars.dart` — twelve groups, ~45 controls, every one with a `tooltip:` string (Material `IconButton` convention) and per-audit-§6.3 explicit enablement (`onPressed: null` when inapplicable). Zoom/Fit/navigation map to `ViewStateService`; Save/Open/New map to `EngineeringProjectNotifier`; Layout/Wire modes have no direct OEP counterpart (see §8).

### 6.5 C. RECONSTRUCTION REQUIREMENT

1. Reproduce row 1 and row 2 control **inventory, order, and labels** exactly as in §6.1–6.2, bound to OEP's equivalent capability where one exists (audit §6.3 binding table governs which Engine call each maps to).
2. Zoom −/+/Fit map to `ViewStateService.setZoom`/`fitAll`. Save/Load/Export SVG map to `EngineeringProjectNotifier` document commands + the existing SVG exporter (`oep_engine` export capability, audit §9.1).
3. Add Module maps to `PlacementToolbar`'s symbol picker, reshaped as V2's side-drawer (§10, §23).
4. **Tooltips are a deliberate, recorded deviation from V2** (§29.9): OEP already provides them platform-wide via Material `IconButton.tooltip`, and removing them would regress accessibility with no offsetting fidelity gain. Keep them.
5. **Disabled states are a deliberate, recorded deviation from V2** for the same reason — OEP's toolbar already disables controls contextually (e.g., Undo when `!canUndo`), and V2 has no controls that are ever contextually inapplicable in a way that would require this (its buttons are always clickable, sometimes no-op). Keep OEP's existing enablement pattern.
6. Theme toggle requires resolving §29.9 (theme scope) before implementation.

---

## 7. Key / Switches System

### 7.1 A. V2 BEHAVIOR — key states

**Source:** `index.html:26-30`, `js/ui/meter-panel.js:17-23`

Four key positions, single-select, `data-key` 0–3: `Off` / `On` / `Crank` / `Run`. Global `keyPos` (default `0`). `setKey(k)` (§6.1 row 4-7) is the only mutator. Two independent button groups render the same state: `.key-btn` (topbar) and `.fp-kb` (wire-inspector floating panel `#fp-ks`, and sidebar `#si-ks`) — kept in sync by `setKey` toggling `.active` on **both** selectors via one `querySelectorAll('.key-btn,.fp-kb')` call.

`setKey` side effects, in order: set `keyPos` → sync all key button `.active` classes → if a wire is selected, `autoPlaceLeads(selW)` (mode-dependent, §17) and `updateMeter()` → `updateBulbs()` (bulb glow driven by `keyPos >= 1`) → `drawWires()` (re-evaluates flow animation, which is `keyPos`-gated) → `Sidebar.onMeterChange()`.

### 7.2 A. V2 BEHAVIOR — switch controls (handlebar switch pack)

**Source:** `js/swpack.js`, `index.html:281-436`

Four switches, each independently stateful, in `#swpack-panel` (a draggable/resizable floating panel, closed by default, opened via `#swpack-btn`):

| Switch | Values | Default | Terminals | Momentary? |
|---|---|---|---|---|
| `lights` | `off` / `on` | `off` | BAT2, TL | no |
| `beam` | `lo` / `hi` | `lo` | LO, HI | no |
| `kill` | `run` / `stop` | `run` | IG1, IG2 | no |
| `start` | boolean (`false`/`true`) | `false` | IG1, ST | **yes** — press/hold/release |

`SWPACK.set(sw, val, btn)`: sets `state[sw]`, updates the rocker's `.active` class, updates the state-description text, calls `update()`.
`SWPACK.startPress()` / `startRelease()`: set `state.start` true/false on mouse/touch down/up (`onmousedown`/`onmouseup`/`ontouchstart`/`ontouchend` on the START button; **not a click handler** — held state).

`update()` (called after every mutation): `updateSchematics()` (redraws inline SVG contact lines per switch), `updateIndicators()` (topbar `#sw-indicators` glyphs/labels/CSS classes), `updateSummary()` (`#swpack-summary-text` HTML), then if defined: `updateMeter()`, `drawWires()`.

### 7.3 A. V2 BEHAVIOR — indicator visual states

**Source:** `main.css:327-339`, `js/swpack.js:140-167`

| Indicator | Base | Active class | Danger class | Cranking class |
|---|---|---|---|---|
| `#swi-lights` | `.sw-ind` (border `border-1`, bg `surf-2`) | `.sw-ind-active` when `on` (border `#164e63`, bg `#0c2231`, label cyan) | — | — |
| `#swi-beam` | `.sw-ind` | `.sw-ind-lo`/`.sw-ind-hi` toggle label colour (`text-md` / `#fbbf24`) | — | — |
| `#swi-kill` | `.sw-ind` | `.sw-ind-active` when `run` | `.sw-ind-danger` when `stop` (border `#7f1d1d`, bg `#2a0808`, label `#f87171`) | — |
| `#swi-start` | `.sw-ind` | — | — | `.sw-ind-cranking` while held (border/bg pulse `crank-pulse .4s infinite`, label `#fbbf24`) |

### 7.4 A. V2 BEHAVIOR — relationship to diagnostic readings

**Source:** `js/swpack.js:22-69` (`OVERRIDES`)

For five specific wire ids (`hlsw-lo`, `hlsw-hi`, `kill-cdi`, `start-relay`, `lh-hi-spl`, `lh-lo-spl`), `SWPACK.getReading(wireId, keyPos)` returns a reading object `{VDC, VAC, CONT, RES, DIODE, note}` computed from `(keyPos, switchState)`, **overriding** the wire's own authored `measurements.json` entry. `updateMeter()` (`meter-panel.js:75`) checks `SWPACK.getReading` first, falling back to `selW.R[keyPos]` only if the override function returns `null`/is absent. This is vehicle-specific (TRX300 handlebar wiring), not a generic mechanism.

### 7.5 A. V2 BEHAVIOR — keyboard interaction

`0`–`3` (no modifier) call `setKey(+e.key)` (`app.js:178`), guarded only by "not currently focused in an input/textarea/select" (`app.js:142`). No keyboard shortcut exists for any switch-pack control.

### 7.6 B. OEP ENGINE BEHAVIOR

Key states map onto `SimulationSession.availableOperatingStates` / `activeOperatingStateId` (`DiagramSimulationService.setOperatingState`). Switch states map onto `availableInputStates` / `activeInputStates` (`setInputState`), both sourced from a loaded `DomainProfile` (§8.5 of the audit) — **there is no vehicle-specific `SWPACK`-equivalent in OEP; a `DomainProfile` must be authored and loaded for any of this to render at all** ("no fabricated default" rule, audit §9.3 item 13). OEP already implements the "no session ⇒ render nothing" discipline V2 does not need (V2's key/switch state always exists, hard-coded per vehicle).

### 7.7 C. RECONSTRUCTION REQUIREMENT

1. KEY row reproduces §7.1's four-button single-select group, sourced from `SimulationSession.availableOperatingStates`, rendered in **every** document mode (not gated), per the existing `_KeySwitchesRow` "works in all 3 modes" requirement (audit §5.2).
2. SWITCHES indicators (topbar) and the switch-pack panel (§7.2–7.3) are **generic, profile-driven** in OEP — they render one indicator/group per `InputStateDefinition`, with icon selection by keyword match (already implemented in `_KeySwitchesRow._iconFor`, audit §6.4). The specific TRX300 switch pack (lights/beam/kill/start with hard-coded schematics) is vehicle content, not a generic Studio feature — see §29.8, unresolved.
3. The reading-override relationship (§7.4) is an **authored-data mechanism** with no direct OEP equivalent; OEP computes readings from `SimulationEngine`, not from a per-wire override table. This is a data-model question, not a presentation one (audit §8.5, unresolved).
4. `0`–`3` keyboard shortcuts for key state are reproduced (§24), guarded by the same input-focus check OEP's own shortcut table already uses implicitly via `CallbackShortcuts`.
5. Momentary START press/hold/release (§7.2) has no OEP `InputStateDefinition.valueType` equivalent confirmed in the audit; whether `InputValueType` supports a momentary/pressed semantic is `UNSPECIFIED BY V2` from the OEP side and must be checked against the Engine model before implementation.

---

## 8. Tool Modes

V2 has **three** mutually-exclusive tool-mode booleans (not four — "normal" is simply the state where all three are `false`, not a fourth flag). This section documents each precisely.

### 8.1 A. V2 BEHAVIOR — mode inventory

| Mode | Global | Default | Activation | Deactivation |
|---|---|---|---|---|
| Normal | *(implicit — no flag)* | active | any other mode turns off | — |
| Layout Edit | `editMode` (bool) | `false` | `toggleEdit()` — `E` key or `#edit-btn` | same toggle |
| Wire | `wireMode` (bool) | `false` | `toggleWireMode()` — `W` key or `#wire-btn` | same toggle, or `Esc`/`#wep-cancel` (`cancelWireMode()`) |
| Route Edit | `routeEditMode` (bool) | `false` | `toggleRouteEditMode()` — `#route-edit-btn`/`#si-route-btn` (inspector action, **not a global keyboard shortcut**); requires `selW` non-null | same toggle, or `Esc` (`exitRouteEditMode()`) |

**Mutual exclusion enforcement** (`module-editor.js:66-76`, `wire-editor.js:52-60`, `routing-editor.js:12-27`):
- Entering Layout Edit while Wire is on: `cancelWireMode()` first, and while Route Edit is on: `exitRouteEditMode()` first.
- Entering Wire while Layout Edit is on: `toggleEdit()` first (turns it off), and while Route Edit is on: `exitRouteEditMode()` first.
- Entering Route Edit while Layout Edit is on: `toggleEdit()` first; while Wire is on: `cancelWireMode()` first. Also **requires a selected wire** — `if (!selW) { showToast('Select a wire first', 'warn'); return; }` — otherwise the toggle is a no-op with a warning toast.

### 8.2 A. V2 BEHAVIOR — per-mode detail

**Normal mode**
- Visual indication: none (absence of badges/cursor override beyond default `grab`).
- Cursor: `grab` (idle) / `grabbing` (panning background).
- Available gestures: background drag pans (`vp` mousedown when not over `.mod-card`/`#fp`); click a card selects module (`selMod`); click a wire hit-path selects wire (`selWire`); Ctrl/Shift+drag on background = rubber-band zoom (`sidebar.js:308-361`); Ctrl/Cmd+wheel = zoom at cursor.
- Unavailable: card dragging (drag handler checks `if (!editMode) return`), wire creation (terminal click only routes to wire-creation logic `if (wireMode)`; in normal mode terminal clicks instead set meter leads).
- Selection: single wire OR single module, mutually exclusive (selecting one clears the other, `sidebar.js` inspector logic + `inspector.js:53-65`).

**Layout Edit mode** (`editMode`)
- Activation side effects: if Wire mode was on, cancel it; if Route Edit was on, exit it. Button text `✦ Layout` → `✦ Done`. `#edit-badge` shown (`✦ LAYOUT EDIT`). `#viewport` gets class `.edit-mode` (cursor becomes `default`; `.mod-card` under it gets cursor `grab`). On entry: `closePanel(); selW = null; tracedWires.clear();` — any active wire selection/trace is cleared.
- Available gestures: card mousedown+drag moves it (10 px grid snap, `Math.round(.../10)*10`), constrained to `x,y >= 0`; card right-click opens context menu with Edit/Delete Module (no Trace); card left-click (no drag) is a **no-op** in edit mode (`if (editMode || wireMode || routeEditMode) return;` in the click handler, `module-editor.js:57`).
- Unavailable: wire selection, wire creation, meter lead placement via terminal click (`if (editMode) return` in `setupTermClicks`).
- Status indication: `#edit-badge` visible; button `.edit-on` (purple).

**Wire mode** (`wireMode`)
- Activation side effects: if Layout Edit was on, turn it off; if Route Edit was on, exit it. Button text `⚡ Wire` → `⚡ Done`. `#wire-badge` shown. `#viewport` gets class `.wire-mode` (cursor `crosshair`). `#wep` (status bar) opens with text `Click a source terminal`.
- Gesture: click a terminal dot (`.t-dot`) → if no `wireSrc` yet, arms it (`wireSrc = {m,t}`, highlights dot `.wf` and card `.wire-src`, status updates to `FROM: <module> · <terminal> → click destination`); click a **second, different** terminal → duplicate-check against existing wires (either direction) — if duplicate, toast warning and reset to armed-nothing state; else create `{id:'wire-'+Date.now(), c:'W', lbl:'New Wire', from, to, desc:'User-created wire', R: 4 default entries labelled Key off/Key on/Cranking/Running}`, select it, reset status, and **300ms later auto-open the wire properties modal** (`setTimeout(() => editWireProps(), 300)`). Clicking the **same** terminal again cancels the pending connection (resets `wireSrc` to null, status back to prompt).
- Cancellation: `Esc` or `#wep-cancel` button → `cancelWireMode()` (turns wire mode off entirely, clears `wireSrc`).
- Preview: mousemove over viewport while `wireMode && wireSrc` updates `mcX`/`mcY` (canvas-space cursor) and `drawWires()` redraws a dashed cyan preview line (`#0891b2`, `stroke-dasharray:'6 3'`) from the source terminal to the cursor.
- New wire's default colour is always `W` (white) with label `New Wire` — the user is expected to edit it via the auto-opened properties modal.

**Route Edit mode** (`routeEditMode`)
- **Precondition:** exactly one wire selected (`selW` non-null). Attempting to enter with no selection shows a warning toast and does not enter the mode.
- Activation side effects: if Layout Edit was on, turn it off; if Wire mode was on, cancel it. Button text `↔ Edit Route` → `↔ Done Routing`. `#wep` opens with status `Click a wire segment · ↑↓←→ nudge · R reset route`. `#viewport` gets class `.route-edit-mode` (cursor `default`).
- Gesture: click a **movable segment** of the selected wire's rendered path (`getMovableSegs` — interior horizontal/vertical runs, excludes the two end stub segments) → selects it (`selSeg = {wid, segIdx, axis}`), status updates to `Seg N selected (horiz → ↑↓ | vert → ←→) · arrows nudge · R reset`. See §15 for full detail.
- Cancellation: `Esc` → `exitRouteEditMode()`.

### 8.3 B. OEP ENGINE BEHAVIOR

OEP's mode axis is `DiagramStudioMode {view, edit, simulate}`, persisted per-tab (`DiagramTab.mode`), gating which **command categories** are available (construction/editing tools Edit-only per audit §2.3 item 34) and driving panel-visibility defaults (`_applyModeDefaults`). It has no concept of "currently drawing a wire" or "currently nudging a route segment" as a persisted mode — those exist as ungated boolean interaction flags (`_wireEditModeActive`, `_wireCreateModeActive`) scoped to the page's `State`, not to `DiagramTab`.

### 8.4 C. RECONSTRUCTION REQUIREMENT

This is audit §8.4 and §11.4's central open question, restated precisely now that V2's actual model is documented:

V2's three tool-mode booleans are a **session-local interaction axis** orthogonal to OEP's **persisted document-purpose axis**. They are not competing implementations of the same concept — `editMode`/`wireMode`/`routeEditMode` have no notion of "does this diagram exist to be looked at vs. edited vs. simulated," and `DiagramStudioMode` has no notion of "am I currently mid-gesture creating a wire." The audit's proposed two-dimension model (§11.4: Document mode owns *what commands exist*; Tool mode owns *what the canvas does with input right now*, selectable only within Document mode `edit`) is consistent with what this section found, but **is not confirmed by V2 source** — V2 simply has no document-purpose axis at all, so V2 cannot confirm or deny how the two should interact. This remains **UNSPECIFIED BY V2** and is logged as unresolved in §29.3.

What V2 source *does* settle, and which the reconstruction must reproduce regardless of the §29.3 outcome:
1. The three tool modes are mutually exclusive, with the exact activation/deactivation cascade in §8.1.
2. Route Edit requires a single wire selection as a precondition, with a warning toast if absent.
3. Layout Edit clears wire selection/trace on entry.
4. Wire mode's terminal-click state machine (arm → complete/cancel/duplicate-reject) is reproduced exactly, including the 300 ms auto-open of wire properties on creation.
5. Each mode's badge, cursor, and status-bar text are reproduced per §8.2.

---

## 9. Diagram Canvas

### 9.1 A. V2 BEHAVIOR — coordinate system

**Source:** `renderer.js:91-93, 124`

Two coordinate spaces: **canvas space** (fixed 1600×1000, where module positions and terminal dots live) and **screen space** (viewport pixels). Transform: `#scene { transform: translate(tx, ty) scale(scale) }`. Conversion screen→canvas used by rubber-band zoom: `cx = (screenX - tx) / scale`.

`getPos(modId, termName)` resolves a terminal's canvas-space centre by reading the **live DOM `getBoundingClientRect()`** of its `.t-dot` element and the canvas's own bounding rect, then dividing by `scale` — i.e., V2 derives wire endpoints from rendered DOM geometry, not from a stored port-offset table.

### 9.2 A. V2 BEHAVIOR — zoom

| Property | Value | Source |
|---|---|---|
| Minimum | `.15` (15%) | `zBy`: `Math.max(.15, ...)`; rubber-band: `Math.max(0.15, ...)` |
| Maximum | `3` (300%) | `zBy`: `Math.min(3, ...)`; rubber-band: `Math.min(3, ...)` |
| Increment (button) | `.15` per click (`zBy(-.15)` / `zBy(.15)`) | `index.html:56-57` |
| Increment (wheel) | `.1` per notch, **requires Ctrl/Cmd held** (`e.ctrlKey \|\| e.metaKey`, else the wheel event is ignored — no unmodified-scroll-zoom) | `renderer.js:105` |
| Zoom centring | **Cursor-anchored** for both button (`px,py` passed only from wheel handler; button calls omit them, defaulting to centre-preserving math with `px==null`... **actually**: `zBy(-.15)`/`zBy(.15)` from buttons pass no `px,py`, so the `if(px!=null)` branch is skipped and `tx,ty` are unchanged — zoom is anchored at canvas origin `(0,0)` for button clicks, and at the cursor for wheel/pinch | `renderer.js:92` |
| Pinch | Two-finger touch; `Math.min(3, Math.max(.15, s0 * (dist/dist0)))`, anchored at the pinch midpoint | `renderer.js:110,113` |
| Rubber-band (Ctrl/Shift+drag) | Computed to fit the dragged rect at `× 0.88` margin, clamped `[.15, 3]` | `sidebar.js:352-355` |
| Display | `#zoom-display` shows `Math.round(scale*100)+'%'`, updated inside `applyT()` | `renderer.js:91` |

### 9.3 A. V2 BEHAVIOR — pan

Background mousedown (not on `.mod-card`/`#fp`, and only when **not** in any tool mode: `if(editMode||wireMode||routeEditMode)return;`) arms panning; `mousemove` on `window` updates `tx = panOX + (clientX - panSX)`; released on `mouseup`. Single-finger touch pans identically when not `editMode`/`wireMode`. No pan boundary/clamping exists — `tx`/`ty` are unconstrained.

### 9.4 A. V2 BEHAVIOR — fit-to-content

`zReset()` (`renderer.js:93`): `s = Math.min(.9, viewportWidth/canvasWidth, (viewportHeight-20)/canvasHeight)`; `tx = Math.max(10, (vw - cw*s)/2)` (centred horizontally, minimum 10 px left margin); `ty = 14` (fixed 14 px top margin, never centred vertically). Called on boot (`bootstrap.js:_initDiagram`), on `F` key, on `Fit` button, and on every `window.resize`.

### 9.5 A. V2 BEHAVIOR — grid

Two `linear-gradient`s (`main.css:134`), `20px 20px` tile, colour `var(--canvas-grid)` (`rgba(0,0,0,.06)` dark / `.07` light). **The grid is always visible — there is no toggle.** It is baked into `#canvas`'s `background-image`, not a separate drawn layer.

### 9.6 A. V2 BEHAVIOR — viewport culling

**None.** `placeCards()` renders every module in `MODULES` unconditionally; `drawWires()` iterates and draws every wire in `WIRES` unconditionally, clearing and rebuilding the entire `#wire-layer` SVG on every call (`wsvg.innerHTML=''`). No culling, no virtualization, anywhere in the V2 source.

### 9.7 A. V2 BEHAVIOR — canvas background

`background-color: var(--canvas-bg)` (`#f5f2eb` dark-theme-name-but-actually-parchment / `#fbfaf6` light), `border: 1.5px solid var(--canvas-border)`, `border-radius: 4px`. The canvas is a visually distinct "paper" surface offset from the surrounding dark chrome — deliberate, not a bug (`--bg` for the page body is a different, similarly light-grey/warm tone in both themes: `#e8e4dc` dark, `#eef0f2` light — see §29.9, V2's "dark theme" is dark chrome around a light canvas in both themes).

### 9.8 A. V2 BEHAVIOR — transform behaviour

`applyT()`: sets `#scene.style.transform`, updates `#zoom-display`, calls `updateMinimap()`. Every zoom/pan mutation calls `applyT()` then (except pure pan) `drawWires()`. There is no separate reconciliation step — `tx`/`ty`/`scale` are the single source of truth, applied directly to the DOM transform every time they change.

### 9.9 B. OEP ENGINE BEHAVIOR

- Zoom: `ViewState.zoom`, mutated via `ViewStateService.setZoom`; range and increment are OEP-defined, not yet confirmed against these V2 values (`UNSPECIFIED BY V2` whether OEP's existing min/max match — audit does not state OEP's zoom bounds).
- Pan: `ViewState.pan`, `TransformationController`; **OEP's `InteractiveViewer` has `panEnabled: false`**, with pan implemented as a custom space-drag handler (audit §9.3) — not V2's unmodified background-drag pan.
- Fit: `ViewStateService.fitAll(scene.contentWidth, scene.contentHeight)` — Engine-computed content size, not a fixed 1600×1000.
- Grid: `ViewState.grid` with `visible`/`snapEnabled`, **toggleable** (`toggleGrid`) — V2 has no toggle at all.
- Culling: OEP culls nodes/wires/annotations against the visible rect with a 200-unit margin (audit §4.9/§9.4, benchmarked necessary at scale — 40,000 wires unculled ≈ 179 ms/paint).

### 9.10 C. RECONSTRUCTION REQUIREMENT

1. Zoom bounds `[0.15, 3]`, button increment `0.15`, Ctrl/Cmd+wheel increment `0.1` per notch — reproduced exactly, mapped onto `ViewStateService.setZoom`.
2. **Unmodified scroll must not zoom** — this is a real V2 behaviour (Ctrl/Cmd-gated), not an oversight, and must be preserved so plain scroll remains available for other purposes (or is simply inert, matching V2, where plain scroll on `#viewport` does nothing because no listener is attached to it).
3. Cursor-anchored zoom for wheel/pinch; button-click zoom anchored at canvas origin — reproduce this asymmetry exactly, it is what V2 source shows, not a design choice being made here.
4. Fit: `Math.min(0.9, vw/contentWidth, (vh-20)/contentHeight)`, centred horizontally with 10 px minimum margin, fixed 14 px top margin (not vertically centred) — reproduced against **Engine-computed** `contentWidth`/`contentHeight`, not a fixed canvas size (§4.8 ruling).
5. Pan: reproduce V2's unconstrained background-drag pan **as the tool-mode-gated Normal-mode gesture** — available only when no tool mode is active, exactly as §8.1 specifies. This must reconcile with OEP's existing `panEnabled:false` + space-drag implementation; that reconciliation is itself part of §29.3 (mode-model resolution) since pan availability depends on tool mode.
6. Grid: reproduce the 20×20 px tile and both theme colours. **OEP's grid toggle is a permitted, recorded deviation** — it is additive (grid can be turned off, which V2 cannot do), not a fidelity loss.
7. Rubber-band zoom (Ctrl/Shift+drag) is reproduced as documented in §9.2, gated to Normal mode.
8. Fit-on-window-resize is **not** reproduced (§4.8 ruling — conflicts with OEP's persisted `ViewState`); recorded in §29.9.
9. Viewport culling is **kept** from OEP (§9.6/§9.9) — it is a performance requirement with no V2 counterpart to conflict with, since V2's dataset is small enough that the absence of culling has never been tested at scale.
10. Canvas background/border styling reproduced from §9.7, understanding that OEP's canvas region sits inside the V2-style dark chrome exactly as V2's does.

---

## 10. Module Rendering

### 10.1 A. V2 BEHAVIOR — shared card shell

**Source:** `renderer.js:31-77` (`buildCard`, `buildStdCard`, `buildBulbCard`, `buildConnCard`), `main.css:136-155`

Every card is a `.mod-card` (`position:absolute`, `background:var(--card-bg)` — always white in both themes, `border:1.5px solid var(--card-border)` — always `#0d0d0d`, `border-radius:3px`, `box-shadow:var(--shadow-soft)`, `user-select:none`, `min-width:40px`, `z-index:10`). A 3 px-wide `.cat-stripe` (`position:absolute;left:0;top:0;bottom:0;border-radius:2px 0 0 2px`) coloured per §5.3 sits on the left edge for every card shape. Above the card, `.mod-label` (`position:absolute;top:0;transform:translate(-50%,-100%)`, i.e. floats **above** the card, centred) shows `${label}<br><span class="mod-sub">${sub}</span>`.

Three shape variants, selected by `buildCard(m)`: `m.bulb` → bulb card; `m.connector` → connector card; else → standard card.

### 10.2 A. V2 BEHAVIOR — standard card

`buildStdCard`: `padding-left:4px`. Inner flex column, `min-height:28px`. A `.t-strip` row of `.t-cell`s, one per terminal, each containing a `.t-lbl` (terminal name, `5.5px`, weight `800`, colour `#444`) above a `.t-dot` (7×7 circle, coloured by `h(terminal.color)`, `title="name: color"`). Strip placement depends on `m.exit`: `exit==='down'` → strip at bottom (`.bot`, `padding-bottom:3px;padding-top:6px`) with a flexible spacer above it; otherwise → strip at top (`.top`, `padding-top:3px;padding-bottom:6px`) with a spacer below.

### 10.3 A. V2 BEHAVIOR — bulb card

`buildBulbCard`: inline SVG glass bulb (circle `r=13`, fill `#fffde7`, stroke `#0d0d0d` 1.2px, class `.bgl`) with a filament path (stroke `#ca8a04`), plus a base rectangle (`#d4d4d4`), plus a terminal strip rendered as a small vertical flex list (not the standard `.t-strip`) with `4.5px` labels. Side (left/right) determined by `m.exit==='right'` → SVG left, terminals right; else terminals left, SVG right. `.bgl` glow state is driven externally by `updateBulbs()` (§10.7), **not** by the card builder itself.

### 10.4 A. V2 BEHAVIOR — connector card

`buildConnCard`: a horizontal pill body (`background:#e2e8f0;border:1.5px solid #475569;border-radius:3px`) with one "slot" per terminal. Each slot has an IN dot (colour = first half of `terminal.color.split('|')`), a small grey pin rectangle (`#94a3b8`), an OUT dot (colour = second half, or same as IN if absent), and a `4px` monospace pin-name label below. Slots are separated by a 1px vertical divider (`#475569`). Terminal ids for connector pins are suffixed `_IN`/`_OUT` (e.g. `d_modid::A_IN`).

### 10.5 A. V2 BEHAVIOR — dimensions

No card has a fixed width or height in CSS — **cards size to content** (`min-width:40px` is the only constraint). Terminal dot size is fixed (7×7 standard, 6×6 bulb, sized via inline styles for connector). This is a departure from a fixed-size-node model.

### 10.6 A. V2 BEHAVIOR — selection / hover / active / drag states

| State | Class | Visual |
|---|---|---|
| Wire-selected endpoint | `.mod-card.wire-selected` | `box-shadow: 0 0 0 2px var(--amber), 0 0 0 4px #fde68a, 0 0 0 6px var(--amber)` (triple ring) |
| Wire-mode source | `.mod-card.wire-src` | `box-shadow: 0 0 0 2px #0891b2, 0 0 0 5px rgba(8,145,178,.3)` |
| Search-flash | `.mod-card.sel-flash` | `box-shadow: 0 0 0 2px var(--purple), 0 0 0 5px rgba(124,58,237,.25)`, removed via `setTimeout` 1500 ms after add |
| Module-selected (info panel open) | `.mod-card.mod-selected` | `box-shadow: 0 0 0 2px var(--cyan), 0 0 0 4px rgba(34,211,238,.2), 0 0 12px rgba(34,211,238,.15)` |
| Dragging | `.mod-card.dragging` | `box-shadow:0 6px 20px rgba(0,0,0,.35); opacity:.92; z-index:100; cursor:grabbing` |
| Terminal hover | `.t-dot:hover` | `transform:scale(1.5)` |
| Terminal wire-mode-armed | `.t-dot.wf` | cyan ring + `scale(1.6)` |
| Terminal hover-while-connecting | `.t-dot.wh` | green ring + `scale(1.5)` (only while `wireMode && wireSrc`, or `leadPlaceMode`) |
| Terminal lead-placed | `.t-dot.lead-r`/`.lead-b` | red/black ring + `scale(1.4)`, `z-index:20`, `position:relative` |

These states are **not mutually exclusive at the CSS level** — multiple classes can stack (e.g. a card can be both `.wire-selected` and, if module info is separately open, `.mod-selected` is unreachable simultaneously since selecting a wire clears `selM` and vice versa, per §12).

### 10.7 A. V2 BEHAVIOR — fault / simulation state

`updateBulbs()` (`meter-panel.js:98-102`): every `.bgl` element gets `fill:#fef9c3; filter:drop-shadow(0 0 4px #fbbf24)` when `keyPos >= 1`, else `fill:#fffde7; filter:''`. **This is the only module-level simulation-state visual in V2** — there is no fault-marker, no per-module voltage indicator, no per-module error state on cards. (Fault/path visualization is wire-level — §11, §16.)

### 10.8 A. V2 BEHAVIOR — dragging

Reproduced in full detail in §13 (Module Interaction). Summary: 10 px grid snap, constrained to non-negative coordinates, only active in Layout Edit mode.

### 10.9 B. OEP ENGINE BEHAVIOR

OEP nodes render via the frozen `SymbolNodeWidget` (`oep_engine`), driven by `DiagramNodeVisual{nodeId, symbolId, position, width, height, selected, highlighted, displayName, category, ports, metadata}`, with symbol-asset-driven geometry (14 seed symbols) rather than three hard-coded card shapes. Category colour resolves via `categoryStripeColor(NodeCategory)`. Nodes have fixed size (`_nodeSize = 100`, resizable via `ResizeNodeCommand`) — the opposite of V2's content-sized cards.

### 10.10 C. RECONSTRUCTION REQUIREMENT

1. Three card shapes (standard/bulb/connector) are reproduced as **presentation variants of the same `DiagramNodeVisual`**, selected by a symbol/metadata flag equivalent to V2's `m.bulb`/`m.connector` — where that flag lives in the OEP symbol model is unresolved (§29.10).
2. Terminal strip, category stripe, floating label-above-card, and all state rings (§10.6) are reproduced pixel-for-pixel.
3. Card sizing: V2's content-sized cards vs. OEP's fixed/resizable nodes is a **real behavioural difference**, not just a visual one — it affects hit-testing, drag geometry, and layout. Logged in §29 as a new item (§29.11) since it was not in the audit's original conflict list.
4. Bulb glow (§10.7) reproduced, driven by the equivalent of `keyPos >= 1` — i.e., whatever OEP's active-operating-state-implies-power concept resolves to (depends on §7.7 resolution).
5. Drag mechanics deferred to §13.

---

## 11. Wire Rendering

### 11.1 A. V2 BEHAVIOR — structural model

**Source:** `renderer.js:171-287`

Every wire is one SVG `<g data-wid="...">` inside `#wire-layer`, **fully rebuilt on every `drawWires()` call** (no diffing). Children, in append order per wire:
1. Glow underlay (only if selected or traced)
2. Main coloured path
3. Bi-colour dashed stripe (only if the colour code has a `/`)
4. Route-edit segment handles (only if `routeEditMode && isSel`) **or** normal-mode wide transparent hit path (only if `normalMode`) — mutually exclusive per wire
5. Flow animation overlay (only if selected or traced, and the wire "has flow")
6. Selected-wire label chip (only if selected, and a horizontal run exists to anchor it)
7. Meter lead dots (only if selected and a lead is placed)

### 11.2 A. V2 BEHAVIOR — normal wire

`stroke` = `h(w.c)` (§5.4 resolution). `stroke-width`: `1.6` default, `2.2` if traced (not selected), `2.6` if selected. `fill:none; stroke-linecap:round; stroke-linejoin:round`. Class `.wp`. `pointer-events:none` on the visible path itself — hit-testing happens via a **separate** invisible path (below).

### 11.3 A. V2 BEHAVIOR — selected wire

`isSel = selW && selW.id === w.id`. Adds: glow underlay (`stroke:#f59e0b` i.e. `--amber`, `stroke-width:8`, `stroke-opacity:.4`, `pointer-events:none`, drawn *before* the main path so it sits behind); increases main-path width to `2.6`; label chip at the longest horizontal segment's midpoint (white background `rx:2`, `fill-opacity:.94`, border `#b45309` 0.9px, text `#7c2d12` `6.5px`, showing `w.lbl || w.c`, width `max(11, text.length*4.6+6)`, height `9`); meter lead dots if any lead is placed (see §17).

### 11.4 A. V2 BEHAVIOR — traced/dimmed wires

`isTr = tracedWires.size>0 && tracedWires.has(w.id)`. Traced glow uses `stroke:#10b981` (green) instead of amber, same `8px`/`.4` opacity treatment; main path width `2.2` (between normal and selected).

`isDim = (selW && !isSel && tracedWires.size===0) || (tracedWires.size>0 && !isTr)` → the **entire `<g>`**'s `style.opacity = isDim ? '0.1' : '1'`. This is the mechanism behind both "dim everything except the selected wire" and "dim everything except the traced circuit" — they share one dimming rule, mutually exclusive by construction (trace only exists when a wire is selected, per §22).

### 11.5 A. V2 BEHAVIOR — bi-colour stripe

If `trH(w.c)` (§5.4) returns non-null: a second path, same `d`, `stroke` = the stripe hex, `stroke-width` `1.4` selected / `.9` normal, `stroke-dasharray:'5 4'`, `pointer-events:none`.

### 11.6 A. V2 BEHAVIOR — hit path (normal mode only)

Only rendered when `normalMode = !editMode && !wireMode && !routeEditMode`. Invisible path (`stroke:transparent`, `stroke-width:10`), same geometry as the main path (using `rt.hit` — the path excluding the two end-stub points — falling back to the full path), class `.wire-hit`, `pointer-events:auto` (the **only** auto pointer-events child of the otherwise `pointer-events:none` `#wire-layer`). Click → `selWire(w, e)`. Right-click (`contextmenu`) → sets `ctxTarget = w`, shows Edit/Trace/Delete-Wire context menu items, also calls `selWire`, positions `#ctx` at cursor.

### 11.7 A. V2 BEHAVIOR — route-edit segment handles

Only rendered when `routeEditMode && isSel`. Documented fully in §15.

### 11.8 A. V2 BEHAVIOR — flow animation

**Source:** `renderer.js:290-359`

Gated by `wireHasFlow(w)`: `false` if `keyPos===0`; else reads the (possibly `SWPACK`-overridden) reading for `(w.id, keyPos)`; `false` if no reading; `false` if `parseFloat(reading.VDC)` is `0`/`NaN`; `false` if `reading.CONT === 'OPN'`. Direction: `wireFlowDir(w)` returns `-1` if the wire's `to` module has category `ground`, else `+1`.

Overlay path: same `d` as main path, `stroke` = `flowColor` (`#67e8f9` if wire colour is `Bl` or `G`, else `#ffffff` — chosen for contrast against the wire's own colour), `stroke-width` `1.8` selected / `1.2` traced-only, `stroke-dasharray:'12 8'`, `stroke-opacity:.72`, class `.flow-overlay`, `data-dir` = `+1`/`-1`, `pointer-events:none`. Also has `filter:drop-shadow(0 0 2px currentColor)` from `main.css:485-487` (note: `stroke` is set via attribute, not `currentColor` — this filter rule likely has no visible effect given the attribute-based stroke; **recorded as observed, not corrected**, per source-precedence rule).

Animation loop: `requestAnimationFrame` ticking `flowOffset += 1.2px` per frame, wrapping at `dash+gap=20`; every `.flow-overlay` element's `stroke-dashoffset` is set to `-flowOffset` (dir `+1`) or `+flowOffset` (dir `-1`). Loop starts (`startFlowAnim`) if any `.flow-overlay` exists after a `drawWires()` pass, stops (`cancelAnimationFrame`) otherwise — checked at the end of every `drawWires()` call, not driven by a separate watcher.

### 11.9 A. V2 BEHAVIOR — preview and invalid wires

Wire-creation preview: a single dashed line (`stroke:#0891b2`, `stroke-width:1.5`, `stroke-dasharray:'6 3'`, `stroke-linecap:round`, `pointer-events:none`) from the armed source terminal to the live cursor position (`mcX,mcY`), drawn only while `wireMode && wireSrc && mcX` is truthy. **There is no "invalid destination" visual state for wire creation** — V2's only validation is duplicate-detection, applied *after* the second click (toast + reject), not live feedback during the drag/preview. There is no equivalent of OEP's `connectionPreviewValid` colour change.

### 11.10 B. OEP ENGINE BEHAVIOR

Wires render via the frozen `WirePainter` (`oep_engine`) from `DiagramWireVisual{relationshipId, points, selected, highlighted}` — flat polylines, single stroke, no glow/stripe/flow/label/dim, matching audit §6.2's finding exactly. Connection preview has a live valid/invalid colour distinction (`connectionPreviewValid`), which V2 does not have.

### 11.11 C. RECONSTRUCTION REQUIREMENT

1. Reproduce the per-wire layering order (§11.1) and every value in §11.2–11.9 exactly, sourced from `DiagramWireVisual` plus whatever colour-code field resolution §29.10 settles.
2. The dim rule (§11.4) is a **single shared mechanism** (opacity 0.1 on the whole group) driving both selection-dim and trace-dim — implement it as one rule, not two, to match V2's actual construction.
3. Flow animation (§11.8) requires: (a) a "has flow" predicate equivalent to `wireHasFlow`, sourced from OEP's `MeasurementResult`/`SimulationSession` rather than authored `measurements.json` + `SWPACK` overrides (data-model dependency, §29.8/§8.5 of the audit); (b) a ground-direction rule (`wireFlowDir`) that reads `NodeCategory.ground` on the target node — this one is directly reproducible against the existing OEP model with no conflict.
4. Hit-path availability is **mode-gated** exactly as in §11.6 — this is a direct consequence of §8's tool-mode requirement, not a separate decision.
5. **Keep** OEP's live valid/invalid connection-preview colouring as a recorded, additive deviation (§29.9) — V2's absence of this feedback is a limitation, not a deliberate design the reconstruction must remove.
6. Route-edit segment handles: see §15.

---

## 12. Selection

### 12.1 A. V2 BEHAVIOR — node (module) selection

**Source:** `ui/inspector.js:59-70`, `js/app.js` click handler in `bootstrap.js:_initEditor`

`selMod(mid, evt)`: if a wire is currently selected, clear it first (`selW=null; closePanel(); leadR=null; leadB=null; clearLeadDots(); tracedWires.clear();`) — **module and wire selection are mutually exclusive, never simultaneous.** Toggle: clicking the already-selected module deselects it (`same = selM === mid; selM = same ? null : mid`). On select: adds `.mod-selected` to the card, calls `showModInfo` (renders into sidebar + optionally the popped-out `#mip`). On deselect: `closeModInfo()`.

Card click only selects when `!editMode && !wireMode && !routeEditMode` (`module-editor.js:56-61`) — no selection changes are possible while any tool mode is active.

Background click (`bootstrap.js:_initEditor`) — only when not over a card/`#fp`/`#mip`/`.wire-hit`, and not in `wireMode`/`routeEditMode` — deselects whichever of `selW`/`selM` is active.

### 12.2 A. V2 BEHAVIOR — wire selection

**Source:** `editor/selection-manager.js`

`selWire(w, evt)`: no-op if `editMode || wireMode` (module info is still selectable in these... actually note: only wire selection is guarded here, not module selection — asymmetric). Toggle-off on re-click (`same = selW && selW.id===w.id; selW = same?null:w`). On select: clears `.wire-selected` from all cards, adds it to **both** endpoint cards (`fc`/`tc` looked up by `w.from.m`/`w.to.m`), calls `autoPlaceLeads(selW)` (§17), calls `showPanel(w, evt)`. On deselect: `closePanel()`, clears leads, clears `tracedWires`, `stopFlowAnim()`.

### 12.3 A. V2 BEHAVIOR — multi-selection

**None.** There is no multi-select mechanism anywhere in V2 source — no Shift-click accumulation, no Ctrl-click toggle-additive, no box-select/marquee for modules or wires. Selection is always zero-or-one module XOR zero-or-one wire.

### 12.4 A. V2 BEHAVIOR — modifier keys

The only modifier-key selection behaviour in V2 is: `Shift+drag` or `Ctrl+drag` on empty canvas → rubber-band **zoom** (§9.2), not selection. `Shift+click` on a terminal while a wire is selected places the black lead instead of red (`wire-editor.js:31`) — a meter interaction, not a selection modifier.

### 12.5 A. V2 BEHAVIOR — deselection / click-empty behaviour

Documented in §12.1 (background click) and §8.2 (Escape cascade, see §24).

### 12.6 A. V2 BEHAVIOR — endpoint highlighting

Covered in §10.6/§12.2 — selecting a wire highlights both its endpoint module cards with `.wire-selected` (triple amber ring).

### 12.7 A. V2 BEHAVIOR — dimming

Covered fully in §11.4. Selecting a wire dims every *other* wire to opacity `.1`; it does **not** dim modules.

### 12.8 A. V2 BEHAVIOR — selection flash

`.sel-flash` (`main.css:140`): purple triple-ring, applied to a card by `scrollToMod(id)` (search result navigation, §18) and removed via `setTimeout(1500)`. This is the **only** transient/flash feedback in V2 — it exists for search results, not for selection itself.

### 12.9 A. V2 BEHAVIOR — hover feedback

Cards: none beyond the browser default. Terminal dots: `scale(1.5)` on hover (§10.6); additionally `.wh` (green ring, `scale(1.5)`) while hovering a terminal during an active wire-mode connection or lead-placement (`setupTermClicks` mouseenter, `wire-editor.js:38`). Wires: none — the invisible hit-path has no hover style at all.

### 12.10 B. OEP ENGINE BEHAVIOR — explicit V2/OEP difference

OEP's `SelectionService`/`GraphSelection` is a genuine multi-select model: `selectMany`, additive selection (Shift), toggle selection (Ctrl), box-select (drag-rect over background), `selectAll`. Node and relationship selection are **not** mutually exclusive at the model level (`GraphSelection` carries `nodeIds`, `relationshipIds`, `groupIds`, `annotationIds` concurrently), though the current `_ImmersiveInspectorPane` only renders detail when exactly one kind is selected with count 1 (audit §6.4).

### 12.11 C. RECONSTRUCTION REQUIREMENT — explicitly additive, not conflicting

This is audit §29.2 (§29.2 below) restated with V2's actual mechanics now on record:

1. **Keep OEP's multi-select model.** V2's single-select-only behaviour is a limitation of a hand-rolled DOM app with no selection service, not a deliberate constraint worth reproducing at the cost of a real OEP capability (per audit's "do not remove a capability to achieve V2 fidelity" rule, §15 item 8).
2. **Adopt V2's single-select *feedback vocabulary* as the presentation for the single-selection case**, since that is what the reconstruction must visually match: endpoint highlighting (§12.6), whole-canvas dimming-except-selected (§12.7), and the flash effect (§12.8) all apply cleanly when exactly one wire or one node is selected. Multi-selection is an OEP-only state with no V2 visual precedent — `UNSPECIFIED BY V2` for how it should look; the reconstruction must define a multi-select visual language without inventing V2 behaviour that doesn't exist (a plain "highlight every selected item" treatment, consistent with existing OEP `GraphViewPanel` selection rendering, is the safe default — but this is a presentation decision the Controller boundary does not gate, so it may be made without further escalation).
3. Toggle-off-on-reclick (§12.1/§12.2) is reproduced for the single-selection case.
4. Node/wire mutual exclusivity (§12.1) is **not** reproduced as a hard rule — OEP's model permits concurrent node+relationship selection and nothing in the audit calls for removing that. V2's exclusivity was a consequence of having one `selW`/one `selM` variable, not a design requirement.
5. Card-click-is-no-op-during-tool-modes (§12.1) and wire-click-guarded-in-edit/wire-mode (§12.2) are reproduced, gated on the resolved tool-mode axis (§8.4/§29.3).
6. Hover feedback (§12.9) reproduced exactly, including the mode-conditional `.wh` state.

---

## 13. Module Interaction

### 13.1 A. V2 BEHAVIOR — click

Single click, no drag: routes to `selMod` (§12.1), **only outside any tool mode**. Inside Layout Edit, a click-without-drag on a card is inert (mousedown starts a potential drag; if the pointer never moves, no position change occurs, and the click handler itself early-returns when `editMode` is true — so there is no click-to-select while in Layout Edit).

### 13.2 A. V2 BEHAVIOR — double click

**None.** No `dblclick` listener exists anywhere in the V2 module/card source. `UNSPECIFIED BY V2`.

### 13.3 A. V2 BEHAVIOR — drag (Layout Edit only)

**Source:** `module-editor.js:15-41`

Drag is only armed on `mousedown` when `editMode` is true, and only if the pointer-down target is not a `.t-dot`. On mousedown: captures the card's current canvas-space top-left (`ox,oy`, derived from `getBoundingClientRect()` relative to `#scene`, divided by `scale` — again DOM-measurement-derived, not read from a stored position field directly at drag-start, though `positions[modId]` is the thing being written), captures the pointer's screen position (`sx,sy`), adds `.dragging` class, sets `z-index:200`.

**Drag threshold: none.** The card becomes `.dragging` and is repositionable from the very first `mousemove`, with no minimum-distance gate.

On `mousemove` (attached to `window`, so it continues even if the pointer leaves the card): new position `nx = round(max(0, ox + (clientX-sx)/scale) / 10) * 10`, same for `ny` — **10 px grid snap, clamped to non-negative**. `card.style.left/top` set directly; `positions[modId]` updated; `drawWires()` called on **every** mousemove (wires re-route live during drag, no separate "preview" vs "commit" distinction — the position array is mutated immediately).

On `mouseup` (also window-level): removes `.dragging`, resets `z-index`, final `drawWires()`.

**There is no cancel gesture.** No `Esc`-during-drag handling exists; releasing anywhere commits the position.

### 13.4 A. V2 BEHAVIOR — snapping

Grid snap only, fixed `10px`, applied unconditionally during Layout Edit drag (§13.3). **No alignment-guide/smart-guide snapping of any kind exists in V2** — no edge/centre alignment to sibling cards.

### 13.5 A. V2 BEHAVIOR — selection while dragging

Not applicable — dragging only occurs in Layout Edit mode, where module selection (`selMod`) cannot be triggered at all (§12.1). The dragged card does not become "selected" in the `selM` sense; it merely visually indicates drag state via `.dragging`.

### 13.6 A. V2 BEHAVIOR — drop behaviour

No special drop zones, no snap-to-other-module, no collision detection. The card simply stops wherever `mouseup` occurs, grid-snapped.

### 13.7 B. OEP ENGINE BEHAVIOR

OEP node dragging (audit §4.9, §9.1): available in **any** document mode (not gated to a "layout edit" tool mode — the closest OEP analogue is document mode `edit`, which additionally permits construction commands), multi-node (whole current selection moves as a rigid group if the dragged node is part of a multi-selection), driven by `MoveNodesCommand` emitted **once at gesture end** (not per-frame), with real alignment-guide computation (`AlignmentGuideComputer`) applied to the group's combined bounding box before grid snap.

### 13.8 C. RECONSTRUCTION REQUIREMENT

1. **Preserve OEP's atomic-command-at-gesture-end model** (audit §9.3 item 2) — this is Engine-level undo/redo correctness, not negotiable against V2's "mutate position on every mousemove" approach. V2's live mutation during drag is a presentation-layer live-preview concern only; the underlying command still fires once, matching OEP's existing `_effectiveLayout()` preview-without-mutation pattern (audit §9.4/hazard table).
2. **Preserve OEP's alignment guides** — an OEP capability with no V2 counterpart; do not remove it to match V2's "grid-snap only" behaviour (audit §15 item 8).
3. Grid snap value: V2 uses `10px`; confirm against OEP's existing `GridComputer`/`ViewState.grid` configured value — if they differ, this is `UNSPECIFIED BY V2 which is correct`; do not silently override OEP's grid setting to force `10px`.
4. **Gate drag availability to the resolved tool-mode axis** — whether OEP keeps "drag available in any mode" (its current behaviour) or narrows it to a V2-style Layout tool mode is the direct, practical consequence of resolving §8.4/§29.3, and must not be decided in this section ahead of that resolution.
5. No drag threshold, no cancel gesture, no drop-zone logic — none of these exist in V2 to reproduce; where OEP already has different behaviour (e.g., any drag threshold Flutter's gesture recognizer imposes), that is a platform characteristic, not a fidelity gap, and needs no reconciliation.
6. Double-click: `UNSPECIFIED BY V2` — no requirement to add or avoid one.

---

## 14. Wire Creation

Full mechanics already documented in §8.2 (Wire mode). This section is the focused restatement required by the task's own structure.

### 14.1 A. V2 BEHAVIOR — source port

First terminal-dot click while `wireMode` is true and no `wireSrc` is armed. Visual: `.t-dot.wf` (cyan ring, `scale(1.6)`) on the dot, `.mod-card.wire-src` (cyan ring) on its owning card. Status bar: `FROM: <module id, hyphens→spaces> · <terminal name> → click destination`.

### 14.2 A. V2 BEHAVIOR — destination port

Second terminal-dot click on a **different** terminal. No live validity feedback is computed before this click (§11.9) — validity is checked only at click time, and the only check is duplicate-detection (§14.4). Any second terminal on any other module is accepted; there is no port-type/category compatibility rule anywhere in V2 source.

### 14.3 A. V2 BEHAVIOR — preview

Dashed cyan line from source terminal to live cursor, described fully in §11.9. No colour change to indicate validity — the preview line is always the same colour regardless of what is currently under the cursor.

### 14.4 A. V2 BEHAVIOR — valid / invalid destination

"Valid" = any terminal that is not the same terminal already armed as source. "Invalid" is only one case: **duplicate wire** — an existing wire connecting the exact same two `(module,terminal)` pairs in either direction. On duplicate: `showToast('Wire already exists', 'warn')`, clears the armed source, resets status to prompt. **There is no other invalid-destination case** — same-module-different-terminal is accepted (a module can wire to itself between two of its own terminals), and there is no "cannot connect incompatible types" rule.

### 14.5 A. V2 BEHAVIOR — cancellation

Clicking the **same** terminal again while armed cancels the pending connection only (returns to "click a source terminal" with wire mode still active). `Esc` or the `#wep-cancel` button exits wire mode entirely (`cancelWireMode()`), also clearing any armed source.

### 14.6 A. V2 BEHAVIOR — connection behaviour on success

New wire object: `{id: 'wire-' + Date.now(), c: 'W', lbl: 'New Wire', from: {m,t}, to: {m,t}, desc: 'User-created wire', R: [4 entries] }`, each `R[i]` = `{VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note: <'Key off'|'Key on'|'Cranking'|'Running'>[i]}`. Pushed to `WIRES`. Armed state cleared, status reset to prompt (wire mode **remains active** — the user can immediately start another wire). `selW` set to the new wire. `drawWires()`. Toast: `Wire created — edit properties`. **300 ms later**, `editWireProps()` is called automatically, opening the wire properties modal pre-populated with the default colour/label/readings for editing.

### 14.7 A. V2 BEHAVIOR — visual feedback summary

| Event | Feedback |
|---|---|
| Source armed | `.wf` dot, `.wire-src` card, status text update |
| Mouse moves with source armed | dashed preview line follows cursor |
| Duplicate destination clicked | warning toast, state reset |
| Same terminal re-clicked | silent cancel of pending connection, status reset |
| Successful connection | success toast, new wire auto-selected, wire-properties modal opens after 300 ms |
| `Esc` / Cancel button | wire mode exits entirely |

### 14.8 A. V2 BEHAVIOR — command/persistence implications

No undo exists for wire creation (§25/§27 — `UndoRedoStack` class is defined in `editor/undo-redo.js` but is **never instantiated or called from anywhere else in the source** — confirmed by grep; it is dead code). A created wire is immediately part of `WIRES` in memory; it is only persisted if the user subsequently calls Save (`saveLayout()`, §23/§4.2), which writes any wire whose `id` starts with `wire-` (i.e., every user-created wire, matching the `Date.now()`-based id prefix) into the saved JSON as `userConns`.

### 14.9 B. OEP ENGINE BEHAVIOR

OEP has two creation paths — drag port→port and two-click Wire mode (audit §2.3 items 21–22) — both gated by `ConnectionValidator.canConnect(graph, sourceNodeId, targetNodeId)` (a real compatibility check, category/port-aware, unlike V2's duplicate-only check) before issuing `CreateRelationshipCommand`, which participates in the undo stack.

### 14.10 C. RECONSTRUCTION REQUIREMENT

1. Reproduce the two-click state machine exactly (§14.1–14.5): arm → complete/cancel/same-terminal-cancel, with the exact status-bar text.
2. **Keep `ConnectionValidator.canConnect`** as the real validity gate (audit non-negotiable — engineering logic, §9.1). V2's duplicate-only check is strictly weaker; OEP's check is a superset that also catches duplicates if the Engine implements that, and must not be weakened to match V2.
3. **Do not reproduce "no invalid-destination visual feedback."** OEP already computes live connection validity (`connectionPreviewValid`) — this is a strict improvement over V2 with no fidelity cost, and audit §5.3 already classifies `ProbeOverlay`'s analogous "add feedback V2 lacks" pattern as the correct direction. Recorded as a deliberate, permitted deviation (§29.9).
4. Auto-open wire-properties-after-creation (300 ms delay) is reproduced **if and only if** OEP has an equivalent "wire override properties" editing surface reachable the same way (`inspector/wire_override_properties.dart` is display-only per audit §4.8 — display-only editors cannot fulfil this requirement as-is). This is a gap: `UNSPECIFIED BY V2 which OEP surface, if any, is the intended target` — flagged for the Controller design phase, not resolved here.
5. Default new-relationship colour/label ("W", "New Wire") and the four-key-position default reading table have no confirmed OEP equivalent field to populate — depends on §29.10 (wire colour code storage) and §8.5/§8.6 of the audit (measurement/terminal model mapping).
6. Wire mode remaining active after a successful connection (allowing immediate chaining) is reproduced.
7. No undo for wire creation in V2 is **not** reproduced — OEP's undo stack already covers `CreateRelationshipCommand` and removing that would be a capability regression (audit §15 item 8).

---

## 15. Wire Route Editing

**This section documents V2's model independently, with no attempt to reconcile it with OEP's. The conflict is resolved (or not) in §29.1.**

### 15.1 A. V2 BEHAVIOR — segment identity

**Source:** `renderer.js:132-139` (`getMovableSegs`), `utils/geometry.js:44-52` (duplicate/canonical implementation, unused by the shipped path — `renderer.js`'s inline copy is what actually runs)

A wire's rendered path (`rt.pts`, produced by `route(w)`, §16) is an ordered list of `{x,y}` points. `getMovableSegs(pts)` returns every **interior** segment — `for i in [1, pts.length-3]`, pairing `pts[i]`/`pts[i+1]` — i.e. it **excludes the first segment (source stub) and the last segment (destination stub)**. Each returned segment has `{i1, i2, axis}` where `axis` is `'y'` if the segment is horizontal (`|p.y - q.y| < 1`), else `'x'`. Segment identity for override storage is **positional index into this filtered list**, not a stable id — if the underlying route's point count changes (e.g. because the wire's own auto-route recomputes differently after a module move), a previously-recorded segment index can silently apply to a different segment.

### 15.2 A. V2 BEHAVIOR — selecting a segment

Only rendered/interactive when `routeEditMode && isSel` for the currently selected wire (§11.7). Each movable segment gets: a wide invisible hit line (`stroke:transparent, stroke-width:18, pointer-events:auto, cursor: 'ns-resize' if axis==='y' else 'ew-resize'`), a visible highlight line (`stroke:'#22d3ee' if active else 'rgba(34,211,238,.35)', stroke-width: 3 if active else 2`), and a midpoint handle dot (`r: 5 if active else 3.5, fill:'#22d3ee' if active else 'rgba(34,211,238,.7)', stroke:'#0e7490'`).

Click on the hit line: `e.stopPropagation()`, sets `selSeg = {wid: w.id, segIdx: i, axis}`, re-renders (`drawWires()`), updates status text: `Seg ${i+1} selected (${axis==='y' ? 'horiz → ↑↓' : 'vert → ←→'}) · arrows nudge · R reset`.

**Note the axis→arrow-key mapping is inverted relative to naive intuition**: a *horizontal* segment (`axis==='y'`, meaning its two endpoints share a y-coordinate... wait — re-reading: `axis = |p.y-q.y|<1 ? 'y' : 'x'`. If the endpoints have nearly-equal y, the segment runs horizontally, and is labelled axis `'y'`.** This means axis label names the coordinate that's *changing along the perpendicular* — i.e. `axis:'y'` = "this segment moves in Y" (a horizontal run is nudged vertically), `axis:'x'` = "this segment moves in X" (a vertical run is nudged horizontally). The status text confirms this: `axis==='y'` → `'horiz → ↑↓'`.**

### 15.3 A. V2 BEHAVIOR — horizontal/vertical segment nudge

**Source:** `app.js:141-158`

Only active when `routeEditMode && selSeg` and the keydown target is not an input/textarea/select. Arrow keys map to nudge direction **only for the matching axis**:
- `axis==='y'` (horizontal segment): `ArrowUp` → `delta = -step`; `ArrowDown` → `delta = +step`. Left/Right ignored for this segment.
- `axis==='x'` (vertical segment): `ArrowLeft` → `delta = -step`; `ArrowRight` → `delta = +step`. Up/Down ignored.

`step = shiftKey ? NUDGE*4 : NUDGE`, where `NUDGE = 6` (`app.js:46`) — so **6 px default nudge, 24 px with Shift**.

### 15.4 A. V2 BEHAVIOR — storage: relative offset, not absolute position

`wireRoutes[selSeg.wid]` is a plain object keyed by segment index: `wireRoutes[wireId][segIdx] = accumulatedOffset` (a single signed number per segment, **not** a pair — since each segment only ever moves along its own perpendicular axis). On each nudge: `cur = wireRoutes[wid][segIdx] || 0; wireRoutes[wid][segIdx] = cur + delta` (accumulates). This is applied in `route(w)` (§16.4) by re-computing the wire's fresh auto-route **every single `drawWires()` call**, then adding each override offset to its corresponding movable segment's two endpoints.

**This is the crux of the model**: the override is a *delta applied on top of a freshly recomputed route*, not a replacement route. If the module moves (changing the fresh auto-route's geometry), the override offsets still apply to whatever segment now occupies that index — the route "follows" endpoint movement while preserving the user's manual adjustment as a relative nudge.

### 15.5 A. V2 BEHAVIOR — reset

`R` key (only when `routeEditMode && selSeg` — checked *before* the general single-key shortcuts in the keydown handler, so `R` does not reach any other binding while a segment is selected) or the inspector's Route action → `resetWireRoute()`: `delete wireRoutes[selW.id]` (removes **the entire override map for the wire**, not just the selected segment), `selSeg = null`, `drawWires()`, toast `Route reset`.

### 15.6 A. V2 BEHAVIOR — route regeneration trigger

Every `drawWires()` call recomputes every wire's route from scratch via `route(w)` — there is no cached/stored absolute route anywhere except the relative `wireRoutes` offsets. `drawWires()` is called after essentially every state change (drag, zoom, pan-end via `applyT`... actually pan does not call `drawWires`, only zoom does; drag calls it on every mousemove) — meaning the override reapplication is continuous and cheap enough to run unthrottled in V2's dataset size.

### 15.7 A. V2 BEHAVIOR — relationship to node movement

Because routes are recomputed fresh every draw and overrides are relative, moving either endpoint module **preserves the manual route adjustment** in relative terms — the route still detours by the same offset, now anchored to the new base geometry. There is no mechanism to detect "this override no longer makes sense" (e.g., if the module moved far enough that the offset now produces a nonsensical path) — V2 applies the stored offset unconditionally.

### 15.8 A. V2 BEHAVIOR — UI mode entry/exit lifecycle

Fully documented in §8.1–8.2. Restated here for completeness: precondition (single wire selected), mutual exclusion with Layout/Wire modes, `#wep` status bar, `.route-edit-mode` cursor class, exit via toggle button or `Esc`.

### 15.9 B. OEP ENGINE BEHAVIOR — for contrast only, not reconciliation

`SetWireRouteCommand(relationshipId, List<Point2D>?)` stores an **absolute, complete point list** replacing the routing provider's output entirely. `null` restores automatic routing. Editing is drag-based (corner drag via `WireEditing.dragCorner`, segment drag via `WireEditing.dragSegment`), not keyboard-nudge-based, though `_handleWireVertexTap` provides a discrete vertex-select analogous to `selSeg`. Once set, the absolute route does **not** re-derive from a fresh auto-route on subsequent draws — it is frozen until explicitly reset (`SetWireRouteCommand(id, null)`) or re-edited.

### 15.10 C. RECONSTRUCTION REQUIREMENT — do not resolve here

Per the task instruction, this section documents V2's model without attempting to make it match OEP. The two models are **semantically different features**:

- V2: continuous relative-offset-on-fresh-recompute, keyed by positional segment index, keyboard-nudge-driven, single-axis-per-segment, whole-route reset only.
- OEP: absolute point-list replacement, keyed by nothing (whole list), drag-driven with a discrete vertex-tap selection, per-vertex/per-segment editing, whole-route reset available via the same `null` mechanism V2 uses (`SetWireRouteCommand(id, null)` ≈ `delete wireRoutes[id]` — this one operation *is* directly equivalent).

The audit already flagged this as unresolved (audit §8.2). This specification adds the following facts the audit did not have, which the eventual resolution owner needs:

1. V2's "follows endpoint movement" behaviour (§15.7) is a *feature*, not an incidental side effect of the implementation — it is exactly the reason wires stay sensibly routed after a module drag without requiring the user to re-adjust every route override each time. OEP's absolute-freeze model does not have this property today.
2. V2's segment-index-as-identity (§15.1) is fragile by V2's own construction (index can point to the wrong segment after topology changes) — this is a known limitation of the reference, not a strength to preserve if OEP designs a relative-offset mechanism from scratch.
3. Keyboard nudge granularity (6 px / 24 px with Shift) is a concrete number the resolution should either adopt or explicitly reject, not leave implicit.
4. The reset operation is the one part of this system that maps cleanly today (`null` route == "no overrides") and needs no new Engine work regardless of how the rest resolves.

This item **blocks** nothing in Waves 1–3 of the audit's implementation order (controller extraction, composition root, chrome) since none of those touch route-edit rendering. It **must** be resolved before Wave 5 (V2 interaction system, which the audit explicitly assigns route-edit keyboard nudging to). See §29.1.

---

## 16. Routing

**Documenting V2 behaviour only, per task instruction — not redesigning OEP routing here.**

### 16.1 A. V2 BEHAVIOR — route generation entry point

**Source:** `renderer.js:140-165` (`route(w)`)

```
route(w):
  a = getPos(w.from.m, w.from.t)   // DOM-measured terminal centre, canvas space
  b = getPos(w.to.m, w.to.t)
  if !a or !b: return null          // terminal not found (module deleted, etc.)
  dA = exitDir(w.from.m)            // module's 'exit' property, default 'down'
  dB = exitDir(w.to.m)
  ea = exitPt(a, dA)                // stub endpoint, STUB=14px out from dA
  eb = exitPt(b, dB)
  sD = (dA === dB)                  // same exit direction?
  ... branch on dA/dB (see 16.2) ...
  c = cleanPts(pts)                 // collapse redundant collinear points
  apply wireRoutes[w.id] overrides (§15.4)
  compute label point (longest horizontal run midpoint)
  return {path, hit, lp, pts: c}
```

### 16.2 A. V2 BEHAVIOR — geometry branches

| Condition | Path shape |
|---|---|
| Either exit direction is `left`/`right` | `[a, ea, {lx,ea.y}, {lx,eb.y}, eb, b]` where `lx = allocX((ea.x+eb.x)/2)` — one shared vertical jog column |
| Same direction, both `down` | `[a, ea, {ea.x,ly}, {eb.x,ly}, eb, b]` where `ly = allocY(min(ea.y,eb.y)-8, null, min(ea.y,eb.y))` — jog *above* both stubs |
| Same direction, both `up` | Same shape, `ly = allocY(max(ea.y,eb.y)+8, max(ea.y,eb.y), null)` — jog *below* both stubs |
| Otherwise (mixed up/down) | `[a, ea, {gxA,ea.y}, {gxA,mY}, {gxB,mY}, {gxB,eb.y}, eb, b]` — two independent jog columns (`gxA=allocX(ea.x)`, `gxB=allocX(eb.x)`) meeting at a shared horizontal jog row `mY = allocY((ea.y+eb.y)/2)` |

`STUB = 14` (px, exit-stub length, `renderer.js:27`).

### 16.3 A. V2 BEHAVIOR — lane allocation

**Source:** `renderer.js:127-129`

```
usedY = Set(), usedX = Set()   // reset at the START of every drawWires() pass
LG = 6                          // lane grid unit

allocY(pref, lo, hi):
  for off in [0, 6, 12, ... 594] step LG:   // up to 100 rings, 600px search radius
    for s in [0, +1, -1]:
      y = round((pref + s*off)/LG)*LG
      if lo!=null and y<lo: continue
      if hi!=null and y>hi: continue
      if y not in usedY: usedY.add(y); return y
  return pref   // fallback: no free lane found within range, use unadjusted preference

allocX: identical, mirrored on X / usedX
```

This is a **first-fit search outward from a preferred value**, alternating +/- offsets, snapped to a 6 px grid, **reset globally once per `drawWires()` pass** and shared across *all* wires drawn in that pass (each `route(w)` call mutates the shared `usedX`/`usedY` sets) — this is how parallel wires avoid overlapping: the first wire drawn claims a lane, the next wire needing a nearby lane is pushed to the next free one.

### 16.4 A. V2 BEHAVIOR — override application

**Source:** `renderer.js:148-160`

After the base route is computed and cleaned (`cleanPts`), points are cloned (`c.map(p=>({x:p.x,y:p.y}))` — defensive copy so overrides never mutate shared references), then: `movable = getMovableSegs(c)` (§15.1); for each `(seg, i)` with a stored `overrides[i]`, add the offset to **both endpoints** of that segment along its own axis (`seg.axis==='y'` → adjust both points' `.y`; `'x'` → adjust `.x`).

### 16.5 A. V2 BEHAVIOR — collinear cleanup

`cleanPts(pts)` (`renderer.js:131`, duplicated in `utils/geometry.js:21-33` as `cleanPoints` — unused duplicate): walks the point list, dropping any interior point that is collinear with its neighbours on either axis (`|a.x-b.x|<.5 && |b.x-c.x|<.5` or same for y), keeping first and last unconditionally.

### 16.6 A. V2 BEHAVIOR — label point

Longest horizontal segment's midpoint across the *final* (override-applied) point list; falls back to the geometric midpoint of the whole path if no horizontal segment exists.

### 16.7 A. V2 BEHAVIOR — determinism and regeneration

Route generation is **fully deterministic given `(terminal positions, exit directions, draw order, lane-allocation state)`** — but lane-allocation state depends on *draw order* (`WIRES.forEach`, array order), meaning the same wire can receive a different lane if `WIRES`' order changes (e.g. after a new wire is appended). This is a real, source-confirmed non-stability property of V2's router, not a hypothetical edge case.

### 16.8 A. V2 BEHAVIOR — relationship to node movement / route overrides

Every draw recomputes from current terminal DOM positions — so dragging a module (§13.3, which calls `drawWires()` on every mousemove) continuously re-routes every wire touching it, live, at 60fps-permitting cost (V2's own dataset is small; audit §14 flags this class of unthrottled full-redraw as the likely performance ceiling at scale, benchmarked separately in OEP at 40,000 wires ≈ 179 ms/paint for the *far cheaper* flat-polyline painter alone).

### 16.9 B. OEP ENGINE BEHAVIOR — for contrast only

`OrthogonalRoutingProvider` with `RoutingContext` (lane + **trunk** allocation — V2 has no trunk-sharing concept, only independent per-wire lane search) and an obstacle-avoidance sweep that extends a jog further out past any node in its path (V2 has no obstacle avoidance at all — a V2 route can and does cross directly over an unrelated module). Per audit's own framing, OEP routing was "inspired by (not copied from)" V2's algorithm and is already a superset in capability.

### 16.10 C. RECONSTRUCTION REQUIREMENT — not decided here

Per task instruction, no redesign of OEP routing occurs in this document. For the record, relevant to the eventual §29.5 resolution:

1. V2's routing geometry (branch table §16.2, stub length 14 px, lane grid 6 px) is **presentation-adjacent but not purely visual** — it determines where wires visually run, which is exactly what "match V2's appearance" could be read to require. Whether visual fidelity extends this far, or stops at wire *styling* (colour, glow, dash, label — §11) while OEP's superior routing (obstacle avoidance, trunk sharing) is kept, is unresolved. See §29.5.
2. If OEP routing is kept (the audit's implied default, given "OEP routing is intentionally superior," audit §8.7), the visual difference from V2 (no obstacle-crossing, different jog placement) is a **known, accepted departure** and should be stated as such rather than silently discovered later.
3. V2's per-draw-pass lane reset (§16.3) has no OEP equivalent to compare against without inspecting `RoutingContext`'s own allocation lifecycle — not established by either source read for this document; flagged `UNSPECIFIED` pending that inspection, not treated as a conflict.

---

## 17. Multimeter / Instrument

### 17.1 A. V2 BEHAVIOR — physical visual design

**Source:** `index.html:119-233` (inline SVG, sidebar Meter tab), `main.css:599-607`

`viewBox="0 0 220 380"`, rendered at `220 × 380` px (`#meter-svg`, `max-width:100%`). Body: red rounded rect (`#c0281e`, `rx=14,ry=14`) with a diagonal metal-sheen gradient overlay at `opacity:.15`.

**Screen assembly:** bezel rect (`22,20,176,100`, fill `#111`, stroke `#333` 1.5px) containing the LCD (`28,26,164,88`, `rx:5`, fill `#1a2e1a`) with a `4%`-opacity scanline pattern overlay. Text elements inside: mode (`x:110,y:50`, centred, `9px`, letter-spacing `2`, fill `#2c9b2c`), value (`x:110,y:80`, centred, `30px`, weight `700`, fill dynamic — mirrors the HTML LCD's colour), unit (`x:182,y:80`, right-aligned, `12px`, fill `#22a022`), range (`x:110,y:100`, centred, `7px`, letter-spacing `3`, fill `#2c9b2c`, static text `AUTO RANGE`), note (`x:110,y:112`, centred, `6px`, fill `#2c6b2c`).

**Dial:** label text `FUNCTION` above a two-ring dial (`cx:110,cy:185`, outer `r:44` stroke `#8b1515` 3px fill `#1a0808`, inner `r:38` stroke `#444`), eight position labels around the ring at fixed coordinates (`VDC` amber/bold at top, `VAC`, `Ω`, `CONT`, `DIODE`, `TEMP`, `mA`, `10A` — **note: only 5 of these 8 have functioning mode buttons; TEMP/mA/10A are decorative dial labels only, not implemented modes**), a rotating pointer (`<g id="dial-pointer" transform="rotate(angle,110,185)">`, amber polygon), and a centre knob (two concentric circles).

**Mode buttons:** a row of 5 rects (`y:242-260`, each `30×18`, `rx:3`) labelled `DC V` / `AC V` / `CONT` / `Ω` / `DIODE`, active state `fill:#7c1515, stroke:#f59e0b`, inactive `fill:#1a0808, stroke:#555`, text colour `#fde68a` active / `#94a3b8` inactive.

**Jacks:** 4 circles at `y:310` — `10A` (`x:38`, decorative, fused, red), `mAμA` (`x:88`, decorative, fused, red), `COM` (`x:138`, black, actively used), `VΩHz°C` (`x:185`, red, actively used). Each jack is three concentric circles (outer ring, inner ring, coloured centre). Warning triangle glyph between COM and mA. `CAT III 600V` text at bottom.

**Leads (always shown, visual only):** red lead body+tip permanently drawn from the V jack outward (`x:185`), black lead permanently drawn from COM (`x:138`) — these are **static decoration**, not the actual measurement leads (those are drawn separately as SVG paths in `#wire-layer`, §17.6).

### 17.2 A. V2 BEHAVIOR — mode buttons and LCD

**Source:** `ui/meter-panel.js:14-24, 27-40, 76-90`

Five modes: `VDC` (label `DC VOLTAGE`, unit `V`), `VAC` (`AC VOLTAGE`, `V~`), `CONT` (`CONTINUITY`, no unit), `RES` (`RESISTANCE`, `Ω`), `DIODE` (`DIODE TEST`, `V`). Default mode: `VDC`.

`setMode(m)`: sets `meterMode`, syncs `.m-btn.active` (HTML sidebar buttons matched by trimmed text), **switches lead mode to `'ends'` unless already `'manual'`** (`if(selW && leadMode!=='manual') setLeadMode('ends',false)`), updates meter if a wire is selected, redraws wires (flow animation is mode-independent but this also refreshes), notifies Sidebar.

`updateMeter()`: no-op if no wire selected. Reads the (possibly SWPACK-overridden) reading for `(selW.id, keyPos)`. Special `CONT` display: value `'000'`/`'0.00'` → shown as `'· · ·'` in cyan (`#22d3ee`); value `'OPN'` → shown as `'OPN'` in red (`#ff6b6b`); other values shown as-is in `--lcd-fg`. Unit is blank for `CONT`. `#lcd-note` = the reading's `.note` field.

Dial pointer angle mapping (`sidebar.js:136`): `{VDC:0, VAC:35, RES:65, CONT:95, DIODE:125}` degrees, rotated around `(110,185)`.

### 17.3 A. V2 BEHAVIOR — lead placement modes

**Source:** `meter-panel.js:53-74, 129-165`

Four modes, default `ends`:

| Mode | Behaviour |
|---|---|
| `ends` | Auto: red = wire's `from` terminal, black = wire's `to` terminal |
| `gnd` | Auto: red = wire's `from` terminal, black = first module found with `category==='ground'` (or `null` if none exists) |
| `pwr` | Auto: red = first module with `category==='power'` having a `B+` terminal (falls back to its first terminal if no literal `B+`), black = wire's `to` terminal |
| `manual` | No auto-placement; user clicks any terminal to place the next lead |

Switching **into** `ends`/`gnd`/`pwr` (via `setLeadMode`) immediately re-runs auto-placement if a wire is selected (`if(mode!=='manual' && selW) autoPlaceLeads(selW)`). Switching mode also shows a toast with the mode's description text (`LM_DESC` table) unless suppressed (`doToast=false`, used internally e.g. by `setMode`'s implicit switch).

### 17.4 A. V2 BEHAVIOR — auto-placement trigger

`autoPlaceLeads(w)` is called from: wire selection (`selWire`, always, regardless of current lead mode — **wait, re-check**: `selWire` calls it unconditionally; but `autoPlaceLeads` itself early-returns `if(leadMode==='manual') return` after `clearLeadDots()` — so selecting a wire while in manual mode clears existing lead dots but places nothing new), key position change (`setKey`, only if a wire is selected), and mode change (`setLeadMode`, if not switching to manual and a wire is selected).

### 17.5 A. V2 BEHAVIOR — manual placement

`placeLead(color)` (triggered by the sidebar's `▸` buttons, `si-lead-place-r`/`si-lead-place-b`, or the popped-out panel's equivalents): switches to `manual` mode if not already, then arms `leadPlaceMode = color` (toggling off if the same colour is clicked again while already armed), adds `.lead-place-mode` to `#viewport` (cursor becomes `crosshair`), shows a toast naming which lead to place. The **next terminal click anywhere** (checked first in `setupTermClicks`, before the wire-mode/edit-mode/normal-mode branches) places that lead and clears the armed state — this works **independent of wire selection state**.

### 17.6 A. V2 BEHAVIOR — probe/lead visualization on canvas

**Source:** `sidebar.js:185-249`, `main.css:636-663`

Two mechanisms draw leads onto the diagram:
1. **On-terminal dot styling**: the placed terminal's `.t-dot` gets `.lead-r`/`.lead-b` class (red/black glow ring, scale 1.4).
2. **Meter-to-terminal SVG lines**: `Sidebar.drawLeadWires()` draws a cubic bezier path from the meter's jack element (`#jack-V` for red, `#jack-COM` for black — the **sidebar's inline SVG jack elements**, measured via `getBoundingClientRect()`) to the placed terminal dot, curving left-then-across (`control point at jack.x - 40`), classed `.lead-wire-r`/`.lead-wire-b` (`stroke-width:2.5, stroke-dasharray:'6 3', opacity:.85`, pulsing animation `leadPulse 2s` staggered `0.5s` between red/black), plus a small filled circle with a `+`/`−` glyph at the terminal end. **This spans from the sidebar's meter graphic across the whole layout to the terminal on the canvas** — a real cross-panel visual connection, redrawn on every relevant state change (`drawLeadWires` is called from `onWireSelected`, `onWireDeselected`, `onMeterChange`, `onLeadsChanged`).

### 17.7 A. V2 BEHAVIOR — measurement display / error states

`OL` equivalent handling exists only for `CONT` mode (`OPN` → red `OPN` text). No dedicated over-range/error display exists for `VDC`/`VAC`/`RES`/`DIODE` beyond whatever literal string the authored/overridden reading contains (e.g. `RES:'OL'` is just displayed as the literal text `OL` with no special styling — it is not a recognized sentinel in `updateMeter`'s logic, unlike `CONT`'s `OPN`).

### 17.8 A. V2 BEHAVIOR — simulation relationship

Readings are **not computed** by any live electrical solver in the shipped path — `updateMeter()` reads either `SWPACK.getReading(wireId,keyPos)` (§7.4, five hard-coded wire ids) or falls back to the wire's own authored `R[keyPos]` array (from `measurements.json`, four entries per wire matching the four key positions). The `simulation/*`/`simulator/*` solver modules exist in the source tree (voltage/continuity/resistance propagators, `electrical-solver.js`) but are **not wired into `updateMeter` or any UI path** — confirmed by grep: no call to any solver function occurs from `ui/meter-panel.js` or `ui/sidebar.js`. They are loaded (`index.html` script tags) but functionally dormant for the meter display.

### 17.9 B. OEP ENGINE BEHAVIOR

`MultimeterController` (audit §4.4): probe slots A/B, arm-then-click placement (no auto-placement-on-selection, no lead-mode concept), `latestResult: MeasurementResult` computed live against `SimulationEngine`/`VerificationReport`, `highlightedPathNodeIds` for continuity-mode path display. Presentation is `DigitalMultimeterPanel` — Material controls, no SVG instrument body (audit §6.5).

### 17.10 C. RECONSTRUCTION REQUIREMENT

1. Build the full SVG instrument (§17.1) as a Studio-owned widget — dimensions, dial, jacks, mode buttons, LCD, all exact values reproduced.
2. Five modes (§17.2), dial pointer angle table, `CONT`-special display (`· · ·` / `OPN`) reproduced, driven by `MultimeterController.latestResult` rather than authored/`SWPACK` readings (§17.8's dormant-solver finding means V2's *shipped* meter is presentation-only over static data — OEP's live-computed model is not a fidelity regression here, it is what V2's own solver modules were evidently intended to do and never were wired up to).
3. Four lead-placement modes (§17.3) are a **real behavioural gap** against OEP's arm-then-click-only model — `MultimeterController` needs either extension or a Controller-level wrapper implementing `ends`/`gnd`/`pwr` auto-placement logic (which reads `EngineeringNode.category`/`Port` data, analogous to V2's `category==='ground'`/`'power'` lookup) plus the existing `manual` mode OEP already has.
4. Auto-placement triggers (§17.4) — on wire selection and on key-state change — are new Controller responsibilities; reproduce the exact "manual mode clears but does not re-place" nuance.
5. Cross-panel lead-wire visualization (§17.6) is a **real, distinctive V2 behaviour with no OEP counterpart at all** (`ProbeOverlay`, audit §5.3, renders probe markers on-canvas but nothing connecting to the meter widget itself). This requires the meter widget and the canvas overlay to share live DOM/layout geometry (or its Flutter equivalent) across the sidebar/canvas boundary — a real implementation challenge flagged here, not resolved.
6. §17.7's asymmetric OL-only-for-CONT handling is reproduced exactly — do not invent a uniform OL-for-everything convention V2 doesn't have.

---

## 18. Search

### 18.1 A. V2 BEHAVIOR — activation / shortcut

`toggleSearch()`, bound to `/` and `?` keys (`app.js:163` — **note**: `?` is also bound to `toggleKbh()`, §6.2/§24 — both are literally the same physical key on a US keyboard when unshifted vs shifted, but the source checks `e.key === '/' || e.key === '?'` for search and a separate handler for the shortcuts panel; this is a real ambiguity, see §24.3) and the `⌕ Find` toolbar button.

### 18.2 A. V2 BEHAVIOR — overlay

`#srch`: fixed, `top:78px`, horizontally centred, `width:300px`, `background:var(--surf-0)`, `border:1.5px solid var(--border-2)`, `border-radius:5px`. Opening clears the input, clears results, and focuses the input (`$('srch-in').value=''; $('srch-res').innerHTML=''; $('srch-in').focus()`).

### 18.3 A. V2 BEHAVIOR — input / search behaviour

`<input id="srch-in" oninput="doSearch(this.value)" onkeydown="srchKey(event)">` — live search on every keystroke, no debounce. `doSearch(q)`: lowercases and trims; empty query → clear results, return. Searches two collections:
- Modules: matches if `label`, `sub`, or `id` (untransformed, case-**sensitive** for id since it's not lowercased before `.includes(q)`... actually `q` is already lowercased but `m.id` is not — so id matching is effectively case-sensitive against a lowercase query, meaning uppercase-containing ids won't match on their uppercase portion) contains the query.
- Wires: matches if `lbl`, `desc`, or `c` (colour code, lowercased for comparison) contains the query.

**Results capped at 14** (`results.slice(0,14)`).

### 18.4 A. V2 BEHAVIOR — results / navigation / selection

Each result row: `<span class="sr-type">` (`module`/`wire`) + label + sub-text. Click: closes search overlay; if module → `scrollToMod(id)`; if wire → `selW = wire; showPanel(wire, centredEventStub); drawWires()` (note: passes a fake event centred on the viewport, since there's no real click position to anchor a floating panel at).

### 18.5 A. V2 BEHAVIOR — centering / highlight / flash

`scrollToMod(id)`: reads `positions[id] || DEFAULT_POS[id]`; if found, sets `tx`/`ty` to centre that position in the viewport (**no zoom change** — centres at current scale), `applyT()`, then adds `.sel-flash` to the card and removes it after 1500 ms.

### 18.6 A. V2 BEHAVIOR — dismissal

`Escape` key (checked in the global keydown cascade — see §24) or re-toggling via `/`/`?`/button. **No "click outside to close" handler exists for `#srch`.**

### 18.7 A. V2 BEHAVIOR — no-results state

`results.length === 0` after a non-empty query → single row, `padding:8px 12px, font-size:8px, color:#444`, text `No results`.

### 18.8 B. OEP ENGINE BEHAVIOR

`DiagramSearchPanel` (docked column, audit §5.4) calls `engine.registry.search.search(graph, layout, query)` → `SearchResult{kind, id}` across five kinds (node, relationship, annotation, **symbol**, **layer** — two kinds V2 has no concept of at all, since V2 has neither a symbol library nor a layer system). `_goToSearchResult` centres **and reframes zoom** for multi-node results (symbol/layer kinds), unlike V2's centre-only.

### 18.9 C. RECONSTRUCTION REQUIREMENT

1. Convert from docked panel to floating overlay per audit §5.4's own instruction, now with exact V2 geometry (§18.2) and behaviour (live-search-on-keystroke, no debounce, 14-result cap, `/` shortcut).
2. **Keep OEP's symbol/layer result kinds** — real capabilities without V2 counterparts (audit §15 item 8); their navigation behaviour (multi-node select + frame) has no V2 precedent and is `UNSPECIFIED BY V2` for exact visual treatment — implement consistently with the single-result centre+flash behaviour this section establishes.
3. Reproduce `sel-flash` exactly (§10.6/§18.5) for the single-node/wire case.
4. Reproduce the no-results row text and styling.
5. The `/` vs `?` shortcut collision (§18.1) is inherited into §24's keyboard map as a documented ambiguity, not silently resolved here.

---

## 19. Legend

### 19.1 A. V2 BEHAVIOR — activation

`toggleLegend()`, bound to `L` key and the `☰ Legend` toolbar button. Building the content (`buildLegend()`) only happens **on open** (`if(legOpen) buildLegend()`), not on every category change — so a category added while the legend is closed will be reflected next time it's opened, not live.

### 19.2 A. V2 BEHAVIOR — contents

`Object.entries(CAT_CLR)` — **all 11 categories are always listed**, regardless of whether any module on the current diagram actually uses that category (unlike OEP's existing `_DiagramLegendPanel`, which lists only categories present, audit §6.4). Header text: `Categories` (`7px`, letter-spacing `.12em`, uppercase, `#555`). Each row: an 8×8 coloured dot (`.lg-dot`) + label (`.lg-lbl`, `8px`, `text-md`).

### 19.3 A. V2 BEHAVIOR — positioning / styling

`#legend`: `position:fixed, left:8px, bottom:10px, z-index:150, background:var(--surf-0), opacity:.97, border:1px solid var(--border-1), border-radius:4px, padding:7px 9px`.

### 19.4 A. V2 BEHAVIOR — dismissal

Re-toggle via `L` key or the toolbar button (toggle, not a close button — `#legend` has no visible close affordance in the DOM at all, only the CSS class toggle). No `Escape` handling for the legend specifically (not in the `Escape` cascade in §24/§8's closing sequence — confirmed absent from `app.js`'s keydown handler's Escape branch).

### 19.5 B. OEP ENGINE BEHAVIOR

`_DiagramLegendPanel` (audit §6.4): filters to categories actually present on the current graph, rendered inside a `DockablePanel` (dock-slot-hosted, not a bare floating overlay), toggled via `_showLegendPanel` + `PanelsToolbar`.

### 19.6 C. RECONSTRUCTION REQUIREMENT

1. Position/size/opacity exactly per §19.3.
2. **List all 11 categories unconditionally, matching V2** — `UNSPECIFIED BY V2 whether this is intentional or an oversight`, but it is what the shipped reference does, so it is what "match V2" requires by the letter of this task. OEP's current filtered-to-present-categories behaviour is the one being changed here, not preserved — flagged since it inverts the audit's own §6.4 characterization of `_DiagramLegendPanel` as already correct; record as a deliberate fidelity choice, not an oversight in this spec (§29.9).
3. `L` shortcut, no `Escape` handling, no close button — reproduced (absence of features is still a specification).
4. Colour source must be the same table cards render from (§5.3) — already an existing OEP rule (audit §6.4), unaffected by item 2 above.

---

## 20. Minimap

### 20.1 A. V2 BEHAVIOR — rendering

**Source:** `renderer.js:118-120`

`updateMinimap()`: a `<canvas>` (`#mm-c`) sized to the container's `offsetWidth`/`offsetHeight`, 2D-context-drawn (not DOM/SVG) fresh on every call — fills background `#1a1a1a`, then for each module, a filled rect at `(pos.x * scaleX, pos.y * scaleY)`, sized `max(3, cardWidth*scaleX) × max(2, cardHeight*scaleY)`, coloured by category (`CAT_CLR[m.cat] || '#555'`). **Wires are not drawn on the minimap at all** — only module rectangles.

### 20.2 A. V2 BEHAVIOR — dimensions / position

`#minimap`: `position:fixed, right:10px, bottom:10px, width:150px, height:90px, background:var(--surf-0), border:1px solid var(--border-1), border-radius:3px, overflow:hidden, cursor:pointer`. **Hidden by default** (`display:none`), shown via `initMinimap()` at bootstrap (`$('minimap').style.display='block'`) — i.e. it is always visible once the app finishes loading; there is no runtime toggle for it anywhere in V2 source (contrast with OEP's `_showMiniMap` toggle, which V2 has no equivalent of).

### 20.3 A. V2 BEHAVIOR — viewport indicator

`#mm-vp` (`position:absolute, border:1px solid var(--amber), border-radius:1px, pointer-events:none`), positioned/sized every `updateMinimap()` call: `vpX = (-tx/scale)*scaleX`, `vpY=(-ty/scale)*scaleY`, `vpW=(viewportWidth/scale)*scaleX`, `vpH=(viewportHeight/scale)*scaleY`, clamped `left/top >= 0` and `width/height <= minimap dimension`.

### 20.4 A. V2 BEHAVIOR — click behaviour

`minimapClick(e)`: converts the click's offset within the minimap to canvas coordinates (`cx = e.offsetX/mm.width * canvas.width`, same for y), then **centres the viewport on that canvas point at the current zoom level** (`tx = vp.width/2 - cx*scale`, same for ty), `applyT()`. **No zoom change on minimap click.**

### 20.5 A. V2 BEHAVIOR — drag behaviour

**None.** `minimapClick` only fires on the `onclick` DOM event — there is no mousedown/mousemove drag-to-pan behaviour on the minimap in V2 source.

### 20.6 B. OEP ENGINE BEHAVIOR

`DiagramMiniMap`/`_MiniMapPainter` (audit §5.3): draws both nodes and wires (a superset of V2's node-only rendering), wrapped in `IgnorePointer` at its current call site — **click is currently disabled**, contradicting V2's core minimap behaviour, per audit finding.

### 20.7 C. RECONSTRUCTION REQUIREMENT

1. Restore click-to-centre (removing `IgnorePointer`) — this is audit §5.3's own finding, now confirmed against V2 source: click centres at current zoom, no zoom change, no clamping beyond what's implied by the viewport-indicator math.
2. **Keep OEP's wire rendering on the minimap** as an additive, non-conflicting improvement over V2's node-only view (per the "no capability regression" rule) — `UNSPECIFIED BY V2 whether wires belong on the minimap`, since V2 simply never draws them; adding them is not contradicting a V2 decision, it is filling a gap V2 left empty.
3. Dimensions (`150×90`), position (`right:10, bottom:10`), always-visible-once-loaded default — reproduced. OEP's existing `_showMiniMap` toggle is a **permitted additive deviation** (§29.9) since V2 has no runtime toggle to conflict with (it's either "not yet loaded" or "shown," never "loaded but hidden by user choice").
4. No drag-to-pan on the minimap — do not add one; V2 does not have it, and inventing it would be inventing behaviour, which this task forbids.

---

## 21. Context Menu

### 21.1 A. V2 BEHAVIOR — activation

Two independent right-click (`contextmenu`) listeners, never unified:
- On a wire's hit path (normal mode only, §11.6): `e.preventDefault(); e.stopPropagation();`, sets `ctxTarget = w`, **shows** Edit and Trace items, sets Delete's text to `✕ Delete Wire`, also calls `selWire` (right-click selects too), positions menu at cursor, opens.
- On a module card (`module-editor.js:42-55`): `ctxTarget = {_mid: modId}`; if `editMode` — **hides both Edit and Trace**, showing only Delete (labelled `✕ Delete Module`); if not `editMode` — shows Edit (labelled `✎ Edit Module`), hides Trace, shows Delete (`✕ Delete Module`). Does **not** call `selMod`.

There is no right-click handler on empty canvas, on terminals, or on annotations (V2 has no annotation concept) — right-click on empty space does nothing (`preventDefault` is not called, so the browser's native context menu would appear, **not suppressed** — confirmed no `document`-level `contextmenu` prevention exists outside these two specific targets).

### 21.2 A. V2 BEHAVIOR — menu location

`#ctx` positioned via inline style at `e.clientX`/`e.clientY` (screen coordinates, not canvas-relative), then `.classList.add('open')`.

### 21.3 A. V2 BEHAVIOR — available actions / context-sensitivity

Three static DOM items always exist (`index.html:683-688`): `#ctx-edit` (`✎ Edit Wire Props`, default text — overwritten per-context), `#ctx-trace` (`◎ Trace Circuit`, never re-labelled), a separator, `#ctx-del` (`✕ Delete`, default text — overwritten). Visibility (`display:''`/`display:'none'`) and label text are mutated per-invocation rather than the menu being rebuilt — this is a **fixed 3-slot menu with conditional visibility**, not a dynamically-constructed item list.

| Context | Edit visible? | Trace visible? | Delete label |
|---|---|---|---|
| Wire (normal mode) | yes, `✎ Edit Wire Props` | yes | `✕ Delete Wire` |
| Module, not editMode | yes, `✎ Edit Module` | no | `✕ Delete Module` |
| Module, editMode | no | no | `✕ Delete Module` |

`ctxEdit()`: if `ctxTarget._mid` → `editModProps(mid)`; else → `selW = ctxTarget; editWireProps()`.
`ctxTrace()`: only acts if target is a wire (`!ctxTarget._mid`) → `selW = ctxTarget; traceCircuit()`.
`ctxDelete()`: if `_mid` → `delModule(mid)` (confirms via native `confirm()`); else → `selW = ctxTarget; deleteSelectedWire()` (also native `confirm()`).

### 21.4 A. V2 BEHAVIOR — keyboard behaviour

None specific to the context menu — it is not reachable or navigable by keyboard at all (no arrow-key item traversal, no Enter-to-activate, no dedicated open shortcut). `Escape`'s global cascade does not explicitly close it either (not in the `Escape` branch list, §8.2/§24) — it is closed only by clicking elsewhere.

### 21.5 A. V2 BEHAVIOR — dismissal

`document.addEventListener('click', e => { if (!e.target.closest('#ctx')) hideCtx(); })` (`app.js:137`) — any click outside the menu closes it and resets `ctxTarget`/labels to default. No `Escape` handling.

### 21.6 B. OEP ENGINE BEHAVIOR

`ContextualCommandResolver` + `EngineeringInteractionContextBuilder` produce a **capability-driven, dynamically-built** menu from a `CursorTarget` (node/relationship/port/annotation/none), respecting document mode — a materially richer model than V2's fixed 3-slot menu (audit §5.7). Port and annotation right-click currently lack hit-testing (audit's own documented gap).

### 21.7 C. RECONSTRUCTION REQUIREMENT

1. **Keep OEP's capability-driven resolver** — it is Engine-facing infrastructure (audit §9.1/§9.2), not chrome; V2's fixed 3-item menu is not a design to reproduce at the *architecture* level, only its **visual treatment** (§4.5 geometry: `min-width:160px`, item padding `7px 12px`, `9px` uppercase text, danger-red Delete styling) is a presentation requirement.
2. Right-click currently selects the target first in V2 for wires but **not** for modules (§21.1) — this asymmetry is `UNSPECIFIED BY V2 why`, and reproducing it literally would be reproducing an inconsistency; `UNSPECIFIED BY V2` whether OEP should adopt select-on-right-click at all, since OEP's contextual menu already builds `CursorTarget` independent of left-click selection by design (audit §4.9, contract-mandated). **Do not change OEP's existing independent-targeting behaviour to match this V2 quirk** — recorded as a non-adopted V2 behaviour, not silently dropped (§29.9).
3. No keyboard navigation, no `Escape` dismissal, click-outside-only dismissal — reproduce these absences; OEP's Material `showMenu` may have different default dismissal behaviour (e.g. it likely already handles `Escape`), which is a **platform characteristic**, not a fidelity target to suppress.
4. Empty-canvas right-click: OEP already resolves a "canvas" `CursorTarget` (audit §2.3 item 16, `_handleSecondaryTap`'s `cursorTarget = const CursorTarget.none()` branch) — V2 has no canvas context menu at all. `UNSPECIFIED BY V2`; keeping OEP's canvas menu is additive, not conflicting.

---

## 22. Tracer

### 22.1 A. V2 BEHAVIOR — activation

`traceCircuit()` (`app.js:112`): no-op if no wire selected. Calls `CircuitTracer.traceFromWire(selW.id)` → `tracedWires` (a `Set` of wire ids reachable via BFS from both endpoints of the selected wire through the connected graph — see §22.6). Reachable also via: the wire inspector's `◎ Trace` action button (`fp-act`, `traceCircuit()`), and the context menu's Trace item (§21.3, wire-only).

### 22.2 A. V2 BEHAVIOR — visualization

**No separate highlight mechanism** — tracing works entirely through the wire-dimming/glow system already documented in §11.4: every wire in `tracedWires` gets the green glow treatment (traced-not-selected width `2.2`), every wire **not** in `tracedWires` (when `tracedWires.size > 0`) gets `opacity:0.1`. The originally-selected wire remains additionally at the amber-selected width/glow if it's also in the traced set (it always is, since trace starts from it).

### 22.3 A. V2 BEHAVIOR — path highlighting (extended capabilities)

**Source:** `diagram/path-highlighter.js`

Beyond simple circuit trace, `PathHighlighter` exposes: `showPowerPath(targetModuleId)` (uses `PowerPath.find`, toast on no-path-found), `showGroundPath(sourceModuleId)` (`GroundPath.find`), `showCircuit(wireId)` (same as `traceCircuit`), `showChargingPath()` (hard-coded `alternator-stator` → `battery-fuses` traversal via `PathFinder.findAllPaths` — **vehicle-specific, not generic**), `clear()`. **None of these four extended functions are wired to any UI control in the shipped `index.html`** — confirmed by grep: no `onclick` or button references `showPowerPath`/`showGroundPath`/`showChargingPath` anywhere in `index.html` or any loaded JS file. They exist as a dormant capability, exactly like the simulation solvers (§17.8).

### 22.4 A. V2 BEHAVIOR — controls / panel behaviour

`#tracer`: fixed, `left:8px, top:50%, translateY(-50%), width:200px, min 160×140`, header (`#tr-hd`, draggable via the generic drag system since it's registered in `DRAG_MAP`, §23) showing `Circuit Trace` (green, `#10b981`) with a panel-menu button and close button. Body (`#tr-body`) lists every wire in the trace (`CircuitTracer.getWires`), each row: coloured dot, label, `from → to` (module ids with hyphens replaced by spaces). The currently-selected wire's row gets class `.act` (highlighted background `#0f2a1c`). Clicking a row: `selW = w; updatePanel(w); drawWires(); renderTracerPanel(wires)` — re-selects that wire within the trace (updates the inspector but does **not** change/re-run the trace itself).

### 22.5 A. V2 BEHAVIOR — dismissal

`closeTracer()`: removes `.open` from `#tracer`, `tracedWires.clear()`, `drawWires()` — closing the panel **clears the trace and its dimming effect**, it's not just hiding the list. Also implicitly cleared whenever selection changes away from the traced wire (deselecting a wire clears `tracedWires` per §12.2).

### 22.6 A. V2 BEHAVIOR — relationship to simulation/analysis

`CircuitTracer.traceFromWire` is pure graph connectivity (BFS via `GraphTraversal`, consuming `EKE.graph` — the `CircuitGraph` built at bootstrap from `MODULES`/`WIRES`) — **not** an electrical/simulation concept. It answers "what's in the same connected sub-graph," not "what's electrically live." It has no dependency on `keyPos` or switch state.

### 22.7 B. OEP ENGINE BEHAVIOR

No direct OEP equivalent exists in the audited surface — audit §5.4/§6.4 note the diagram workspace has "no equivalent" trace/tracer surface, and the Engineering Intelligence panels (`RecommendationPanel`, `EngineeringExplorerPanel`, etc.) are a materially different, Foundation-backed concept, not graph-connectivity tracing.

### 22.8 C. RECONSTRUCTION REQUIREMENT

1. Build a `#tracer`-equivalent floating panel at the exact geometry in §22.4, driven by a graph-connectivity BFS over `EngineeringGraph` (the OEP equivalent traversal — confirm whether one already exists in `oep_engine`'s public API before assuming new Engine work is required; not established by the sources read for this document).
2. Trace visualization reuses the **same** dim/glow mechanism as selection (§11.4/§22.2) — this is one shared rendering rule, not two, consistent with §11.11 item 2.
3. **Do not wire up** `showPowerPath`/`showGroundPath`/`showChargingPath` as if they were shipped V2 features — they are dormant, unreferenced code in the reference implementation (§22.3). If OEP's own Simulation/Verification capabilities (`SimulationStateOverlay`'s `propagationPathNodeIds`, audit §5.3) cover equivalent ground, that is a separate OEP capability, not a V2 fidelity requirement.
4. Closing the tracer clears the trace (§22.5) — reproduce this coupling exactly, it is not two independent actions in V2.
5. Row click re-selects without re-tracing (§22.4) — reproduce exactly.

---

## 23. Floating Panel System

### 23.1 A. V2 BEHAVIOR — panel manager scope

**Source:** `app.js:203-297` (IIFE, "Panel manager")

Managed panels: `DRAG_MAP = {fp: 'fp-drag', mip: 'mip-drag', 'swpack-panel': 'swpack-hd', tracer: 'tr-hd'}` — **exactly four panels** participate in the generic drag/resize/persist system: wire inspector pop-out (`#fp`), module info (`#mip`), switch pack (`#swpack-panel`), tracer (`#tracer`). `RESIZABLE_IDS = Object.keys(DRAG_MAP)` — the same four get a resize grip. **`#srch`, `#legend`, `#minimap`, `#kbh`, `#ctx`, modals, and the sidebar itself are NOT part of this system** — they have fixed positions/sizes with no drag or resize capability at all.

### 23.2 A. V2 BEHAVIOR — panel creation

Panels are static DOM elements present in `index.html` from load, initially `display:none` (`#fp`, `#mip`) or controlled by `.open` class toggling display (`#tracer`, `#swpack-panel`) — there is no dynamic panel-instantiation API; "creating" a panel means showing a pre-existing, singleton DOM node. There is exactly one instance of each panel type — no multi-instance panels.

### 23.3 A. V2 BEHAVIOR — default position

On `boot()` (called on `DOMContentLoaded` or immediately if already loaded): for each of the four managed panels, `applySaved(panel, panelId)` reads `localStorage['wiring-panel-' + panelId]` (JSON: `{left, top, width, height}`) and applies whatever fields are present; if nothing is saved, the panel keeps its CSS-authored default position (inline/stylesheet). `swpack-panel` additionally clears its centring `transform` if a saved `left` exists (since it's normally centred via `transform:translateX(-50%)`).

### 23.4 A. V2 BEHAVIOR — floating / dragging

`attachDrag(panelEl, handleEl)`: on handle mousedown/touchstart (ignoring clicks on `.panel-menu-btn`/`.panel-menu` or non-handle buttons) — converts the panel to `position` from its current `getBoundingClientRect()` (`style.left/top` set explicitly, `transform:'none'` clears any centring transform), then tracks `window`-level mousemove/touchmove to reposition (`panel.style.left = clientX - offsetX`, etc.) until mouseup/touchend, at which point `clamp(panelEl)` runs (§23.7).

### 23.5 A. V2 BEHAVIOR — resizing

`attachResize(panelEl)`: appends a `.resize-handle` div (`position:absolute, right:0, bottom:0, width:16px, height:16px, cursor:nwse-resize`, diagonal gradient visual, cyan on hover) to the panel, sets `panelEl.style.overflow='hidden'`. Drag from the handle: `panel.width = max(CSS min-width, startWidth + deltaX)`, `panel.height = max(CSS min-height, startHeight + deltaY)` — **bottom-right corner resize only, no other edge/corner, no maximum size enforced beyond what CSS `max-width`/`max-height` (if any) provides** (only `#swpack-panel` and `#mip` declare a `max-` constraint in CSS; `#fp`/`#tracer` have none).

### 23.6 A. V2 BEHAVIOR — minimum / maximum size

| Panel | min-width | min-height | max-width | max-height |
|---|---|---|---|---|
| `#fp` | 260px | 200px | — | — |
| `#mip` | 240px | 200px | — | 480px |
| `#tracer` | 160px | 140px | — | — |
| `#swpack-panel` | 380px | 340px | 96vw | — |

(All from `main.css`, §23.5's fallback reads `getComputedStyle(...).minWidth/minHeight` at drag time, defaulting to `180`/`140` if unset — meaning the JS-level floor is `180×140` even where CSS declares something smaller, an inconsistency: `#tracer`'s CSS `min-width:160px` is **overridden upward** to `180px` by the resize handler's own fallback logic reading a *different* property than what's declared, since `min-width` IS declared for `#tracer`... re-check: `getComputedStyle` **will** return the CSS-declared `160px`/`140px` correctly since it's explicitly set — the `180/140` fallback only applies to panels with **no** CSS min declared at all, which is none of the four. No actual inconsistency; noted and dismissed.)

### 23.7 A. V2 BEHAVIOR — close

Each managed panel has its own dedicated close button with panel-specific behaviour (not part of the generic manager): `#fp-close` → `closePanel()` (`fp.style.display='none'`, notifies Sidebar); `#mip-close` → `closeModInfo()` (clears `selM`, redraws); `#tr-close` → `closeTracer()` (§22.5); `#swpack-panel`'s close is the same `SWPACK.toggle()` as its open button (no separate close button — the header only has a panel-menu button and an `✕` that also calls `toggle()`).

### 23.8 A. V2 BEHAVIOR — menu (`⋮`)

`panelMenuOpen(id, btn)`: builds a 4-item menu (`📌 Set as Default Position`, `↺ Reset to Default`, `⊡ Re-center Panel`, `⤡ Reset Size`) positioned below-and-left of the `⋮` button (`top:btn.bottom+4, left:btn.left-140`). `panelMenuCmd(cmd)`:
- `default`: `save(panelId, getState(panel))` → writes current `{left,top,width,height}` to `localStorage`, toast `Default position saved`.
- `reset`: `localStorage.removeItem(...)`, `panel.style.cssText=''` (full inline-style wipe, reverting to CSS defaults), re-applies the centring transform for `swpack-panel` specifically, toast `Position reset`.
- `center`: centres the panel in the current window (`(innerWidth-panel.width)/2`, same for height), clears transform. **No toast for this action** (only one not toasted).
- `resetSize`: clears `width`/`height` inline styles only (position untouched), toast `Size reset`.

**Not every managed panel exposes this menu in its header** — only `#tracer` (`tr-hd`... wait, checking: `panelMenuOpen` is called from `swpack-hd`'s panel-menu-btn and `tracer`'s — confirmed both `#swpack-panel` and `#tracer` have a `.panel-menu-btn` in their headers (`index.html:288, 680`). `#fp` and `#mip` do **not** have a panel-menu button in their DOM** — so the `⋮` menu is only reachable on 2 of the 4 managed panels, not all 4.

### 23.9 A. V2 BEHAVIOR — persistence

`localStorage` keys `wiring-panel-<id>` (one per panel, only written by explicit "Set as Default Position," **not automatically on every drag/resize** — dragging/resizing changes the panel's live position but does not persist it unless the user explicitly saves it via the menu). This means: refreshing the page reverts any un-saved drag/resize back to the last explicitly-saved (or CSS-default) position.

### 23.10 A. V2 BEHAVIOR — reposition after resize/close

`clamp(panelEl)` (called at drag end only, not on window resize, not on resize-handle drag end): `left = clamp(0, current, windowWidth-60)`, `top = clamp(0, current, windowHeight-60)` — keeps at least 60px of the panel within the viewport, does not affect width/height.

### 23.11 A. V2 BEHAVIOR — multiple panels / overlap / z-order

No collision avoidance, no cascade-on-open, no automatic z-order-to-front-on-focus — every managed/fixed panel has a **static** CSS `z-index` (§4.5 table) that never changes at runtime. Two floating panels can freely overlap with no interaction beyond whichever has the higher static z-index always winning.

### 23.12 A. V2 BEHAVIOR — pop-out / dock (sidebar-specific, distinct system)

**Source:** `js/ui/sidebar.js:253-289` — this is a **third, separate** floating mechanism from §23.1's four-panel manager, applying only to the Inspector and Meter sidebar tabs.

`popOut('inspector')`: shows `#fp` at `left: max(10, innerWidth/2 - 160), top: 100px`, dims the sidebar pane to `opacity:.35`, toast. `popOut('meter')`: shows `#meter-popout` at `left: innerWidth-270, top:100px`, dims `#sidebar-meter`, toast. `dockIn(name)`: hides the floating counterpart, restores sidebar opacity. **Note**: popping out the Inspector reuses the *same* `#fp` element the wire-selection floating panel already uses (§23.1) — they are the same DOM node serving two logical roles (auto-shown-on-wire-select in its original design intent vs. explicitly-popped-from-sidebar), which is why `#fp`'s content (`fp-info`, etc.) is populated by the same `updatePanel(w)` function regardless of which path opened it.

### 23.13 B. OEP ENGINE BEHAVIOR

Audit §7 catalogues **four competing panel-placement systems already coexisting** in OEP: `DockablePanel`+`PanelDockSlot` (4 fixed slots), `InstrumentDock` (`DockPosition{bottom,floating,left,right}` + its own drag/resize via `_FloatingFrame`/`_ResizeGrip`), 11 independent visibility booleans on `_DiagramStudioPageState`, and `KnowledgePanel` columns. None currently implement per-panel persisted position/size the way V2's `localStorage`-backed system does (only visibility booleans are persisted, per audit §5.1).

### 23.14 C. RECONSTRUCTION REQUIREMENT

This is the fullest specification of what audit §7's "one unified panel model" must actually do, now grounded in V2 source rather than description:

1. **Only floating panels get drag/resize/persist** — reproduce V2's scope discipline: not every overlay needs to be a managed panel (`#legend`/`#minimap`/`#kbh`/`#srch` are fixed by design, §19–20/§18/§24). The unified model applies to the panel-*class* of surfaces (wire inspector, module info, switch/key-states equivalent, tracer, and — extending beyond V2's four — any OEP panel currently in `DockablePanel`/`InstrumentDock`), not to every fixed overlay.
2. Bottom-right-corner-only resize, with per-panel min-size (and max where V2 declares one) exactly per §23.6.
3. Persistence is **explicit-save, not automatic** (§23.9) — this is a deliberate V2 behaviour (drag freely, only "Set as Default Position" commits it) and must not be silently changed to auto-persist-on-every-drag, which would be inventing behaviour V2 doesn't have.
4. The 4-item `⋮` menu (§23.8) is reproduced with its exact 4 commands and exact per-command side effects, including the one command (`center`) that does not toast.
5. **The `⋮` menu is not present on every panel in V2** (§23.8) — `UNSPECIFIED BY V2 why #fp/#mip lack it`; whether the reconstruction gives every OEP panel the menu (a reasonable normalization, since building two panel variants purely to reproduce an apparent inconsistency serves no fidelity purpose) or reproduces the exact V2 subset is a **presentation decision the Controller boundary does not gate** — record the choice made, but it does not require escalation.
6. Clamp-to-viewport-with-60px-margin on drag end (§23.10) reproduced.
7. No collision avoidance, no z-order-on-focus, static z-index per surface (§23.11) — reproduced (i.e., do not add drag-to-front behaviour V2 lacks).
8. Pop-out/dock-back for the sidebar Inspector/Meter tabs (§23.12) is a **separate mechanism** from the four-panel manager and must be built as such — not folded into the same generic drag/resize system, since V2 itself keeps them architecturally distinct (the popped-out inspector reuses `#fp`, which is *also* independently a managed panel — this dual role is source-confirmed, not a simplification).
9. This entire system's persistence (§23.9, `localStorage`-equivalent) is **UI state**, and must be stored via `DiagramWorkspaceState`'s new panel-layout schema (audit §5.1/§12.4) — never mixed with `DiagramDocument`'s engineering-data envelope, closing the loop on the audit's "V2 conflates the two" warning (§3.6 of this document).

---

## 24. Keyboard Map

### 24.1 A. V2 BEHAVIOR — complete keyboard map

**Source:** `app.js:141-179` (global `keydown` listener), plus mode-specific/inline handlers cited per row. Guard: the entire handler no-ops if `e.target.tagName` is `INPUT`/`TEXTAREA`/`SELECT` (`app.js:142`) — no shortcut fires while a text field has focus, with no exceptions.

Checked **in this exact order** (first match wins, `return` after handling):

| Order | Key | Modifier | Guard | Action | Context | Visual Effect | State Change |
|---|---|---|---|---|---|---|---|
| 1 | `ArrowUp`/`ArrowDown`/`ArrowLeft`/`ArrowRight` | + optional `Shift` | `routeEditMode && selSeg` | nudge selected segment (§15.3) | Route Edit, segment selected | route redraws | `wireRoutes[wid][segIdx] += delta` |
| 2 | `r` / `R` | — | `routeEditMode` (checked after arrow-key block, so only reached if not caught by #1's guard failing — but note: `R` reset is checked **unconditionally within** `routeEditMode`, not requiring `selSeg`) | `resetWireRoute()` | Route Edit | route redraws, toast | `delete wireRoutes[selW.id]` |
| 3 | `e` / `E` | — | any (not gated to a mode) | `toggleEdit()` | global | badge/cursor/button change | `editMode` flips |
| 4 | `w` / `W` | — | any | `toggleWireMode()` | global | badge/cursor/button change | `wireMode` flips |
| 5 | `f` / `F` | — | any | `zReset()` | global | viewport re-fits | `scale/tx/ty` recomputed |
| 6 | `/` or `?` | — | any | `e.preventDefault(); toggleSearch()` | global | `#srch` opens/closes | `srchOpen` flips |
| 7 | `l` / `L` | — | any | `toggleLegend()` | global | `#legend` opens/closes | `legOpen` flips |
| 8 | `G` | `Ctrl+Shift` | any | `e.preventDefault(); GraphInspector.toggle()` | global (developer) | `#graph-inspector` shows/hides | `_visible` flips |
| 9 | `Escape` | — | any | cascading dismissal, see §24.2 | global | varies | varies |
| 10 | `Delete` | — | `selW && !editMode` | `deleteSelectedWire()` | wire selected, not in Layout Edit | confirm dialog, wire removed | `WIRES` mutated |
| 11 | `0`–`3` | — | `!e.ctrlKey && !e.metaKey` | `setKey(+e.key)` | global | key buttons update, LCD/bulbs/wires refresh | `keyPos` set |

### 24.2 A. V2 BEHAVIOR — Escape cascade (checked in this exact order, first match wins)

**Source:** `app.js:166-176`

1. `leadPlaceMode` set → clear it, remove `.lead-place-mode` cursor class, update lead buttons.
2. else `routeEditMode` → `exitRouteEditMode()`.
3. else `wireMode` → `cancelWireMode()`.
4. else `#mpm` (edit module modal) open → `closeMpm()`.
5. else `#add-modal` (add module modal) open → `closeAddModal()`.
6. else `#wpm` (wire properties modal) open → `closeWPM()`.
7. else `srchOpen` → `toggleSearch()` (closes it).
8. else `selM` (module selected) → `closeModInfo(); drawWires();`.
9. else `selW` (wire selected) → `selW=null; closePanel(); leadR=null; leadB=null; clearLeadDots(); tracedWires.clear(); drawWires();` (**no explicit `return`/redraw call listed after this branch in the source's own structure — it's the final `if`, not an `else if`, meaning if none of 1-8 matched, this one still runs its own body directly**).

**Not included in the cascade at all**: closing `#legend`, `#tracer`, `#srch` is item 7 already listed—correcting: **`#tracer`, `#minimap`, `#kbh`, `#ctx`, `#swpack-panel`, `#fp`/`#mip` (when independently popped out) have no `Escape` handling.** Only the nine items above respond to `Escape`.

### 24.3 A. V2 BEHAVIOR — key conflicts within V2 itself

1. **`/` and `?` both open Search** (row 6) — meaning **`?` never reaches the Shortcuts-panel toggle bound to the `?` toolbar button**, since the global keydown handler's `/`-or-`?` branch runs first and calls `return`. The `?` toolbar **button**'s `onclick="toggleKbh()"` still works (it's a separate DOM event path, not the keydown handler), but the **keyboard** `?` key is fully claimed by Search. This is a real, source-confirmed self-conflict in V2, not a hypothetical.
2. `R` (reset route) is checked before the mode-toggle letters below it, but only acts within `routeEditMode` — outside that mode, `r`/`R` falls through to no binding (it is not, for instance, a global "redo" or anything else).
3. `L` (legend) and `l` inside a text field are correctly excluded by the input-focus guard — no conflict with typing.

### 24.4 A. V2 BEHAVIOR — no `Enter` binding

No keydown handler references `Enter`/`Return` anywhere in the global listener. Individual form inputs may submit-on-Enter via native browser form behaviour where applicable, but there is no app-level Enter shortcut. `UNSPECIFIED BY V2` beyond this absence.

### 24.5 A. V2 BEHAVIOR — no function keys

No `F1`–`F12` bindings exist anywhere in V2 source.

### 24.6 B. OEP ENGINE BEHAVIOR / existing OEP shortcut table

**Source:** audit §2.3 item 33 (`diagram_studio_page.dart:2334-2362`)

| Key | Modifier | Action |
|---|---|---|
| `Z` | Ctrl | Undo |
| `Y` | Ctrl | Redo |
| `Z` | Ctrl+Shift | Redo (alternate) |
| `C` | Ctrl | Copy |
| `X` | Ctrl | Cut |
| `V` | Ctrl | Paste |
| `D` | Ctrl | Duplicate |
| `S` | Ctrl | Save |
| `A` | Ctrl | Select all |
| `Delete` | — | Delete selection |
| `Backspace` | — | Delete selection |
| `Escape` | — | Cancel pending connection, else deselect all |
| `0` | Ctrl | Reset view |
| `M` | Ctrl | Toggle Instrument Dock |

### 24.7 A/B. CONFLICT TABLE — V2 unmodified key vs. OEP Ctrl-modified key

No literal collision exists between V2's table (§24.1, all unmodified single keys except the two `Ctrl+Shift+G`/`Ctrl` items) and OEP's table (§24.6, all `Ctrl`-modified except bare `Delete`/`Backspace`/`Escape`) **except**:

| Key | V2 meaning (unmodified) | OEP meaning (unmodified) | Collision? |
|---|---|---|---|
| `Delete` | Delete selected wire (guarded: `selW && !editMode`) | Delete selection (any kind) | **Same key, different guard/scope — must be reconciled, not a hard collision but a semantic overlap** |
| `Escape` | 9-step cascade (§24.2) | Cancel connection else deselect all | **Same key, both are cascades — must be merged, not layered** |
| `0` | Set key position to Off (bare `0`) | Reset view (**`Ctrl+0`**) | No collision — different modifier |
| `E`, `W`, `F`, `/`, `?`, `L`, `R` (bare) | Tool-mode/view shortcuts | *(unbound in OEP's table)* | No collision, but **occupies letters OEP has not used** — safe to add, contingent on §8.4/§29.3 |

### 24.8 C. RECONSTRUCTION REQUIREMENT

1. Reproduce the full order-sensitive dispatch table (§24.1) exactly, including the input-focus guard.
2. Reproduce the 9-step Escape cascade (§24.2) **merged** with OEP's existing 2-step cascade (§24.6's `Escape` row) into one ordered list — OEP's "cancel pending connection" step corresponds to no V2 step (V2 has no drag-in-progress connection state distinct from `wireMode`'s armed-source state, which V2's own cascade step 3 already covers) and should be inserted at the position matching its semantic equivalent (immediately alongside/before the wire-mode-cancel step). This merge is a Controller-design task, not resolved further here.
3. Reproduce the `Delete` semantic distinction: V2 deletes only a selected **wire**, guarded against Layout Edit mode; OEP deletes the **current selection of any kind**. **Do not narrow OEP's Delete to wires-only** — that would be a capability regression (audit §15 item 8). Instead, reproduce V2's Layout-Edit-mode guard as an additional OEP-side gate once §8.4/§29.3 resolves what "Layout Edit mode" corresponds to in the merged model.
4. `Ctrl+0` (OEP reset view) and bare `0` (V2 key-position) coexist without conflict — both reproduced.
5. Add V2's bare single-key bindings (`E`/`W`/`F`/`/`/`?`/`L`/`R`) — none collide with OEP's `Ctrl`-modified table. **The `/`-vs-`?` self-conflict (§24.3 item 1) is reproduced as-is**, not fixed — this task forbids improving V2, and fixing a real (if minor) V2 bug would be exactly that. Record it in §29 as a known, intentionally-preserved defect, not silently corrected.
6. No `Enter`, no function-key bindings — none added.

---

## 25. Animation

### 25.1 A. V2 BEHAVIOR — wire flow

Fully specified in §11.8. Restated for completeness: `requestAnimationFrame` loop, `1.2px`/frame `stroke-dashoffset` advance, `12px`/`8px` dash/gap (`20px` cycle), direction `±1` via `data-dir`, loop starts/stops based on presence of any `.flow-overlay` element after each `drawWires()` pass (checked, not event-driven).

### 25.2 A. V2 BEHAVIOR — selection / hover transitions

`.t-dot` — `transition: transform .1s, box-shadow .1s`. `.sidebar-tab` — `color .15s, border-color .15s`. `.sw-ind` — `all .15s`. `.sw-pos` — `all .12s`. `.lm-btn` — `all .1s`. `.mbtn-rect` (SVG meter mode buttons) — `fill .1s` (via inline style, not CSS class, since it's an SVG attribute context). `.mip-wire-link` — `background .1s`. `.mpm-dot` — `background .15s`. `#mod-panel` — `width .18s ease` (the module drawer slide).

### 25.3 A. V2 BEHAVIOR — flash effects

`.sel-flash` — no CSS transition; it is a discrete class add/remove pair with a fixed `setTimeout(1500)` in JS (§10.6/§18.5), not a CSS animation/keyframe.

### 25.4 A. V2 BEHAVIOR — CSS keyframe animations

| Animation | Keyframes | Duration | Applied to |
|---|---|---|---|
| `leadpulse` | `0%,100%: 0 0 0 2px cyan` / `50%: 0 0 0 4px rgba(cyan,.3)` | `1s infinite` | `.lead-btn-active` |
| `crank-pulse` | `0%,100%: border #78350f` / `50%: border #f59e0b + glow` | `.4s infinite` (topbar indicator) / `.35s infinite` (switch-pack button, separately declared with the same name — **two different-duration rules share the identical animation-name `crank-pulse`, the second declaration in source order wins per CSS cascade rules for the class that references it**) | `.sw-ind-cranking`, `.sw-pos-cranking` |
| `leadPulse` (distinct from `leadpulse` above — **case-sensitive name collision, two separate keyframe definitions**: lowercase `leadpulse` at `main.css:300` for button glow, capital-P `leadPulse` at `main.css:656-659` for on-canvas lead-wire opacity) | `0%,100%: opacity .7` / `50%: opacity 1` | `2s ease-in-out infinite`, red lead; same but `+0.5s` delay for black lead | `.lead-wire-r`, `.lead-wire-b` |

### 25.5 A. V2 BEHAVIOR — timing/easing summary

No named easing curves beyond CSS defaults (`ease` default for transitions unless specified) and one explicit `ease` on `#mod-panel`'s width transition; `leadPulse`'s keyframe animation explicitly uses `ease-in-out`. All other transitions/animations use the browser default timing function (`ease`, implicit).

### 25.6 A. V2 BEHAVIOR — conditions

Flow animation: `keyPos !== 0` AND a non-zero, non-`OPN` reading exists (§11.8). Lead pulse (`.lead-btn-active`): while `leadPlaceMode` is armed. Crank pulse: while `SWPACK.state.start` is `true` (held). Lead wire pulse: unconditional whenever a lead is placed (not gated by key position or measurement validity — purely presence-of-lead).

### 25.7 B. OEP ENGINE BEHAVIOR

No animation system is documented in the audit for the current Diagram Studio canvas beyond implicit Flutter widget transitions (not itemized in the audit, since the audit found no V2-equivalent flow/pulse animation exists in OEP at all — audit §5.3/§6.4 explicitly note flow animation and trace dimming as things to *add*).

### 25.8 C. RECONSTRUCTION REQUIREMENT

1. Reproduce flow animation exactly (§11.8/§25.1) — already required by §11.11 item 3; cross-referenced here as the canonical animation-timing source.
2. Reproduce every transition duration/property in §25.2 on the corresponding reconstructed control.
3. Reproduce `sel-flash` as a discrete 1500 ms timed class toggle, not a CSS transition.
4. Reproduce all three keyframe animations (§25.4) with their exact timing, **including preserving the lowercase/uppercase `leadpulse`/`leadPulse` naming distinction's practical effect** (two visually distinct pulse behaviours — button glow vs. canvas-line opacity — must remain distinct effects in the reconstruction; the naming collision itself is a Flutter-irrelevant CSS artefact, not a behaviour to reproduce literally).
5. No named easing beyond default/`ease`/`ease-in-out` as documented — do not introduce custom curves.

---

## 26. Responsive Behavior

### 26.1 A. V2 BEHAVIOR — window becomes narrow

`#topbar` (row 1): horizontally scrolls (hidden scrollbar), content never wraps or shrinks — logo, key buttons, switch indicators, badges all remain full-size, requiring horizontal scroll to reach later items at narrow widths. `#topbar-actions` (row 2): wraps to additional lines (`flex-wrap:wrap`), growing `#topbar-wrap`'s total height. `#left-sidebar`: **does not shrink** — fixed 260px regardless of window width, will overlap/compress the viewport region if the window is narrower than sidebar+minimum-viewport. `#viewport`: `min-width:0` allows it to be compressed arbitrarily, including to zero or negative available space (no minimum enforced). `window.resize` triggers `zReset()` (re-fit) + `drawWires()` + `updateMinimap()` — the diagram content re-fits, but sidebar/topbar layout is pure CSS flex response with no JS-driven breakpoint logic.

### 26.2 A. V2 BEHAVIOR — window becomes wide

`#viewport` simply gets more space (`flex:1`); `#canvas`'s fixed 1600×1000 content does not grow — at very wide windows, `zReset()`'s `Math.min(.9, ...)` fit calculation would compute a scale **capped at 0.9** even if the canvas could fit larger, meaning the canvas never displays above 90% scale purely from a fit operation, leaving visible surrounding `#viewport` background beyond the canvas border at wide/tall windows. `#topbar-actions` un-wraps back toward one line as space permits.

### 26.3 A. V2 BEHAVIOR — sidebar changes size

**Not possible** — no resize affordance exists for `#left-sidebar` (§4.3). `UNSPECIFIED BY V2` for anything beyond "it does not happen."

### 26.4 A. V2 BEHAVIOR — floating panel overlaps

No collision avoidance (§23.11) — panels overlap freely with static z-index precedence, no runtime layout adjustment.

### 26.5 A. V2 BEHAVIOR — viewport changes

Handled entirely by `window.resize` → `zReset()` (§9.4/§26.1) — the only viewport-size-reactive logic in V2.

### 26.6 A. V2 BEHAVIOR — controls cannot fit

Row 1 (`#topbar`) overflows horizontally with a hidden native scrollbar (still scrollable via trackpad/shift-wheel/touch, just not visibly showing a scrollbar thumb) — this is the only "controls cannot fit" handling; row 2 wraps instead of scrolling. No control is ever hidden, collapsed into an overflow menu, or reflowed into icon-only form based on available width.

### 26.7 B. OEP ENGINE BEHAVIOR

Audit §6.3 records that OEP's existing toolbar deliberately uses `Wrap` (not horizontal scroll) specifically **because** a fixed-viewport horizontal scroll made buttons unreachable in existing interaction tests — i.e. OEP already made and validated the opposite choice from V2's row-1 approach, for a concrete, test-confirmed reason.

### 26.8 C. RECONSTRUCTION REQUIREMENT

1. Reproduce row 2 wrap-not-scroll behaviour (this matches OEP's existing validated approach — no conflict).
2. **Row 1's horizontal-scroll-no-wrap behaviour conflicts with OEP's own test-validated finding** (§26.7) that scroll-based overflow made controls unreachable in automated interaction tests. This is a genuine V2-vs-OEP-testing conflict, not resolved here — flagged in §29 as a new item (§29.12) since it was not in the audit's original conflict list and directly affects whether §6's row-1 control order can be reproduced as literally horizontally-scrolling.
3. Sidebar remains fixed-width, non-resizable (§4.3/§26.3) — already required by §4.9.
4. Fit-on-resize is **not** reproduced (§4.8/§9.10 item 8 — conflicts with persisted `ViewState`).
5. No responsive breakpoint logic, no control collapsing/hiding by width — none added.
6. Canvas fit cap at `0.9` scale (§26.2) is reproduced as part of the fit calculation already specified in §9.4/§9.10 item 4.

---

## 27. State Model

### 27.1 A. V2 BEHAVIOR — complete state inventory with persistence class

| State | Global(s) | Persistence |
|---|---|---|
| **Document/engineering** | `MODULES`, `WIRES`, `positions` (module layout), `wireRoutes` (segment overrides) | Session — held in memory; explicit "Save" (§4.2 row 12) writes `positions`+`wireRoutes`+user-created modules/wires to a **downloaded file**, not auto-saved; "Load" merges a file back in. No autosave of any kind exists in the shipped source (`storage/autosave.js` is referenced in `docs/architecture.md` but the file does not exist in the tree). |
| **Tool/interaction mode** | `editMode`, `wireMode`, `routeEditMode`, `wireSrc`, `selSeg` | Transient — reset on page reload, never persisted |
| **Selection** | `selW`, `selM` | Transient |
| **Simulation/electrical** | `keyPos`, `SWPACK.state` (`lights`/`beam`/`kill`/`start`) | Transient — reset to defaults (`keyPos=0`, `lights:'off'`, `beam:'lo'`, `kill:'run'`, `start:false`) on every reload |
| **Measurement/meter** | `meterMode`, `leadR`, `leadB`, `leadPlaceMode`, `leadMode` | Transient |
| **Viewport** | `scale`, `tx`, `ty` | Transient — always re-derived by `zReset()` at boot |
| **Panel/UI** | `kbhOpen`, `mpOpen`, `srchOpen`, `legOpen`, panel `left/top/width/height` (§23) | **Mixed**: open/closed booleans are transient (reset on reload); panel geometry is **session+persistent** — persisted only via explicit "Set as Default Position" to `localStorage`, otherwise transient |
| **Theme** | `data-theme` attribute | **Persistent** — `localStorage['wiring-sim-theme']`, restored on every load (`app.js:183-201`, an IIFE that runs at script-parse time, before `bootstrap()`) |
| **Trace** | `tracedWires`, `ctxTarget` | Transient |
| **Undo/redo** | `UndoRedoStack` class exists but is **never instantiated anywhere** | N/A — dead code, no undo state exists in the running app |

### 27.2 A. V2 BEHAVIOR — persistent vs. session vs. transient, precisely

- **Persistent** (survives reload without user action, via `localStorage`): theme; any panel's explicitly-saved default position/size (only the four managed panels, only if the user invoked "Set as Default Position").
- **Session** (survives within the tab's lifetime but not a manual reload unless explicitly saved): the *live* (unsaved) position/size of a dragged/resized panel — lost on reload unless separately committed to `localStorage`.
- **Transient** (never survives anything, including navigating away and back within the same page without reload — since these are plain variables, not even `sessionStorage`-backed): every other listed state — document content itself is **fully transient** unless the user explicitly downloads a save file.

### 27.3 B. OEP ENGINE BEHAVIOR — for contrast

Per audit §12.4: engineering data (`DiagramDocument`) is file-persistent with autosave to a recovery file; UI state (`DiagramWorkspaceState`) is persistent via `WorkspaceStateStorage`; temporary workspace state (`DiagramTabsStorage`) is persistent; user preferences (`DiagramStudioSettings`) are persistent. **OEP persists categories V2 never persists at all** (document content via autosave; tab/workspace state) and treats as ambient-but-real several things V2 treats as pure runtime variables (`ViewState` zoom/pan is included in `DiagramWorkspaceState`, §5.1 of this document — V2's `scale`/`tx`/`ty` are never saved anywhere, always re-derived by `zReset()`).

### 27.4 C. RECONSTRUCTION REQUIREMENT

1. This section is primarily descriptive; the persistence-category separation is already governed by audit §12.4 and §3.6 of this document. No new requirement is introduced beyond confirming: **theme persistence** (§27.1) belongs in `DiagramStudioSettings` (user preference) if theme is adopted at all — contingent on §29.9.
2. Panel geometry persistence (§27.1/§27.2's explicit-save-only model) is already required verbatim by §23.14 item 3.
3. **Document content is never auto-saved in V2** — this is the opposite of OEP's autosave-to-recovery-file behaviour (audit §4.1). **Do not weaken OEP's autosave to match V2** — autosave is Engine/Studio-host infrastructure (`DiagramDocument.autosave`, audit-classified KEEP, engineering-data-adjacent), not a presentation concern this task can override, and the audit's forbidden-changes list (§15 item 8 of the audit) already protects it as a capability.
4. Undo/redo: V2's dead `UndoRedoStack` establishes **no requirement or precedent whatsoever** — OEP's real, wired undo/redo (`StudioCommandActions`, audit §4.2, non-negotiable KEEP) is entirely unaffected by this section.

---

## 28. OEP Mapping

| V2 Concept | V2 Source | OEP Source of Truth | Future Controller Responsibility | Presentation Responsibility | Status |
|---|---|---|---|---|---|
| Module (`MODULES` entry) | `renderer.js`, `modules.json` | `EngineeringNode` + `Port` + `symbolId` | Provide `DiagramNodeVisual` view models | Render card shape/stripe/terminals | ADAPT |
| Wire (`WIRES` entry) | `renderer.js`, `wires.json` | `EngineeringRelationship` | Provide `DiagramWireVisual` view models | Render glow/stripe/flow/label | ADAPT |
| `positions` | `renderer.js` global | `DiagramLayoutState.positions` | Reconcile drag gestures → `MoveNodesCommand` | Live preview during drag | MATCH (mechanism differs, concept matches) |
| `wireRoutes` (relative offsets) | `renderer.js` global | `DiagramLayoutState` wire overrides (absolute) | Translate route-edit gestures → `SetWireRouteCommand` | Render route/segment handles | **CONFLICT** (§29.1) |
| `keyPos` | `app.js` global | `SimulationSession.activeOperatingStateId` | `DiagramSimulationService.setOperatingState` | KEY row rendering | ADAPT |
| `SWPACK.state` | `js/swpack.js` | `SimulationSession.activeInputStates` | `DiagramSimulationService.setInputState` | SWITCHES row/panel rendering | ADAPT (generic profile-driven vs. vehicle-hard-coded — §29.8) |
| Wire reading (`w.R[keyPos]` / `SWPACK.getReading`) | `swpack.js`, `measurements.json` | `MeasurementResult` (computed) | Query live measurement, not authored table | LCD/flow-animation display | **CONFLICT** (§8.5 of audit) |
| `selW` / `selM` (single, mutex) | `editor/selection-manager.js` | `GraphSelection` (multi, non-mutex) | none new — Engine already owns this | Single-selection visual language (§12.11) | ADAPT |
| `editMode`/`wireMode`/`routeEditMode` | `app.js`, `editor/*` | `DiagramStudioMode` (different axis) | Own the new tool-mode axis | Badges/cursor/status bar | **CONFLICT** (§29.3) |
| `scale`/`tx`/`ty` | `renderer.js` | `ViewState.zoom`/`pan` | Bridge gesture → `ViewStateService` calls | Apply transform | MATCH |
| Grid (always-on) | `main.css` | `ViewState.grid` (toggleable) | none new | Render grid | ADAPT (additive toggle) |
| `tracedWires` | `app.js`, `path-highlighter.js` | *(no confirmed equivalent)* | New: graph-connectivity BFS query | Reuse dim/glow rendering | UNKNOWN (§22.7) |
| `leadR`/`leadB`/`leadMode` | `meter-panel.js` | `MultimeterController` (arm-then-click only) | Extend: 4 lead-placement modes | Meter widget + on-canvas leads | ADAPT |
| Meter reading | `index.html` SVG, `meter-panel.js` | `MultimeterController.latestResult` | none new | SVG instrument body | ADAPT |
| Wire colour code (`w.c`) | `renderer.js`, `wires.json` | *(no confirmed field)* | none — pure data question | Resolve hex/name/stripe | UNKNOWN (§29.10) |
| Module `exit` direction | `modules.json` | `node.metadata['exit']` | none new | Terminal strip placement | MATCH |
| Module `bulb`/`connector` flags | `modules.json` | *(no confirmed field)* | none — pure data question | Card shape selection | UNKNOWN (§29.10) |
| `positions[id]`/`DEFAULT_POS[id]` fallback | `renderer.js` | `DiagramLayout.compute` fallback | already exists | already exists | MATCH |
| Routing (`route(w)`, `allocX`/`allocY`) | `renderer.js` | `OrthogonalRoutingProvider`/`RoutingContext` | none — Engine-owned | Render whatever the provider returns | **CONFLICT** (§29.5) |
| Search (`doSearch`) | `app.js` | `SearchService.search` | Query trigger only | Floating overlay (§18) | ADAPT |
| Legend (`buildLegend`, `CAT_CLR`) | `app.js`, `renderer.js` | `categoryStripeColor` | none new | Floating overlay, all-categories-always | ADAPT |
| Minimap (`updateMinimap`, `minimapClick`) | `renderer.js` | `DiagramMiniMap`/`DiagramScene` | Wire up `onTap` | Restore interactivity | ADAPT |
| Context menu (`#ctx`, `ctxTarget`) | `app.js`, `module-editor.js`, `wire-editor.js` | `ContextualCommandResolver` | already exists | Re-skin to V2 geometry | ADAPT |
| Tracer (`#tracer`, `CircuitTracer`) | `app.js`, `diagnostics/circuit-tracer.js` | *(no confirmed equivalent)* | New: BFS-backed panel | New floating panel (§22) | UNKNOWN |
| Floating panel manager (`DRAG_MAP`, `localStorage`) | `app.js` | *(4 competing systems, audit §7)* | New: unified panel controller | New unified panel widget | **CONFLICT** (§29.7) |
| Theme (`data-theme`) | `main.css`, `app.js` | `StudioColors` (dark only) | New: theme provider (if adopted) | Token swap | UNKNOWN (§29.9) |
| Undo/redo (`UndoRedoStack`) | `editor/undo-redo.js` (dead) | `EditingService`/`StudioCommandActions` (real) | already exists | already exists | MATCH (V2's is dead code — no conflict possible) |
| Save/Load (`saveLayout`/`onLayoutFile`) | `storage/project-saver.js`/`-loader.js` | `DiagramDocument` (separates engineering data from UI state) | Document commands, unchanged | Save/Load buttons in action row | **CONFLICT** (§29.6) |

---

## 29. Known Conflicts and Unresolved Decisions

For each: V2 behaviour, OEP behaviour, why they differ, whether it blocks implementation, proposed decision owner, and which Wave (per audit §16) it must be resolved before.

### 29.1 V2 route override model vs. OEP absolute route model

- **V2:** relative per-segment offset, reapplied on top of a freshly recomputed auto-route every draw, keyed by positional segment index (§15).
- **OEP:** absolute point-list replacement (`SetWireRouteCommand`), frozen until explicitly reset, drag-edited.
- **Why they differ:** different underlying architecture — V2 has no persisted route state beyond the delta, recomputing the base route on every frame because its dataset is small enough to afford it; OEP treats a manually-set route as a first-class, stable artefact.
- **Blocks implementation:** Yes, for Wave 5 (V2 interaction system — route-edit keyboard nudging) per audit §16. Does not block Waves 1–4.
- **Decision owner:** Engine architecture owner (this is a data-model question — audit §8.2 already classified it as "an Engine model question... must be scheduled separately").
- **Resolve before:** Wave 5.

### 29.2 V2 selection semantics vs. OEP selection semantics

- **V2:** single-select only, node/wire mutually exclusive, no modifiers, no box-select (§12).
- **OEP:** multi-select, additive/toggle modifiers, box-select, node+relationship selection not mutually exclusive.
- **Why they differ:** V2 is a hand-rolled single-variable selection model; OEP has a real `SelectionService`.
- **Blocks implementation:** No — §12.11 already gives a non-blocking resolution (keep OEP's model, adopt V2's single-selection *feedback vocabulary*). This is recorded as resolved-in-this-document, not open, but listed here per the task's explicit instruction to document it as item 2.
- **Decision owner:** N/A — resolved by this document's §12.11 ruling, consistent with audit §15 item 8 (no capability regression).
- **Resolve before:** N/A (already resolved for presentation purposes; multi-select *visual language*, per §12.11 item 2, remains an open presentation detail with no blocking dependency).

### 29.3 V2 tool modes vs. OEP document modes

- **V2:** `editMode`/`wireMode`/`routeEditMode`, session-local, mutually exclusive, gate *what gesture the canvas performs* (§8).
- **OEP:** `DiagramStudioMode{view,edit,simulate}`, persisted per-tab, gates *what commands exist and which panels default-show*.
- **Why they differ:** orthogonal concerns that V2 never needed to separate (V2 has no "read-only inspection" vs. "editing" vs. "simulating" document-purpose concept at all) — confirmed by full source read, not merely suspected by the audit.
- **Blocks implementation:** Yes — directly determines drag availability (§13.8 item 4), pan availability (§9.10 item 5), hit-path/gesture routing (§8.4), and the Escape/Delete keyboard merge (§24.8 items 2–3).
- **Decision owner:** Studio architecture owner / whoever authored the original audit's §11.4 proposal — needs ratification, not re-derivation, since this document confirms the audit's premise (the two axes are genuinely orthogonal in V2 source) without confirming the audit's specific two-dimension *design* (that remains a design choice, not a source fact).
- **Resolve before:** Wave 3 (audit: "V2 shell and chrome... new mode UI on the two-dimension model").

### 29.4 V2 inspector vs. shared OEP Property Inspector

- **V2:** sidebar-embedded Wire/Module inspector (§10 of this doc's forward reference is actually the audit's §10.8 — cross-referenced), always reachable, reading `selW`/`selM` directly.
- **OEP:** `PropertyInspectorPanel`, shared across all Studios, currently **not mounted on the Diagram Studio route at all** (audit §8.3 — `studio_shell.dart:370`'s full-window carve-out bypasses it).
- **Why they differ:** architectural — OEP's inspector is a shell-level shared surface; the Diagram Studio route opted out of the shell.
- **Blocks implementation:** Yes — determines whether the V2 sidebar inspector *replaces* or *mirrors* the shared panel.
- **Decision owner:** Studio shell owner (needs to determine whether the cross-route bridging in `_syncPropertyInspectorSelection` is intentional or a regression, per audit §8.3's own framing).
- **Resolve before:** Wave 3 (the V2 sidebar's Inspector tab is built in Wave 3, per audit §16, and needs this answer to know whether it's the sole inspector surface or a parallel one).

### 29.5 V2 routing vs. OEP routing provider

- **V2:** `allocX`/`allocY` lane search (6 px grid, first-fit outward), no obstacle avoidance, no trunk sharing, draw-order-dependent lane assignment (§16).
- **OEP:** `OrthogonalRoutingProvider` with trunk-column sharing and obstacle-avoiding exit sweeps — a strict capability superset.
- **Why they differ:** OEP was deliberately built as an improvement, not a port (audit §8.7 quotes "inspired by (not copied from)").
- **Blocks implementation:** No, for wire *rendering* (glow/stripe/flow/label, §11) — those apply to whatever points the provider returns, regardless of which provider. Yes, if "visual fidelity" is interpreted to require identical route *geometry* (which would require either downgrading OEP's router or accepting visible routing differences from V2 screenshots).
- **Decision owner:** Whoever owns the acceptance-criteria sign-off (§30) — this is fundamentally a scope question about what "matches V2" means for routing specifically.
- **Resolve before:** Wave 4 (canvas construction) only if geometry-level fidelity is required; otherwise non-blocking, since OEP routing can simply be used as-is with V2-style wire *styling* on top.

### 29.6 V2 persistence vs. OEP separation of engineering data and UI state

- **V2:** `saveLayout()` writes `positions` + `wireRoutes` + user modules + user wires (engineering-data-shaped content) to one downloaded JSON; theme + panel geometry persist separately via `localStorage` (UI-state-shaped content) — two systems, but the *file* system itself conflates layout (engineering) with nothing else (it does NOT include panel state), so re-reading V2 source narrows the audit's original characterization: **V2's save file is actually engineering-data-only** (positions + routes + user-created topology); the conflation the audit warned about (§3.6 of this document, audit §12.4) is specifically that V2 has no separate "workspace state" file at all — panel/theme state lives in `localStorage` (a different mechanism, correctly separated in practice, just not documented that way in the audit's original framing).
- **OEP:** four-way separation (`DiagramDocument` / `DiagramWorkspaceState` / `DiagramTabsStorage` / `DiagramStudioSettings`), all file-based.
- **Why they differ:** V2 never needed multi-document tabs or a document-open/save dialog model (it has exactly one hard-coded vehicle, loaded once); its "save" is closer to OEP's `saveAs` for a single always-open document.
- **Blocks implementation:** No — this document's re-reading resolves the apparent conflict; V2's two mechanisms (download-file for layout, `localStorage` for UI/theme) map cleanly onto OEP's `DiagramDocument`/`DiagramWorkspaceState` split respectively, with no adoption of V2's conflation actually required, because on closer inspection there wasn't one.
- **Decision owner:** N/A — resolved by this document.
- **Resolve before:** N/A.

### 29.7 V2 panel persistence vs. OEP workspace persistence

- **V2:** explicit-save-only (`localStorage`, per-panel, via `⋮` menu), only 4 of many overlays participate (§23).
- **OEP:** 4 competing panel-placement systems (audit §7), none with true per-panel persisted position/size — only visibility booleans persist.
- **Why they differ:** OEP's systems accreted incrementally (`DockablePanel`, `InstrumentDock`, boolean toggles, `KnowledgePanel`) without a unifying design; V2 had one system from the start, scoped narrowly.
- **Blocks implementation:** Yes — Wave 6 (audit §16) is explicitly "unified floating panel model... replacing `DockablePanel`/`PanelDockSlot`/`InstrumentDock`."
- **Decision owner:** Studio architecture owner.
- **Resolve before:** Wave 6. Full behavioural spec already provided in §23.14 of this document — the remaining decision is implementation ownership/timing, not behaviour.

### 29.8 V2 simulation state vs. OEP simulation architecture

- **V2:** hard-coded, vehicle-specific switch pack (`SWPACK`) with a per-wire reading-override table (§7.4); dormant, unwired solver modules (§17.8) that were evidently intended to replace the override table but never were connected.
- **OEP:** generic, profile-driven (`DomainProfile`/`InputStateDefinition`), computed via live `SimulationEngine`, with an explicit "no fabricated default" discipline that requires a loaded profile before anything renders.
- **Why they differ:** V2 is a single-vehicle demo with authored data; OEP is a generic engine meant to serve arbitrary domain profiles.
- **Blocks implementation:** Partially — the *generic* switch-indicator/KEY-row presentation (§7.7 items 1–2) is not blocked, since it maps cleanly onto existing `DiagramSimulationService` capability. The *specific* TRX300 switch-pack panel with its hard-coded schematics (§7.2–7.3) is vehicle content, not Studio architecture, and is out of scope for "is this required" without a scoping decision.
- **Decision owner:** Product/scope owner (is a reference-vehicle demo panel in scope for the reconstruction, or does the reconstruction only need the generic mechanism it's built on?).
- **Resolve before:** Wave 3 (KEY/SWITCHES row is built there) for the generic case; indefinite/optional for the vehicle-specific switch-pack panel.

### 29.9 Deliberate, recorded deviations (not conflicts requiring a decision, but requiring sign-off that they are acceptable)

Collected from callouts throughout this document. These are cases where V2 and OEP differ, a ruling was made in this document, and the ruling favours **not** reproducing a V2 limitation because doing so would regress an existing OEP capability with no fidelity benefit. Listed together for a single review pass:

1. Fit-on-window-resize (§4.8, §9.10 item 8, §26.8 item 4) — not reproduced; conflicts with persisted `ViewState`.
2. Tooltips (§6.5 item 4) and contextual disabled states (§6.5 item 5) on toolbar controls — kept from OEP; V2 has neither.
3. Live connection-preview validity colouring (§14.10 item 3) — kept from OEP; V2 has no such feedback.
4. Legend listing all categories unconditionally, not just present ones (§19.6 item 2) — **this one is the opposite direction**: it is V2's behaviour being adopted **over** OEP's current (arguably better) filtered behaviour, purely for fidelity. Flagged for explicit sign-off since it's a rare case of fidelity requiring OEP to regress a nicety.
5. OEP's minimap `_showMiniMap` runtime toggle (§20.7 item 3) — kept; V2 has no toggle to conflict with.
6. OEP's wire rendering on the minimap (§20.7 item 2) — kept as additive; V2 draws nodes only.
7. Not adopting V2's right-click-selects-for-wires-but-not-modules asymmetry (§21.7 item 2) — OEP's existing independent-targeting behaviour is kept.
8. The `/`-vs-`?` V2 self-conflict (§24.8 item 5) — reproduced as-is, not fixed, per the "do not improve V2" rule; flagged here only so it is not mistaken for an oversight in a later review.
9. V2 uses dark chrome around a light diagram canvas, in **both** its "dark" and "light" themes — this is directly established by V2 source (§9.7: `--canvas-bg` is `#f5f2eb`/`#fbfaf6`, a light parchment tone in both `[data-theme="dark"]` and `[data-theme="light"]`, while the surrounding chrome uses the dark `--surf-*` tokens regardless of theme name). The open question is whether the OEP reconstruction reproduces this exact V2 behavior — a light canvas inside dark chrome in both themes — or instead applies an OEP theme convention (e.g. an all-dark canvas, or a canvas that itself flips light/dark with the theme). This is a deliberate visual-fidelity decision, not yet ruled on anywhere in this document, and requires sign-off before Wave 3 (first visible chrome). No decision is invented or implied here.
10. Keyboard focus-visible styling (§5.9 item 6) — added; V2 has none for any control.

**Decision owner for this whole cluster:** whoever signs off the acceptance criteria (§30) — these do not block any Wave individually, but should be reviewed as a batch before Wave 3 (first visible chrome) so they are not discovered piecemeal during implementation.

### 29.10 New conflict: OEP model fields with no confirmed source (not in the original audit's conflict list)

- **V2 fields with no confirmed OEP equivalent:** wire colour code (`w.c`, drives hex/name/stripe/flow-colour resolution throughout §5.4/§11); module `bulb`/`connector` shape flags (§10.1); connector pin `IN|OUT` dual-colour encoding (§10.4).
- **Why this matters:** every one of these is load-bearing for *visual* fidelity (§10–11), not just data modelling — without them, cards/wires cannot render in V2's visual language at all, only in a colourless/uniform-shape approximation of it.
- **Blocks implementation:** Yes, for Wave 4 (canvas construction).
- **Decision owner:** OEP data model owner (Engine or symbol-library maintainer) — this may require new `Port`/`EngineeringNode`/symbol-metadata fields, which, per the frozen-Engine constraint (§3.1), would itself need to be escalated as a separate Engine architecture decision if no existing field/metadata convention covers it.
- **Resolve before:** Wave 4.

### 29.11 New conflict: fixed-size vs. content-sized nodes (not in the original audit's conflict list)

- **V2:** cards size to content, no fixed dimension (§10.5).
- **OEP:** fixed `100×100` nodes (`_nodeSize`), resizable via `ResizeNodeCommand`, but not auto-sizing to content.
- **Why this matters:** affects hit-testing geometry, drag/resize interaction, port anchor placement, and how much visual information a card can show before truncation.
- **Blocks implementation:** Partially — card *shape* (§10.1–10.4) can be built within a fixed footprint as an approximation, but true content-sizing (cards growing/shrinking with terminal count, as V2's do) would require either a new auto-size Engine capability or accepting a fixed-footprint approximation.
- **Decision owner:** Studio/Engine architecture owner.
- **Resolve before:** Wave 4 (non-blocking if a fixed-footprint approximation is accepted; blocking if true content-sizing is required for fidelity sign-off).

### 29.12 New conflict: V2 topbar row-1 horizontal-scroll vs. OEP's test-validated wrap behaviour (not in the original audit's conflict list)

Fully stated in §26.8 item 2. **Decision owner:** whoever owns the existing interaction test suite (the same tests that drove OEP's original `Wrap` decision must either be updated to tolerate scroll-based overflow, or row 1's control set must be kept small enough to never overflow at the tested viewport widths). **Resolve before:** Wave 3.

---

## 30. Acceptance Criteria

Each criterion is testable and cites the section that defines the exact expected value.

### 30.1 Visual fidelity

- [ ] All 35 tokens × 2 themes (§5.1) render at the exact hex values specified, verifiable by sampling rendered pixel colour against the token table.
- [ ] Every hard-coded (non-tokenised) colour in §5.2 appears at its specified value in its specified context.
- [ ] Category colours (§5.3) and wire colour codes (§5.4) resolve identically to V2's `h()`/`trH()`/`cn()` functions given the same input.
- [ ] Typography scale (§5.5), radii/spacing/transitions/opacity (§5.6) match within the tolerance of Flutter's logical-pixel rendering of the same nominal values.
- [ ] Window/topbar/sidebar/viewport geometry (§4) matches specified dimensions and anchors.
- [ ] Module card shapes (standard/bulb/connector, §10.1–10.4) are visually distinguishable per V2's construction, including terminal strip placement rules.
- [ ] Wire rendering states (normal/selected/traced/dimmed/bi-colour/flow, §11.2–11.8) are each independently verifiable against a diagram with wires in each state simultaneously.
- [ ] Multimeter SVG instrument (§17.1) matches V2's `viewBox`, element geometry, and colour values.

### 30.2 Interaction fidelity

- [ ] Tool-mode mutual exclusion and activation/deactivation cascade (§8.1) reproduced exactly, per the resolution of §29.3.
- [ ] Wire creation two-click state machine (§14.1–14.5), including duplicate-rejection and same-terminal-cancel, verified by scripted interaction test.
- [ ] Module drag: 10 px (or OEP-confirmed) grid snap, non-negative clamp, live re-route during drag (§13.3).
- [ ] Selection feedback (endpoint highlight, dim-others, flash) verified for the single-selection case (§12.6–12.8).
- [ ] Context menu content-per-target-type matrix (§21.3) reproduced for wire and module contexts at minimum.
- [ ] Floating panel drag/resize/explicit-save-persistence (§23.3–23.9) verified: a panel dragged and reloaded without "Set as Default" reverts; a panel dragged, saved, and reloaded retains position.

### 30.3 Keyboard fidelity

- [ ] Every row of §24.1's dispatch table fires the correct action, in the correct precedence order, with the input-focus guard active.
- [ ] The merged Escape cascade (§24.2 + OEP's existing steps, per §24.8 item 2) dismisses the topmost active state and no other, verified by testing from each of the 9+ V2 states plus OEP's connection-in-progress state.
- [ ] `Delete` semantics match the resolution of §24.8 item 3 (scope + Layout-Edit-mode guard).

### 30.4 Canvas behaviour

- [ ] Zoom bounds `[0.15, 3]`, button increment `0.15`, Ctrl/Cmd+wheel increment `0.1`, unmodified scroll does not zoom (§9.2, §9.10 items 1–2).
- [ ] Cursor-anchored zoom for wheel/pinch, origin-anchored for buttons (§9.2/§9.10 item 3) — verified by checking the scene point under the cursor remains fixed across a wheel-zoom, and does not for a button-zoom.
- [ ] Fit calculation matches §9.4's formula against Engine-computed content size (§9.10 item 4).
- [ ] Viewport culling active above a defined object-count threshold, with no visible pop-in within a reasonable pan speed (§9.6/§9.9, performance-adjacent — see §30.11).

### 30.5 Wire behaviour

- [ ] Dim rule (§11.4) implemented as one shared mechanism for both selection-dim and trace-dim (§11.11 item 2).
- [ ] Flow animation timing (1.2px/frame, 12/8 dash/gap) and start/stop-on-presence-check (§11.8/§25.1) verified against a wire with an active, non-zero, non-`OPN` reading.
- [ ] Route-edit keyboard nudge (6px/24px-Shift) reproduced **only after §29.1 resolution** — this criterion is conditionally testable, blocked on that decision.

### 30.6 Module behaviour

- [ ] Bulb glow condition (§10.7) verified against the resolved key-state equivalent.
- [ ] Card shape selection (standard/bulb/connector) verified once §29.10 resolves the underlying data field.

### 30.7 Instrument behaviour

- [ ] Five meter modes, dial pointer angles, `CONT`-special display (§17.2) verified against `MultimeterController.latestResult` for each mode.
- [ ] Four lead-placement modes (§17.3) verified for correct auto-placement target selection (`ends`/`gnd`/`pwr`) and correct no-op-until-click behaviour (`manual`).
- [ ] Cross-panel lead-wire visualization (§17.6) verified to connect the correct jack to the correct terminal at the correct screen coordinates after a pan/zoom change.

### 30.8 Panel behaviour

- [ ] Unified panel model supports drag (any edge/corner per implementation decision, minimum bottom-right per V2, §23.5), resize with correct min/max per §23.6, and the 4-item `⋮` menu with exact per-command effects (§23.8).
- [ ] Sidebar pop-out/dock-back (§23.12) verified to share state correctly between the docked and floating presentation of the same logical panel.

### 30.9 Persistence behaviour

- [ ] `DiagramDocument`/`DiagramWorkspaceState`/`DiagramTabsStorage`/`DiagramStudioSettings` separation maintained — verified by a test asserting no engineering-data field ever appears in a `DiagramWorkspaceState` JSON dump (§12.4 of the audit, §3.6 of this document).
- [ ] Panel geometry persists only on explicit save, not on every drag (§23.9/§23.14 item 3), verified by the reload test in §30.2.

### 30.10 Simulation behaviour

- [ ] KEY row and generic SWITCHES indicators render only when a `DomainProfile`/session provides real states (no-fabrication rule preserved, §7.7 item 1).
- [ ] Reading resolution sources from `MeasurementResult`, not an authored table, once §8.5/§29 (audit) resolves the data model (§7.7 item 3) — conditionally testable.

### 30.11 Performance

- [ ] No regression against the existing benchmark (40,000 wires ≈ 179 ms/paint or better) after V2-style per-wire rendering (glow/stripe/flow/label layers) is added — re-run `test/performance/rendering_performance_test.dart`-equivalent after Wave 4.
- [ ] Flow animation `requestAnimationFrame` loop starts/stops based on presence of active flow overlays, not running unconditionally (§11.8/§25.1), verified by confirming no animation ticks occur when zero wires have flow.

---

## Implementation Authority

1. This document governs the Diagram Studio reconstruction.
2. The V2 source governs observable reference behavior.
3. OEP Engine governs engineering truth.
4. OEP Foundation governs repository/persistence truth.
5. The future Studio Controller mediates between V2-compatible UI and OEP.
6. No reconstruction implementation may modify frozen Engine/Foundation components without a separate explicit architecture decision.
7. V2 behavior must not be silently changed to accommodate OEP.
8. OEP engineering semantics must not be silently changed merely to reproduce V2 presentation behavior.
9. Any unresolved conflict must be explicitly documented and escalated as an architecture decision.

**Unresolved items requiring escalation before the Wave each is attached to, per §29:**

| § | Conflict | Blocks |
|---|---|---|
| 29.1 | Route override model | Wave 5 |
| 29.3 | Tool modes vs. document modes | Wave 3 |
| 29.4 | V2 inspector vs. shared Property Inspector | Wave 3 |
| 29.5 | Routing geometry fidelity scope | Wave 4 (conditional) |
| 29.7 | Panel persistence unification | Wave 6 |
| 29.8 | Switch-pack scope (generic vs. vehicle-specific) | Wave 3 (generic case), indefinite (vehicle-specific) |
| 29.9 | Batch of deliberate deviations | Wave 3 (review, not a blocker) |
| 29.10 | Wire colour / bulb / connector data fields | Wave 4 |
| 29.11 | Fixed-size vs. content-sized nodes | Wave 4 (conditional) |
| 29.12 | Topbar row-1 scroll vs. tested wrap behaviour | Wave 3 |

Nothing in this document authorises implementation. This specification becomes actionable only once each item above attached to a given Wave is resolved by its stated decision owner, and only within the scope of the Wave the audit (`docs/DIAGRAM_STUDIO_RECONSTRUCTION_AUDIT.md`, §16) already defines.

**STOP. Wave 0 complete. Do not proceed to Wave 1.**

