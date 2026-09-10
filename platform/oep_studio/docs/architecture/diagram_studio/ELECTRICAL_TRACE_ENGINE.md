# Electrical Trace Engine (PRODUCT-READINESS-005)

## Purpose

Answer, as structured engineering data: "what is this component electrically
connected to, and how does energy/current actually flow through it?" — the
capability behind "click the headlight and understand its circuit." This is
an analysis/query layer, not a visualization feature and not a second
electrical solver.

## Where this lives

- `platform/oep_engine/lib/core/trace/` — implementation.
- `platform/oep_engine/lib/trace/trace.dart` — public barrel, exported
  transitively via `engineering_engine.dart`.
- `platform/oep_engine/test/trace/` — tests (synthetic fixtures + TRX300).

## Architecture

```
Engineering Graph -> Electrical Topology -> Operating State -> Electrical Solution
    -> SolvedElectricalState (PRODUCT-READINESS-004) -> Trace Engine -> TraceResult
```

`TraceEngine.trace()` takes an `EngineeringGraph`, a `TraceTarget`, a
`TraceMode`, and — for `conducting`/`currentFlow` modes — a
`SolvedElectricalState` and an `ElectricalOperatingContext`. It never
computes voltage, current, resistance, or conducting state itself:

- **Physical-mode connectivity** comes from `EngineeringGraph`'s own
  relationships (terminal-aware, via `metadata['sourcePort']`/`['targetPort']`)
  plus each component's state-INDEPENDENT terminal topology
  (`ElectricalComponentBehavior.physicallyConnectableTerminalPairs`, or the
  engine's own built-in connector-same-pin / splice-all-bridge / ground-sink
  classification when no behavior is supplied). None of this is an
  electrical calculation — it is either static graph structure or a
  component's own declared, state-independent wiring shape.
- **Conducting/current-flow gating** is read directly from a caller-
  supplied `SolvedElectricalState` (per relationship, via
  `ElectricalBranchState.conductingState`/`current`/`currentDirection`) and
  from `ElectricalComponentBehavior.conductingTerminalPairs` for a
  component's own internal terminal bridging (a topology/state lookup —
  "is the switch in the ON position" — not an electrical solve).

The Trace Engine is read-only: it never mutates `EngineeringGraph`,
`SolvedElectricalState`, or any argument, and has no side effects on
persistence, simulation state, or UI selection.

## The three trace modes

- **Physical** — "what physical engineering objects are connected?" Does
  not consult `SolvedElectricalState` at all; does not imply current is
  flowing. An open switch is still part of the physical chain.
- **Conducting** — "what electrically conductive paths exist right now?"
  State-dependent; an open switch breaks this trace.
- **Current-flow** — "where is actual current flowing?" Built strictly on
  solved branch current/direction (`ElectricalBranchState.current`/
  `currentDirection`) — never on `voltage != 0`, wire endpoint ordering,
  screen coordinates, or SVG direction.

Conducting connectivity is always a subset of physical connectivity — the
engine computes physical paths once as the structural backbone, then
re-walks each one for conducting/current-flow modes, truncating at the
first hop that fails conducting-mode gating and recording the blocking
step (`TracePath.blockingStep`/`blockingReason`) rather than discarding the
path. This means a query never collapses to "no path" when "physical path
found, but blocked here" is the more useful, honest answer.

## Terminal-centric targets

`TraceTarget` has three constructors — `.component(id)`, `.terminal(probePoint)`,
`.relationship(id)` — all normalized by the engine into a set of starting
terminals (`ProbePoint`s) before tracing begins. A component-level trace
expands to every one of its own ports (or a single portless terminal as a
graceful fallback for a node with no declared ports); a relationship-level
trace resolves to that relationship's own two endpoint terminals. There is
no separate code path per target kind — wire-centric tracing goes through
exactly the same engine as component/terminal tracing (§5/§28 — no
duplicate architecture).

## TraceResult / TracePath

`TraceResult` carries: the target, mode, the `ElectricalSolutionGeneration`
that produced it (`null` only for a `physical` trace run with no solved
state at all), a deterministically-ordered, deduplicated list of
`TracePath`s, the source/return terminal sets, every component/relationship/
terminal touched, splice/connector component sets (tracked separately —
never conflated), and a list of structured `TraceDiagnostic`s.

`TracePath` preserves ordered topology as a list of `TracePathStep`s, each
carrying a full `ProbePoint` (never a bare node id) and the relationship (if
any) crossed to reach it. A path's own `pathId` is a deterministic string
built from its ordered steps — never object identity or collection
iteration order — which is what makes ordering (§19) and deduplication
(§19) both reproducible.

## Source / return semantics

Source and return/ground candidates are identified by scanning every
terminal a trace actually visits for `ElectricalTerminalState.isSourceTerminal`/
`isReferenceTerminal` (both already part of PRODUCT-READINESS-004's own
model) — never by hardcoding a component name or category. Zero, one, or
several terminals of either role may be found; `TraceResult.hasMultipleSources`/
`hasMultipleReturns` and matching diagnostics surface that honestly rather
than assuming a unique source/ground.

## Splice vs. connector

A splice (`metadata['v2Category'] == 'splice'`, matching the real V2↔OEP
bridge's own existing convention — not a new signal) is modeled as an
unconditional, state-independent junction bridging every one of its own
terminals (`AlwaysBridgeElectricalComponentBehavior`). A connector
(`NodeCategory.connector` or `metadata['v2Connector'] == true`) bridges
only the SAME physical pin to itself — two different pins are never
automatically equivalent (`PassThroughElectricalComponentBehavior`,
carried over unchanged from PRODUCT-READINESS-004). The two are tracked as
separate sets on `TraceResult` and must never be conflated.

## Switches / unmodeled components

Absent a real, caller-supplied `ElectricalComponentBehavior`, the engine
NEVER fabricates internal bridging for a component (the same conservative
default PRODUCT-READINESS-002 proved correct in the Legacy V2 JS solver,
`AP-DEADEND-GENERALIZE-001`) — an unmodeled inline component (a switch with
no behavior supplied) is a structural dead end for tracing purposes, not a
silently-assumed pass-through. A real switch behavior must explicitly
declare its structural capacity via
`physicallyConnectableTerminalPairs` (for physical trace) and its actual,
state-dependent bridging via `conductingTerminalPairs` (for conducting/
current-flow trace) — this is a genuine, additive extension point on
PRODUCT-READINESS-004's own `ElectricalComponentBehavior` contract (see
that class's own doc comment for why it was added rather than
repurposing the existing method).

## Zero current vs. open

A conducting branch/path with `current.value == 0` remains
`ElectricalConductingState.conducting` — a de-energized-but-intact circuit
is a real, valid state, never collapsed into `open`. This is PRODUCT-
READINESS-004's own explicit invariant, carried through unchanged.

## Blocked-path semantics

A path that is physically found but conducting-mode blocked reports
`conductingState: open` with `blockingStep` (the terminal that would have
been reached) and `blockingReason` (why) populated — never a bare "no
path." This is the direct, literal expression of "physical connectivity
is a superset of conducting connectivity."

## Cycle handling

The engine tracks visited terminals per path-in-progress; an edge that
would revisit an already-visited terminal within the SAME path is not
followed further (preventing infinite traversal) and is recorded as a
`TraceDiagnosticCode.cycleDetected` diagnostic naming exactly where the
cycle was found, rather than silently truncating or rejecting the whole
graph as untraceable.

## Legacy V2 migration boundary

The Legacy V2 diagnostics modules (`circuit-tracer.js`, `path-finder.js`,
`power-path.js`, `ground-path.js`, `path-highlighter.js`) were the
behavioral reference for this design, not source copied wholesale. Their
known limitations — pin-blind traversal (inherited from `GraphTraversal`'s
own whole-node BFS, unrelated to PRODUCT-READINESS-002's pin-gating fixes
to the voltage/ground propagators specifically), unordered wire-id sets
instead of ordered paths, and current-flow visualization driven by
`voltage != 0` rather than solved current — are explicitly NOT carried into
this architecture.

## UI boundary

The Trace Engine returns engineering references only (`ProbePoint`s,
component/relationship ids, `ElectricalReading`s) — never Flutter widgets,
SVG elements, screen coordinates, CSS classes, colors, or animation
controllers. A future renderer consumes `TraceResult` to decide what to
highlight/animate; highlighting logic does not belong in the solver, and
electrical tracing does not belong in the renderer.

## Future Circuit artifact boundary

No persisted `Circuit` `EngineeringObject` was introduced or assumed in
this phase. The live circuit is derived from `EngineeringGraph` + operating
state + `SolvedElectricalState` on every query. A future named/persisted
Circuit artifact (an engineering-knowledge/annotation object referencing
wires/components/terminals) may be introduced later, but must never
replace this live derivation, matching PRODUCT-READINESS-004's own
Knowledge-Runtime-vs-Live-Simulation authority boundary.

## Persistence / performance

`TraceResult` is never persisted — it is derived runtime analysis,
recomputed on demand. No caching is introduced in this phase (§36: "Do not
introduce caching until correctness and generation invalidation are well-
defined"); a future cache, if added, must be keyed by
`ElectricalSolutionGeneration` and trace target/mode.

## What is NOT integrated yet

- No solver populates `SolvedElectricalState` from a real `EngineeringGraph`
  (unchanged from PRODUCT-READINESS-004's own report).
- `diagram7.json` (the real TRX300 fixture) stores `"ports": []` on every
  node — real per-terminal data lives only in `metadata['v2Terminals']`
  (name/color pairs with no stable id), a format PRODUCT-READINESS-004/005's
  `Port`-based model does not read directly. The TRX300 test suite uses a
  test-only adapter (mirroring the existing JS test harness's own
  `loadOepSampleAsV2` precedent) to reconstruct real `Port`s from
  `v2Terminals` for testing; production `EngineeringNode`/`Port`/the real
  V2↔OEP bridge are untouched. Populating `ports` for real bridged/ingested
  diagrams remains a real, disclosed dependency for any future production
  integration.
- No Dart `ElectricalComponentBehavior` is ported for the real switch/lamp/
  motor/diode component types TRX300 actually uses (only splice/connector,
  matching the bridge's own existing `v2Category`/`v2Connector` metadata) —
  confirmed by a dedicated regression test that will fail loudly once that
  work begins, so this document stays accurate without manual upkeep.
- `MultimeterController`/DMM widgets/Android DMM/OIP protocol are untouched
  (PRODUCT-READINESS-006's scope).
