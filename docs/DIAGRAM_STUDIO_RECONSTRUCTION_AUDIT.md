# Diagram Studio Reconstruction Audit (AP-DIAGRAM-001)

**Status:** Read-only audit. No source file was modified, deleted, renamed, or refactored to produce this document.
**Scope audited:** `oep_studio/lib/diagram_studio/` (79 Dart files, 13,947 lines) plus every directly referenced Studio dependency required to understand its architecture, plus the canonical reference implementation at `reference/legacy_wiring_sim_v2/eke-wiring-sim/`.
**Reference implementation:** Wiring Simulator V2 (EKE) — `index.html` (838 lines), `css/main.css`, `js/diagram/renderer.js`, `js/editor/*`, `js/ui/*`.
**Formal V2 Reconstruction Specification:** not yet supplied. Every statement below about V2 is derived from reading the V2 source directly; where the spec is required to settle a question, the item is filed under **UNKNOWN** (§8).

---

## 1. Executive Summary

### 1.1 What was found

The current Diagram Studio is **not disposable**. It contains a substantial, genuinely working Engineering Engine integration that took multiple work packages (WORK_PACKAGE_024/025, AP-DS-001…006, WP-DS-005A) to build, and which the V2 reference has no equivalent of at all: an undoable Engine command pipeline, a shared cross-route project/session/selection state, a Foundation-backed Intelligence service, a Simulation Engine session model, an Instruments runtime with a real measurement bridge, a publishing/report pipeline, and a document/persistence model.

What is genuinely wrong is **not the engineering layer — it is the presentation and interaction layer, and the place that layer lives.**

Three structural facts dominate this audit:

1. **`workspaces/diagram_studio_page.dart` is a 3,785-line monolith** that simultaneously acts as: composition root, interaction controller (selection, drag, resize, connect, reconnect, route-edit, box-select, pan), viewport/transform reconciler, document lifecycle coordinator, panel layout manager, dock manager, toolbar host, Property Inspector bridge, Intelligence trigger, Simulation overlay coordinator, probe-arming controller, and the home of nine private presentation widgets. There is no controller/adapter layer between the Engine and Flutter. This single file is the primary obstacle to a V2-faithful rebuild.

2. **The diagram renderer does not live in Studio — it lives inside the Engine package.** `GraphViewPanel` (469 lines), `SymbolNodeWidget` (378), `WirePainter`, `AnnotationWidget`, `WireEditHandles`, `ResizeHandles`, `ReconnectHandle`, `GridPainter`, `GuidesPainter`, `ConnectionPreviewPainter` are all in `oep_engine/lib/views/widgets/`. The target architecture requires a V2-compatible presentation layer, and the Engine is frozen for this work. This is the single most important architectural boundary decision in the whole reconstruction (see §12).

3. **A previous attempt at V2 fidelity already exists inside the monolith and is half-finished.** "Phase 14 (UI Layout Ratification)" added `_ImmersiveColors` (three colour tokens lifted from `css/main.css`), `_ImmersiveInspectorSidebar` (a two-tab Inspector/Meter sidebar modelled on V2's `#left-sidebar`), `_KeySwitchesRow` (modelled on V2's KEY/SWITCHES topbar row), `_DiagramLegendPanel` (modelled on `#legend`), a wire-create two-click mode, and a shell carve-out in `studio_shell.dart:370` giving Diagram Studio the whole window. These are directionally correct but were bolted onto the existing widget tree rather than replacing it, so the workspace now carries **two competing chrome systems at once** (V2-style immersive strip + twelve `IconButton` toolbar groups + `DockablePanel` slots + `InstrumentDock` + `KnowledgePanel` column). Reconstruction must finish this transition, not restart it.

### 1.2 Classification totals

| Class | Count | Share of audited components |
|---|---|---|
| KEEP | 38 | Engineering model, services, storage, runtime, reports |
| ADAPT | 21 | Presentation-coupled but behaviourally correct |
| REPLACE | 19 | Chrome, canvas host, toolbars, monolith page |
| DEPRECATE | 6 | Dead or superseded |
| UNKNOWN | 9 | Blocked on the V2 Reconstruction Specification or on model-mapping confirmation |

### 1.3 The one-sentence finding

> Rebuild the *window* — canvas host, chrome, panels, interaction routing — as a Studio-owned V2-compatible presentation layer; preserve the *engine-facing* half entirely — commands, document, session, selection, routing, simulation, instruments, intelligence, persistence — and put the architectural boundary at a new **Studio Controller / Adapter** layer that sits between `EngineeringProjectState` and the new presentation, absorbing every interaction handler currently embedded in `diagram_studio_page.dart`.

---

## 2. Current Diagram Studio Architecture

### 2.1 Directory inventory

```
lib/diagram_studio/                              13,947 lines / 79 files
├── ai/                    2 files    119 lines  AI request assembly (no UI coupling)
├── commands/              1 file      58 lines  Undo/redo/clipboard facade over engine
├── context_menu/          1 file     143 lines  showMenu host for contextual commands
├── host/                  2 files    356 lines  Engine lifecycle + document file model
├── inspector/             8 files    331 lines  Property Inspector modes (shared panel)
├── instruments/          12 files  1,470 lines  Instrument framework, DMM, dock, probes
├── instruments_host/      2 files    198 lines  OIP hardware bridge
├── intelligence/          1 file     246 lines  Foundation Intelligence orchestration
├── migration/             2 files    315 lines  Legacy file migration (dialog + models)
├── panels/               14 files  1,594 lines  Explorer/Layers/Search/Annotations/EI panels
├── persistence/           4 files    270 lines  Workspace state, recent files/projects
├── publishing/            8 files  1,392 lines  Reports, title block, publishing centre
├── repository/            1 file     361 lines  Foundation repository sync + migration
├── settings/              4 files    336 lines  Diagram Studio preferences
├── simulation/            8 files  1,599 lines  Simulation service + panels + overlay
├── tabs/                  5 files    509 lines  Multi-document tabs + mode switcher
├── toolbars/              1 file     653 lines  Twelve toolbar groups
└── workspaces/            1 file   3,785 lines  DiagramStudioPage (the monolith)
```

### 2.2 Layer reality vs. layer intent

The intended layering (per `docs/architecture/diagram_studio/ARCHITECTURE_SPECIFICATION.md` and the engine's own `CLAUDE.md`) is "Studio orchestrates, Engine executes." That rule is **honoured for data** and **violated for interaction**:

| Concern | Where it actually lives today | Correct? |
|---|---|---|
| Graph / relationships / groups / ports | `oep_engine` `EngineeringGraph` | ✅ |
| Layout, annotations, layers, wire routes | `oep_engine` `DiagramLayoutState` | ✅ |
| Undoable mutation | `oep_engine` `EditingService` + `*Command` | ✅ |
| Selection | `oep_engine` `SelectionService` | ✅ |
| Viewport (zoom/pan/grid/guides) | `oep_engine` `ViewStateService` | ✅ |
| Routing geometry | `oep_engine` `OrthogonalRoutingProvider` | ✅ |
| Scene assembly | `oep_engine` `DiagramView.render → DiagramScene` | ✅ |
| Hit testing | `oep_engine` `DiagramHitTesting` | ✅ |
| **Canvas rendering (Flutter widgets)** | **`oep_engine/lib/views/widgets/`** | ⚠️ Engine owns presentation |
| **Gesture → command translation** | **`diagram_studio_page.dart` (inline)** | ❌ No controller layer |
| **Interaction mode state** | **`diagram_studio_page.dart` (bool fields)** | ❌ Ad-hoc |
| **Drag/resize/route preview geometry** | **`diagram_studio_page.dart` (inline)** | ❌ View-local, duplicated |
| Chrome (toolbars/panels/docks) | `diagram_studio/toolbars`, `panels`, page | ✅ location, ❌ design |

### 2.3 Responsibilities embedded in `diagram_studio_page.dart`

Enumerated exhaustively, because item 1 of the "specifically audit" list requires it. Line references are to the file as audited.

| # | Responsibility | Members | Lines |
|---|---|---|---|
| 1 | Engine/session bootstrap and teardown | `_bootstrap`, `initState`, `dispose` | 500–655 |
| 2 | Instrument registry + dock construction | `_initInstruments`, `_instruments`, `_dockController` | 278–296 |
| 3 | Intelligence service lifecycle + debounced sync | `_intelligence`, `_scheduleIntelligenceSync`, `_validateNow`, `_analyzeSelectedNode` | 230–232, 719–772 |
| 4 | Validation/analysis overlay marker translation | `_validationMarkerNodeIds`, `_analysisHighlightNodeIds` | 799–813 |
| 5 | Simulation session/overlay coordination | `_simulationService`, `_refreshSimulationOverlay`, `_openSimulationCenter` | 265–335 |
| 6 | Domain profile loading (file picker → session) | `_loadDomainProfile`, `_domainProfile` | 180–219 |
| 7 | Document lifecycle + dirty confirmation | `_newDocument`, `_openDocument`, `_saveDocument`, `_saveAsDocument`, `_closeDocument`, `_confirmDiscardChanges` | 815–886 |
| 8 | Tab lifecycle (open/close/activate/reopen) | `_closeTab`, `_activateTab`, `_reopenRecentlyClosed`, `_showRecentlyClosedMenu` | 896–977 |
| 9 | Workspace state persistence | `_persistWorkspaceState`, `_cachedDocumentPath`, `_cachedViewState` | 366–374, 610–621 |
| 10 | Property Inspector bridging | `_syncPropertyInspectorSelection`, `_selectLayerInInspector` | 659–699 |
| 11 | Viewport/transform two-way reconciliation | `_applyTransformFromViewState`, `_syncViewStateFromTransform`, `_ensureViewportSize` | 983–1007 |
| 12 | Fit/centre/selection-bounds maths | `_selectionBounds`, `_fitAll`, `_fitSelection`, `_centerSelection`, `_boundsForNodes`, `resetView` | 1009–1040, 2218–2241 |
| 13 | Node creation / delete / group / ungroup | `_addNode`, `_deleteSelection`, `_groupSelection`, `_ungroupSelection` | 1044–1087 |
| 14 | Undo/redo/clipboard incl. OS clipboard fallback | `_undo`, `_redo`, `_copy`, `_cut`, `_paste`, `_duplicateSelection` | 1089–1138 |
| 15 | Selection interaction + modifier semantics | `_additiveModifierPressed`, `_toggleModifierPressed`, `_spacePressed`, `_handleNodeTap`, `_handleBackgroundTap` | 1142–1188 |
| 16 | Contextual (right-click) menu targeting | `_handleSecondaryTap`, `_handleNodeSecondaryTap`, `_handlePortSecondaryTap`, `_handleAnnotationSecondaryTap`, `_openContextualMenu` | 1190–1326 |
| 17 | Background pan / box-select | `_handleBackgroundPanStart/Update/End`, `_boxSelectRect`, `_panStartPan` | 1328–1367 |
| 18 | Hover / cursor scene position | `_handleHover`, `_cursorScenePosition` | 1369–1381 |
| 19 | Node dragging + smart guides + snapping | `_siblingBounds`, `_draggedGroupBounds`, `_handleNodeDrag*`, `_snappedDragPositions`, `_effectiveLayout` | 1390–1524 |
| 20 | Node resize (corner handles, min size) | `_handleNodeResize*`, `_previewResize`, `_minNodeSize` | 1526–1616 |
| 21 | Port anchoring + drag-to-connect | `_portAnchor`, `_nodeAt`, `_handlePort*` | 1618–1765 |
| 22 | Two-click Wire-create mode | `_wireCreateModeActive`, `_handleWireCreateModePortTap` | 1699–1732 |
| 23 | Drag-to-reconnect wire endpoints | `_reconnectingWire`, `_handleReconnectDrag*` | 1767–1813 |
| 24 | Annotation create/move/edit/delete | `_effectiveAnnotations`, `_addAnnotation`, `_handleAnnotation*`, `_editAnnotationText`, `_deleteAnnotation` | 1815–1909 |
| 25 | "Edit Route" wire vertex/segment editing | `_reseedWireEditPoints`, `_toggleWireEditMode`, `_insertWireVertex`, `_removeWireVertex`, `_restoreAutomaticRouting`, `_handleWireCorner*`, `_handleWireSegment*` | 1911–2061 |
| 26 | Placement tools (rotate/mirror/array/replace) | `_rotateSelection`, `_mirrorSelection`, `_openArrayPlacement`, `_replaceSymbol` | 2063–2095 |
| 27 | Align / distribute | `alignSelection`, `distributeSelection` | 2105–2121 |
| 28 | Layer CRUD | `_createLayer`, `_deleteLayer`, `_toggleLayerVisible`, `_toggleLayerLocked` | 2123–2152 |
| 29 | Search execution + result navigation | `_runSearch`, `_goToSearchResult` | 2154–2213 |
| 30 | Panel visibility state (11 booleans) | `_showLayerPanel` … `_showSessionsPanel`, `_applyModeDefaults`, `_anySidePanelVisible` | 92–107, 233–237, 477–498 |
| 31 | Dock slot assignment + slot resizing | `_panelSlot`, `_slotSize`, `_movePanel`, `_resizeSlot` | 137–161 |
| 32 | Panel width state | `_explorerWidth`, `_sidePanelsWidth` | 363–364 |
| 33 | Keyboard shortcut table | `CallbackShortcuts` bindings | 2334–2362 |
| 34 | Toolbar composition (12 groups) | `build` `Wrap` | 2448–2599 |
| 35 | Canvas stack composition (5 overlays) | `build` `LayoutBuilder`/`Stack` | 2644–2840 |
| 36 | Side-panel column composition (9 panels) | `build` | 2844–2974 |
| 37 | Nine private presentation widgets | `_ImmersiveInspectorSidebar`, `_ImmersiveSidebarTabButton`, `_ImmersiveInspectorPane`, `_ImmersiveMeterPane`, `_KeySwitchesRow`, `_KeySwitchGroup`, `_KeySwitchButton`, `_DiagramLegendPanel`, `_DocumentActionsBar`, `_ResizeHandle`, `_VerticalResizeHandle`, `_InstrumentToolbar`, `_IntelligenceToolbar` | 3038–3785 |

**37 distinct responsibilities in one `State` class.** Of these, only #1–#12 and #29 belong anywhere near a composition root; #13–#28 belong in a controller; #30–#37 belong in the presentation layer.

### 2.4 The V2 reference model (as read from source)

| V2 concept | V2 implementation | OEP counterpart today |
|---|---|---|
| Window layout | `#topbar-wrap` (2 rows) + `#main-area` = `#left-sidebar` \| `#viewport` | Immersive strip + Wrap toolbar + 4 dock slots + explorer + canvas + side column |
| Left sidebar | Permanent, 2 tabs: Inspector / Meter, each pop-out-able (`popOut`/`dockIn`) | `_ImmersiveInspectorSidebar` inside a `DockablePanel` in the left slot |
| Modes | 3 booleans: `editMode` (Layout), `wireMode`, `routeEditMode` — mutually exclusive, with `#edit-badge`/`#wire-badge` and a `#wep` status bar | `DiagramStudioMode {view, edit, simulate}` per tab + `_wireEditModeActive` + `_wireCreateModeActive` |
| Module presentation | DOM `.mod-card` with `.cat-stripe`, terminal strip of `.t-dot` colour dots, `.mod-label` + `.mod-sub`; three card shapes (standard / bulb / connector) | `SymbolNodeWidget` (engine), symbol-asset driven, `categoryStripeColor` |
| Wire presentation | SVG `<g>` per wire: glow, coloured main path, dashed stripe for bi-colour, wide transparent hit path, flow animation overlay, midpoint label chip | `WirePainter` (engine) — flat polylines, no stripe/glow/flow/label |
| Selection | `selWire`/`selMod` — single-select, toggles off on re-click, dims all other wires to 10% opacity, highlights both endpoint cards | `GraphSelection` — multi-select sets, additive/toggle modifiers, box-select |
| Dragging | `setupDrag(card)` per card, layout-edit mode only | `_handleNodeDrag*` + `MoveNodesCommand`, any mode, multi-node, with alignment guides |
| Wire editing | Route-edit mode: click a *segment*, arrow-keys nudge by 6px (24 with Shift), `R` resets; stored as `wireRoutes[id][segIdx] = offset` | Vertex/segment *drag*, absolute point list via `SetWireRouteCommand` |
| Wire creation | Wire mode: click source terminal → click destination terminal; duplicate detection; opens props modal | Drag port→port, or two-click Wire mode; `ConnectionValidator` + `CreateRelationshipCommand` |
| Routing | `route(w)` with `allocX`/`allocY` 6px lane allocation, per-module `exit` direction, `STUB=14` | `OrthogonalRoutingProvider` with `RoutingContext` lane + trunk allocation, obstacle sweep |
| Zoom/pan | `scale`/`tx`/`ty` on `#scene` transform; Ctrl+wheel zoom at cursor, background drag pan, `zReset()` fit, pinch | `ViewState` + `TransformationController` + `InteractiveViewer` (`panEnabled: false`, space-drag pan) |
| Meter | Photoreal 220×380 SVG multimeter: LCD, function dial, 5 mode buttons, 4 jacks, lead plugs; leads placed on terminals with 4 placement modes | `DigitalMultimeterPanel` (Material controls) + `ProbeOverlay` + `MultimeterController` |
| Key state | `keyPos` 0–3 (Off/On/Crank/Run), driven from topbar, sidebar, and `0`–`3` keys; plus `SWPACK` handlebar switch panel | `SimulationSession.activeOperatingStateId` / `activeInputStates` + `_KeySwitchesRow` |
| Search | Floating `#srch` overlay, `/` key, live results, click → `scrollToMod`/select wire | `DiagramSearchPanel` docked in the right column |
| Legend | Floating `#legend`, `L` key | `_DiagramLegendPanel` in a dock slot |
| Minimap | `#minimap` canvas + `#mm-vp` viewport box, **click to centre** | `DiagramMiniMap` wrapped in `IgnorePointer` — **not clickable** |
| Context menu | `#ctx`: Edit / Trace / Delete | `showDiagramContextMenu` + `ContextualCommandResolver` (capability-driven) |
| Panels | Free-floating, drag by header, resize grip, per-panel `⋮` menu (set default / reset / centre / reset size), persisted to `localStorage` | `DockablePanel` in 4 fixed slots, shared slot thickness, no persistence |
| Theme | `data-theme` light/dark toggle persisted to `localStorage` | Dark only (`StudioColors` + `_ImmersiveColors`) |
| Trace | `#tracer` panel listing wires in the traced sub-graph, dims everything else | No equivalent in the primary workspace |

---

## 3. Current Dependency Graph

### 3.1 Inbound — what outside `lib/diagram_studio/` depends on it

These are the edges that break if a file is removed. Verified by import scan.

| Consumer | Imports from `diagram_studio/` | Breakage risk if removed |
|---|---|---|
| `core/services/engineering_project_service.dart` | `host/diagram_document.dart`, `host/engine_host.dart`, `settings/diagram_studio_settings_provider.dart` | **CRITICAL** — the shared project provider used by Validation, Search, Project Explorer, Workbench, Command Registry |
| `core/commands/command_registry.dart` | `commands/studio_command_actions.dart` | HIGH — global command palette undo/redo/clipboard |
| `core/context/contextual_command_definitions.dart` | `ai/diagram_ai_service.dart` | MEDIUM — contextual "Ask AI" command |
| `core/context/engineering_interaction_context.dart` + `_builder.dart` | `instruments/multimeter/multimeter_controller.dart`, `simulation/diagram_simulation_service.dart` | HIGH — capability resolution for every contextual menu |
| `core/services/unified_ai_context_service.dart` | `ai/diagram_prompt_context.dart` | MEDIUM |
| `core/routing/studio_registry.dart` | `settings/diagram_studio_settings_page.dart` | MEDIUM — Studio registry descriptor |
| `shared/widgets/property_inspector_panel.dart` | all 8 files in `inspector/` | **HIGH** — the shared Property Inspector's diagram modes |
| `features/copilot/copilot_page.dart`, `features/validation/validation_page.dart` | `ai/diagram_ai_service.dart` | MEDIUM |
| `features/project_explorer/project_explorer_page.dart` | `persistence/recent_projects_storage.dart` | MEDIUM |
| `workbench/perspectives/diagram_perspective.dart` | `workspaces/diagram_studio_page.dart` | **HIGH** — Workbench Diagram Perspective centre |
| `workbench/perspectives/instruments_perspective.dart`, `instrument_dock_panel_client.dart` | `instruments/core/engineering_instrument.dart` | HIGH — Instruments Perspective |
| `app/studio_shell.dart` | (behavioural) full-window carve-out at `:370` for `StudioDestination.diagram` | HIGH |

**51 test files** reference Diagram Studio symbols, including 12 workflow tests that drive `DiagramStudioPage` directly (`diagram_studio_interaction_test.dart`, `_edit_mode_`, `_view_mode_`, `_simulate_mode_`, `_tabs_and_modes_`, `_wire_create_mode_`, `_key_states_panel_*`, `_legend_panel_`, `diagram_hit_testing_widget_test.dart`, `diagram_context_menu_test.dart`).

### 3.2 Outbound — what `diagram_studio/` depends on

```
diagram_studio/
├── package:engineering_engine  ← graph, layout, commands, selection, viewstate,
│                                 routing, symbols, search, validation, simulation,
│                                 clipboard, exporters, AND the canvas widgets
├── package:oep_instruments_runtime  ← OIP host bridge (instruments_host/)
├── core/foundation/            ← FoundationBridge, OepApiTypes  (intelligence, repository)
├── core/services/              ← engineeringProjectServiceProvider, foundationRuntimeServiceProvider
├── core/context/               ← contextual command resolver + interaction context
├── core/models/                ← EngineeringInspectable, ObjectCategory, RelationshipType
├── core/theme/studio_colors    ← every widget
├── core/routing/               ← StudioDestination
├── knowledge/                  ← AiRequest/AiResponse/AiProviderRegistry, KnowledgePanel widget
├── engineering_intelligence/   ← ei_widgets (EI panel primitives)
├── settings/services/          ← SettingsStorage.root() (every persistence file)
└── shared/widgets/             ← PropertyField, DockablePanel, PanelDockSlot,
                                  OepListView, ValidationFindingsList
```

### 3.3 The critical cycle

```
studio_shell / workbench  ──►  DiagramStudioPage  ──►  engineeringProjectServiceProvider
                                                              │
                               diagram_studio/host/  ◄────────┘   (EngineHost, DiagramDocument)
                               diagram_studio/settings/ ◄─────┘   (settings provider)
```

`core/services/engineering_project_service.dart` — a **core** service — imports **three files out of `diagram_studio/`**. This means `host/` and `settings/` are, in practice, *platform* components that happen to be filed under `diagram_studio/`. Any reconstruction that treats everything under `lib/diagram_studio/` as replaceable UI will break the shared project provider and, transitively, Validation, Search, Project Explorer, the Command Registry, and the Workbench. This is recorded as a hard constraint in §15.

---

## 4. KEEP Components

*Existing implementation should remain substantially intact. Each entry gives: (3) current responsibility, (4) current dependencies, (6) reason, (7) what must be preserved, (8) what must change, (9) what breaks if removed.*

### 4.1 Engine & document boundary — `host/`

**`host/engine_host.dart` — `EngineHost`**
- **Responsibility:** Engine lifecycle only — `EngineeringEngine.create()`, `initialize()`, load the 14 seed symbols from `packages/engineering_engine/assets/symbols/*.json` via `rootBundle`, `beginSession`, `dispose`.
- **Dependencies:** `engineering_engine`, `flutter/services (rootBundle)`.
- **Reason:** 66 lines, zero engineering logic, zero UI. It is the *only* place in the app that constructs the Engine, and it exists specifically because `SymbolLibrary` is Flutter-independent and needs a Studio-side asset loader.
- **Preserve:** the whole class, verbatim. `_seedSymbolIdentifiers` must stay in sync with the engine's asset set.
- **Change:** nothing for the V2 rebuild. (Future: symbol set will need V2's category-driven card shapes — that is a *renderer* concern, not a loader concern.)
- **Breaks if removed:** `EngineeringProjectNotifier.ensureEngineStarted()` → the shared provider → Validation page, Search, Project Explorer, Command Registry, Workbench, every workflow test.
- **Note:** this file is mis-filed. It is a platform component under a studio directory (§3.3).

**`host/diagram_document.dart` — `DiagramDocument`, `DiagramDocumentMetadata`, `DiagramRecoveryCandidate`**
- **Responsibility:** the on-disk document — `{schemaVersion, documentId, graph, layout, metadata}` JSON envelope; open/save/saveAs/close; dirty flag; autosave to a separate recovery file under `SettingsStorage.root()/autosave/`; crash-recovery discovery (`findRecovery`, `recoverFrom`).
- **Dependencies:** `dart:io`, `dart:convert`, `engineering_engine` (`EngineeringGraph.toJson`, `DiagramLayoutState.toJson`), `settings/services/settings_storage.dart`.
- **Reason:** This is **engineering data persistence**, categorically distinct from the UI state in `persistence/`. It composes two already-serialisable engine types and adds nothing of its own. It is also the documented workaround for Foundation having no diagram-layout schema (`docs/REPOSITORY_INTEGRATION.md`), which the V2 rebuild does not change.
- **Preserve:** the envelope schema (`schemaVersion = 1`), the autosave-is-never-the-user's-file rule, metadata timestamps, recovery matching by `originalPath`.
- **Change:** nothing structurally. V2 fidelity may later add a *V2-shaped* import/export path (V2 saves `positions` + `wireRoutes` as a layout JSON via `saveLayout()`/`loadLayoutFile()`); that is an **additive importer/exporter**, not a change to this envelope.
- **Breaks if removed:** `EngineeringProjectState.document` (a required constructor field), every document command in the Command Registry, `test/diagram_document_test.dart`.

### 4.2 Command facade — `commands/`

**`commands/studio_command_actions.dart` — `StudioCommandActions`**
- **Responsibility:** thin facade over `engine.editing` / `engine.clipboard` / `engine.registry.selection` for undo, redo, copy, cut, paste, duplicate, delete. Also exposes `canUndo`/`canRedo`/`hasClipboardContent` for enablement.
- **Dependencies:** `engineering_engine` only. **No Flutter import.**
- **Reason:** This is exactly the shape the new architecture wants — a UI-agnostic action surface over the Engine. It is already shared by the page's toolbar buttons, its keyboard bindings, and the global `CommandRegistry`, which is why all three stay consistent.
- **Preserve:** all seven operations and the three enablement getters, unchanged. Preserve the `cut` → `deselectAll` and `paste`/`duplicate` → `selectMany(pastedNodeIds)` post-conditions — V2 has no equivalent, and losing them is a silent behavioural regression.
- **Change:** nothing. The new V2 toolbar and the new keyboard map both bind to this same object.
- **Breaks if removed:** `core/commands/command_registry.dart`, every edit action in `diagram_studio_page.dart`, the global command palette.
- **Gap noted (not a defect):** `StudioCommandActions` does **not** call `markDirty()`; the page does that at ~30 call sites. The new controller must own that responsibility or the dirty flag silently dies (see §9.4).

### 4.3 Engineering services

| Path / Component | Responsibility | Dependencies | Reason to KEEP | Preserve | Change | Breaks if removed |
|---|---|---|---|---|---|---|
| `simulation/diagram_simulation_service.dart` — `DiagramSimulationService` + `diagramSimulationServiceProvider` | Sole point of contact with the engine's `SimulationEngine`: session create/delete, pause/resume/reset, operating & input state, fault injection, verification | `engineering_engine`, `flutter_riverpod`, `core/services/engineering_project_service.dart` | Pure engineering-runtime orchestration; already provider-scoped so it outlives the page; the V2 KEY/SWITCHES row and flow animation both need exactly this | Provider identity (`engineeringProjectServiceProvider`-derived, single instance), session-state semantics, `availableOperatingStates`/`availableInputStates` as the *only* source of key states | Nothing. New chrome reads the same service | `EngineeringInteractionContext(_builder)`, `SimulationCenterDialog`, `SimulationControlsToolbar`, `MultimeterController`, `_KeySwitchesRow`, `test/simulation/*` |
| `intelligence/diagram_intelligence_service.dart` — `DiagramIntelligenceService` | The **only** contact point with the Engineering Intelligence Platform: debounced diagram→Foundation sync, `validate()`, `analyzeNode()`, Foundation-object-id ↔ canvas-node-id translation (`nodeIdFor`) | `engineering_engine`, `core/foundation/foundation_bridge.dart`, `core/foundation/oep_api_types.dart`, `repository/diagram_repository_service.dart` | No UI coupling whatsoever — it takes `graph`/`layout` and returns `OepWorkflowResult` + object ids. V2 has no equivalent, so this is pure OEP surplus that must survive | The single-service rule, the debounce, `nodeIdFor` translation, null-bridge tolerance | Nothing internally. Its *triggers* move from the page to the controller | 5 EI panels, the validation/analysis overlays, `PublishingCenterDialog`, `test/intelligence_panels_test.dart` |
| `repository/diagram_repository_service.dart` — `DiagramRepositoryService implements LegacyMigrator` | Foundation repository read/write for diagram decomposition; implements the legacy-migration contract | `engineering_engine`, `core/foundation/*`, `core/models/*`, `migration/legacy_migration_models.dart` | Foundation integration; entirely headless | Object/relationship mapping, migration contract | Nothing | `DiagramIntelligenceService`, `LegacyMigrationDialog`, `test/legacy_migration_dialog_test.dart` |
| `ai/diagram_ai_service.dart` — `DiagramAiService` | Resolves a provider from `AiProviderRegistry` and sends an `AiRequest` | `knowledge/models/*`, `knowledge/services/ai_provider_registry.dart` | 33 lines, static, **no Flutter, no diagram UI type** | The registry-lookup + graceful "no provider" `AiResponse` | Nothing | `contextual_command_definitions.dart`, `copilot_page.dart`, `validation_page.dart` |
| `ai/diagram_prompt_context.dart` — `DiagramPromptContext` | Builds an `AiRequest` from `EngineeringGraph` + `GraphSelection` | `engineering_engine`, `knowledge/models/ai_request.dart` | Pure function of engine data; reads selection but not any widget | Prompt shape, evidence-label map, "never invent" system prompt | Nothing | `unified_ai_context_service.dart` |

**Conclusion for the `ai/` audit item (list item 9):** `ai/` is **not coupled to the existing UI architecture**. Both files depend only on the Knowledge AI models and on `engineering_engine` types. Nothing in `ai/` imports `flutter/material.dart`, any panel, any toolbar, or `diagram_studio_page.dart`. It can be carried across the rebuild untouched. Nothing is to be removed.

### 4.4 Instruments runtime

| Path / Component | Responsibility | Dependencies | Reason | Preserve | Change | Breaks if removed |
|---|---|---|---|---|---|---|
| `instruments/core/engineering_instrument.dart` — `EngineeringInstrument`, `InstrumentRegistry` | Abstract instrument contract + registry `ChangeNotifier` | `flutter/widgets` only | Framework contract, not chrome. Also consumed by the Workbench Instruments Perspective | The contract shape (`id`, title, `buildPanel`) and registry semantics | Nothing | `instruments_perspective.dart`, `instrument_dock_panel_client.dart`, `InstrumentDock`, `test/instruments/*` |
| `instruments/multimeter/multimeter_controller.dart` — `MultimeterController`, `multimeterRuntimeServiceProvider` | Probe slots A/B, measurement mode, live-mode timer, `latestResult`, `highlightedPathNodeIds`, bookmark/history integration | `engineering_engine`, `flutter_riverpod`, `simulation/diagram_simulation_service.dart`, `instruments/bookmarks/*`, `instruments/history/*` | The measurement **runtime**. V2's meter is a *presentation* of exactly this data (LCD value, unit, OL, lead locations). Deliberately not `autoDispose`-fragile; reachable from the Context & Capability Bridge | Probe model, `latestResult` shape, live-mode timer, path highlight set, provider identity | Nothing in the controller. Its *panel* is replaced (§6) | `EngineeringInteractionContext(_builder)`, `ProbeOverlay`, `DigitalMultimeterPanel`, `_ImmersiveMeterPane`, `test/instruments/multimeter_controller_test.dart` |
| `instruments/bookmarks/measurement_bookmark.dart` + `_store.dart` | Named measurement bookmarks + JSON persistence | `dart:io`, `settings_storage` | Headless data + storage | Schema and file location | Nothing | `MultimeterController`, `test/instruments/measurement_bookmark_store_test.dart` |
| `instruments/history/measurement_history_entry.dart` + `_store.dart` | Measurement history + JSON persistence | `dart:io`, `settings_storage` | Headless data + storage | Schema and file location | Nothing | `MultimeterController`, `test/instruments/measurement_history_store_test.dart` |
| `instruments_host/oip_host_bridge_service.dart` — `OipHostBridgeService` | Bridges real instrument hardware via `oep_instruments_runtime` | `oep_instruments_runtime`, `engineering_engine` | Hardware integration; app-wide, deliberately not page-owned (the page's `dispose()` explicitly does **not** stop it) | App-wide lifetime, independence from page mount/unmount | Nothing | `instrument_bridge_provider.dart`, Settings page, `test/instruments_host/*` |
| `instruments_host/instrument_bridge_provider.dart` — `instrumentBridgeServiceProvider` | Riverpod provider for the above | `flutter_riverpod`, `core/services/engineering_project_service.dart` | Same | Provider identity | Nothing | Settings page `_InstrumentBridgeSection` |

### 4.5 Persistence (engineering-adjacent + UI-agnostic storage)

| Path / Component | Responsibility | Category | Reason | Preserve | Change | Breaks if removed |
|---|---|---|---|---|---|---|
| `persistence/workspace_state_storage.dart` — `WorkspaceStateStorage` | Load/save `diagram_studio_workspace.json` under `SettingsStorage.root()` | UI state **storage mechanism** | The *mechanism* is correct and schema-agnostic; only the schema it carries is stale (see §5) | File location, JSON-with-indent convention, `FormatException` → defaults fallback | Nothing in the storage class | `diagram_studio_page.dart` bootstrap/dispose, `test/diagram_workspace_state_test.dart` |
| `persistence/recent_projects_storage.dart` — `RecentProjectEntry`, `RecentProjectsStorage` | Recent Engineering Projects (Foundation-backed, AP-DS-002) | Engineering data reference | Consumed **outside** Diagram Studio | Entry schema | Nothing | `features/project_explorer/project_explorer_page.dart`, `test/recent_projects_storage_test.dart` |
| `persistence/recent_files_storage.dart` — `RecentFilesStorage` | Recent local diagram file paths | UI state | Storage convention referenced by three other storage classes as the canonical pattern | The pattern | Nothing | Only tests + doc references today — see §7 for the "no live caller" finding |
| `tabs/diagram_tabs_storage.dart` — `DiagramTabsStorage` | Persist open tabs + recently-closed | Temporary workspace state | Correct category separation already | File location, schema | Nothing | `DiagramTabsNotifier.ensureRestored`, `test/diagram_studio/tabs/*` |
| `settings/diagram_studio_settings_storage.dart` — `DiagramStudioSettingsStorage` | Persist `DiagramStudioSettings` | User preferences | Correctly separate from workspace state and from `UserConfiguration` | File location | Nothing | Settings provider |

### 4.6 Settings model & provider

**`settings/diagram_studio_settings.dart` — `DiagramStudioSettings`** and **`settings/diagram_studio_settings_provider.dart` — `DiagramStudioSettingsNotifier`, `diagramStudioSettingsProvider`**
- **Responsibility:** three new-document defaults — `defaultGridVisible`, `defaultSnapEnabled`, `defaultGuidesVisible` — applied by `EngineeringProjectNotifier._applyNewDocumentViewStateDefaults` on every new/opened/closed document.
- **Dependencies:** storage class only (model has **zero** imports).
- **Reason:** Deliberately not part of `UserConfiguration`'s versioned schema; these are Engine `ViewState` defaults. The V2-compatible Studio still has a grid and still needs defaults.
- **Preserve:** the three fields, the provider identity (imported by `core/services/engineering_project_service.dart`), and the "defaults, not live state" semantic.
- **Change:** the *set* of settings will grow (see §5 — theme, nudge step, wire-exit default, panel-layout persistence). Adding fields is backward compatible with `fromJson`'s `?? true` defaults.
- **Breaks if removed:** `engineering_project_service.dart` (**core**), `studio_registry.dart`, `test/diagram_studio_settings_test.dart`, `test/settings_registry_test.dart`.

### 4.7 Publishing & reporting (headless)

| Path / Component | Responsibility | Reason | Preserve | Change | Breaks if removed |
|---|---|---|---|---|---|
| `publishing/engineering_summary.dart` — `EngineeringSummary` | Derive a textual engineering summary from `EngineeringGraph` | Pure function of engine data; no Flutter | Derivation rules | Nothing | `PublishingCenterDialog`, `test/publishing/engineering_summary_test.dart` |
| `publishing/exchange_checklist.dart` — `ExchangeChecklist(Item)` | Pre-publish readiness checks | Same | Check definitions | Nothing | `PublishingCenterDialog`, tests |
| `publishing/package_manifest.dart` — `PackageManifest` | Manifest for exported packages | Same | Schema | Nothing | `PublishingCenterDialog`, tests |
| `publishing/intelligence_reports.dart` — `IntelligenceReportRenderer` | Render `OepWorkflowResult` to report text | Depends only on `oep_api_types` | Rendering rules | Nothing | `PublishingCenterDialog`, tests |
| `publishing/tabular_report_kind.dart` — `TabularReportKind` | Enumerates BOM / wire-list / connector-list report kinds | Pure enum + derivation over the graph | Kind set and column derivation | Nothing | `TabularReportDialog`, tests |
| `publishing/title_block_storage.dart` — `TitleBlockStorage`, `TitleBlockPresetStorage` | Persist title-block data + presets | Engineering document metadata, correctly separated | Schema, preset model | Nothing | `TitleBlockEditorDialog`, tests |
| `migration/legacy_migration_models.dart` — `LegacyMigrationItem`, `LegacyMigrationResult`, `LegacyMigrator` | Contract + result model for migrating legacy files | Headless contract implemented by `DiagramRepositoryService` | The `LegacyMigrator` interface | Possibly **extend** to cover V2 project JSON import (see §8) | `DiagramRepositoryService`, `LegacyMigrationDialog`, tests |

### 4.8 Property Inspector modes — `inspector/`

All eight files: `engineering_node_properties.dart`, `engineering_relationship_properties.dart`, `engineering_port_properties.dart`, `engineering_group_properties.dart`, `diagram_annotation_properties.dart`, `diagram_layer_properties.dart`, `engineering_evidence_link_properties.dart`, `wire_override_properties.dart`.

- **Responsibility:** read-only property views for each `EngineeringInspectable` variant, rendered by the **shared** `shared/widgets/property_inspector_panel.dart`, which switches modes on `FoundationRuntimeNotifier.selectedEngineeringInspectable`.
- **Dependencies:** `engineering_engine`, `shared/widgets/property_field.dart`, and (for node/relationship/evidence-link) `flutter_riverpod` + `core/services/foundation_runtime_service.dart` + `core/models/engineering_inspectable.dart`.
- **Reason to KEEP:** they are **not Diagram Studio chrome** — they are the platform Property Inspector's diagram modes, consumed by a shared widget that other studios render. They are display-only by design (SDD-011); editing flows through Engine commands. Rebuilding the Diagram Studio window does not change what a node's properties *are*.
- **Preserve:** the `EngineeringInspectable` → mode mapping, the display-only rule, the evidence-link drill-down (`engineering_node_properties.dart:52-72` → `EngineeringInspectable.evidenceLink` → "Go to Evidence").
- **Change:** **nothing in these files.** The V2-shaped inspector is a *different, additional* presentation (V2's `#left-sidebar` Wire/Module inspector) that must read the same selection — see §5.7 and §8.3 for the reachability problem.
- **Breaks if removed:** `shared/widgets/property_inspector_panel.dart` (8 imports) → the Property Inspector in **every** studio.

### 4.9 Interaction-model logic worth preserving verbatim (currently inside the monolith)

These are *methods*, not files, and they are listed here because their **logic** is KEEP even though their **location** is REPLACE. They move to the new Studio Controller (§11) unchanged.

| Logic | Location today | Why it must survive |
|---|---|---|
| Alignment-guide computation for a multi-node drag treated as one rigid rect, then per-node grid snap | `_draggedGroupBounds`, `_snappedDragPositions` (1412–1494) | Non-obvious, correct, and hard-won: guides fire on the *group* box so relative spacing never changes mid-drag. V2 has no equivalent |
| Resize preview with opposite-edge pinning + minimum size, emitted as one atomic `ResizeNodeCommand` | `_previewResize`, `_handleNodeResizeEnd` (1555–1616) | Single-undo semantics for a whole gesture |
| Port anchor resolution preferring authored `SymbolPort` geometry, falling back to `fallbackPorts(exit:)` | `_portAnchor` (1620–1636) | Keeps pin rendering, wire endpoints and drag anchors in agreement — the exact class of bug V2 avoids by construction |
| OS-clipboard fallback around the in-process clipboard | `_copy`, `_paste` (1108–1133) | Cross-window/cross-restart paste |
| Two-way `ViewState` ↔ `Matrix4` reconciliation (stream → matrix always; matrix → stream only at `onInteractionEnd`) | `_applyTransformFromViewState`, `_syncViewStateFromTransform` (983–1000) | Prevents fighting the gesture recogniser mid-pinch; makes `ViewState` authoritative |
| Search-result navigation incl. symbol-kind (select every node using that symbol) and layer-kind (select every entity on the layer + reveal in inspector) | `_goToSearchResult` (2158–2213) | Real behaviour with no V2 counterpart |
| Contextual-menu target construction (`CursorTarget` independent of left-click selection) | `_handleSecondaryTap` + 3 siblings (1206–1326) | Contract-mandated (`docs/context menu service`, § 7) |

---

## 5. ADAPT Components

*Useful functionality, but must be modified to support the V2 interaction/UI model.*

### 5.1 `persistence/diagram_workspace_state.dart` — `DiagramWorkspaceState`

- **Responsibility:** persisted workspace snapshot — `lastDocumentPath`, `showLayerPanel`, `showSearchPanel`, `explorerWidth`, `sidePanelsWidth`, `viewState`.
- **Dependencies:** `engineering_engine` (`ViewState`).
- **Reason to ADAPT:** the *category discipline* is exactly right (it deliberately excludes graph and layout — "saving them here too would create two sources of truth"), but the *fields* are a snapshot of a panel set that V2 does not have. Only 2 of the 11 panel-visibility booleans the page actually owns are persisted; `_panelSlot`/`_slotSize` are explicitly runtime-only.
- **Preserve:** `viewState` persistence (zoom/pan/grid/guides is genuinely ambient session state), `lastDocumentPath`, and above all the exclusion rule.
- **Must change:** replace the ad-hoc panel booleans with a V2-shaped layout record — per-panel `{docked|floating, x, y, w, h, visible}` (V2 persists exactly this to `localStorage` under `wiring-panel-<id>`, plus "set as default position" / "reset"), the active sidebar tab (Inspector/Meter), theme, and legend/minimap/search visibility. Bump `schemaVersion` or tolerate absent keys.
- **Breaks if removed:** `WorkspaceStateStorage`, page bootstrap/dispose, `test/diagram_workspace_state_test.dart`.

### 5.2 `toolbars/diagram_toolbars.dart` — `SimulationControlsToolbar`

- **Responsibility:** Simulate-mode runtime strip — status chip, Start/Resume/Pause/Reset/Stop against `DiagramSimulationService`, plus an Operating-State dropdown when `session.availableOperatingStates` is non-empty; threads `DomainProfile` into `createSession`.
- **Dependencies:** `engineering_engine`, `simulation/diagram_simulation_service.dart`, `core/theme/studio_colors.dart`.
- **Reason to ADAPT (not REPLACE):** its *command bindings* are the exact set V2's topbar KEY row implies (session lifecycle + active operating state) and it already refuses to fabricate states. Only the presentation is wrong: V2 renders key positions as four inline `key-btn` pills in the topbar with live `sw-ind` indicator glyphs, not a dropdown behind a status chip.
- **Preserve:** the five session operations, the `domainProfile` threading (so the toolbar and `_KeySwitchesRow` share **one** session), and the "no session ⇒ no fabricated state" rule.
- **Must change:** presentation → V2 topbar pill group; merge with `_KeySwitchesRow` so KEY and SWITCHES are one component, not two that both read the same session; remove the mode gate (V2's key state is live in every mode — a finding already acted on for `_KeySwitchesRow` but not for this toolbar).
- **Breaks if removed:** `test/diagram_studio/toolbars/simulation_controls_toolbar_operating_state_test.dart`, `test/workflow/diagram_studio_simulate_mode_test.dart`.

### 5.3 Canvas overlays

| Path / Component | Responsibility | Deps | Reason to ADAPT | Preserve | Must change |
|---|---|---|---|---|---|
| `panels/diagram_intelligence_overlay.dart` — `DiagramIntelligenceOverlay` | Validation markers + analysis highlights positioned by the same `pan`/`zoom` the canvas uses; tap → select & frame | `engineering_engine`, `studio_colors` | The additive-`Positioned.fill`-with-shared-transform pattern is the correct way to layer on the canvas without touching the renderer, and it survives a renderer swap. Only its coordinate source changes | The pattern, the id-translation contract (`nodeIdFor`), "empty set renders nothing" | Coordinate source becomes the new presentation layer's transform, not `ViewState.pan/zoom` read separately; visual language must become V2's (dim-others + glow, per `renderer.js` `isDim`/glow path) rather than Material markers |
| `simulation/simulation_state_overlay.dart` — `SimulationStateOverlay` | Node voltage/state chips, fault markers, propagation-path highlight | `engineering_engine`, `studio_colors` | Same pattern; and it is the natural host for V2's **flow animation** and **traced-circuit dimming**, which are the two most characteristic V2 visual behaviours | Snapshot/verification/fault inputs, path-highlight input, tap-to-select | Add V2 flow animation (`stroke-dasharray` marching ants, direction from `from→to`, reversed into ground, suppressed at key-off / `CONT=OPN`) and V2 trace dimming; move wire-level effects into the wire renderer where they belong |
| `instruments/probe/probe_overlay.dart` — `ProbeOverlay`, `ProbeSlot`, `placeByNodeTap`, `placeByPortTap` | Renders probe A/B markers; static helpers place a probe from a node or port tap | `engineering_engine`, `multimeter_controller.dart`, `studio_colors` | Directly corresponds to V2's red/black lead dots drawn on terminals (`renderer.js` `mk(leadR,…)`), and the click-to-place model matches V2's `leadPlaceMode` | `ProbeSlot`, both placement helpers, the controller as the source of truth | V2 renders leads **only for the selected wire** and offers four placement modes (`ends`, `→GND`, `→PWR`, `manual`) with automatic placement at wire endpoints on selection; OEP has arm-then-click only. Add auto-placement on wire selection and the four modes |
| `panels/diagram_mini_map.dart` — `DiagramMiniMap`, `_MiniMapPainter` | Scaled scene thumbnail + viewport rect | `engineering_engine`, `studio_colors` | Concept and painter are right | **It is wrapped in `IgnorePointer` at the call site** (`diagram_studio_page.dart:2799`) — V2's minimap is *click-to-centre* (`minimapClick`). Restore interactivity; that is a call-site change plus an `onTap` callback |

### 5.4 Panels that survive but leave the primary workspace

V2's primary workspace has **exactly two** persistent surfaces: the left sidebar (Inspector/Meter) and the viewport. Everything else is a floating, toggled, dismissible overlay. The following OEP panels are behaviourally sound but must stop occupying a permanent column.

| Path / Component | Reason to ADAPT | Preserve | Must change | Breaks if removed |
|---|---|---|---|---|
| `panels/diagram_search_panel.dart` — `DiagramSearchPanel` | V2 *has* search (`#srch`, `/` key) — but as a floating overlay with live results, not a docked column panel | `search`/`onGoToResult` callback contract, result rendering | Becomes a floating, `/`-triggered overlay; Escape closes; result click centres and flashes the target (V2 `sel-flash`) | Page build; `SearchToolbar` |
| `panels/diagram_layer_panel.dart` — `DiagramLayerPanel` | Layers are a **real OEP capability with no V2 counterpart** (`DiagramLayer`, `CreateLayerCommand`, layer visibility/lock). It must not be deleted merely because V2 lacks it | All CRUD callbacks and `onSelectLayer` → Property Inspector | Moves off the primary workspace into a toggled/secondary surface; must not be a default-visible column | Page build; `LayersToolbar`; layer commands lose their only UI |
| `panels/diagram_annotation_panel.dart` — `DiagramAnnotationPanel` | Annotations are a real OEP capability; V2 has none | Select/edit/delete callbacks | Same — toggled surface, not a default column | Page build |
| `panels/diagram_explorer_panel.dart` — `DiagramExplorerPanel` | A structural tree of the graph; V2 has none, but the Workbench/Engineering Perspective is the natural home | Tree rendering + `onSelectNode` | Relocate out of the diagram workspace (Workbench sidebar or Object Explorer) | Page build only |
| `panels/recommendation_panel.dart`, `engineering_explorer_panel.dart`, `knowledge_graph_panel.dart`, `query_console_panel.dart`, `knowledge_sessions_panel.dart`, `intelligence_panel_shared.dart` | Engineering Intelligence surfaces — substantial OEP value, zero V2 counterpart. All five are already gated on `_intelligence != null` and share `IntelligenceResultSummary`/`ObjectChips`/`BusyBar` | Every panel's `intelligence`/`onSelectNode`/`selectedNodeId` contract; the shared primitives | Move to a secondary Intelligence surface (Workbench perspective, or a single toggled dock) instead of five independent boolean-gated columns in the diagram workspace; the six toggle buttons in `_IntelligenceToolbar` collapse into one entry point | Page build; `test/intelligence_panels_test.dart` |

### 5.5 Instrument dock → V2 sidebar + pop-out

| Path / Component | Responsibility | Reason to ADAPT | Preserve | Must change |
|---|---|---|---|---|
| `instruments/dock/instrument_dock_controller.dart` — `InstrumentDockController` | Async-loaded dock layout state, visibility toggling per instrument | The *state model* (position, size, visibility, per-instrument) is very close to what V2's panel manager persists | Async `load()`, `toggleVisible(id)`, notifier semantics | Reconcile with V2's panel model: any panel can be docked-in-sidebar or popped-out-floating, dragged by header, resized by grip, with a `⋮` menu (set default / reset / re-centre / reset size) persisted per panel |
| `instruments/dock/instrument_dock_state.dart` — `InstrumentDockState`, `DockPosition {bottom, floating, left, right}` | Dock geometry model | Already models floating | Enum + serialisation | Extend with per-panel default-position memory; unify with `PanelDockSlot` so there is **one** panel-placement model, not two |
| `instruments/dock/instrument_dock_storage.dart` — `InstrumentDockStorage` | JSON persistence for the above | Correct mechanism | File location | Schema follows the state change |
| `instruments/dock/instrument_dock.dart` — `InstrumentDock`, `_AutoHideStrip`, `_FloatingFrame`, `_DockTabBar`, `_DockTab`, `_ResizeGrip` | The dock's Flutter chrome | `_FloatingFrame` and `_ResizeGrip` are genuinely V2-like (draggable header, corner resize grip). The tab bar and auto-hide strip are not | The floating-frame + resize-grip behaviour | Auto-hide strip and dock tab bar are dropped in favour of V2's sidebar-tab + pop-out model |

### 5.6 Tabs and modes

**`tabs/diagram_tab.dart` — `DiagramTab`; `tabs/diagram_tabs_controller.dart` — `DiagramTabsState`, `DiagramTabsNotifier`, `diagramTabsProvider`** → **KEEP the model/controller** (multi-document is a real OEP capability V2 lacks; the notifier already handles open/activate/close/pin/recently-closed/restore, and the "one engine holds one document" constraint is documented). **ADAPT** only `DiagramTab.mode`.

**`tabs/diagram_tab_bar.dart` — `DiagramTabBar`, `_TabChip`**
- **Reason to ADAPT:** V2 is single-document and has no tab bar, so there is no reference visual — but removing tabs would delete an OEP capability. Restyle to the V2 chrome (dark `--surf-0`, amber accent, 9–10px uppercase) rather than redesign.
- **Preserve:** select/close/pin/new/history callbacks.
- **Must change:** visual language only; must fit inside the V2 top strip without adding a third bar.

**`tabs/diagram_mode_switcher.dart` — `DiagramModeSwitcher`, `_ModeButton`** → see §6.6; the *widget* is REPLACE, but the *mode concept* is ADAPT: OEP's `{view, edit, simulate}` and V2's `{normal, editMode, wireMode, routeEditMode}` are different axes. The reconstruction must define one model (proposal in §11.4), not silently pick one.

### 5.7 Context menu

**`context_menu/diagram_context_menu.dart` — `showDiagramContextMenu`**
- **Responsibility:** hosts a `MenuDescriptor` produced by `ContextualCommandResolver` in a `showMenu`, executes the chosen command, surfaces notifications.
- **Dependencies:** `core/context/contextual_command_resolver.dart`, `engineering_interaction_context.dart`, `menu_descriptor.dart`, `core/notifications/platform_notification_service.dart`, `studio_colors`.
- **Reason to ADAPT:** the capability-driven resolver is an OEP contract (`docs/context menu service`) that must be preserved; only the *presentation* (Material `showMenu`) differs from V2's `#ctx` (3 flat items, `danger` styling on Delete).
- **Preserve:** the resolver hand-off, `CursorTarget`-based targeting, the post-execution `setState` + `markDirty` obligation currently in `_openContextualMenu`.
- **Must change:** V2 visual treatment; and the **documented gap** must be closed — port and annotation right-click work via widget callbacks, but `_handleSecondaryTap`'s point-based path cannot hit-test ports or annotations (no standalone query exists). The new presentation layer owns hit-testing and should expose one `hitTest(point) → target` for all target kinds.
- **Breaks if removed:** `test/workflow/diagram_context_menu_test.dart`, `test/core/context/contextual_command_resolver_test.dart`.

### 5.8 Settings page

**`settings/diagram_studio_settings_page.dart` — `DiagramStudioSettingsProvider`, `DiagramStudioSettingsPage`, `_InstrumentBridgeSection`**
- **Responsibility:** Studio-registry settings descriptor + the settings UI (grid/snap/guides defaults) + instrument-bridge enable/port controls.
- **Dependencies:** `settings/models`, `settings/services`, `settings/widgets`, `instruments_host/instrument_bridge_provider.dart`, `studio_colors`.
- **Reason to ADAPT:** required by `core/routing/studio_registry.dart`, so it must keep existing; but the settings it exposes must grow to cover the V2-compatible Studio.
- **Preserve:** the `SettingsProvider` implementation and registry wiring; `_InstrumentBridgeSection` unchanged (hardware, unrelated to UI).
- **Must change:** add V2-relevant preferences — theme (light/dark, V2 persists this), route-nudge step (V2 `NUDGE = 6`, ×4 with Shift), default module wire-exit direction, panel-layout reset, minimap/legend defaults.
- **Answer to audit item 8:** required by the V2-compatible Studio → the three `ViewState` defaults, plus the new preferences above. Unrelated to it → `_InstrumentBridgeSection` (hardware bridge; keep, don't touch).

---

## 6. REPLACE Components

*Should be replaced by a new implementation modelled on Wiring Simulator V2. In every case the **callbacks and command bindings are preserved**; only the widget that draws them is new.*

### 6.1 `workspaces/diagram_studio_page.dart` — `DiagramStudioPage` / `_DiagramStudioPageState`

- **Responsibility:** all 37 items in §2.3.
- **Dependencies:** 47 imports — `engineering_engine`, `file_selector`, `flutter/services`, `flutter_riverpod`, 7 `core/*` modules, `knowledge/widgets/knowledge_panel.dart`, 2 `shared/widgets`, and 20 `diagram_studio/*` modules.
- **Classification:** **REPLACE** — as a *file*. Explicitly **not** "delete": ~60% of its body is logic classified KEEP in §4.9 and must be moved out intact before the file is retired.
- **Reason:** 3,785 lines with no internal boundary. The V2 layout (`#topbar-wrap` / `#left-sidebar` / `#viewport`) cannot be expressed by editing this `build()` — it currently emits, in order: an immersive top strip (tab bar + mode switcher + document actions), a `Wrap` of twelve toolbar groups, a top dock row, a left dock column, an Object Explorer column, the canvas `Stack` (5 overlay layers + coordinate readout + minimap), a right side-panel column of up to 9 `KnowledgePanel`s, a right dock column, and a bottom dock row — then an `InstrumentDock` layered over the whole thing. That is four competing layout systems.
- **What must be preserved:** every item in §4.9; the shortcut table (§2.3 #33); the bootstrap ordering (`ensureEngineStarted` → instruments → intelligence → workspace state → tabs restore → mode defaults → subscriptions → initial transform → inspector sync); the `dispose()` constraints (cached document path/ViewState because Riverpod marks the element disposed before `dispose()`; deferred `clearEngineeringInspectableSelection` via `scheduleMicrotask`; **not** stopping the app-wide instrument bridge).
- **What must change:** it becomes a thin composition root (§11.5) — mount the V2 shell, wire providers to a controller, own nothing else.
- **Breaks if removed:** `workbench/perspectives/diagram_perspective.dart`; 12 workflow tests that pump `DiagramStudioPage` directly.

### 6.2 Canvas host — the `GraphViewPanel` call site

- **Responsibility today:** `GraphViewPanel` (in **`oep_engine/lib/views/widgets/graph_view_panel.dart`**, 469 lines) renders grid, wires, symbol nodes with ports, guides, box-select, connection preview, reconnect handles, resize handles, wire-edit handles — inside an `InteractiveViewer` with `panEnabled: false`, and applies viewport culling for nodes, wires and annotations.
- **Dependencies:** `DiagramScene`, `ViewState`, `SymbolProvider`, ~40 callbacks; plus `SymbolNodeWidget`, `WirePainter`, `AnnotationWidget`, `GridPainter`, `GuidesPainter`, `ConnectionPreviewPainter`, `ResizeHandles`, `WireEditHandles`, `ReconnectHandle`, `OriginIndicator`.
- **Classification:** **REPLACE the Studio's use of it.** The Engine file itself is **frozen** and must not be modified (§15). The Demonstration Host in `oep_engine/example/` also consumes it and must keep working.
- **Reason:** V2's module and wire presentation cannot be reached from this widget without editing it. Concretely, V2 requires: category-stripe cards with a terminal strip of colour-coded dots and label/sub-label (`buildStdCard`), a bulb card shape, a dual-pin inline-connector card shape (`buildConnCard`); per-wire glow, bi-colour dashed stripe, selected-wire midpoint label chip, marching-ants flow animation, and dim-to-10% of every non-traced wire; a wide transparent per-wire hit path whose availability depends on the active mode; and per-segment hit zones with midpoint handles in route-edit mode. `WirePainter` draws flat polylines with no per-wire state, and `SymbolNodeWidget` renders symbol-asset geometry.
- **What must be preserved:** the **inputs**, not the widget — `DiagramScene`/`DiagramNodeVisual`/`DiagramWireVisual` stay the contract (`DiagramNodeVisual` already carries `displayName`, `category`, `ports`, `metadata['exit']`, which is exactly what a V2 card needs); the viewport-culling behaviour (benchmarked: 40,000 unculled wires ≈ 179 ms/paint); `kNodeHitMargin`'s hit-inflation fix; the `IgnorePointer` around the connection preview (without it the preview absorbed the second click of a two-click wire).
- **What must change:** a new Studio-owned `DiagramCanvas` renders `DiagramScene` in V2's visual language and routes gestures to the controller.
- **Breaks if removed:** nothing — the Engine widget stays where it is, still used by the Demonstration Host. Only the Studio's call site changes. `test/workflow/diagram_hit_testing_widget_test.dart` targets the Studio's canvas and will need re-pointing.

### 6.3 `toolbars/diagram_toolbars.dart` — eleven of twelve groups

`_ToolbarIcon`, `_ToolbarGroup`, `SelectionToolbar`, `EditActionsToolbar`, `DiagramNavigationToolbar`, `AlignDistributeToolbar`, `PlacementToolbar`, `WireEditingToolbar`, `LayersToolbar`, `PanelsToolbar`, `AnnotationsToolbar`, `ViewToolbar`, `SearchToolbar`, `ConstraintsToolbar`.

- **Responsibility:** ~45 icon buttons and popup menus across twelve groups, laid out in a `Wrap` (deliberately, because a horizontal scroll made late buttons unreachable in tests).
- **Dependencies:** `engineering_engine` (enums: `AlignmentMode`, `DistributionAxis`, `MirrorAxis`, `AnnotationType`, `EditingConstraints`, `ConstraintAxis`, `ViewState`), `studio_colors`.
- **Reason to REPLACE:** V2's entire command surface is **~14 controls in one row**: zoom −/+/Fit, Layout, Wire, ＋Module, ⌕Find, ☰Legend, Save, Load, Export SVG, theme, ?. OEP shows ~45 at once. The existing file's own comment concedes the point: consolidation "needs real icon-set reduction, not just a container swap." A density pass on `_ToolbarIcon` was already tried (48→30 px) and is not sufficient.
- **What must be preserved — this is the highest-value artefact in the file:** the **command-binding table**. Every group's callbacks are correct Engine calls and must be re-bound, not re-derived:

| Group | Bindings that must survive |
|---|---|
| Selection | `selection.selectAll(graph, layout:)`, `deselectAll()`, `CreateGroupCommand`, `UngroupCommand` |
| Edit actions | `StudioCommandActions.{undo,redo,cut,copy,paste,duplicate,delete}` + enablement getters |
| Navigation | `viewState.{fitAll,fitSelection,centerSelection,goBack,goForward,resetView}` + `canGoBack`/`canGoForward` |
| Align/Distribute | `AlignNodesCommand` (≥2 nodes), `DistributeNodesCommand` (≥3 nodes) |
| Placement | `CreateNodeCommand` per symbol id, `RotateNodesCommand(90/180/arbitrary)`, `MirrorNodesCommand(h/v)`, `ArrayPlaceCommand`, `ReplaceSymbolCommand` |
| Wire editing | wire-create mode toggle; `SetWireRouteCommand(points)`; `SetWireRouteCommand(null)` = restore auto-routing; insert/remove vertex via `WireEditing.{insertVertex,removeVertex}` |
| Layers | `CreateLayerCommand`, panel toggle |
| Annotations | `CreateAnnotationCommand` per `AnnotationType`, with `portLabel` correctly excluded (it needs a real port anchor and is created only from the port context menu) |
| View | `toggleGrid`, `toggleSnap`, `setGuidesVisible`, `showGridSettingsDialog`, `showNamedLayoutsDialog` (+ its load/reset session wiring) |
| Search | panel toggle |
| Constraints | `setConstraints` (orthogonal movement, axis lock) |

- **What must change:** presentation and *inventory*. V2-frequency commands (zoom, fit, Layout, Wire, Module, Find, Legend, Save/Load/Export, theme) get the single visible row; everything else moves to the context menu, the Command Palette, or a secondary surface. Nothing in the binding table may be deleted without an explicit decision — several bindings (`AlignNodesCommand`, `DistributeNodesCommand`, `ArrayPlaceCommand`) exist *only* here.
- **Breaks if removed:** page build; `test/workflow/diagram_studio_edit_mode_test.dart`, `_view_mode_`, `_simulate_mode_`, `_wire_create_mode_` all tap these buttons by tooltip/icon.

### 6.4 Private chrome widgets inside the monolith

| Component (line) | Responsibility | Reason to REPLACE | Preserve | Change |
|---|---|---|---|---|
| `_ImmersiveColors` (3038) | Three colour tokens (`surf-0`, `surf-1`, amber) lifted from `css/main.css` | V2's palette is ~30 CSS custom properties across two themes (`--surf-0/1/2`, `--border-0/1`, `--text-hi/md/lo/faint`, `--amber`, `--cyan`, `--purple`, shadows) | The intent, and the decision to scope the palette to Diagram Studio rather than change shared `StudioColors` | Becomes a complete, themed token set with light/dark support |
| `_ImmersiveInspectorSidebar`, `_ImmersiveSidebarTabButton` (3055, 3113) | Two-tab Inspector/Meter sidebar | Correct concept, wrong shell: it is nested inside a `DockablePanel` inside a dock slot, so it is neither permanent nor pop-out-able. V2's `#left-sidebar` is a fixed structural column with a `⊞` pop-out per pane | Tab model, tab-button styling | Becomes a first-class structural column with pop-out/dock-back (`popOut`/`dockIn`) |
| `_ImmersiveInspectorPane` (3150) | Wire / Module / Port inspector reading `GraphSelection` + `EngineeringGraph` | Right data, far thinner than V2. V2's wire inspector shows colour swatch (with bi-colour gradient), colour name, label, from/to with terminal names, description, a key-state row, and an action row (Edit / Trace / Route / Delete). V2's module info shows category-coloured stripe, sub-label, exit, notes, and **every terminal with its connected wires as clickable links** | The honest empty state; the port-to-relationship association via `metadata['sourcePort']`/`['targetPort']` (established convention — do not invent a second mechanism); "never fabricate a field" | Full V2 content and the four inspector actions |
| `_ImmersiveMeterPane` (3281) | Probe A/B ids + latest result | Duplicates `DigitalMultimeterPanel` with less function; V2's Meter tab is the photoreal instrument itself | Nothing beyond the binding to `MultimeterController` | Deleted in favour of one meter component (see §7) |
| `_KeySwitchesRow`, `_KeySwitchGroup`, `_KeySwitchButton` (3337–3507) | KEY/SWITCHES row from real session states, with keyword→icon mapping kept in Studio (not the engine) | Concept correct, location wrong — it lives in a `DockablePanel` in the top dock slot; V2 puts it inline in the topbar next to the logo | The "no fabricated default" rule; the keyword→icon map staying out of `oep_engine`; boolean vs positional input handling | Moves into the V2 topbar; merges with `SimulationControlsToolbar` (§5.2); gains V2's live `sw-ind` indicator glyphs and momentary-press START |
| `_DiagramLegendPanel` (3516) | Category colour legend using `categoryStripeColor` | Correct data source (shared with the cards — no second colour table). V2's `#legend` is a floating overlay toggled by `L` | The shared colour source | Floating overlay + `L` shortcut |
| `_DocumentActionsBar` (3556) | Dirty indicator + New/Open/Save/Save As/Load Profile/Publish/Simulate/Close | Eight `IconButton`s in a second bar; V2 has Save/Load/Export SVG inline in the single action row | The reason these exist rather than deferring to Ribbon commands: the page's versions run the unsaved-changes confirmation **and** persist workspace state, which the Ribbon's thinner commands do not | Folds into the single V2 action row; the confirmation+persist behaviour moves into the controller so the Ribbon path gets it too (closing the recorded Command Framework gap) |
| `_ResizeHandle`, `_VerticalResizeHandle` (3621, 3641) | 6 px draggable dividers for slot/panel sizing | Tied to the dock-slot model being replaced | The clamped-resize behaviour | Replaced by V2 panel resize grips + sidebar splitter |
| `_InstrumentToolbar` (3674) | Dock toggle + arm probe A/B | V2 has no probe-arming toolbar; leads are placed from the meter panel's own `▸` buttons and placement modes | The arm-then-click placement path (still needed for `manual` mode) | Moves into the meter component |
| `_IntelligenceToolbar` (3714) | Validate / Analyze + five panel toggles | Six toggles for five panels is the densest single source of clutter; no V2 counterpart | Validate/Analyze triggers | Collapses to one Intelligence entry point (§5.4) |

### 6.5 `instruments/multimeter/digital_multimeter_panel.dart` — `DigitalMultimeterPanel`, `_Controls`, `_Result`, `DigitalMultimeterInstrument`

- **Responsibility:** Material-styled meter UI — mode selection, probe display, result readout — registered as an `EngineeringInstrument`.
- **Dependencies:** `multimeter_controller.dart`, `engineering_instrument.dart`, `studio_colors`, `engineering_engine`.
- **Reason to REPLACE:** V2's meter is the single most distinctive element of the reference UI — a 220×380 SVG instrument body with a bezelled LCD (mode text, 30 px value, unit, "AUTO RANGE", note line, scanline overlay), a function dial with eight labelled positions and a rotating pointer, five mode buttons, four labelled jacks with inserted lead plugs, and a `CAT III 600V` marking; below it, lead-location rows with `▸` place buttons and a four-way lead-placement mode selector.
- **Preserve:** `DigitalMultimeterInstrument`'s registration into `InstrumentRegistry` (the Workbench Instruments Perspective depends on the instrument contract); every binding to `MultimeterController`; the `verificationReport` callback.
- **Change:** the entire visual implementation → a `CustomPaint`/SVG-equivalent V2 instrument.
- **Breaks if removed:** `test/instruments/digital_multimeter_panel_test.dart`; the Instruments Perspective panel client.

### 6.6 `tabs/diagram_mode_switcher.dart` — `DiagramModeSwitcher`, `_ModeButton`

- **Responsibility:** three-way View/Edit/Simulate switch driving `DiagramTab.mode` and `_applyModeDefaults`.
- **Dependencies:** `core/context/engineering_interaction_context.dart` (`DiagramStudioMode`), `studio_colors`.
- **Reason to REPLACE:** the mode *axis* is wrong for V2. V2's modes are **tool modes** (`editMode` = layout drag, `wireMode` = draw wire, `routeEditMode` = nudge segments), mutually exclusive, each with a badge and a status bar, each toggled by a single key (`E`, `W`, and Route from the inspector). OEP's `{view, edit, simulate}` is a *document-purpose* axis that additionally hides panels. These coexist rather than compete, but one model must be authoritative (§11.4).
- **Preserve:** `DiagramStudioMode` as an enum (it is in `core/context/` and feeds `ContextualCommandResolver`, `DiagramTab` persistence, and `test/workflow/diagram_studio_tabs_and_modes_test.dart` — **do not delete it**).
- **Change:** the widget, and the introduction of an explicit tool-mode dimension alongside it.
- **Breaks if removed:** page build; tabs/modes workflow tests.

### 6.7 `panels/diagram_recent_commands_panel.dart` — `DiagramRecentCommandsPanel`

- **Responsibility:** lists `engine.editing.recentDescriptions`.
- **Reason to REPLACE (as a workspace panel):** a permanent column showing undo-history strings has no V2 counterpart and is pure clutter in a diagram-dominant workspace.
- **Preserve:** `recentDescriptions` is genuine Engine data — surface it as an undo-history dropdown on the Undo button, or in the Output Panel.
- **Breaks if removed:** page build only.

---

## 7. DEPRECATE Components

*Redundant with the new Studio architecture; should eventually be removed. Nothing here is to be deleted during reconstruction — each needs a confirmed replacement first.*

| Path / Component | Responsibility | Why redundant | Preserve | Removal precondition | Breaks if removed |
|---|---|---|---|---|---|
| `panels/diagram_validation_panel.dart` — `DiagramValidationPanel` | Renders a `ValidationReport` via `ValidationFindingsList` | **Already dead.** The page's own comment records its removal in "Phase 3, Objective 6": it duplicated the shared Output Panel's Validation tab. Import scan confirms **no live call site** — only comments in `package_validation_dialog.dart` / `validation_findings_list.dart` and one comment in `unified_workflow_test.dart` | `ValidationFindingsList` (shared, still used) | None — it is already unreferenced | Nothing |
| `persistence/recent_files_storage.dart` — `RecentFilesStorage` | Recent local diagram file paths | Superseded twice over: `DiagramTabsStorage` is the authoritative "what was open last" record (explicitly superseding `workspace.lastDocumentPath`), and `WorkspaceManager.recentWorkspaces` drives the Workbench sidebar's recent list. Import scan finds **no live caller** — only three doc-comment references citing it as the storage *pattern* | The storage pattern (cited by `TitleBlockStorage`, `DiagramTabsStorage`, `WorkspaceStateStorage`) | Confirm no on-disk file needs migrating | `test/recent_files_storage_test.dart` |
| `_ImmersiveMeterPane` (in `diagram_studio_page.dart:3281`) | Compact probe/result summary | Duplicate meter concept alongside `DigitalMultimeterPanel` and the V2 instrument. Its own doc comment admits full interaction "remains in the existing `InstrumentDock`" | Nothing | V2 meter component exists and is mounted in the sidebar Meter tab | Nothing external |
| `_DocumentActionsBar` (`:3556`) as a **separate bar** | Second row of document buttons | Duplicates both the Ribbon's `diagram.*` commands and the V2 single action row | Its confirmation + persist behaviour (must move into the controller, not be lost) | Controller owns confirm+persist; Ribbon commands route through it | Nothing external |
| `_IntelligenceToolbar` (`:3714`) as **six workspace toggles** | Toggles five EI panels | Five permanent columns in the diagram workspace is the clutter V2 exists to refute | Validate/Analyze triggers; all five panels (§5.4) | A single Intelligence entry point exists | Nothing external |
| Dual chrome overlap: `PanelsToolbar` + `LayersToolbar` + `SearchToolbar` + `_IntelligenceToolbar` + `_InstrumentToolbar` visibility booleans (11 in `_DiagramStudioPageState`) + `_panelSlot`/`_slotSize` + `InstrumentDock` visibility | Four independent panel-placement/visibility systems | V2 has exactly one panel model (floating, draggable, resizable, per-panel persisted, `⋮` menu) | The user-stated requirement that panels have "a permanent place to sit … with the ability to move that panel to another place as well as resize" — V2 satisfies this with its panel manager | One unified panel model implemented | `test/workflow/diagram_studio_key_states_panel_drag_test.dart`, `_resize_`, `_legend_panel_` |

---

## 8. UNKNOWN Components

*Insufficient information. Each entry states exactly what must be investigated and who/what can answer it.*

**8.1 — The V2 Reconstruction Specification itself.**
The task states a formal spec "will be provided separately." Everything in this audit about V2 is read from source. Where source and spec disagree, the spec wins. **Investigate:** obtain the spec before any implementation begins; re-validate §6.2 (canvas), §11 (architecture) and §16 (order) against it.

**8.2 — Wire route override model mismatch.**
V2 stores `wireRoutes[wireId][segmentIndex] = offset` — a *relative nudge per movable segment*, recomputed against a freshly auto-routed path every draw, so a module move re-routes and the nudges still apply. OEP stores an *absolute point list* via `SetWireRouteCommand(relationshipId, List<Point2D>)`; once set, the route is frozen and no longer follows its endpoints. These are semantically different features. **Investigate:** does the V2-compatible Studio need V2's relative-offset semantics? If yes, this is an **Engine model question** (`DiagramLayoutState` wire overrides + a new command), not a UI question — and the Engine is frozen for this work, so it must be scheduled separately. Do not emulate relative offsets in UI state.

**8.3 — Property Inspector reachability in the Diagram route.**
`app/studio_shell.dart:370` returns a bare `Scaffold(body: child)` for `StudioDestination.diagram`, so **`PropertyInspectorPanel` is not mounted in the Diagram Studio route at all** (it is mounted only at `:418`, in the non-diagram branch). Yet `_syncPropertyInspectorSelection` (`diagram_studio_page.dart:659`) pushes `EngineeringInspectable` on every selection change, and `dispose()` clears it. So the eight `inspector/` modes render only if the user navigates to another studio. **Investigate:** is the bridge intentionally cross-route (feeding Validation/Search/Workbench), or is it a regression introduced by the Phase 14 full-window carve-out? This determines whether the V2 sidebar inspector *replaces* or *mirrors* the shared Property Inspector. Until answered, keep both and keep the bridge.

**8.4 — Mode-model reconciliation.**
See §6.6. **Investigate (spec):** does the V2-compatible Studio keep OEP's `{view, edit, simulate}` document modes *and* add V2 tool modes, or collapse to V2's model only? `DiagramStudioMode` is in `core/context/` and participates in contextual-command resolution and tab persistence, so this is not a purely visual decision.

**8.5 — V2 measurement data ↔ OEP simulation model.**
V2 stores per-wire, per-key-position readings (`wire.R[keyPos] = {VDC, VAC, CONT, RES, DIODE, note}`) as *authored data* in `measurements.json`, overridden at runtime by `SWPACK.getReading`. OEP computes readings from `SimulationEngine` + `MeasurementResult`. The engine does have `DomainProfile`, `OperatingStateDefinition`, `InputStateDefinition` (`oep_engine/lib/core/simulation/state/`), which map plausibly onto V2's `keyPos` and switch-pack. **Investigate:** whether V2 fidelity requires *authored* per-state readings (a data-model question) or only that the UI *presents* computed readings in V2's shape. The presentation is safe to build either way; the data model is not.

**8.6 — V2 module/terminal model ↔ OEP node/port model.**
V2 modules carry `terminals[{n, c}]` where `c` is a colour code, `exit` direction, `cat` category, `bulb`/`connector` shape flags, and connector pins encode `"IN|OUT"` colour pairs. OEP nodes carry `Port` objects, `NodeCategory`, `symbolId`, and `metadata['exit']`. `DiagramNodeVisual` already threads `displayName`, `category`, `ports`, `metadata` to the renderer, and `fallbackPorts(ports, exit:)` already derives V2-style edge port geometry. **Investigate:** where wire colour code, bi-colour stripe, and connector IN/OUT pin colours live in the OEP model — `Port.type`? `relationship.metadata`? If nowhere, a metadata convention must be agreed (and, per §15, it must be an *existing-metadata* convention, not a new parallel model).

**8.7 — Routing parity.**
V2: `allocX`/`allocY` on a 6 px lane grid, `STUB = 14`, four exit directions, deterministic per-draw allocation reset. OEP: `OrthogonalRoutingProvider` with `RoutingContext` lane + trunk allocation and obstacle sweeping — explicitly "inspired by (not copied from)" the reference (`EKE_ALGORITHMS.md` #3). **Investigate:** whether "match V2 exactly" extends to *routing geometry*. If yes, that is Engine work and is out of scope for a presentation rebuild; if no, record that OEP routing is intentionally superior and V2 fidelity stops at wire *appearance*.

**8.8 — Switch-pack (`SWPACK`) scope.**
V2 ships a bespoke `#swpack-panel` with per-switch rocker controls, live schematic SVGs, state descriptions and a state summary — deeply vehicle-specific (1988 Honda TRX300). OEP deliberately keeps domain vocabulary out of the engine and derives switches from a loaded `DomainProfile`. **Investigate:** is the switch-pack panel in scope for reconstruction as a *generic* input-state panel driven by `availableInputStates`, or out of scope as reference-vehicle-specific content?

**8.9 — Theme scope.**
V2 has a persisted light/dark theme (`data-theme`, `localStorage`) and a topbar toggle; OEP is dark-only via `StudioColors`, with `_ImmersiveColors` as a three-token Diagram-Studio-local override. **Investigate:** whether the V2-compatible Studio introduces a real theme system, and whether it is Diagram-Studio-scoped (consistent with the existing "studio-by-studio" rule) or platform-wide (a much larger change touching every studio).

---

## 9. Engineering Logic That Must Be Preserved

Everything in this section is **authoritative engineering behaviour**. None of it may be reimplemented in, moved into, or duplicated by the new presentation layer.

### 9.1 Owned by `oep_engine` — untouchable

| Capability | Type / entry point |
|---|---|
| Graph model | `EngineeringGraph`, `EngineeringNode`, `EngineeringRelationship`, `EngineeringGroup`, `Port`, `EvidenceLink` |
| Layout model | `DiagramLayoutState` (positions, sizes, annotations, layers, wire routes), `DiagramLayout.compute` |
| Undoable mutation | `EditingService.execute/undo/redo/resetSession`, `EditingSession`, and every `*Command` (`CreateNode`, `MoveNodes`, `ResizeNode`, `RotateNodes`, `MirrorNodes`, `ArrayPlace`, `ReplaceSymbol`, `AlignNodes`, `DistributeNodes`, `CreateRelationship`, `ReconnectRelationship`, `SetWireRoute`, `CreateGroup`, `Ungroup`, `CreateAnnotation`, `UpdateAnnotation`, `CreateLayer`, `UpdateLayer`, `DeleteLayer`, `DeleteMany`) |
| Selection | `SelectionService` (`selectNode`, `toggleNode`, `selectMany`, `selectAll`, `deselectAll`, `changes` stream), `GraphSelection` |
| Viewport | `ViewStateService` (`setZoom`, `setPan`, `fitAll`, `fitSelection`, `centerSelection`, `resetView`, `goBack`, `goForward`, `toggleGrid`, `toggleSnap`, `setGuidesVisible`, `setConstraints`, `setViewportSize`, `hoverPort`), `ViewState` |
| Scene assembly | `DiagramView.render(graph, layout:, routing:, symbols:, selection:) → DiagramScene` |
| Routing | `RoutingProvider` / `OrthogonalRoutingProvider`, `RoutingContext`, `RoutingRequest` |
| Hit testing | `DiagramHitTesting.relationshipAt`, `.nodesInRect` |
| Geometry helpers | `GridComputer.snap`, `AlignmentGuideComputer.computeGuides/snapToGuides`, `WireEditing.insertVertex/removeVertex/dragCorner/dragSegment`, `fallbackPorts` |
| Validation | `EngineeringEngine.validate → ValidationReport` |
| Search | `SearchService.search → SearchResult` (kinds: node, relationship, annotation, symbol, layer) |
| Clipboard | `ClipboardService.copy/cut/paste/duplicate`, `ClipboardCodec` |
| Symbols | `SymbolProvider` / `SymbolLibrary`, `SymbolPort` |
| Connection rules | `ConnectionValidator.canConnect(graph, sourceNodeId, targetNodeId)` |
| Simulation | `SimulationEngine`, `SimulationSession`, `SimulationStateSnapshot`, `VerificationReport`, `DomainProfile`, `OperatingStateDefinition`, `InputStateDefinition`, fault registry |
| Measurement | `MeasurementResult` |
| Export | SVG / PNG / PDF exporters, `EngineIds` |

### 9.2 Owned by Studio, engine-facing — must survive the rebuild intact

- `EngineHost` — engine construction + symbol seeding (§4.1).
- `DiagramDocument` — document envelope, autosave, recovery (§4.1).
- `EngineeringProjectNotifier` (**`core/`**) — the shared engine/session/selection/viewState/validation state, the document lifecycle methods, `_applyNewDocumentViewStateDefaults`, recent history, active project. Out of scope to change; the new Studio reads from it exactly as today.
- `StudioCommandActions` — the seven edit operations (§4.2).
- `DiagramSimulationService`, `MultimeterController`, `OipHostBridgeService`, `DiagramIntelligenceService`, `DiagramRepositoryService` (§4.3–4.4).

### 9.3 Interaction *semantics* that are engineering, not decoration

These are behaviours that look like UI but encode real rules; they must be carried over exactly.

1. **Connection legality** — every wire creation path (drag, two-click) gates on `ConnectionValidator.canConnect` before issuing `CreateRelationshipCommand`; a self-connection (same node) is refused and leaves the pending connection armed.
2. **Atomic gestures** — a drag/resize emits **one** command at gesture end (`MoveNodesCommand` with all final positions; `ResizeNodeCommand` carrying both size and moved position). Never per-frame commands: one gesture = one undo step.
3. **Preview vs. truth** — in-progress drags render from `_effectiveLayout()` (a layout *copy* with preview positions applied). The real layout is never mutated during a gesture.
4. **Snap order** — alignment-guide snap applies to the whole dragged group; grid snap applies per node, afterwards.
5. **Route editing constraint** — `WireEditing.dragCorner/dragSegment` are given `viewState.constraints.minimumWireLength`; the constraint is Engine-owned.
6. **Restore auto-routing** — `SetWireRouteCommand(id, null)` is the canonical "undo my manual route," distinct from undo.
7. **Selection-driven mode teardown** — leaving a single-relationship selection exits Edit-Route mode and clears working points (`_reseedWireEditPoints`).
8. **Dirty tracking** — every mutating path calls `markDocumentDirty()`, which also schedules the debounced Intelligence sync. Both effects must be preserved together.
9. **Validation cadence** — validation recomputes automatically on every `sessionChanges` emission in `EngineeringProjectNotifier`; "Revalidate"/"Validate Now" exist only to bypass debounce.
10. **Probe placement precedence** — when a probe is armed, a node/port tap places the probe **instead of** changing selection, on both the tap and pan-start paths (a plain click never reaches `onPanStart`, which is why both exist).
11. **Port-level targeting** — `metadata['sourcePort']`/`['targetPort']` is the established port↔relationship association used by `StateConditionResolver` and `VerificationEngine`. The V2 inspector and any new port UI must use it, not a new mechanism.
12. **Symbol-first port geometry** — authored `SymbolPort` geometry wins; `fallbackPorts(node.ports, exit:)` is the fallback. Pin rendering, wire endpoints and drag anchors must all resolve identically.
13. **No fabricated state** — KEY/SWITCHES render nothing when the session has no real states; the Operating-State dropdown is absent rather than defaulted. This discipline is explicit across Phases 9–14 and must survive.

### 9.4 Preservation hazards (things that will silently break)

| Hazard | Why | Mitigation |
|---|---|---|
| `markDirty()` lives in the page, not in `StudioCommandActions` | ~30 call sites; moving commands without it silently kills dirty tracking *and* Intelligence sync | The new controller must be the only place *Diagram Studio's own presentation-layer* commands are executed (not a claim about `engine.editing.execute` callers elsewhere in OEP — the global Contextual Command System is a separate, unaffected pathway; see AP-DIAGRAM-W1-R1), and must call `markDocumentDirty()` centrally |
| `dispose()` cannot use `ref.read` | Riverpod marks `ConsumerStatefulElement` disposed before `dispose()` runs — hence `_cachedDocumentPath`/`_cachedViewState` and the captured `_foundationNotifier` | Keep the caching pattern in whatever owns teardown |
| `clearEngineeringInspectableSelection` must be deferred | Mutating a provider during tree finalisation throws; hence `scheduleMicrotask` | Preserve |
| The instrument bridge must **not** be stopped on unmount | It is app-wide, controlled from Settings | Preserve the deliberate omission |
| `_viewStateSub` → matrix sync is one-directional by design | The reverse direction runs only at `onInteractionEnd` to avoid fighting the gesture recogniser | Preserve the asymmetry |
| Viewport culling | 40,000 wires unculled ≈ 179 ms/paint (measured) | Any new renderer must cull nodes, wires and annotations before building/painting |
| `kNodeHitMargin` | Edge-exit port markers sit exactly on the node boundary and fall outside `Size.contains()` without inflation | Any new node widget must reproduce the inflate-and-shift |
| Connection preview must be `IgnorePointer` | A bare `CustomPaint` hit-tests as opaque and swallowed the second click of a two-click wire | Preserve |

---

## 10. UI / Presentation Logic That Should Be Rebuilt

Everything below is presentation or interaction routing. It carries no engineering authority and is safe to rebuild against V2.

### 10.1 Window composition
The whole layout emitted by `_DiagramStudioPageState.build()` — immersive strip, `Wrap` toolbar, four dock slots, explorer column, side-panel column, layered `InstrumentDock` — is replaced by V2's three-region shell: `topbar-wrap` (identity + KEY/SWITCHES + mode badges, and an action row) over `main-area` (`left-sidebar` | `viewport`), with all other surfaces as floating overlays.

### 10.2 Diagram viewport
Scene transform application, background pan, Ctrl+wheel zoom-at-cursor, pinch, fit, minimap-click-to-centre, zoom percentage readout, rubber-band zoom box. OEP currently has: `InteractiveViewer` with `panEnabled: false`, space-drag pan, `Ctrl+0` reset, a coordinate/zoom readout chip, and a **non-interactive** minimap. V2 semantics to adopt: background drag pans in normal mode only (never in a tool mode); Ctrl/⌘+wheel zooms about the cursor; `F` fits; minimap click centres.

### 10.3 Module presentation
Category stripe, label + sub-label, terminal strip of colour dots with terminal labels, exit-direction-aware strip placement (top vs bottom), bulb card shape, inline-connector card with dual IN/OUT pins and per-pin separators, and the state classes `.mod-selected`, `.wire-selected` (endpoint highlight), `.wire-src`, `.sel-flash`.

### 10.4 Wire presentation
Per-wire group with: dim-to-10% when another wire is selected or a trace is active; glow underlay (amber for selected, green for traced); coloured main path with selection-dependent stroke width; dashed second stroke for bi-colour codes; a wide transparent hit path enabled **only in normal mode**; midpoint label chip on the selected wire; marching-ants flow overlay when a wire has non-zero voltage and continuity; per-segment hit zones with midpoint handles in route-edit mode; a dashed preview line while a wire is being drawn.

### 10.5 Selection behaviour
V2: single-select, click-to-toggle-off, endpoint cards highlighted, leads auto-placed at wire ends, trace state cleared on deselect, `Escape` cascades (lead-place → route-edit → wire-mode → modals → search → module info → wire). OEP: multi-select with additive/toggle modifiers and box-select. **These are additive, not conflicting** — keep multi-select, adopt V2's single-select feedback, its endpoint highlight, and its `Escape` cascade.

### 10.6 Dragging
V2: drag cards only in layout-edit mode. OEP: drag in any mode, multi-node, with alignment guides and grid snap. Keep OEP's capability; adopt V2's mode gating so a click in normal mode selects rather than nudges.

### 10.7 Wire editing and routing UI
Route-edit mode with segment click-select, arrow-key nudge (6 px, ×4 with Shift), `R` to reset, a status bar (`#wep`) reporting the selected segment and available keys. OEP has drag-based vertex/segment editing with no keyboard nudge and no status bar. Rebuild the *interaction*, keeping `WireEditing.*` and `SetWireRouteCommand` as the mechanism (subject to §8.2).

### 10.8 Inspector presentation
V2's Wire Inspector (colour swatch with bi-colour gradient, colour name, label, from/to with terminal names, description, key-state row, Edit/Trace/Route/Delete actions) and Module Info (stripe, sub-label, category dot, exit, notes, every terminal with its connected wires as clickable cross-links). Rebuild fully; read from `EngineeringGraph`/`GraphSelection` exactly as `_ImmersiveInspectorPane` already does.

### 10.9 Meter presentation
The photoreal instrument (§6.5) plus lead rows, lead-placement mode selector, and on-canvas lead dots for the selected wire.

### 10.10 Panels and overlays
One panel model: floating, header-drag, corner-resize, per-panel `⋮` menu (set default position / reset / re-centre / reset size), persisted per panel; sidebar panes pop out and dock back. Replaces `DockablePanel`+`PanelDockSlot`, `InstrumentDock`, `KnowledgePanel` columns and the 11 visibility booleans.

### 10.11 Toolbar and command surface
One dense action row (§6.3), a legend overlay (`L`), a search overlay (`/`), a keyboard-hint overlay (`?`), toast notifications, and mode badges.

### 10.12 Keyboard model
V2: `E` layout, `W` wire, `F` fit, `/` search, `L` legend, `0`–`3` key position, `Del` delete wire, `Esc` cascade, `Ctrl+Scroll` zoom, arrows nudge, `R` reset route. OEP: `Ctrl+Z/Y/C/X/V/D/S/A`, `Del`/`Backspace`, `Esc`, `Ctrl+0`, `Ctrl+M`. Merge: keep OEP's editor shortcuts, add V2's single-key tool/view shortcuts (they do not collide).

### 10.13 Theming
A real token set with light/dark support (§8.9), replacing `_ImmersiveColors`' three tokens.

---

## 11. Proposed New Diagram Studio Architecture

### 11.1 Target stack

```
┌──────────────────────────────────────────────────────────────────────┐
│ OEP FOUNDATION  (frozen)                                             │
│   FoundationBridge · repository · audit log                          │
└──────────────────────────────────────────────────────────────────────┘
                    ▲                                   ▲
┌───────────────────┴───────────┐   ┌───────────────────┴──────────────┐
│ OEP ENGINE  (frozen)          │   │ STUDIO ENGINEERING SERVICES      │
│  EngineeringGraph             │   │  (KEEP — §4.1–4.4)               │
│  DiagramLayoutState           │   │   EngineHost                     │
│  EditingService + Commands    │   │   DiagramDocument                │
│  SelectionService             │   │   StudioCommandActions           │
│  ViewStateService             │   │   DiagramSimulationService       │
│  RoutingProvider              │   │   MultimeterController           │
│  DiagramView → DiagramScene   │   │   DiagramIntelligenceService     │
│  DiagramHitTesting            │   │   DiagramRepositoryService       │
│  SimulationEngine             │   │   OipHostBridgeService           │
│  SearchService · Validation   │   │   Diagram*Storage                │
│  ClipboardService · Symbols   │   │   AI prompt/service              │
│  [views/widgets — NOT USED    │   └──────────────────────────────────┘
│   by the new Studio]          │                    ▲
└───────────────────────────────┘                    │
                    ▲                                │
                    └──────────────┬─────────────────┘
                                   │
┌──────────────────────────────────┴───────────────────────────────────┐
│ ★ STUDIO CONTROLLER / ADAPTER  (NEW — the missing layer)             │
│   DiagramStudioController                                            │
│     • reads EngineeringProjectState (engine, session, selection,     │
│       viewState, document, validationReport)                         │
│     • owns interaction state ONLY: tool mode, drag/resize/connect/   │
│       reconnect/route-edit gesture state, box-select rect, hover,    │
│       armed probe, cursor scene position                             │
│     • translates gestures → Engine Commands (the ONLY executor)      │
│     • centralises markDocumentDirty() + Intelligence sync            │
│     • exposes derived view models: DiagramScene, effective layout,   │
│       inspector view model, meter view model, key-state view model   │
│   DiagramStudioLayoutController   (panels, sidebar, overlays)        │
│   DiagramStudioViewportController (zoom/pan/fit ↔ ViewState)         │
└──────────────────────────────────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┴───────────────────────────────────┐
│ ★ V2-COMPATIBLE PRESENTATION  (NEW — Studio-owned)                   │
│   DiagramCanvas        renders DiagramScene in V2's visual language  │
│   ModuleCardRenderer   standard / bulb / connector cards             │
│   WireRenderer         glow · stripe · dim · flow · label · hit path │
│   OverlayLayers        guides · box-select · preview · probes ·      │
│                        validation · simulation                       │
│   V2 chrome            TopBar · LeftSidebar(Inspector|Meter) ·       │
│                        ActionRow · Legend · Search · Minimap ·       │
│                        Tracer · KbHints · Toast · ContextMenu        │
│   V2 panel model       floating · drag · resize · ⋮ menu · persisted │
└──────────────────────────────────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┴───────────────────────────────────┐
│ ★ V2-COMPATIBLE INTERACTION SYSTEM  (NEW)                            │
│   HitTester   point → {node, port, wire, wireSegment, annotation}    │
│   ToolModes   normal · layout · wire · route   (mutually exclusive)  │
│   GestureRouter  routes pointer/keyboard events by active tool mode  │
│   KeyMap      V2 single-key + OEP editor shortcuts                   │
└──────────────────────────────────────────────────────────────────────┘
                                   │
                            Flutter widgets
```

### 11.2 Proposed directory layout

```
lib/diagram_studio/
├── host/            KEEP     engine_host.dart, diagram_document.dart
├── commands/        KEEP     studio_command_actions.dart
├── ai/              KEEP     unchanged
├── intelligence/    KEEP     unchanged
├── repository/      KEEP     unchanged
├── simulation/      KEEP     service; panels → secondary surfaces
├── instruments/     KEEP     runtime; panel → V2 meter
├── instruments_host/KEEP     unchanged
├── publishing/      KEEP     unchanged
├── inspector/       KEEP     shared Property Inspector modes
├── persistence/     ADAPT    workspace-state schema
├── settings/        ADAPT    add V2 preferences
├── tabs/            KEEP     model/controller; ADAPT tab bar
│
├── controller/      ★ NEW    diagram_studio_controller.dart
│                             layout_controller.dart
│                             viewport_controller.dart
│                             tool_mode.dart
│                             gesture_router.dart
│                             hit_tester.dart
│
├── presentation/    ★ NEW    canvas/diagram_canvas.dart
│                             canvas/module_card.dart
│                             canvas/wire_renderer.dart
│                             canvas/overlays/*.dart
│                             chrome/top_bar.dart
│                             chrome/action_row.dart
│                             chrome/left_sidebar.dart
│                             chrome/wire_inspector.dart
│                             chrome/module_inspector.dart
│                             chrome/meter_instrument.dart
│                             chrome/legend_overlay.dart
│                             chrome/search_overlay.dart
│                             chrome/minimap.dart
│                             chrome/tracer_panel.dart
│                             chrome/status_bar.dart
│                             chrome/toast.dart
│                             panels/floating_panel.dart
│                             panels/panel_manager.dart
│                             theme/v2_tokens.dart
│
└── workspaces/      REPLACE  diagram_studio_page.dart → thin composition root
```

### 11.3 Controller contract (sketch — not implementation)

The controller is the **only** object that calls `engine.editing.execute`. That single rule fixes the `markDirty` hazard (§9.4), gives the Ribbon path the same confirmation/persistence behaviour as the toolbar path, and makes the presentation layer trivially testable.

- **Reads:** `EngineeringProjectState` (engine, session, selection, viewState, document, validationReport).
- **Owns:** tool mode; drag/resize/connect/reconnect/route-edit gesture state; box-select rect; hover; cursor scene position; armed probe slot.
- **Emits:** commands, selection calls, viewport calls; a `DiagramScene` + effective layout for rendering; inspector/meter/key-state view models.
- **Never owns:** graph, layout, selection truth, viewport truth, validation, simulation state, measurement state.

### 11.4 Proposed mode model (pending §8.4)

Two orthogonal dimensions, explicitly separated rather than conflated:

| Dimension | Values | Source of truth | Effect |
|---|---|---|---|
| **Document mode** (OEP) | `view`, `edit`, `simulate` | `DiagramTab.mode` (persisted) | Which command *sets* are available; feeds `ContextualCommandResolver` |
| **Tool mode** (V2) | `normal`, `layout`, `wire`, `route` | Controller (session-local) | Which gestures the canvas routes; badge + status bar; mutually exclusive; only selectable within document mode `edit` |

This preserves `DiagramStudioMode` (required by `core/context/` and tab persistence) while giving V2's `E`/`W`/Route toggles a real home.

### 11.5 What `diagram_studio_page.dart` becomes

Answering audit item 1 and item 10 directly: **it remains the Studio entry point, reduced to a thin composition root** — it should *not* be replaced by a different entry point, because `workbench/perspectives/diagram_perspective.dart` and `studio_shell.dart` both address it by name, and 12 workflow tests pump it directly. Its new body:

1. `ref.watch(engineeringProjectServiceProvider)` and `ref.watch(diagramTabsProvider)`.
2. Construct/obtain `DiagramStudioController` (a provider, so it outlives rebuilds and is reachable from the Command Registry).
3. Await bootstrap (engine → instruments → intelligence → workspace state → tabs restore → subscriptions).
4. Render `DiagramStudioShell(controller: …)` — the V2 three-region layout.
5. Own nothing else. Target size: **under 200 lines**, mirroring V2's own rule that `app.js` "becomes bootstrap only (<200 lines)."

---

## 12. Migration Boundary

### 12.1 The boundary, stated precisely

> **The boundary is `DiagramScene` in, Engine Commands out.**
>
> Everything that consumes `DiagramScene`, `ViewState`, `GraphSelection`, `MeasurementResult`, `SimulationStateSnapshot` and `ValidationReport` **for display**, and everything that converts a user gesture into a *request*, is **presentation and is rebuilt**.
>
> Everything that produces those types, and everything that executes a command, persists a document, computes a route, resolves a measurement, validates a graph, or talks to Foundation, is **engineering and is preserved**.

### 12.2 Boundary table

| Direction | Crosses the boundary as | Examples |
|---|---|---|
| Engine → Presentation | Immutable value types only | `DiagramScene`, `DiagramNodeVisual`, `DiagramWireVisual`, `ViewState`, `GraphSelection`, `ValidationReport`, `SimulationStateSnapshot`, `MeasurementResult`, `SearchResult`, `DomainProfile` |
| Presentation → Controller | Intent, never mutation | `onNodeTap(id)`, `onPortDragEnd(...)`, `onSegmentNudge(dir, large)`, `onToolModeChanged(mode)` |
| Controller → Engine | Commands and service calls only | `engine.editing.execute(MoveNodesCommand(...))`, `selection.selectNode(...)`, `viewState.fitAll(...)` |
| Never crosses | Widgets, `BuildContext`, `Offset`/`Size`/`Matrix4`, theme tokens, panel state | The Engine must never learn about V2 chrome |

### 12.3 Three specific boundary rulings

**(a) `oep_engine/lib/views/widgets/` is on the *presentation* side of the boundary but lives in the Engine package.**
This is a pre-existing violation of the stack in §11.1, and the audit brief forbids changing Engine code. **Ruling:** do not modify, do not delete, do not move those widgets. The new Studio simply stops importing them and renders `DiagramScene` itself. The Demonstration Host keeps them working. Record as technical debt for a later, separately-scheduled Engine work package: "Engine should not own Flutter presentation."

**(b) `host/` and `settings/` are on the *engineering/platform* side but live under `lib/diagram_studio/`.**
`core/services/engineering_project_service.dart` imports three files from them (§3.3). **Ruling:** leave them where they are during reconstruction (moving them is a cross-cutting rename this audit forbids), but treat them as **platform components with a studio-shaped path** — they are KEEP, and no reconstruction step may assume "under `diagram_studio/` ⇒ replaceable UI."

**(c) `inspector/` is on the *presentation* side but belongs to the shared Property Inspector, not to Diagram Studio.**
**Ruling:** KEEP untouched. The V2 sidebar inspector is a *second, Studio-local* presentation of the same selection; it does not replace the shared modes. Resolve §8.3 before deciding whether the two are both mounted.

### 12.4 Persistence category separation (answering audit item 7)

The brief requires these categories to remain separated. They currently are — mostly. Ruling per file:

| File | Category | Correct today? | Ruling |
|---|---|---|---|
| `host/diagram_document.dart` | **Engineering data** (graph + layout + metadata) | ✅ | KEEP; never add UI state to this envelope |
| `host/diagram_document.dart` autosave/recovery | **Engineering data** (recovery copy) | ✅ — deliberately a separate file from the user's save path | KEEP |
| `persistence/diagram_workspace_state.dart` | **UI state** (panel visibility, widths) **+ ambient session state** (`ViewState`) | ⚠️ mixed, but deliberately and correctly: it explicitly excludes graph/layout, and `ViewState` is documented as ambient, never document content | ADAPT the schema; keep both the exclusion rule and the `ViewState` inclusion |
| `persistence/workspace_state_storage.dart` | UI state storage | ✅ | KEEP |
| `tabs/diagram_tabs_storage.dart` | **Temporary workspace state** (open tabs, recently closed) | ✅ | KEEP |
| `settings/diagram_studio_settings_storage.dart` | **User preferences** (new-document defaults) | ✅ | KEEP; extend the model |
| `instruments/dock/instrument_dock_storage.dart` | UI state (dock layout) | ✅ category, ⚠️ duplicated by `_panelSlot`/`_slotSize` (runtime-only, unpersisted) | ADAPT into the single V2 panel model |
| `instruments/bookmarks/*_store.dart`, `history/*_store.dart` | **Engineering data** (measurements) | ✅ | KEEP |
| `publishing/title_block_storage.dart` | **Engineering document metadata** | ✅ | KEEP |
| `persistence/recent_projects_storage.dart` | Engineering data reference | ✅ | KEEP |
| `persistence/recent_files_storage.dart` | UI state | ✅ category, but **no live caller** | DEPRECATE (§7) |

**One new rule to enforce:** layout is engineering data (`DiagramLayoutState`, saved in the document); *panel* layout is UI state (saved in workspace state). V2 conflates them (`layout.json` holds `positions` and is saved by the same button as everything else) — **do not adopt that**.

---

## 13. File-by-File Migration Plan

All 79 files under `lib/diagram_studio/`, plus the external files that constrain them. **Wave** refers to §16.

| # | File | Primary component | Class | Action | Wave |
|---|---|---|---|---|---|
| 1 | `ai/diagram_ai_service.dart` | `DiagramAiService` | KEEP | Untouched | — |
| 2 | `ai/diagram_prompt_context.dart` | `DiagramPromptContext` | KEEP | Untouched | — |
| 3 | `commands/studio_command_actions.dart` | `StudioCommandActions` | KEEP | Untouched; controller becomes its sole caller | 2 |
| 4 | `context_menu/diagram_context_menu.dart` | `showDiagramContextMenu` | ADAPT | Re-skin to V2 `#ctx`; close port/annotation hit-test gap via new `HitTester` | 5 |
| 5 | `host/diagram_document.dart` | `DiagramDocument` + 2 | KEEP | Untouched | — |
| 6 | `host/engine_host.dart` | `EngineHost` | KEEP | Untouched | — |
| 7 | `inspector/diagram_annotation_properties.dart` | `DiagramAnnotationProperties` | KEEP | Untouched | — |
| 8 | `inspector/diagram_layer_properties.dart` | `DiagramLayerProperties` | KEEP | Untouched | — |
| 9 | `inspector/engineering_evidence_link_properties.dart` | `EngineeringEvidenceLinkProperties` | KEEP | Untouched | — |
| 10 | `inspector/engineering_group_properties.dart` | `EngineeringGroupProperties` | KEEP | Untouched | — |
| 11 | `inspector/engineering_node_properties.dart` | `EngineeringNodeProperties` | KEEP | Untouched | — |
| 12 | `inspector/engineering_port_properties.dart` | `EngineeringPortProperties` | KEEP | Untouched | — |
| 13 | `inspector/engineering_relationship_properties.dart` | `EngineeringRelationshipProperties` | KEEP | Untouched | — |
| 14 | `inspector/wire_override_properties.dart` | `WireOverrideProperties` | KEEP | Untouched | — |
| 15 | `instruments/bookmarks/measurement_bookmark.dart` | `MeasurementBookmark` | KEEP | Untouched | — |
| 16 | `instruments/bookmarks/measurement_bookmark_store.dart` | `MeasurementBookmarkStore` | KEEP | Untouched | — |
| 17 | `instruments/core/engineering_instrument.dart` | `EngineeringInstrument`, `InstrumentRegistry` | KEEP | Untouched | — |
| 18 | `instruments/dock/instrument_dock.dart` | `InstrumentDock` + 5 | ADAPT | Keep `_FloatingFrame`/`_ResizeGrip` behaviour; drop auto-hide strip + dock tab bar | 6 |
| 19 | `instruments/dock/instrument_dock_controller.dart` | `InstrumentDockController` | ADAPT | Merge into unified panel manager | 6 |
| 20 | `instruments/dock/instrument_dock_state.dart` | `InstrumentDockState`, `DockPosition` | ADAPT | Extend to per-panel default position; unify with `PanelDockSlot` | 6 |
| 21 | `instruments/dock/instrument_dock_storage.dart` | `InstrumentDockStorage` | ADAPT | Schema follows state | 6 |
| 22 | `instruments/history/measurement_history_entry.dart` | `MeasurementHistoryEntry` | KEEP | Untouched | — |
| 23 | `instruments/history/measurement_history_store.dart` | `MeasurementHistoryStore` | KEEP | Untouched | — |
| 24 | `instruments/multimeter/digital_multimeter_panel.dart` | `DigitalMultimeterPanel`, `_Controls`, `_Result` | REPLACE | New V2 photoreal instrument; **keep** `DigitalMultimeterInstrument` registration | 6 |
| 25 | `instruments/multimeter/multimeter_controller.dart` | `MultimeterController` | KEEP | Untouched | — |
| 26 | `instruments/probe/probe_overlay.dart` | `ProbeOverlay`, `ProbeSlot` | ADAPT | Add auto-place-on-wire-selection + 4 lead modes; render only for selected wire | 6 |
| 27 | `instruments_host/instrument_bridge_provider.dart` | provider | KEEP | Untouched | — |
| 28 | `instruments_host/oip_host_bridge_service.dart` | `OipHostBridgeService` | KEEP | Untouched | — |
| 29 | `intelligence/diagram_intelligence_service.dart` | `DiagramIntelligenceService` | KEEP | Untouched; triggers move to controller | 2 |
| 30 | `migration/legacy_migration_dialog.dart` | `LegacyMigrationDialog` | KEEP | Untouched (test-only caller today) | — |
| 31 | `migration/legacy_migration_models.dart` | `LegacyMigrator` + 2 | KEEP | Possibly extend for V2 project import (§8.6) | 8 |
| 32 | `panels/diagram_annotation_panel.dart` | `DiagramAnnotationPanel` | ADAPT | Move to toggled floating panel | 7 |
| 33 | `panels/diagram_explorer_panel.dart` | `DiagramExplorerPanel` | ADAPT | Relocate out of diagram workspace | 7 |
| 34 | `panels/diagram_intelligence_overlay.dart` | `DiagramIntelligenceOverlay` | ADAPT | Re-host on new canvas transform; V2 dim+glow language | 4 |
| 35 | `panels/diagram_layer_panel.dart` | `DiagramLayerPanel` | ADAPT | Toggled floating panel, not a default column | 7 |
| 36 | `panels/diagram_mini_map.dart` | `DiagramMiniMap` | ADAPT | Restore click-to-centre (drop `IgnorePointer` at call site) | 4 |
| 37 | `panels/diagram_recent_commands_panel.dart` | `DiagramRecentCommandsPanel` | REPLACE | Undo-history dropdown / Output Panel | 7 |
| 38 | `panels/diagram_search_panel.dart` | `DiagramSearchPanel` | ADAPT | Floating `/`-triggered overlay with `sel-flash` | 5 |
| 39 | `panels/diagram_validation_panel.dart` | `DiagramValidationPanel` | DEPRECATE | Already unreferenced — remove after confirming | 8 |
| 40 | `panels/engineering_explorer_panel.dart` | `EngineeringExplorerPanel` | ADAPT | Secondary Intelligence surface | 7 |
| 41 | `panels/intelligence_panel_shared.dart` | 3 shared primitives | KEEP | Untouched | — |
| 42 | `panels/knowledge_graph_panel.dart` | `KnowledgeGraphPanel` + 3 | ADAPT | Secondary Intelligence surface | 7 |
| 43 | `panels/knowledge_sessions_panel.dart` | `KnowledgeSessionsPanel` | ADAPT | Secondary Intelligence surface | 7 |
| 44 | `panels/query_console_panel.dart` | `QueryConsolePanel` | ADAPT | Secondary Intelligence surface | 7 |
| 45 | `panels/recommendation_panel.dart` | `RecommendationPanel` | ADAPT | Secondary Intelligence surface | 7 |
| 46 | `persistence/diagram_workspace_state.dart` | `DiagramWorkspaceState` | ADAPT | New V2-shaped panel-layout schema | 6 |
| 47 | `persistence/recent_files_storage.dart` | `RecentFilesStorage` | DEPRECATE | Remove after confirming no on-disk migration need | 8 |
| 48 | `persistence/recent_projects_storage.dart` | `RecentProjectsStorage` | KEEP | Untouched | — |
| 49 | `persistence/workspace_state_storage.dart` | `WorkspaceStateStorage` | KEEP | Untouched (schema changes in #46) | — |
| 50 | `publishing/engineering_summary.dart` | `EngineeringSummary` | KEEP | Untouched | — |
| 51 | `publishing/exchange_checklist.dart` | `ExchangeChecklist` | KEEP | Untouched | — |
| 52 | `publishing/intelligence_reports.dart` | `IntelligenceReportRenderer` | KEEP | Untouched | — |
| 53 | `publishing/package_manifest.dart` | `PackageManifest` | KEEP | Untouched | — |
| 54 | `publishing/publishing_center_dialog.dart` | `PublishingCenterDialog`, `DiagramPrintPreviewDialog` | KEEP | Untouched; entry point moves to V2 action row | 5 |
| 55 | `publishing/tabular_report_dialog.dart` | `TabularReportDialog` | KEEP | Untouched | — |
| 56 | `publishing/tabular_report_kind.dart` | `TabularReportKind` | KEEP | Untouched | — |
| 57 | `publishing/title_block_editor_dialog.dart` | `TitleBlockEditorDialog` | KEEP | Untouched | — |
| 58 | `publishing/title_block_storage.dart` | `TitleBlockStorage`, `TitleBlockPresetStorage` | KEEP | Untouched | — |
| 59 | `repository/diagram_repository_service.dart` | `DiagramRepositoryService` | KEEP | Untouched | — |
| 60 | `settings/diagram_studio_settings.dart` | `DiagramStudioSettings` | ADAPT | Add V2 preferences (theme, nudge step, exit default) | 6 |
| 61 | `settings/diagram_studio_settings_page.dart` | `DiagramStudioSettingsPage` + 3 | ADAPT | Surface new preferences; `_InstrumentBridgeSection` untouched | 6 |
| 62 | `settings/diagram_studio_settings_provider.dart` | `DiagramStudioSettingsNotifier` | KEEP | Untouched | — |
| 63 | `settings/diagram_studio_settings_storage.dart` | `DiagramStudioSettingsStorage` | KEEP | Untouched | — |
| 64 | `simulation/diagram_simulation_service.dart` | `DiagramSimulationService` | KEEP | Untouched | — |
| 65 | `simulation/fault_injection_panel.dart` | `FaultInjectionPanel` | KEEP | Untouched (lives in Simulation Center) | — |
| 66 | `simulation/power_distribution_panel.dart` | `PowerDistributionPanel` | KEEP | Untouched | — |
| 67 | `simulation/simulation_center_dialog.dart` | `SimulationCenterDialog` | KEEP | Untouched; entry point moves to V2 action row | 5 |
| 68 | `simulation/simulation_diagnostics_panel.dart` | `SimulationDiagnosticsPanel` | KEEP | Untouched | — |
| 69 | `simulation/simulation_playback_controls.dart` | `SimulationPlaybackControls` | KEEP | Untouched | — |
| 70 | `simulation/simulation_sessions_panel.dart` | `SimulationSessionsPanel` | KEEP | Untouched | — |
| 71 | `simulation/simulation_state_overlay.dart` | `SimulationStateOverlay` | ADAPT | Re-host; add V2 flow animation + trace dimming | 4 |
| 72 | `tabs/diagram_mode_switcher.dart` | `DiagramModeSwitcher` | REPLACE | New mode UI on the two-dimension model (§11.4) | 3 |
| 73 | `tabs/diagram_tab.dart` | `DiagramTab` | KEEP | Untouched | — |
| 74 | `tabs/diagram_tab_bar.dart` | `DiagramTabBar`, `_TabChip` | ADAPT | Restyle into the V2 top strip | 3 |
| 75 | `tabs/diagram_tabs_controller.dart` | `DiagramTabsNotifier` | KEEP | Untouched | — |
| 76 | `tabs/diagram_tabs_storage.dart` | `DiagramTabsStorage` | KEEP | Untouched | — |
| 77 | `toolbars/diagram_toolbars.dart` | `SimulationControlsToolbar` | ADAPT | Merge into V2 topbar KEY row | 3 |
| 78 | `toolbars/diagram_toolbars.dart` | 11 other groups + 2 privates | REPLACE | New action row; **binding table preserved verbatim** (§6.3) | 3 |
| 79 | `workspaces/diagram_studio_page.dart` | `DiagramStudioPage` + 13 privates | REPLACE | Extract §4.9 logic → controller; extract chrome → presentation; reduce to <200-line composition root | 1–7 |

### 13.1 External files that must be touched (outside `lib/diagram_studio/`)

| File | Change | Constraint |
|---|---|---|
| `app/studio_shell.dart:370` | Full-window carve-out remains; re-verify once the V2 shell exists | Do not change other studios' chrome |
| `workbench/perspectives/diagram_perspective.dart` | No change if `DiagramStudioPage` keeps its name and self-contained chrome | `suppressWorkbenchStatusBar: true` still applies |
| `shared/widgets/dockable_panel.dart`, `panel_dock_slot.dart` | Superseded by the V2 panel model **inside Diagram Studio only** | Other studios may still use them — do not delete |
| `knowledge/widgets/knowledge_panel.dart` | Diagram Studio stops using it | Knowledge Studio still does — do not delete |
| `test/workflow/diagram_studio_*.dart` (12 files) | Re-point at the new widget tree | Behavioural assertions must be preserved, not weakened |

### 13.2 Files explicitly **not** to be touched

`oep_engine/**` (all), `oep_foundation/**` (all), `core/services/engineering_project_service.dart`, `core/context/**`, `core/commands/command_registry.dart`, `shared/widgets/property_inspector_panel.dart`, `core/routing/studio_registry.dart`.

---

## 14. Risks

| # | Risk | Severity | Likelihood | Evidence | Mitigation |
|---|---|---|---|---|---|
| R1 | **Treating `lib/diagram_studio/` as "the UI" and replacing it wholesale** breaks `core/services/engineering_project_service.dart`, which imports `host/` and `settings/` | Critical | High | §3.1, §3.3 | §15 forbids it; §13 marks 38 files KEEP; run the import scan before any deletion |
| R2 | **Losing `markDirty()`** when commands move out of the page — dirty tracking *and* debounced Intelligence sync both die silently | High | High | §9.4; ~30 call sites | Controller is the sole command executor and calls `markDocumentDirty()` centrally; add a test asserting dirty-after-edit |
| R3 | **Reimplementing engineering logic in the new renderer** (routing, snapping, hit-testing, measurement) because it is "easier to draw it that way" | High | Medium | V2 does exactly this — its renderer owns routing, allocation and hit zones | §12.2 boundary table; code review rule: no geometry maths in `presentation/` beyond transform application |
| R4 | **V2's relative wire-route model is adopted in UI state** to avoid an Engine change, creating a parallel layout model | High | Medium | §8.2 | Escalate as an Engine work package; until resolved, keep absolute `SetWireRouteCommand` |
| R5 | **Regression in the 12 workflow tests** that drive `DiagramStudioPage` by tooltip/icon | High | High | §3.1 | Re-point tests wave by wave; never weaken an assertion to make it pass |
| R6 | **Performance regression** — a naive V2-faithful renderer (per-wire glow + stripe + flow + label, per-node card widgets) without culling | High | Medium | 40,000 wires unculled ≈ 179 ms/paint (measured, `test/performance/rendering_performance_test.dart`) | Port culling first, before visual fidelity; keep `RepaintBoundary` discipline; re-run the perf test each wave |
| R7 | **Losing capabilities V2 lacks** — layers, annotations, groups, multi-select, box-select, align/distribute, array placement, symbol replace, multi-document tabs, Intelligence, publishing | High | High | V2 has none of these; §5.4, §6.3 | Every removal from the visible surface must be a *relocation* with a recorded destination, never a deletion |
| R8 | **Two chrome systems coexisting indefinitely** — the Phase 14 immersive strip already coexists with the old toolbars | Medium | High | §1.1 item 3 | Wave 3 must *delete* the `Wrap` toolbar in the same change that introduces the action row |
| R9 | **Engine widgets diverge** — `GraphViewPanel` still used by the Demonstration Host while Studio uses a new renderer; bug fixes land in one | Medium | High | §6.2 | Accept consciously; record as debt; keep `DiagramScene` as the shared contract so fixes are portable |
| R10 | **`_ImmersiveColors`-style partial theming** — a V2 look built on three tokens | Medium | High | §6.4 | Extract the full `main.css` token set (both themes) before building chrome (Wave 0) |
| R11 | **Property Inspector double-presentation** — V2 sidebar inspector and shared `PropertyInspectorPanel` drift apart | Medium | Medium | §8.3 | Resolve §8.3 first; if both are kept, both must read `EngineeringInspectable` from the same notifier |
| R12 | **Spec/source divergence** — this audit's V2 model is read from source, not from the (unissued) spec | Medium | Medium | §8.1 | Re-validate §6.2/§11/§16 on spec receipt before Wave 1 |
| R13 | **Instrument contract breakage** cascading into the Workbench Instruments Perspective when the DMM panel is replaced | Medium | Medium | §3.1, §6.5 | Keep `DigitalMultimeterInstrument`'s registration and the `EngineeringInstrument` contract unchanged |
| R14 | **Persistence category collapse** — adopting V2's habit of saving positions, panel layout and preferences together | Medium | Medium | §12.4 | The category table in §12.4 is normative; add a test that workspace state never contains graph/layout |
| R15 | **Selection-model conflict** — V2's single-select toggle-off vs OEP's multi-select with modifiers | Low | Medium | §10.5 | Treat as additive: OEP model retained, V2 feedback adopted |
| R16 | **Scope creep into `oep_engine` routing** to chase V2 wire geometry | Medium | Medium | §8.7 | Ruling required before Wave 4; presentation fidelity ≠ geometry parity |

---

## 15. Explicitly Forbidden Changes

The following are **prohibited** for the entire reconstruction, not merely for this audit.

1. **Do not modify `oep_foundation`.** No schema change, no API change, no repository-interface change.
2. **Do not modify `oep_engine`.** Specifically including `lib/views/widgets/` — `GraphViewPanel`, `SymbolNodeWidget`, `WirePainter`, `AnnotationWidget`, `GridPainter`, `GuidesPainter`, `ConnectionPreviewPainter`, `ResizeHandles`, `WireEditHandles`, `ReconnectHandle`, `OriginIndicator` — even though they are presentation. Stop importing them; do not edit, move, or delete them.
3. **Do not change repository interfaces** (`FoundationBridge`, `oep_api_types`, `DiagramRepositoryService`'s Foundation contract).
4. **Do not move engineering logic into UI code.** No routing, snapping, hit-testing, validation, measurement resolution, simulation state, or graph mutation inside `presentation/`.
5. **Do not create a parallel data model to reproduce the V2 UI.** No Studio-side `Module`, `Terminal`, `Wire`, `positions`, `wireRoutes`, or `MEASUREMENTS` mirror. Every V2 concept maps onto `EngineeringNode` / `Port` / `EngineeringRelationship` / `DiagramLayoutState` / `SimulationSession`, or it is escalated as an Engine question (§8.2, §8.5, §8.6).
6. **Do not let the UI become the source of truth.** Selection, viewport, layout, graph and simulation state are read from the Engine every frame; the controller may hold *in-progress gesture* state only, and must reconcile to the Engine at gesture end.
7. **Do not delete anything under `lib/diagram_studio/` classified KEEP or ADAPT**, and do not delete DEPRECATE items before their replacement is confirmed working.
8. **Do not remove a capability to achieve V2 fidelity.** Layers, annotations, groups, multi-select, align/distribute, array placement, symbol replacement, tabs, Intelligence, simulation and publishing are OEP capabilities V2 never had. They may be *relocated*; they may not be dropped.
9. **Do not weaken or delete existing tests** to accommodate the new widget tree. Re-point them.
10. **Do not remove the `EngineeringProjectNotifier` boundary.** The page must never own the engine again.
11. **Do not change `core/context/` command-resolution contracts** (`EngineeringInteractionContext`, `CursorTarget`, `ContextualCommandResolver`, `DiagramStudioMode`).
12. **Do not modify `shared/widgets/property_inspector_panel.dart` or the eight `inspector/` modes** to serve the V2 sidebar. Build the V2 inspector alongside them.
13. **Do not adopt V2's persistence conflation** (§12.4).
14. **Do not begin implementation before the V2 Reconstruction Specification is received** and reconciled against §8.

---

## 16. Recommended Implementation Order

Nine waves. Each wave ends with the app building, the existing test suite green (re-pointed, not weakened), and the performance test re-run.

**Wave 0 — Preconditions (no code).**
Receive and reconcile the V2 Reconstruction Specification (§8.1). Obtain rulings on §8.2 (route override model), §8.3 (Property Inspector reachability), §8.4 (mode model), §8.7 (routing parity). Extract the full `css/main.css` token set for both themes into a specification of `v2_tokens.dart`. **Exit:** every §8 item is either resolved or explicitly deferred with a recorded owner.

**Wave 1 — Controller extraction (behaviour-preserving, zero visual change).**
Create `controller/diagram_studio_controller.dart`. Move §4.9 logic and §2.3 items #13–#28 out of the page, verbatim. Make the controller the sole command executor and centralise `markDocumentDirty()`. The page keeps its existing widget tree and simply delegates. **Exit:** all 12 workflow tests pass unmodified. *This is the highest-value wave and the one most likely to be skipped — do not skip it.*

**Wave 2 — Composition root reduction.**
Move bootstrap, subscriptions, teardown constraints (§9.4), document/tab lifecycle and workspace persistence into controller/providers. Page shrinks toward <200 lines but still renders the old tree. **Exit:** page contains no gesture handlers and no engine calls.

**Wave 3 — V2 shell and chrome (first visible change).**
Build `presentation/theme/v2_tokens.dart`, `chrome/top_bar.dart` (identity + KEY/SWITCHES merged from `_KeySwitchesRow` + `SimulationControlsToolbar` + mode badges), `chrome/action_row.dart` (the ~14-control row, bound to the preserved §6.3 table), restyled `DiagramTabBar`, new mode UI on the §11.4 two-dimension model, `chrome/left_sidebar.dart` with Inspector/Meter tabs. **Delete the `Wrap` toolbar in this same wave** (R8). Canvas still `GraphViewPanel`. **Exit:** V2 window frame around the old canvas; toolbar-driven tests re-pointed.

**Wave 4 — V2 canvas.**
`presentation/canvas/`: `DiagramCanvas` consuming `DiagramScene`; `ModuleCardRenderer` (standard/bulb/connector); `WireRenderer` (glow, stripe, dim, label chip, flow animation, hit path); viewport culling **ported first**; `kNodeHitMargin` reproduced; `IgnorePointer` on the preview. Re-host `DiagramIntelligenceOverlay`, `SimulationStateOverlay`, `ProbeOverlay`; restore minimap click-to-centre. Stop importing `GraphViewPanel`. **Exit:** perf test at or better than baseline; `diagram_hit_testing_widget_test.dart` re-pointed and passing.

**Wave 5 — V2 interaction system.**
`HitTester` (node/port/wire/segment/annotation from one point — closes the §5.7 gap), `ToolModes` + `GestureRouter` + mode badges + `#wep` status bar, route-edit segment select and arrow-key nudge, V2 selection feedback (endpoint highlight, dim, `sel-flash`), merged keyboard map, search overlay (`/`), legend overlay (`L`), keyboard-hints overlay (`?`), toast, V2 context menu. **Exit:** every V2 shortcut works; every OEP editor shortcut still works.

**Wave 6 — Meter, instruments, panel model, persistence, settings.**
V2 photoreal multimeter (keeping `DigitalMultimeterInstrument`); lead rows + four placement modes + auto-place on wire selection; unified floating panel model (drag, resize, `⋮` menu, per-panel persistence) replacing `DockablePanel`/`PanelDockSlot`/`InstrumentDock` **within Diagram Studio only**; new `DiagramWorkspaceState` schema; new settings fields. **Exit:** one panel system; panel positions survive restart; instrument tests pass.

**Wave 7 — Relocations.**
Move Layers, Annotations, Explorer, Recent Commands and the five Intelligence panels off the primary workspace to their recorded destinations; single Intelligence entry point; wire the Tracer panel (V2 `#tracer`) to the existing trace/analysis capability. **Exit:** primary workspace = topbar + sidebar + viewport + floating overlays, and **no capability is unreachable**.

**Wave 8 — Cleanup.**
Remove DEPRECATE items (§7) now that replacements exist: `diagram_validation_panel.dart`, `recent_files_storage.dart`, `_ImmersiveMeterPane`, the residual dual-chrome state. Record §12.3(a) and §12.3(b) as Engine/platform debt items. Update `docs/architecture/diagram_studio/*` to describe the new layering. **Exit:** no dead code; documentation matches implementation.

---

## Closing Statement

> **Exactly what should we rebuild, exactly what should we preserve, and exactly where is the architectural boundary?**

**Rebuild — the window, not the machine.**
Rebuild `workspaces/diagram_studio_page.dart` (all 3,785 lines of it, as a decomposition rather than a deletion); the Studio's canvas host and its entire visual language (module cards, wire rendering, selection feedback, overlays); eleven of the twelve toolbar groups as a single V2 action row; the top strip, left sidebar, inspector presentation, meter instrument, legend, search, minimap interactivity, context-menu presentation, panel model, keyboard model and theme. Add the two layers that do not exist today: a **Studio Controller/Adapter** and a **V2-compatible interaction system**.

**Preserve — everything that knows what a circuit is.**
Preserve `oep_engine` and `oep_foundation` untouched; `EngineHost` and `DiagramDocument`; `StudioCommandActions` and the complete toolbar→command binding table; `DiagramSimulationService`, `MultimeterController`, `OipHostBridgeService`, `DiagramIntelligenceService`, `DiagramRepositoryService`; the AI, publishing, migration, bookmark/history and settings modules; the eight shared Property Inspector modes; the tab model and controller; every storage class and — critically — the separation between engineering data, diagram layout, UI state and temporary workspace state. Preserve too the non-obvious interaction *semantics* catalogued in §9.3 and the hazards in §9.4: one gesture = one command, preview-never-mutates, guide-snap-then-grid-snap, symbol-first port geometry, probe-placement precedence, and "never fabricate a state."

**The boundary — `DiagramScene` in, Engine Commands out.**
It sits at the new **Studio Controller / Adapter**. Above it, presentation consumes immutable value types (`DiagramScene`, `ViewState`, `GraphSelection`, `MeasurementResult`, `SimulationStateSnapshot`, `ValidationReport`) and emits nothing but *intent*. Below it, the controller is the single object permitted to execute an Engine command, and the Engine remains the sole author of graph, layout, routing, selection, viewport, validation, simulation and measurement truth. No Flutter type crosses downward; no mutation crosses upward except as a command. Two pre-existing violations are recorded and consciously left in place for now: the Engine package owns Flutter presentation widgets (§12.3a), and `host/`+`settings/` are platform components filed under a studio directory (§12.3b). Neither may be "fixed" during this reconstruction.

**V2 is the reference for appearance and behaviour. OEP is the source of truth for engineering data. The controller is the only place the two are allowed to meet.**






