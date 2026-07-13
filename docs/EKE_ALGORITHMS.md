# EKE Algorithm Inventory (ENGINE-TASK-000072)

Reusable algorithms identified in `engine_reference_only/`. Concepts only
— no code has been or will be migrated.

---

### 1. Graph traversal (BFS reachability + shortest path)

**Location.** `core/graph/graph.js` (`reachableFrom`, `findPath`).

**Purpose.** Flood-fill reachability from a node, and shortest node-to-node
path.

**Inputs.** Graph, start node id (+ target id for path-finding).

**Outputs.** Set of reachable node ids / ordered path array, or
unreachable signal.

**Complexity.** Standard BFS, O(V+E).

**Migration recommendation.** **Already migrated in Phase 1** —
`GraphTraversal.reachableFrom`/`findPath` in the Engineering Engine is a
from-scratch reimplementation of the identical algorithm shape,
independently arrived at. No further action needed; this entry exists to
confirm parity, not to propose new work.

---

### 2. Directional power/ground path tracing

**Location.** `core/graph/queryengine.js` (`getPowerPath`, `getDependents`)
and `apps/simulator/diagnostics/{power-path,ground-path,path-finder,
circuit-tracer}.js`.

**Purpose.** Trace current flow conceptually from a source (battery/
stator) downstream to loads, or upstream from a load back to its source —
a directional variant of plain reachability that stops at recognized
"source" or "ground" node types rather than exploring the whole graph.

**Inputs.** Graph, a starting node, and a type-based stopping predicate
(e.g. "stop at any node classified as a power source").

**Outputs.** An ordered node/wire-id sequence representing the traced
path, consumed directly by `path-highlighter.js` for rendering (see
`EKE_INTERACTION_MODEL.md`).

**Complexity.** BFS/DFS with an early-termination predicate, O(V+E) worst
case, typically much less in practice since it stops at source/ground
boundaries.

**Migration recommendation.** Needs Migration. This is a well-scoped,
valuable algorithm the Engineering Engine doesn't have yet:
`NavigationService.highlightPathBetween` today finds the shortest path
between two named nodes, not a *directional, type-aware* trace ("show me
everything downstream of this battery"). Recommend adding this as an
additional `GraphTraversal`/`NavigationService` capability once
`NodeCategory` semantics (source vs. load vs. ground) are established
clearly enough to define the stopping predicate — worth a short design
note before implementation, not a large effort.

---

### 3. Orthogonal wire auto-routing with lane allocation

**Location.** `apps/simulator/diagram/renderer.js` (`route(w)`, `usedX`/
`usedY` allocation state).

**Purpose.** Compute a visually clean orthogonal (horizontal/vertical
only) path between two terminal positions, allocating a distinct "lane"
offset so multiple parallel wires between similar regions don't overlap
visually.

**Inputs.** Source/target terminal screen positions, current
lane-occupancy state (shared across the whole redraw pass).

**Outputs.** An ordered polyline (list of points) describing the route.

**Complexity.** Greedy, effectively O(1) per wire (checks and increments
a small allocation table), O(n) for n wires per full pass — not
graph-search-based, a layout heuristic rather than a pathfinding
algorithm.

**Migration recommendation.** Needs Migration — the single highest-value
rendering algorithm not yet in the Engineering Engine (Phase 1's
`DiagramView` connects node centers with straight lines only). Recommend
implementing as a pure function in `lib/core/views/diagram/` (e.g.
`DiagramWireRouter`), taking node/port positions and existing route
occupancy and returning a polyline — keeping it consistent with
`DiagramView`'s existing "produce scene data, never paint" contract
(ADR-003).

---

### 4. Selection state management

**Location.** `apps/simulator/editor/selection-manager.js`.

**Purpose.** Track "what is currently selected," toggle on repeated
clicks.

**Inputs/Outputs.** Trivial — a single id in, a single id (or none) held
as state.

**Complexity.** O(1).

**Migration recommendation.** Already migrated — `SelectionService`
(Phase 1) covers this and more (node/relationship/port/symbol/group/
evidence kinds, not just wire/module).

---

### 5. Highlight-set computation (path-highlighter)

**Location.** `apps/simulator/diagram/path-highlighter.js`.

**Purpose.** Given a traversal result (power path, ground path, full
circuit), produce the wire-id set a renderer should visually
distinguish, without the highlighter itself touching rendering.

**Inputs.** Graph + a traversal request (which path type, from which
node).

**Outputs.** A `Set` of wire/relationship ids to highlight.

**Complexity.** Dominated by whichever traversal algorithm (#1 or #2)
produced the path — the highlight-set step itself is O(path length).

**Migration recommendation.** Already migrated conceptually —
`NavigationService.highlightPathBetween` computes a node/relationship id
set and emits it via `NavigationEvent`, mirroring this exact
traversal-computes/renderer-paints separation (see
`EKE_INTERACTION_MODEL.md`). Extending it to directional power/ground
tracing (#2) is the remaining gap, not the pattern itself.

---

### 6. Connection/topology validation

**Location.** `reasoning/topology/topologyvalidator.js`
(`validateConnection` — BFS reachability check between two ids) and the
duplicate-wire rejection in `apps/simulator/editor/wire-editor.js`.

**Purpose.** Answer "are these two points electrically connected?" (a
reachability query framed as a yes/no validation) and prevent creating a
redundant identical connection.

**Inputs.** Graph, two node/terminal ids (or a proposed new wire).

**Outputs.** Boolean (connected / not connected; allowed / rejected).

**Complexity.** O(V+E) for the reachability check; O(n) linear scan for
duplicate-wire detection in the reference's flat-array model (would be
O(1) average-case against the Engineering Engine's `Map`-keyed
relationships, or O(degree) scanning a single node's relationships).

**Migration recommendation.** Needs Migration as an explicit
`ValidationService` rule ("would this create a duplicate relationship?")
— a small, cheap addition given the Engineering Graph's existing
`relationshipsForNode` helper.

---

### 7. Component/symbol lookup and alias resolution

**Location.** `core/graph/graph.js` (`findComponentById/ByType/
ByCategory` — linear `.filter`/`.find` scans over flat arrays);
`knowledge/components/*.json` alias catalogs, consulted during
extraction label-classification (`extraction/symbols/symboldetector.js`,
`diagram-extractor`'s Python classifier).

**Purpose.** Two related but distinct things: (a) find graph objects
matching a predicate; (b) resolve a raw OCR/label string to a canonical
component type via a synonym table (e.g. "HEADLIGHT" / "HI BEAM" →
`lamp`).

**Inputs.** (a) graph + predicate; (b) a raw string + an alias table.

**Outputs.** (a) matching object(s); (b) a canonical type id or "no
match."

**Complexity.** (a) O(n) linear scan in the reference (a real, measurable
weakness at scale); (b) O(1) if backed by a hash map, which the
reference's alias tables effectively are.

**Migration recommendation.** (a) Already improved — Engineering Graph's
`Map<String, EngineeringNode>` gives O(1) id lookup and
`GraphQuery.nodesByCategory`/`nodesBySymbol` are simple O(n) filters only
where a full scan is actually necessary (unavoidable for a "find all
matching X" query regardless of storage). (b) Already migrated —
`SymbolLibrary.lookup` resolves by identifier or case-insensitive alias
in Phase 1, matching this exact pattern.

**Note for future work.** Two separate `systems/`-related directories
exist in the reference (`systems/` at repo root — `confidencecalculator.
js`, `graphmatcher.js`, `recognizer.js`, `systemtemplates.js` — and
`reasoning/systems/`). Whether these are duplicates, an in-progress move,
or genuinely distinct was not conclusively resolved in this pass — flagged
here rather than asserted, and worth a direct diff before any future
system-recognition migration work begins.

---

### 8. System/topology recognition (template matching)

**Location.** `reasoning/systems/{systemtemplates,recognizer}.js`,
`reasoning/topology/{topologytemplates,topologyrecognizer}.js`,
`systems/graphmatcher.js`, `systems/confidencecalculator.js`.

**Purpose.** Given a graph, decide which named systems/topologies (e.g.
"CDI ignition circuit") it contains, by checking whether the graph's
component types satisfy a template's required/optional type lists.

**Inputs.** Graph, a static template dictionary (`{name: {required:
[types], optional: [types]}}`).

**Outputs.** For topologies: binary match (fixed 100% confidence). For
systems: a graduated score (`foundCount / totalPossible * 100`), plus a
materialized `System` node with `belongs_to` relationships added to the
graph — i.e. **recognition mutates the graph** by adding derived
knowledge, a notable and deliberate design choice.

**Complexity.** O(V) per template (count matching component types), ×
O(templates) total — cheap, no graph traversal required, purely a
set-membership check against the node type multiset.

**Migration recommendation.** Needs Migration — this is genuinely
reusable and not yet present in any form in the Engineering Engine. It
naturally becomes a new provider behind a `SystemRecognitionProvider`-
shaped interface (following the established provider/registry pattern,
ADR-001), producing `EngineeringGroup`s (SDD-027) rather than a bespoke
`System` node type — see `EKE_GRAPH_COMPARISON.md`. The "recognition
mutates the graph by adding derived groups" behavior is worth preserving
deliberately (it's a legitimate write, not an accidental side effect),
but should go through `GraphService`/`EngineEventBus` rather than direct
mutation, consistent with how all other graph writes already work in
Phase 1.

---

### 9. Confidence scoring / property resolution

**Location.** `systems/confidencecalculator.js`, the cumulative-evidence
pattern documented in `wiring-diagram-design-rules.md` Rule 37, and
`output/knowledgegraphserializer.js`'s confidence rollup (`overall` =
average of extraction confidence + per-topology confidence; `recognition`
= mean of topology confidences).

**Purpose.** Combine multiple independent, possibly-conflicting signals
(OCR confidence, symbol-match confidence, topology-match confidence) into
a single aggregate confidence value for a graph object or the graph as a
whole — described qualitatively in Rule 37 as strictly additive
(corroborating evidence raises confidence, contradicting evidence lowers
it, no single signal is dispositive).

**Inputs.** A set of `{score, source}` evidence entries.

**Outputs.** A single aggregate confidence number (0–100 or 0.0–1.0
depending on call site — the reference is **not consistent** about this
normalization, a minor but real inconsistency worth avoiding in a fresh
design).

**Complexity.** O(n) in the number of evidence entries — simple
averaging/weighting, not a sophisticated statistical model.

**Migration recommendation.** Needs Migration, gated on the confidence
field gap already flagged in `EKE_GRAPH_COMPARISON.md`. Recommend: (a)
adopt a single normalized range (0.0–1.0) consistently, unlike the
reference; (b) implement as a pure function taking a list of evidence
records and returning a score, independent of any specific object type,
so it can score a node, a relationship, or a whole graph identically.
