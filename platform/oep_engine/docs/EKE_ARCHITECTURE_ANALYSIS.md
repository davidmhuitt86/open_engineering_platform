# EKE Architecture Analysis (ENGINE-TASK-000066)

A complete architectural description of `engine_reference_only/` — the mature
Electrical Knowledge Engine (EKE) reference implementation — treated as a
mature engineering application, not critiqued for code style. This document
does not evaluate JavaScript/Python/HTML/DOM implementation quality; it
extracts engineering concepts, workflows, data flow, and architectural
lessons for the Engineering Engine (`oep_engine`).

Sources: the reference's own `docs/` (architecture.md, vision.md,
object-model.md, graph-schema-v2.md, workspace.md, system-library.md,
roadmap.md, wiring-diagram-design-rules.md), direct code exploration of
`core/`, `apps/simulator/`, `apps/extractor/`, `reasoning/`, `extraction/`,
`diagram-extractor/`, `database/`, `knowledge/`, `output/`, `training-data/`,
`tests/`.

---

## Major subsystems

The reference's own architecture doc names five subsystems, confirmed by
exploration:

1. **Extraction Engine** — `diagram-extractor/` (Python: OCR, vision,
   pipeline orchestration) + `extraction/` (JS: OCR postprocessing, symbol
   catalog, tables, tiling) + `apps/extractor/` (client + CLI glue).
2. **Canonical Electrical Graph** — `core/graph/` (Graph, QueryEngine,
   GraphEditor) — the center of the architecture; everything else produces
   or consumes it.
3. **Reasoning Engine** — `reasoning/` (topology, systems, rules,
   diagnostics, faults, evidence, explanations, reports, assistant).
4. **Simulator and Training Platform** — `apps/simulator/` — a full
   browser application (DOM+SVG diagram, editing, meter, diagnostics UI)
   with its own parallel `core/behavior/` state engine.
5. **Knowledge Database** — `database/` (vehicles, systems, connectors,
   manufacturers), `knowledge/components/`, `output/` (serializer + SQLite
   store), `training-data/`.

Additionally, `android/` is a thin Kivy/Python mobile wrapper (a secondary
client, not a sixth subsystem) — out of scope for further analysis.

## Responsibilities and boundaries

The reference states its own architectural rules plainly (`architecture.md`):
"Everything feeds the graph," "Everything consumes the graph," "The graph
owns the truth — subsystems must never duplicate electrical information."
In practice, this rule is **honored for the core graph object model but
violated once at the reasoning/knowledge boundary** — see "Weaknesses"
below (the `database/systems` vs. `reasoning/systems/systemtemplates.js`
duplication is a direct instance of the exact thing the architecture doc
warns against).

`workspace.md` documents a second architectural layer not visible from the
graph docs alone: a **Workspace** that exists only during extraction,
holding multiple disagreeing detector outputs (OCR passes, color
detectors) until confidence can be established, with the rule "no detector
may directly modify the Canonical Graph — the Workspace is the arbitration
layer." This is a clean idea; whether it's actually implemented as a
distinct object in code, versus being the informal shape of
`diagram-extractor`'s pipeline + corrections DB, was not confirmed to the
same rigor as the Graph itself — treat the Workspace as a **documented
intent** more than a verified concrete module.

## Data flow

```
Source Material (image/PDF)
  -> Python: preprocess, multi-pass OCR, wire-trace, template-match symbols
  -> JS: classify labels (alias table + corrections overrides), build graph
  -> Reasoning: topology/system recognition, evidence, diagnostics, rules
  -> Output: KnowledgeGraphSerializer (JSON) + KnowledgeGraphStore (SQLite)
  -> Consumers: Simulator (interactive), DiagnosticAssistant (Q&A), CLI
```

Two independent processes (Python REST API + JS client/CLI) communicate
over HTTP, with a genuine, working local-JS fallback classifier if the
Python API is unreachable — a real degraded-mode path, not a stub.

## Interaction flow (Simulator)

Global mutable state (`scale`/`tx`/`ty`/`editMode`/`wireMode`/`selW`/`selM`)
drives everything; there is no central state store/reducer — direct
mutation followed by an explicit re-render call (`drawWires()`,
`applyT()`). Mode is exclusive and toggled (Layout Edit / Wire / Route
Edit / normal), each unlocking a different interaction set. See
`EKE_INTERACTION_MODEL.md` for full detail.

## Rendering flow

Hybrid **DOM (module cards) + SVG (wires)**, not canvas — the one
`<canvas>` element is the minimap only. Rendering is entirely
imperative/on-demand: state changes are followed by an explicit
`drawWires()`/`placeCards()` call, not a frame loop (the one exception —
current-flow dash animation — does use `requestAnimationFrame`). See
`EKE_RENDERING_PIPELINE.md` for full detail.

## Event flow

Mostly **not** event-bus-driven despite a `utils/events.js` EventBus
existing — it's largely unused; the real architecture is direct function
calls against shared global state. This is a deliberate simplicity choice
for a single-page app, but it is the opposite of the Engineering Engine's
`EngineEventBus`-mediated internal communication (SDD-026) and the
provider/registry extension model (ADR-001) — see "Improved concepts" in
`EKE_GRAPH_COMPARISON.md`.

---

## Strengths

1. **The graph-is-truth philosophy is genuinely well-executed at the core
   object-model level.** `object-model.md`/`graph-schema-v2.md` are clear,
   principled, and match what the code actually does for
   Component/Terminal/Wire/Net/System. This independently validates
   SDD-024's identical philosophy (see `EKE_GRAPH_COMPARISON.md`).
2. **The multi-pass OCR engine is genuinely sophisticated** — 3 zoom
   levels × up to 6 preprocessing variants × tiling × 2 rotations, with
   confidence-boosting cross-pass voting. This is real, working
   engineering, not aspirational documentation.
3. **The wire-tracing and masking vision code is real and non-trivial**
   (skeleton-based tracer, morphology-based border/title-block masking).
4. **`wiring-diagram-design-rules.md` is an exceptional, highly reusable
   body of domain knowledge** — 40 heuristics spanning drafting conventions
   and electrical plausibility, written as probabilistic guidance rather
   than absolute rules. This is the single most valuable artifact in the
   reference repository for the Engineering Engine's future
   import/validation work, independent of any code.
5. **The label-correction learning loop is real** — a human correction to
   a misclassified label is stored and demonstrably applied to future
   extractions (confirmed via the reference's own test).
6. **The path-highlighter / selection-manager / renderer three-way split**
   (traversal-only vs. click-state-only vs. paint-only) is a genuinely
   clean separation of concerns, worth preserving as a concept (already
   reflected in the Engineering Engine's `NavigationService` vs.
   `SelectionService` split — ADR pending confirmation, see
   `EKE_INTERACTION_MODEL.md`).
7. **Multi-vehicle, multi-manufacturer extensibility is a first-class
   design goal**, even though only one vehicle (Honda TRX300) is currently
   seeded — the schema and folder structure anticipate it cleanly.

## Weaknesses

1. **Several parallel, only loosely-connected reasoning subsystems
   instead of one pipeline.** `DiagnosticAssistant.diagnose()` (symptom →
   fault) never touches `core/behavior` (key-state), `reasoning/diagnostics`
   (structural checks), `reasoning/rules` (completeness rules),
   `reasoning/evidence`, `reasoning/explanations`, or `reasoning/reports`.
   Meanwhile `apps/simulator`'s own `diagnose()` combines a *different*
   subset (`StateEngine` + `DiagnosticEngine` + `RuleEngine` +
   `FailureEngine`). Two "fault" concepts exist and don't talk to each
   other: `FaultReasoner`'s static symptom library vs. `FailureEngine`'s
   graph-mutating fault injection.
2. **Significant dead/orphaned code**, discovered only by tracing actual
   call sites, not by reading file lists: the entire Python CV symbol
   shape-detection pipeline (Hu-moment matching against 19 reference
   symbols) is fully built but never invoked; `undo-redo.js`'s command
   stack is defined but never instantiated; `clipboard.js` is a pure
   placeholder; three of four `diagram/` rendering-split files
   (`module-renderer.js`, `wire-renderer.js`, `label-renderer.js`,
   `viewport.js`) are documentation stubs with no executable code, their
   responsibilities still living in the `renderer.js` monolith;
   `SimulatorStateManager` is defined but unused (bare globals used
   instead); `ElectricalSolver`/`FaultInjector` exist as real code with no
   UI ever calling them.
3. **Documentation/behavior drift.** The README claims extractions queue
   for review "below 75%," but the actual code hardcodes an 80% threshold
   and never reads the `confidence_threshold` parameter threaded through
   the API for that purpose. The README's CLI table implies a `correct`
   command exists; it does not appear in `eke.js`'s actual command
   dispatch.
4. **Real duplication the architecture explicitly warns against.**
   `database/systems/*.json` (rich, technician-facing knowledge) and
   `reasoning/systems/systemtemplates.js` (terse runtime matcher) overlap
   in required/optional component lists for the same systems, and
   **disagree** (e.g. `starting`'s required components differ between the
   two) — plus `database/systems` only covers 3 of the 6 systems the
   runtime templates recognize. This is exactly the "subsystems must never
   duplicate electrical information" rule being broken in practice.
5. **A genuine data conflict between generic and manufacturer-specific
   knowledge.** `wiring-diagram-design-rules.md` Rule 36 lists Black as the
   generic ground-wire color; `database/manufacturers/honda.json` states
   Honda's ground is Green. Nothing in the reference resolves this
   precedence — a from-scratch reimplementation needs an explicit
   override layer (manufacturer convention wins over generic heuristic),
   not an assumption of one universal table.
6. **UI editing is intentionally minimal and admits real gaps**: no
   multi-selection (only ever one wire or one module selected at a time),
   no copy/paste/duplicate, no alignment tools, no working undo/redo
   despite the class existing. These are honestly-documented Phase-2/3
   goals in the reference's own architecture doc, not silent omissions.
7. **Test coverage has real blind spots.** ~24 real test scripts (no
   formal test framework — manual assert/console patterns) cover core
   graph, extraction pipeline, and reasoning/systems well, but **zero**
   coverage exists for `output/` (the JSON serializer and SQLite store)
   or `database/` (no schema validation, no cross-check that
   `database/systems` and `systemtemplates.js` agree — which is precisely
   how the conflict in point 4 went unnoticed). Multi-manufacturer test
   coverage is zero (`training-data/{kawasaki,suzuki,yamaha}/` are empty).
8. **The "Workspace" arbitration layer described in `workspace.md`** is a
   strong idea but wasn't confirmed as a distinct, verifiable module to
   the same standard as the Graph itself — treat it as design intent to
   evaluate, not a proven pattern to copy as-is.

## Future opportunities (recommendations only — not implemented here)

See `EKE_MIGRATION_MATRIX.md` §Future Architecture Recommendations for the
full, dedicated treatment (ENGINE-TASK-000074). In summary: a unified
diagnostic pipeline (resolving the parallel-subsystems weakness above), an
explicit confidence field on graph objects (see `EKE_GRAPH_COMPARISON.md`),
a manufacturer-override-aware validation layer building on
`wiring-diagram-design-rules.md`, and treating the "Workspace" concept as
something to design deliberately for the Engineering Engine's own future
Import Engine rather than adopting the reference's version wholesale.
