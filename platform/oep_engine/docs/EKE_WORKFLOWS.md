# EKE Workflow Analysis (ENGINE-TASK-000068)

Every user workflow found in `engine_reference_only/apps/simulator/` (the
only interactive UI in the reference — `apps/editor/` is a headless
graph-construction API with no UI of its own). Workflows the reference
never implemented are documented as such, since an honest gap is as
important as a present feature (per WORK_PACKAGE_020 scope).

---

### Create Diagram

**Purpose.** Start a new working circuit.

**Reference workflow.** The reference has no "New Diagram" workflow in
the simulator — it always boots from a fixed vehicle dataset
(`diagrams/trx300/`) loaded by `storage/vehicle-loader.js` at bootstrap.
The closest analog to "create" is the *extraction* pipeline producing a
new Knowledge Graph from a source image (a fundamentally different
workflow — see Import in `EKE_FEATURE_INVENTORY.md`), or `apps/editor`'s
headless `GraphEditor` API (`addComponent`/`connect`/`build()`), which has
no interactive UI at all.

**Interaction.** None (load-on-boot only) for the simulator; programmatic
only for the editor API.

**Future implementation notes.** The Engineering Engine's Demonstration
Host already does this correctly for Phase 1 — `GraphBuilder` constructs
a seed graph in code. A real "blank diagram" workflow doesn't exist to
migrate; it would be designed fresh when Diagram Studio is built
(`oep_studio`, out of scope here).

---

### Place Component

**Purpose.** Add a new component to the circuit.

**Reference workflow.** Toolbar "Add Module" → modal with preset library
(by component type) → component appears with a default/auto position →
user optionally repositions in Layout Edit mode.

**Interaction.** Modal-driven, not drag-from-palette. No canvas
drag-and-drop-to-place gesture exists.

**Future implementation notes.** Worth migrating the two-step shape
(choose type → confirm details) but reconsider drag-from-a-symbol-palette
as an alternative/additional interaction, since the Engineering Engine's
Symbol Library (SDD-028) makes a visual palette natural in a way the
reference's preset-modal-only approach doesn't fully exploit.

---

### Connect Components

**Purpose.** Create an electrical relationship between two components.

**Reference workflow.** Toggle Wire Mode (`W`) → click a source terminal
→ live dashed preview line follows the cursor → click a destination
terminal → new wire object created (duplicate connections rejected with a
toast) → Wire Properties modal auto-opens for color/label/readings.

**Interaction.** Click-click, not drag-to-connect. Real, working,
genuinely interactive.

**Future implementation notes.** This is a strong, migratable workflow
shape: mode toggle → click source port → live preview → click target port
→ auto-open inspector for details. The Engineering Engine's `Port` model
(SDD-027) and `SelectionService.selectPort` already provide the pieces;
what's missing is the live-preview-line interaction and duplicate-
connection rejection, both worth preserving.

---

### Edit Properties

**Purpose.** Change a component's or relationship's data.

**Reference workflow.** Click to select → property panel/modal opens →
edit fields → changes commit immediately (no explicit "save" step, no
undo).

**Interaction.** Direct-manipulation, immediate-commit.

**Future implementation notes.** Immediate-commit-with-no-undo is
explicitly flagged as a weakness in `EKE_ARCHITECTURE_ANALYSIS.md` — worth
improving on, not copying, once real editing is built (out of scope for
this work package).

---

### Delete

**Purpose.** Remove a component or wire.

**Reference workflow.** Select → `Delete` key or context-menu "Delete" →
confirmation dialog → removal. Deleting a component cascades to delete
every wire attached to it.

**Interaction.** Confirm-then-commit, cascading.

**Future implementation notes.** The Engineering Engine's
`EngineeringGraph.withoutNode` already cascades relationship removal
(built in Phase 1, independently arrived at the same behavior) —
confirms this is the correct default, not something to redesign.

---

### Copy / Paste / Duplicate

**Purpose.** Reuse an existing component/subcircuit.

**Reference workflow.** **None exists.** `clipboard.js` is a pure
doc-comment placeholder (Phase 3 goal); no copy/cut/paste/duplicate
command exists anywhere in the codebase.

**Interaction.** N/A.

**Future implementation notes.** A Future Enhancement with no reference
behavior to draw from — would need to be designed from scratch when
editing is eventually implemented (explicitly out of scope for both
WORK_PACKAGE_019 and 020).

---

### Move

**Purpose.** Reposition a component in the diagram.

**Reference workflow.** Layout Edit mode only → drag a component card →
position snaps to a 10px grid → attached wires re-route automatically.
Moving a component **only** updates layout/position data — the graph
(model layer) is untouched, a clean confirmation of the reference's own
"layout is not electrical information" rule (`graph-schema-v2.md`, Final
Rule) matching SDD-024 exactly.

**Interaction.** Mode-gated drag, grid-snapped.

**Future implementation notes.** Directly migratable concept: move
belongs entirely to a View's layout data, never to the Engineering Graph.
The Engineering Engine's `DiagramLayout` (Phase 1, currently a fixed grid
auto-layout) would need to become mutable/persistable per-view layout
data to support this — a natural Phase-3-or-later View enhancement.

---

### Align

**Purpose.** Line up multiple components.

**Reference workflow.** **None exists.** No alignment/distribution
tooling of any kind was found, and it isn't referenced as an aspirational
stub either (unlike copy/paste, which at least has a placeholder file).

**Interaction.** N/A.

**Future implementation notes.** Future Enhancement, designed fresh —
requires multi-selection (also not in the reference) as a prerequisite.

---

### Navigate

**Purpose.** Move around a large diagram; jump to a specific element.

**Reference workflow.** Pan (drag-background / Space+drag / middle-click
/ touch), zoom (Ctrl+scroll zoom-to-cursor / buttons / pinch), Fit View
(`F`), minimap click-to-jump.

**Interaction.** Continuous/direct-manipulation for pan/zoom; single
action for Fit View; click-to-jump for the minimap.

**Future implementation notes.** Pan/zoom already exist at a basic level
in the Demonstration Host (`InteractiveViewer`); zoom-to-cursor precision,
Fit-View-to-content-bounds, and the minimap are the concrete gaps worth
migrating, roughly in that priority order (see `EKE_MIGRATION_MATRIX.md`).

---

### Search

**Purpose.** Find a specific component/wire by name or property.

**Reference workflow.** `/` or `?` opens a search overlay; presumably
filters/jumps to matching elements (exact ranking/matching algorithm not
deeply traced in this pass — flagged for a closer look if Search is
prioritized for migration).

**Interaction.** Keyboard-triggered overlay.

**Future implementation notes.** SDD-026 already names `SearchService` as
a planned public service; the reference confirms this is a real,
expected workflow shape (keyboard-triggered, overlay-based) worth
matching.

---

### Validate

**Purpose.** Check the diagram/graph for problems.

**Reference workflow.** Two separate paths exist and don't share
results: (1) `Ctrl+Shift+G` opens a Graph Inspector panel showing
`DiagnosticEngine` + `RuleEngine` structural findings; (2) the extraction
pipeline's `DrawingValidator` runs drafting-convention checks but is
always fed empty data in practice (inert).

**Interaction.** Manual trigger (keyboard shortcut) for the graph
inspector; automatic-but-ineffective for the drawing validator.

**Future implementation notes.** The Engineering Engine's Validation
Panel (Phase 1 Demonstration Host) already replicates the useful half of
this workflow (manual trigger, findings list) and, per
`EKE_FEATURE_INVENTORY.md`, already covers an equal-or-broader set of
structural checks than the reference's `DiagnosticEngine`. The domain-
completeness rules (`RuleEngine`) and drafting-convention checks
(`DrawingValidator`, once properly fed real data) are the migratable
gaps.

---

### Export

**Purpose.** Produce an external artifact from the graph.

**Reference workflow.** Programmatic only (no UI export button found in
the simulator pass) — `KnowledgeGraphSerializer.toJSON()` /
`toMinifiedJSON()`, or persistence via `KnowledgeGraphStore` (SQLite).

**Interaction.** None in the simulator UI; CLI/API-driven.

**Future implementation notes.** The Engineering Engine already has
`JsonExportProvider` (Phase 1). A UI-triggered export action doesn't
exist in the reference to migrate — it would be new work when Diagram
Studio is eventually built.
