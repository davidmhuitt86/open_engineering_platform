# Diagram Studio — Architecture Specification

**Architecture Phase:** AP-DS-001

## 1. Package layout

```
oep_studio/lib/diagram_studio/          (Studio shell — 27 files, ~3,209 lines)
├── ai/                 diagram_ai_service.dart, diagram_prompt_context.dart
├── commands/            studio_command_actions.dart (toolbar→command glue)
├── host/                diagram_document.dart, engine_host.dart
├── inspector/           8 property-panel widgets (one per entity type)
├── panels/              annotation/explorer/layer/recent-commands/search/validation panels
├── persistence/         diagram_workspace_state.dart, workspace_state_storage.dart
├── settings/            settings model, page, provider, storage
├── toolbars/            diagram_toolbars.dart (376 lines)
└── workspaces/          diagram_studio_page.dart (1,441 lines — the canvas host page)

oep_engine  (platform/oep_engine, package `engineering_engine`, 165 files)
├── bridge/, core/bridge/       FoundationBridgePort — deliberately unimplemented (see ENGINEERING_MODEL.md)
├── clipboard/, core/clipboard/  ClipboardEntry, ClipboardExtraction
├── core/diagrams/, diagrams/     diagram-level types
├── core/editing/, editing/       EditingCommand, CommandHistory, EditingSession, 33 concrete commands
├── core/graph/, graph/           EngineeringGraph, EngineeringNode/Relationship/Group, algorithms, InMemoryGraphProvider
├── core/selection/               GraphSelection, SelectionService
├── core/simulation/, simulation/ NoOpSimulationProvider (explicit Phase-1 placeholder) + electrical/hydraulic/mechanical/pneumatic dirs
├── core/symbols/, symbols/       symbol library, renderers, standards, validation
├── core/validation/              graph validation
├── core/viewstate/, viewstate/   ViewState, GridComputer, AlignmentGuideComputer
├── core/views/, views/           GraphViewPanel (the canvas), dialogs, widgets, DiagramLayer/DiagramAnnotation
├── core/exporters/, exporters/   json/ (real), pdf/ + svg/ (empty — .gitkeep only)
├── core/importers/, importers/   images/, pdf/, svg/, shared/
└── extensions/                   automotive/aviation/hydraulic/industrial/marine/pneumatic/rail/robotics domain stubs
```

**Note on the duplicate top-level/`core/`-nested directory structure inside `oep_engine`** (`bridge/` and `core/bridge/`, `clipboard/` and `core/clipboard/`, `exporters/` and `core/exporters/`, etc.): both sets exist side by side. This was observed but not root-caused in this review (a plausible explanation is a public re-export barrel pattern, `core/` holding implementation and the top-level holding a public-facing re-export, consistent with the presence of `lib/public/`) — flagged in `ARCHITECTURAL DEBT` below as an item for AP-DS-002 to formally document or collapse, not something this phase redesigns.

## 2. Layering

```
Foundation Repository (oep_foundation, via FoundationBridge FFI)
        ⋮  (NOT YET CONNECTED — see ENGINEERING_MODEL.md §Foundation Bridge)
oep_engine — EngineeringGraph (in-memory document model)
        ↑
oep_engine — EditingCommand / CommandHistory (mutation surface)
        ↑
oep_engine — GraphViewPanel (canvas/rendering) + ViewState (viewport/grid/guides)
        ↑
oep_studio/diagram_studio — DiagramStudioPage (gesture handling, tool-mode state, drag orchestration)
        ↑
oep_studio/diagram_studio — panels/toolbars/inspectors (chrome)
        ↑
oep_studio/core/routing — StudioRegistry (navigation entry point)
```

Every arrow above was independently verified: `DiagramStudioPage` imports and calls `engineering_engine` APIs directly for every mutating and selection operation; it never reimplements graph/command logic. The Foundation Repository connection is drawn as explicitly disconnected — the only Foundation-facing code in `diagram_studio/` is a read-only "is a repository open" display badge, not a data path.

## 3. Component responsibilities

| Component | Package | Responsibility | Status |
|---|---|---|---|
| `DiagramDocument` | oep_studio | Open/save orchestration: composes `EngineeringGraph.toJson()` + `DiagramLayoutState.toJson()` into one local JSON file | Implemented |
| `DiagramStudioPage` | oep_studio | Canvas host: gesture handling, drag/box-select/connect/reconnect/wire-edit state, command dispatch, keyboard shortcuts | Implemented (see Editing/Interaction docs for the ad hoc tool-mode caveat) |
| Panels (annotation/explorer/layer/search/validation/recent-commands) | oep_studio | Side-panel chrome reading from Engine state | Implemented |
| Inspectors (8 files) | oep_studio | Per-entity-type property forms | Implemented |
| Toolbars | oep_studio | Command trigger buttons | Implemented |
| Settings | oep_studio | Studio-local preferences | Implemented |
| `EngineeringGraph` | oep_engine | The document model: nodes, relationships, groups, ports | Implemented |
| `GraphViewPanel` | oep_engine | Canvas rendering (hybrid CustomPaint + widget tree) | Implemented, not performance-optimized |
| `ViewState` / `GridComputer` / `AlignmentGuideComputer` | oep_engine | Viewport transform mirror, grid snap, alignment guides | Implemented |
| `EditingCommand` / `CommandHistory` | oep_engine | Command pattern + undo/redo (depth 100) | Implemented |
| `GraphSelection` / `SelectionService` | oep_engine | Multi-kind selection state | Implemented |
| `ClipboardEntry` / `ClipboardExtraction` | oep_engine | In-process copy/paste | Implemented (not OS clipboard) |
| `FoundationBridgePort` | oep_engine | Interface for future Foundation persistence | **Still not implemented — AP-DS-002 delivered real Foundation persistence via a different mechanism (`DiagramRepositoryService`, Studio-side, backed by `FoundationBridge`'s FFI layer directly), not this interface. Zero consumers remain. See `ENGINEERING_MODEL.md`'s AP-DS-002 update.** |
| `DiagramRepositoryService` | oep_studio | Real Foundation Engineering Repository persistence (AP-DS-002) — save/load/migrate | Implemented |
| JSON exporter | oep_engine | Diagram → JSON export | Implemented |
| PDF/SVG exporters | oep_engine | Diagram → PDF/SVG export | **Not implemented — empty directories (`.gitkeep` only)** |
| Printing | — | — | **Does not exist anywhere in either package** |
| Simulation providers | oep_engine | Electrical/hydraulic/mechanical/pneumatic simulation | **`NoOpSimulationProvider` placeholder only, self-documented as Phase 1 scope** |
| Engineering Intelligence integration | — | Validation/Analysis/Reasoning/Recommendations from `EngineeringIntelligencePlatform` | **Does not exist — zero cross-references found beyond one incidental doc-comment mention** |

## 4. Architectural debt identified in this review (report only — not fixed in this phase)

1. Duplicate top-level/`core/`-nested directory structure in `oep_engine` (`bridge/` vs `core/bridge/`, etc.) — undocumented reason, needs a clarifying note or consolidation in AP-DS-002.
2. Two move-related commands exist (`MoveNodesCommand` plural and `MoveNodeCommand` singular) — possible legacy duplication, needs a one-line audit to confirm whether both are actively used or one is dead code.
3. `AlignNodesCommand`/`DistributeNodesCommand` exist as real command classes but no confirmed toolbar/menu trigger was found wiring them into the UI in the files reviewed — possible orphaned commands, needs a dedicated grep pass in AP-DS-002.
4. Search results of kind `symbol` and `layer` are found by the search panel but their selection handler is an explicit no-op (`case SearchResultKind.symbol: case SearchResultKind.layer: break;`) — a genuine, small, fixable incompleteness.
5. Two-way state sync risk between Flutter's `InteractiveViewer` `TransformationController` matrix and the Engine's own `ViewState.zoom`/`pan`, reconciled only at gesture end — a documented but unresolved source-of-truth duplication (see `CANVAS_ARCHITECTURE.md`).
