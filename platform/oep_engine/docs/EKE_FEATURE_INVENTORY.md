# EKE Feature Inventory (ENGINE-TASK-000067)

Every significant feature found in `engine_reference_only/`, grouped and
classified. Classifications:

- **Already Implemented** — the Engineering Engine (Phase 1) already
  covers the underlying capability, even if the reference's specific UI
  polish differs.
- **Needs Migration** — real reference behavior worth preserving,
  not yet present in the Engineering Engine.
- **Future Enhancement** — a reasonable capability with no working
  reference implementation to draw behavior from (either never built, or
  built as unused/dead scaffolding) — would be designed fresh.
- **Not Applicable** — reference-specific (implementation detail,
  duplicated persistence layer Foundation already owns, or dead code with
  nothing to preserve).

---

## Editing

| Feature | Reference behavior | Classification |
|---|---|---|
| Add component/module | Modal-driven creation, preset library | Needs Migration |
| Edit component properties | Property modal | Needs Migration |
| Delete component | Cascades to remove attached wires | Needs Migration |
| Create wire (click-click) | Click source terminal → click target terminal, live dashed preview | Needs Migration |
| Edit wire properties | Color/label/per-key-state readings modal | Needs Migration |
| Delete wire | Confirm dialog, context menu or `Delete` key | Needs Migration |
| Move/drag component | Layout-edit-mode only, 10px grid snap, layout-only (never touches the graph) | Needs Migration |
| Route editing (nudge wire segments) | Arrow-key nudge, `R` to reset | Future Enhancement (low priority polish) |
| Copy / paste / duplicate | **Not implemented** — `clipboard.js` is a doc-comment placeholder only | Future Enhancement |
| Align / distribute | Not implemented, not even referenced as a stub | Future Enhancement |
| Undo / redo | Command-stack class defined, **never instantiated or wired up** | Future Enhancement |

## Navigation

| Feature | Reference behavior | Classification |
|---|---|---|
| Pan | Drag-background / Space+drag / middle-click / touch | Already Implemented (basic version via `InteractiveViewer` in the Demonstration Host) |
| Zoom | Ctrl/Cmd+scroll (zoom-to-cursor), toolbar buttons, pinch | Already Implemented (basic); zoom-to-cursor precision is Needs Migration |
| Fit View | Computes scale to fit content bounds | Needs Migration |
| Minimap | Canvas-rendered overview + viewport box | Future Enhancement |
| Search | `/` or `?` opens search overlay | Needs Migration |
| Legend toggle (simulator UI panel) | Shows wire-color legend | Needs Migration |
| Validation/graph inspector navigation | `Ctrl+Shift+G` opens a findings panel | Already Implemented (Engineering Engine's Validation Panel, Phase 1) |
| Keyboard shortcuts (general) | ~15 shortcuts covering mode switches, key position, escape-cascade | Needs Migration |

## Selection

| Feature | Reference behavior | Classification |
|---|---|---|
| Select a wire/relationship | Single-select, toggles | Already Implemented |
| Select a component/node | Single-select, opens info panel | Already Implemented |
| Selection → property panel sync | Direct, immediate | Already Implemented |
| Multi-selection | **Does not exist** in the reference (only ever one wire or one module selected) | Future Enhancement |
| Hover affordance | Terminal-dot hover class in wire/lead-placement modes only | Needs Migration |

## Rendering

| Feature | Reference behavior | Classification |
|---|---|---|
| Component/wire visual rendering | DOM cards + SVG wire layer (implementation detail) | Not Applicable — Engineering Engine uses `DiagramScene` + Flutter painter/SVG by design (ADR-003) |
| Orthogonal wire auto-routing | Computed route avoiding naive straight lines, allocation-aware | Needs Migration — see `EKE_ALGORITHMS.md` |
| Selection/highlight glow rendering | Amber glow (selected), green glow (traced), dimming of everything else | Already Implemented (concept — `runtime.selected`/`runtime.highlighted` render); reference's dimming-of-non-relevant-elements nuance is Needs Migration |
| Grid (drag snap) | 10px snap during drag | Needs Migration |
| Current-flow animation | `requestAnimationFrame` dash-offset loop | Future Enhancement (Simulation-adjacent, deferred) |
| Minimap rendering | Canvas overview | Future Enhancement |

## Validation

| Feature | Reference behavior | Classification |
|---|---|---|
| Structural graph checks (isolated nodes, broken relationships, missing systems) | `DiagnosticEngine.analyze()` | Already Implemented (Engineering Engine's `ValidationService` covers an equivalent or broader set: floating nodes, broken relationships, unknown/missing symbols, duplicate ports, evidence mapping) |
| Drafting-convention validation (orthogonality, junction dots, label proximity, etc.) | `DrawingValidator` implements several `wiring-diagram-design-rules.md` rules, but is **always fed empty data** in the running pipeline — effectively inert | Needs Migration (revive properly, don't copy the inert wiring) |
| Domain-completeness rules ("has coil but no CDI") | `RuleEngine`, 4 built-in rules | Needs Migration |
| Confidence-based flagging | Threshold-based review queue (see discrepancy in `EKE_ARCHITECTURE_ANALYSIS.md`) | Needs Migration — pending a confidence field (`EKE_GRAPH_COMPARISON.md`) |

## Import

| Feature | Reference behavior | Classification |
|---|---|---|
| Pre-extracted label import (JSON) | `eke.js labels` | Already Implemented (`JsonImportProvider`, though schema differs — see graph comparison) |
| Multi-pass OCR extraction | 3 zoom × 6 preprocessing variants × tiling × 2 rotations, cross-pass voting | Needs Migration (large effort — real, sophisticated engineering) |
| Wire tracing from image | Skeleton-based tracer with junction/dot detection | Needs Migration |
| Masking (borders/title blocks) | Morphology-based | Needs Migration |
| Symbol shape detection (CV) | Hu-moment matching, fully coded but **never called by the running pipeline** — dead code | Not Applicable (nothing proven to migrate; a fresh design would be a Future Enhancement) |
| Perceptual-hash symbol template matching | What actually runs for unmatched regions | Needs Migration |
| Label classification + correction learning loop | Alias table + human-correction overrides, real and demonstrably applied to future extractions (labels only) | Needs Migration |
| PDF import | `pdf2image`/Poppler wrapper with page-diagram-likelihood scoring | Needs Migration |
| Legend region parsing | Fully coded (`legendparser.js`) but **never invoked** — no legend-region detection step exists anywhere | Not Applicable (aspirational only) |

## Export

| Feature | Reference behavior | Classification |
|---|---|---|
| JSON knowledge graph export | `KnowledgeGraphSerializer` — versioned schema with confidence/systems/topologies | Needs Migration (fuller schema pending Net/confidence/system-recognition concepts) |
| SQLite persistence/query layer | Hybrid blob + normalized tables, explicitly documented as "interim before Neo4j" | Not Applicable — Foundation owns persistence in this architecture (SDD-025); duplicating a bespoke store here would violate that boundary |
| PDF/SVG/PNG export | Not implemented in the reference (aspirational per `docs/roadmap.md`/README's phase table) | Needs Migration (already an SDD-026 future exporter) |

## Simulation

| Feature | Reference behavior | Classification |
|---|---|---|
| Behavior/state engine (key off/on/cranking/running) | Finite state machine, hardcoded per-component-type behavior lookup, **no real signal propagation through wires** | Needs Migration — explicitly deferred ("no simulation yet") |
| Fault injection | `FaultInjector` fully coded, **no UI ever calls it** | Needs Migration — deferred; design fresh rather than porting unused code |
| Electrical solver | `ElectricalSolver.solve()` exists, **never invoked** | Needs Migration — deferred |
| Meter/multimeter reading | Static per-key-state lookup table, not a live solve | Needs Migration — deferred |
| Symptom-to-fault reasoning | `FaultReasoner` — real, working fuzzy symptom matcher against a static fault library | Needs Migration — deferred to Diagnostic/Simulation Engine |

## Knowledge

| Feature | Reference behavior | Classification |
|---|---|---|
| Component type catalog | 15 types (`knowledge/components/`), consistent `type/aliases/category/inputs/outputs` shape | Needs Migration — the *electrical-semantics* half (inputs/outputs/category as engineering knowledge) is distinct from Symbol Library appearance data (SDD-028) and has no Engineering Engine equivalent yet |
| System library (symptoms, diagnostic steps, specs) | `database/systems/` — rich, technician-facing; **duplicates and disagrees with** `reasoning/systems/systemtemplates.js` | Needs Migration (reconcile the duplication when migrating — don't carry it forward) |
| Vehicle database | Single seeded vehicle (Honda TRX300) | Needs Migration (low priority; sparse in the reference itself) |
| Manufacturer wire-color conventions | `database/manufacturers/honda.json` — genuinely conflicts with the generic color table in `wiring-diagram-design-rules.md` | Needs Migration (with an explicit override-precedence design — see graph comparison) |
| Wiring diagram design rules (40 heuristics) | `wiring-diagram-design-rules.md` — drafting conventions + electrical plausibility | Needs Migration — highest-value knowledge artifact found, entirely independent of code |
| Diagnostic assistant (NL Q&A, symptom diagnosis) | Real, working — combines `FaultReasoner` + `QueryEngine` | Needs Migration — deferred to Diagnostic/Simulation Engine |

## Usability

| Feature | Reference behavior | Classification |
|---|---|---|
| Keyboard-shortcut hint panel | Static overlay | Future Enhancement |
| Theme toggle (light/dark) | Simple CSS class toggle | Future Enhancement |
| Toast notifications | `ui/notifications.js` | Needs Migration (small, real UX pattern) |
| Context menus (wire/component) | Shared menu, contextually filtered | Needs Migration |
| Autosave | `storage/autosave.js` | Needs Migration (useful once real editing exists) |
| Floating/dockable panels | Drag/resize/dock manager in `app.js` | Not Applicable to the Engine layer — this is Studio workspace-framework territory (`oep_studio`'s own docking system), out of scope here |
