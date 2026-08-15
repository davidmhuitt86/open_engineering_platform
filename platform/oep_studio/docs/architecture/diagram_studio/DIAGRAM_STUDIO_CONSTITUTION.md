# Diagram Studio Constitution

**Architecture Phase:** AP-DS-001
**Status:** Ratified (Phase 1 architecture freeze)
**Scope:** `oep_studio/lib/diagram_studio/` + `oep_engine` (`platform/oep_engine`, imported as package `engineering_engine`)

---

## 1. What Diagram Studio is

Diagram Studio is OEP's flagship engineering-diagram editor: a canvas-based tool for creating and editing wiring/schematic-style diagrams composed of engineering entities (components, connectors, wires, harnesses, groups, annotations) with real command-pattern editing, undo/redo, selection, grid/snap, and smart alignment guides.

**As verified by direct code inspection, Diagram Studio today is a fully local, disconnected drawing tool.** It does not yet write to or read from the Foundation Repository. This is not an oversight — it is a deliberate, explicitly documented Phase 1 scope boundary (see §4).

## 2. The two-package architecture (foundational fact for every other document in this set)

Diagram Studio is split across two packages, and this split is the single most important fact for anyone extending it:

- **`oep_studio/lib/diagram_studio/`** (27 files, ~3,209 lines) — the Studio-side shell: document open/save orchestration, panels, toolbars, inspectors, settings, workspace-state persistence. This code owns no canvas, no rendering, no document model, no command system.
- **`oep_engine`** (`platform/oep_engine`, package name `engineering_engine`, 165 files) — the real engine: canvas/viewport (`GraphViewPanel`), the document/graph model (`EngineeringGraph`), the command/undo-redo system (`EditingCommand`/`CommandHistory`), selection, clipboard, grid/snap/guides, symbol library, JSON export.

The governing principle, stated verbatim in the Studio-side page's own doc comment and ratified here as a constitutional rule: **"Studio orchestrates, Engine executes."** Every editing, selection, routing, search, and validation operation is a direct call into the Engine's public API (`package:engineering_engine/engineering_engine.dart`). `oep_studio`'s `diagram_studio/` code must never reimplement engine logic locally; it may only compose Engine calls into Studio-native UI chrome (panels, toolbars, dialogs, routing).

## 3. Constitutional principles

1. **Studio orchestrates, Engine executes.** (§2). No canvas, document, command, or selection logic may be added to `oep_studio/lib/diagram_studio/`; it belongs in `oep_engine`.
2. **Everything on the canvas has engineering meaning.** Every node/relationship type in `EngineeringGraph` (component, connector, wire, circuit, harness, module, relay, fuse, switch, ground, sensor, actuator, measurement point, procedure, specification) is a defined engineering concept, not a decorative shape. There are no graphics-only primitives in the node/relationship type system. (Annotations are the one deliberate exception — they are view-layer text/callout objects with no engineering type, by design, for labeling and notes.)
3. **The command pattern is the only path to mutation.** Every change to the diagram — move, rotate, mirror, group, delete, create, reconnect, property update — goes through an `EditingCommand` subclass executed via `CommandHistory`. There is no direct mutation of `EngineeringGraph` state outside a command. This is what makes undo/redo, dirty-tracking, and (eventually) collaborative editing possible.
4. **No Foundation Repository writes without an explicit bridge.** Foundation's actual repository schema has no concept of Diagram Layout, ViewState, Annotations, Layers, or wire overrides — only `EngineeringObject`/`Relationship` plus an append-only audit log. Building genuine Foundation-backed diagram persistence requires a Foundation-side schema extension that is explicitly out of scope for Diagram Studio to unilaterally introduce (`oep_foundation` may not be modified from within a Diagram Studio work package). Until that schema work happens and a real `FoundationBridgePort` implementation is built, diagrams remain local-only, and this must stay honestly reflected in every relevant document rather than implied otherwise.
5. **Do not redesign working architecture.** The command system, selection model, grid/snap/guide logic, and most direct-manipulation editing are genuinely complete and correctly wired — verified by direct inspection, not assumed. This freeze protects that work. Future phases refine and extend; they do not rebuild.
6. **No hidden state machines.** Interaction modes (select, connect, box-select, wire-edit, reconnect, annotate) currently exist as ad hoc boolean/nullable fields on one 1,441-line page `State` class rather than a formal `Tool` interface. This is accepted as the current reality, not retroactively declared "the architecture" — see `EDITING_ARCHITECTURE.md` for the explicit recommendation to formalize this in a future phase.
7. **Performance is not yet engineered, and this document does not pretend otherwise.** The current rendering path has no dirty-region redraw, no viewport culling, no `RepaintBoundary` usage, and triggers a full `setState()`-driven rebuild on every pointer-move frame during a drag. `PERFORMANCE_TARGETS.md` states target performance as aspirational goals for a future phase, not achieved current behavior.

## 4. Explicitly out of scope for this architecture phase (AP-DS-001)

- No major new editing features (per the work package's own instruction).
- No redesign of the command/selection/grid systems (they work; they are frozen as-is pending targeted refinement items named in the roadmap).
- No implementation of the Foundation Bridge, printing, PDF/SVG export, simulation, or Engineering Intelligence Platform integration — all four are real, named, currently-absent-or-stub systems documented honestly in their respective sections below and deferred to future Architecture Phases (see `IMPLEMENTATION_ROADMAP.md`).

## 5. Ratification

This Constitution, together with `ARCHITECTURE_SPECIFICATION.md`, `INTERACTION_MODEL.md`, `DOCUMENT_MODEL.md`, `ENGINEERING_MODEL.md`, `CANVAS_ARCHITECTURE.md`, `EDITING_ARCHITECTURE.md`, `PERFORMANCE_TARGETS.md`, and `IMPLEMENTATION_ROADMAP.md`, constitutes the frozen Phase 1 architecture of Diagram Studio. It was produced by direct inspection of the current implementation (both `oep_studio/lib/diagram_studio` and `oep_engine`), not by design intent alone — every claim of "implemented," "partial," or "absent" in this document set is traceable to a specific file.
