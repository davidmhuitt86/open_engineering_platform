# EKE Migration Matrix & Future Architecture Recommendations
(ENGINE-TASK-000073 / ENGINE-TASK-000074)

No migration is implemented in this work package. This is planning
output only, to be authorized feature-by-feature in future work packages.

---

## Immediate — small effort, high value, no blocking dependencies

| Reference Feature | Engineering Engine Destination | Priority | Difficulty | Dependencies | Notes |
|---|---|---|---|---|---|
| Orthogonal wire auto-routing + lane allocation | `lib/core/views/diagram/` (new `DiagramWireRouter`) | High | Low–Medium | None | Biggest concrete rendering gap; pure function, fits existing `DiagramView` contract |
| Dim non-selected/non-highlighted scene elements | `DiagramScene`/`DiagramNodeVisual`/`DiagramWireVisual` (new opacity concept) | High | Low | None | Directly portable, meaningfully improves legibility |
| Duplicate-relationship rejection | `ValidationService` (new rule) | Medium | Low | None | Cheap given existing `relationshipsForNode` |
| Relay coil/contact isolation check (design rule 30) | `ValidationService` (new rule) | Medium | Low | None | One of the 40 design-rule heuristics, cheap to encode as a deterministic check |
| Zoom-to-cursor, Fit-View | Demonstration Host (or future Diagram Studio) viewport | Medium | Low | None | Host-level, not engine core |
| Escape-cascade keyboard pattern | Demonstration Host / future Studio interaction layer | Low | Low | None | UX pattern, not an engine capability |

## Near Term — moderate effort, needs a short design pass first

| Reference Feature | Engineering Engine Destination | Priority | Difficulty | Dependencies | Notes |
|---|---|---|---|---|---|
| Click-click wire creation (live preview, duplicate rejection, auto-open inspector) | `SelectionService`/`Port` model + Host UI workflow | High | Medium | Port-level selection UI affordances | Real, working reference workflow — see `EKE_WORKFLOWS.md` |
| Directional power/ground path tracing | `GraphTraversal`/`NavigationService` extension | High | Medium | `NodeCategory` source/load/ground semantics need to be unambiguous first | See `EKE_ALGORITHMS.md` #2 |
| System/topology recognition (template matching) | New `SystemRecognitionProvider` producing `EngineeringGroup`s | High | Medium | New provider interface (extends ADR-001 pattern); writes go through `GraphService`/`EngineEventBus` | See `EKE_ALGORITHMS.md` #8 |
| Wiring diagram design rules (40 heuristics) | Future Import/Validation knowledge base | High | Medium (content-authoring, not code) | None blocking | Highest-value knowledge artifact found; largely a data-authoring task |
| Component electrical-semantics catalog (inputs/outputs/category) | New knowledge layer, distinct from Symbol Library appearance data | Medium | Medium | Needs an SDD-level decision on where "electrical semantics distinct from appearance" lives | Not just a bigger Symbol Library — a different concern (SDD-028 is explicitly appearance-only) |
| Confidence as a first-class field | SDD-027 amendment (`EngineeringNode`/`EngineeringRelationship`) | High | Medium | **Requires architectural review before implementation** | Documented gap, `EKE_GRAPH_COMPARISON.md` |
| `Net` (electrical-equivalence-class) concept | SDD-027 amendment (new `EngineeringNet` or similar) | High | Medium–High | **Requires architectural review before implementation** | Documented gap, `EKE_GRAPH_COMPARISON.md` |
| Keyboard-triggered search overlay | `SearchService` (already named, unimplemented, in SDD-026) | Medium | Medium | None | Confirms this planned service is a real, expected workflow |
| Shared contextual context-menu pattern | Demonstration Host / future Studio | Low | Low | None | UI pattern, not engine capability |
| Toast notifications | Demonstration Host / future Studio | Low | Low | None | UI pattern, not engine capability |

## Long Term — large effort, deferred to future authorized work packages

| Reference Feature | Engineering Engine Destination | Priority | Difficulty | Dependencies | Notes |
|---|---|---|---|---|---|
| Behavior/state engine (key off/on/cranking/running) | Real `SimulationProvider` implementation | High (eventually) | High | Simulation Engine work package explicitly not yet authorized | Reference's own version has no real signal propagation — worth designing better, not porting |
| Fault injection + electrical solver | Simulation Engine | High (eventually) | High | Same as above | Reference's own version is unused dead code — design fresh |
| Symptom-to-fault diagnostic reasoning + NL assistant | Diagnostic/Simulation Engine, possible AI integration | High (eventually) | High | Simulation Engine + AI integration policy (SDD-025/026: "AI never edits Engineering Graphs directly... Engineer approval remains mandatory") | Real, working in the reference; unify rather than replicate the reference's fragmented parallel-subsystems problem (`EKE_ARCHITECTURE_ANALYSIS.md`) |
| Multi-pass OCR / vision extraction pipeline | `ImportProvider` (PDF/image formats) | High (eventually) | High | Large effort; likely its own work package given scope | The most sophisticated, genuinely reusable engineering in the reference |
| Meter/multimeter simulation | Simulation Engine | Medium | High | Simulation Engine | Reference's version is a static lookup table, not a real solve — worth doing properly this time |
| Undo/redo (Command pattern) | Future Editing Engine | High (eventually) | Medium | Editing not yet authorized (WORK_PACKAGE_019/020 explicitly exclude it) | Reference sketched the right pattern but never wired it up — implement it correctly, first time |
| Copy/paste/duplicate/align/multi-select | Future Editing Engine | Medium | Medium | Editing not yet authorized | No reference behavior to draw from — design fresh |
| Drag-to-move layout persistence | Future Diagram Studio + View-level layout storage | Medium | Medium | Diagram Studio not started (`oep_studio`, out of scope) | Reference confirms layout-only mutation is correct (matches SDD-024) |

## Will Not Migrate

| Reference Feature | Reason |
|---|---|
| DOM/CSS/SVG hybrid rendering mechanics | Explicitly forbidden (WORK_PACKAGE_019/020); superseded by the Flutter View/scene-description model (ADR-003) |
| Global-mutable-variable state architecture | Superseded by the provider/registry (ADR-001) + `Stream`-based service model (SDD-026) |
| Flat parallel-array graph storage | Superseded by `Map`-keyed `EngineeringGraph` (O(1) lookup vs. O(n) scan) |
| SQLite persistence/query layer (`output/knowledgegraphstore.js`) | Foundation owns persistence in this architecture (SDD-025) — a bespoke store here would violate that boundary |
| CV symbol shape-detection pipeline (Hu-moment matching) | Dead/orphaned in the reference itself — nothing proven to migrate; a future symbol-detection effort would be designed fresh |
| Legend region parser | Never invoked in the reference — aspirational only, nothing working to preserve |
| Floating/dockable panel manager | `oep_studio`'s own workspace/docking framework is the correct home for this concern, not the Engineering Engine |

---

## Future Architecture Recommendations (ENGINE-TASK-000074)

Recommendations only — none implemented here.

**Performance.** The reference's full-rebuild-every-redraw rendering
(`EKE_RENDERING_PIPELINE.md`) works at its current scale but wouldn't
scale gracefully. Recommend the Engineering Engine's `DiagramView`
eventually support incremental scene diffing (recompute only what
changed) once real-world graph sizes are known, rather than assuming
Flutter's default repaint behavior is sufficient indefinitely.

**Scalability.** Both graphs currently assume "one vehicle's wiring
diagram" scale (tens of components). If the Engineering Graph is meant to
scale to much larger systems (industrial plants, aircraft), the `Map`-
based storage is a good foundation, but traversal algorithms (`GraphQuery`,
`NavigationService`) should be revisited for very large graphs (e.g.
indexed adjacency lists, bounded-depth queries) before that becomes a
real workload.

**Plugin architecture.** SDD-029's extension manifest is already more
principled than anything found in the reference (which has no plugin
concept at all — the entire simulator is one monolithic app). No
reference behavior to draw from here; the Engineering Engine is already
ahead architecturally in this dimension. Recommend prioritizing a
concrete first extension (e.g. an "Automotive" package wrapping the 14
seed symbols + the wiring-diagram-design-rules knowledge) to validate
SDD-029 in practice.

**Marketplace.** Same observation — no reference equivalent. The
migration matrix above (component electrical-semantics catalog, wiring
design rules, system templates) is exactly the kind of content a first
Marketplace "Automotive Diagnostics" package would ship — worth treating
as a target for validating the extension/registration story end-to-end.

**Simulation.** The reference's fragmented reasoning subsystems
(`EKE_ARCHITECTURE_ANALYSIS.md` weakness #1) are the strongest cautionary
lesson available: recommend designing one unified Diagnostic/Simulation
pipeline from the start (symptom → candidate faults → graph-structural
context → recommended tests → explanation), rather than accreting
several independently-useful-but-disconnected engines the way the
reference did.

**AI.** SDD-025/026 already establish "AI consumes Engineering Knowledge,
never edits directly, engineer approval mandatory." The reference's
`DiagnosticAssistant` (natural-language Q&A over a graph) is a good proof
that this shape works in practice and is worth treating as a reference
UX pattern (ask a question, get a graph-derived answer with a cited
path) once AI integration is authorized — not as code to port, but as
validated interaction design.

**Rendering.** Beyond the wire-routing/dimming gaps already in the
matrix above, the reference's type-specific card builders (battery card
vs. bulb card vs. connector card look different) confirms that a Symbol-
Library-driven rendering approach (SDD-028, already implemented) is the
right generalization of an idea the reference expressed through
hand-written builder functions instead of data.

**Collaboration.** No reference equivalent exists (single-user, local,
single-page app) — nothing to migrate. Flagged here only because
WORK_PACKAGE_020 asks for it explicitly: if multi-user editing is ever a
goal, the Engineering Graph's immutable-copy-on-write model
(`EngineeringGraph.withNode`, etc.) is a reasonable foundation for future
operational-transform or CRDT-style merging, since every edit already
produces a new, diffable graph value rather than mutating shared state
in place — unlike the reference's direct-global-mutation model, which
would not extend to collaboration without a rewrite.
