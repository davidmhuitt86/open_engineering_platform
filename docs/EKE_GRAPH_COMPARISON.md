# EKE Graph Comparison (ENGINE-TASK-000071)

Comparing the reference implementation's Canonical Electrical Graph (CEG) —
documented in `engine_reference_only/docs/object-model.md` and
`graph-schema-v2.md`, and confirmed against `core/graph/graph.js` — against
the Engineering Graph (SDD-027). This is a concept comparison; no code was
migrated.

---

## Philosophical alignment

Both graphs share the identical founding principle, independently arrived
at in each spec:

| | Reference (CEG) | Engineering Engine |
|---|---|---|
| Founding rule | "Everything feeds the graph... everything consumes the graph... the graph owns the truth" (`architecture.md`) | "Engineering Graph represents Engineering Knowledge... Diagram Renderer visualizes the Engineering Graph" (SDD-024) |
| Layout separation | "If information affects electrical behavior, it belongs in the graph. If information affects only visual appearance, it belongs in the simulator/editor." (`graph-schema-v2.md`, Final Rule) | "The graph contains no visual layout information" (SDD-024); Runtime Metadata excluded from persistence (SDD-027) |
| Stable identity | "Every object must have a stable identifier" (Principle 2) | `id` on every Node/Relationship/Group/Port |
| Multiple views | Diagrams/simulations/diagnostics are "merely views of the graph" | "Diagram Renderer visualizes the Engineering Graph... Multiple renderers may exist" |

This is the single most important finding of this comparison: **the two
architectures were designed around the same idea independently.** That
validates SDD-024's design rather than requiring correction — see
`EKE_ARCHITECTURE_ANALYSIS.md` §Strengths.

---

## Object-by-object comparison

### Equivalent concepts (same idea, different shape)

| Reference object | Engineering Graph equivalent | Notes |
|---|---|---|
| `Component` (id, type, label, terminals[], metadata) | `EngineeringNode` (id, category, displayName, symbolId, ports, metadata) | Reference conflates "type" (electrical kind, e.g. `relay`) with what SDD-028 splits into `symbolId` (appearance) — see "Improved concepts" below. |
| `Terminal` (id, componentId, designation, direction) | `Port` (id, name, direction, type) — owned by the node, not a separate graph-level object | Reference makes Terminal a first-class graph object with its own id, referenced by wires. Engineering Graph makes Port a value nested in the node. See "Missing concepts." |
| `Wire` (id, sourceTerminalId, targetTerminalId, color, gauge) | `EngineeringRelationship` (id, relationshipType, sourceNode, targetNode, metadata) | Reference wires connect *terminals*; Engineering Relationships connect *nodes*. Reference's `color`/`gauge` are physical-wire metadata with no direct SDD-027 field — they'd live in `metadata` today. |
| `System` (id, type, members[], confidence) | `EngineeringGroup` (id, kind, memberNodeIds) | Close match; reference's `confidence` (from recognition, 0–100%) has no equivalent field on `EngineeringGroup` today — see "Missing concepts." |
| `Evidence` (id, source, value, confidence) — extraction evidence | `EvidenceLink` (id, kind, sourceReference, locator, confidence) | Same purpose (traceability to source material), independently converged shape. |
| Ground modeled "as components and nets" | `NodeCategory.ground` | Direct match. |
| `Vehicle` (top-level metadata: manufacturer, model, year, source) | `EngineeringGraph.metadata` (free-form map) | Reference has a typed top-level object; Engineering Graph has an untyped bag. Workable but weaker for e.g. search/filter by vehicle. |

### Missing concepts (reference has it, Engineering Graph doesn't yet)

1. **`Net`** — "electrically common conductors... battery positive may span multiple wires and connectors but remain one electrical net." This is a real gap: nothing in SDD-027 represents *electrical equivalence classes* distinct from a `Circuit`/`Harness` `EngineeringGroup`. A `Net` is not organizational (like a Group) — it's an assertion that many relationships are the *same electrical node*. Recommendation: this is exactly the kind of finding WORK_PACKAGE_020 asks to be documented, not implemented — flagged for a future SDD-027 amendment or an `EngineeringNet` concept, reviewed architecturally before building.
2. **`Connector` / `ConnectorPin`** as first-class graph objects with pin-level identity independent of the component they sit on. Engineering Graph's `Port` is close but is owned by a single node, and SDD-027 doesn't distinguish "a connector is itself a Node with its own pins" from "a component's ports." The reference explicitly separates `Connector` (id, label, pins[]) from generic components. Today this maps adequately to `NodeCategory.connector` + `Port`s, but connector *pairing* (Rule 21: "connector halves are always paired") has no explicit graph concept on either side.
3. **`Behavior`** (conditions[], effects[]) — a first-class graph object describing system operation states (Key ON, Engine Running). SDD-027 has nothing corresponding; this is squarely Phase-2/Simulation-Engine territory (SDD-025 lists Simulation as future work), so its absence is expected, not a defect, at this stage.
4. **`Fault`** (id, type, target, symptoms[]) as a graph object. Same as above — explicitly deferred to a future Simulation/Diagnostic Engine.
5. **Confidence as a first-class, typed field.** The reference threads `confidence` through nearly every object (Component-via-evidence, Wire, System, topology match). SDD-027's `EngineeringNode`/`EngineeringRelationship` have no dedicated confidence field — it would currently be smuggled into `metadata`. Given the Engineering Engine's own future import pipeline will need this (OCR/vision-derived nodes), this is worth a documented recommendation (see `EKE_MIGRATION_MATRIX.md`).

### Improved concepts (Engineering Graph does it better)

1. **Clean data/appearance separation via the Symbol Library (SDD-028).** The reference's `Component.type` is doing double duty — it's simultaneously the electrical classification *and* (via `knowledge/components/<type>.json`) the implied visual symbol. Engineering Graph explicitly splits this: `category` (electrical/structural kind) is independent of `symbolId` (which Symbol Library definition renders it). This is a genuine improvement: a node's category never needs to change just because someone wants to render it differently, and "Unknown Symbol" handling (SDD-028) has no reference-side equivalent — an unrecognized reference component type has no graceful fallback.
2. **Provider/interface architecture (ADR-001).** The reference has no equivalent extension mechanism — `Graph`, `QueryEngine`, `GraphEditor` are concrete classes with no interface layer. Engineering Graph's `GraphProvider`/`SerializationProvider` abstraction means storage can be swapped (in-memory today, Foundation-backed later) without touching `GraphService`. The reference has no such seam — swapping its SQLite store (`output/knowledgegraphstore.js`) for anything else would require touching the store's callers directly.
3. **Runtime metadata is a typed, excluded-from-persistence concept (SDD-027), not convention.** The reference relies on "the simulator owns layout" as a documented rule, but nothing in the `Graph`/`Component` classes themselves *enforces* that a UI concern can't leak into a serialized graph — it's a discipline, not a type-level guarantee. `RuntimeMetadata.toJson()` exclusion is enforced by the model itself.
4. **Views as a formal layer (ADR-003).** The reference's "diagrams are merely views of the graph" is stated as philosophy but has exactly one concrete renderer (the simulator's canvas). Nothing in the reference formalizes "a View is `render(graph) -> scene`, swappable, and there could be several." SDD-024/025 make this an explicit architectural layer from day one.

### Deprecated concepts (deliberately not carried forward)

1. **Flat parallel-array graph storage** (`Graph` holds `components[]`, `terminals[]`, `wires[]`, ... as separate arrays, cross-referenced by id, scanned with `.filter`/`.find`). Engineering Graph uses `Map<String, T>` keyed by id for O(1) lookup instead of O(n) linear scans — a straightforward implementation improvement, not an architectural one.
2. **Generic string-typed relationship label** (`connected_to`, `belongs_to` as arbitrary strings). `RelationshipType` is a closed enum (SDD-024's list) with an `other` escape hatch — trades a small amount of flexibility for compile-time safety and an explicit, documented vocabulary.
3. **Browser DOM/CSS-based rendering and selection state** (CSS class toggling for "traced," canvas-and-DOM-hybrid rendering). No equivalent exists or should exist in the Engineering Engine — this is precisely the implementation layer WORK_PACKAGE_019/020 forbid migrating. Superseded entirely by the View/scene-description model (ADR-003).

---

## Migration strategy

No code migration occurred or is proposed here (per WORK_PACKAGE_020 scope). Recommended sequencing, expanded fully in `EKE_MIGRATION_MATRIX.md`:

1. **Immediate-eligible (Engineering Graph already covers or trivially extends):** Component/Terminal/Wire/System concepts — already representable via `EngineeringNode`/`Port`/`EngineeringRelationship`/`EngineeringGroup`.
2. **Needs an SDD-027 conversation before building:** `Net` (electrical-equivalence-class) is the one real object-model gap found. Confidence-as-a-field is the one real field-level gap found. Both are documented here and in the migration matrix as *findings requiring architectural review*, not implemented.
3. **Correctly deferred:** `Behavior` and `Fault` as graph objects — these belong to the Simulation Engine, explicitly out of scope for both WORK_PACKAGE_019 and 020.
