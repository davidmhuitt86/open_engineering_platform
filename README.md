# Engineering Engine

The Engineering Engine runtime for the Open Engineering Platform (OEP):
the Engineering Graph, Symbol Library, Views, validation, navigation,
selection, import/export, and a simulation framework placeholder.

Status: **Phase 1 (WORK_PACKAGE_019) implemented.** **WORK_PACKAGE_020**
(EKE architectural analysis) **complete** — documentation only, no engine
code changes (see `docs/EKE_*.md` below). **WORK_PACKAGE_021** (Engineering
Graph Editing) **implemented** — the engine is a fully interactive,
undoable editor: create/delete/move/duplicate nodes and relationships,
multi/box selection, grouping, clipboard, deterministic undo/redo, and a
replaceable orthogonal routing engine. **WORK_PACKAGE_022** (Diagram
Editing Environment) **implemented** — a professional editing/drafting
experience around that stable Engineering Graph: `ViewState` (zoom/pan/
viewport/grid/guides/theme, a fifth permanently-separate runtime system,
never in undo/redo), named layout persistence, a computed grid/snap
system, ephemeral alignment guides plus real undoable Align/Distribute
commands, port hover and drag-to-connect/reconnect (reusing the existing
relationship commands), routing improvements (shared trunks, two-axis
corner cleanup, an explicit determinism contract), viewport navigation
math with back/forward history, and a drafting-tool Demonstration Host
(rulers, coordinate readout, resizable panels). **WORK_PACKAGE_023**
(Professional Engineering Editing) **implemented** — professional
drafting capability on top of that stable diagram editing environment:
advanced selection (lasso/crossing/window/connected-component/similar/
category/layer/invert), manual wire editing (insert/remove vertex, drag
segment/corner, restore automatic routing — all through one
`SetWireRouteCommand`), a full annotation system (text labels, leader
notes, callouts, wire/component labels, revision notes — Diagram Layout
data, undoable, selectable, copy/paste-able), drafting layers (create/
delete/rename/visibility/lock/print-visibility/assignment), placement
tools (rotate/mirror/array-place/replace-symbol), advisory editing
constraints (orthogonal movement/axis lock/angle constraint/snap
priority/minimum wire length/connection protection), Engineering Graph +
Diagram Layout search (implementing SDD-026's previously-unbuilt Search
Engine) with result navigation, and Demonstration Host productivity
tooling (recent commands).

Governed by SDD-024 through SDD-030 plus amendments SDD-024A/027A/028A
(`docs/specifications/`, `docs/amendments/`). Implementation reasoning
that isn't in the SDDs themselves is recorded in
`docs/ARCHITECTURE_DECISIONS.md`.

---

## Quick start

```dart
import 'package:engineering_engine/engineering_engine.dart';

final engine = EngineeringEngine.create();
await engine.initialize();

final graph = await engine.graph.create(id: 'demo');
engine.beginEditingSession(graph);

const node = EngineeringNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery');
engine.editing.execute(CreateNodeCommand(node, position: const Point2D(0, 0)));
engine.editing.undo(); // removes it again
engine.editing.redo(); // brings it back

final report = engine.validate(engine.editing.session.graph);

await engine.shutdown();
```

See `docs/ENGINEERING_ENGINE.md` for the full public API.

## Documentation

| Doc | Covers |
|---|---|
| `docs/ENGINEERING_ENGINE.md` | Runtime architecture, entry point, package layout |
| `docs/ENGINEERING_GRAPH.md` | Graph object model, building, querying, validation |
| `docs/SYMBOL_LIBRARY.md` | Symbol Definition schema, the 14 seed symbols, loading |
| `docs/DIAGRAM_STUDIO.md` | The View layer, Diagram View, and the Demonstration Host (**not** Diagram Studio) |
| `docs/GRAPH_EDITING.md` | Editing philosophy, what's editable, movement-as-layout, grouping, clipboard |
| `docs/UNDO_REDO.md` | The command model, `CommandHistory`, `EditingService`, what's outside undo/redo |
| `docs/ROUTING_ENGINE.md` | `RoutingProvider`, the default orthogonal router, port-snapping scoping (WORK_PACKAGE_021 base) |
| `docs/SELECTION_MODEL.md` | `GraphSelection` vs. `FocusState`, multi/box/toggle selection |
| `docs/VIEW_STATE.md` | `ViewState`/`ViewStateProvider`, the fifth runtime concern, viewport navigation, serialization |
| `docs/LAYOUT_SYSTEM.md` | Named layout persistence, `JsonFileLayoutSerializer`, why three parallel serializers |
| `docs/GRID_SYSTEM.md` | `GridSettings`/`GridComputer`, plus Alignment & Guides (smart guides vs. Align/Distribute commands) |
| `docs/ROUTING_ARCHITECTURE.md` | WORK_PACKAGE_022 routing additions: determinism contract, two-axis corner cleanup, Shared Trunks |
| `docs/PORT_INTERACTION.md` | `PortReference`, hover vs. selection, drag-to-connect/reconnect, `ConnectionValidator` |
| `docs/WIRE_EDITING.md` | Manual wire routes, `WireEditing` geometry (insert/remove/drag-segment/drag-corner/cleanup), `SetWireRouteCommand` |
| `docs/ANNOTATION_SYSTEM.md` | `DiagramAnnotation`, annotation commands, selection/clipboard integration |
| `docs/LAYER_SYSTEM.md` | `DiagramLayer`, layer commands, visibility filtering, advisory lock |
| `docs/EDITING_CONSTRAINTS.md` | `EditingConstraints`, `ConstraintMath`, Snap Priority, why constraints are advisory |
| `docs/SEARCH_AND_NAVIGATION.md` | `SearchProvider`/`SearchService`, result navigation on `NavigationService` |
| `docs/ARCHITECTURE_DECISIONS.md` | Why — the ADR log for implementation decisions |
| `docs/specifications/SDD-0{24..30}-*.md`, `docs/amendments/SDD-0{24,27,28}A-*.md` | The architecture itself |
| `docs/tasks/WORK_PACKAGE_019.md` … `WORK_PACKAGE_023.md` | The governing work packages |

### EKE reference-implementation analysis (WORK_PACKAGE_020)

| Doc | Covers |
|---|---|
| `docs/EKE_ARCHITECTURE_ANALYSIS.md` | Subsystems, data/interaction/rendering/event flow, strengths, weaknesses, opportunities |
| `docs/EKE_FEATURE_INVENTORY.md` | Every reference feature, classified (Already Implemented / Needs Migration / Future Enhancement / Not Applicable) |
| `docs/EKE_WORKFLOWS.md` | Every user workflow (create, place, connect, edit, delete, move, navigate, search, validate, export, ...) |
| `docs/EKE_INTERACTION_MODEL.md` | Selection, highlighting, dragging, connection, keyboard shortcuts, viewport, undo/redo (and the honest gaps) |
| `docs/EKE_RENDERING_PIPELINE.md` | Scene generation, wire/component rendering, layering, grid, viewport — with migration recommendations |
| `docs/EKE_GRAPH_COMPARISON.md` | Reference Canonical Electrical Graph vs. Engineering Graph (SDD-027) — equivalent/missing/improved/deprecated concepts |
| `docs/EKE_ALGORITHMS.md` | Reusable algorithms (routing, traversal, highlight propagation, recognition, confidence scoring) with migration recommendations |
| `docs/EKE_MIGRATION_MATRIX.md` | Full migration matrix (Immediate/Near Term/Long Term/Will Not Migrate) + future architecture recommendations |

## Reference implementation

`platform/engine_reference_only/` is the mature HTML/JS Electrical
Knowledge Engine — the official *behavioral* reference for workflows,
interaction model, and algorithm concepts. No HTML/CSS/JavaScript/DOM/SVG
implementation from it has been migrated; only architectural ideas are
preserved, reimplemented from scratch in Dart. See `docs/DIAGRAM_STUDIO.md`
and `docs/ENGINEERING_GRAPH.md` for what was and wasn't carried over.

## Verification

```
flutter analyze
flutter test

cd example
flutter analyze
flutter test integration_test/ -d windows
flutter build windows
```

## Repository boundaries

This package owns Engineering Engine runtime behavior only. It never owns
Repository persistence (`oep_foundation`) or Studio user interface
(`oep_studio`) — see SDD-025/026. `example/` is a verification harness for
this package, not a preview of Diagram Studio.
