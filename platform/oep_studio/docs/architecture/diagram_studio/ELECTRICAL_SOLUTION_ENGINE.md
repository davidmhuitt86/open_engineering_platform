# Electrical Solution Engine — architecture

Status as of PRODUCT-READINESS-006B. Supersedes the PRODUCT-READINESS-004
Phase A version of this document (that phase was model/contracts-only; a
real, native, tested solver now exists — see "Solver authority" below).
See "PRODUCT-READINESS-006B — arbitrary measurement & the general
resistive network" near the end of this document for the most recent
addition (the `measure()` query and the general series/parallel/mixed
network solver PRODUCT-READINESS-006 itself had explicitly deferred).

## Solver authority: NATIVE

**Decision: native Dart implementation, not an adapter over the Legacy V2
JS solver.** Considered and rejected: `oep_engine` is a plain Dart package
with no WebView/JS-runtime dependency today (`webview_flutter*` appears
only in `oep_studio`), and a genuine cross-platform solver (Windows/Linux/
Android/iOS, no platform-specific logic) cannot be built by embedding a JS
engine into `oep_engine` purely to reuse the JS solver's math — that would
itself be the platform-specific complexity this architecture is meant to
avoid, not less of it.

`ElectricalSolver` (`core/simulation/electrical/electrical_solver.dart`)
instead **re-implements the same proven invariants** PRODUCT-READINESS-002
established and regression-tested in the JS solver — battery isolation,
same-pin gating, multi-entry BFS, multi-position switch continuity, lamp/
motor dead-ends, connector/splice distinction, open-vs-zero — natively,
against the terminal-centric model, validated by an equivalent Dart-side
regression suite (`test/simulation/electrical/electrical_solver_test.dart`,
fixtures A–P) rather than by calling into the JS implementation.

This is realistically a **hybrid migration**: one new, real authority for
`SolvedElectricalState` going forward; one existing, unmodified, still-
correct system (the Legacy V2 JS solver) continuing to drive the WebView's
own live bulb-glow display — a presentation-layer concern untouched by
this work. The two are kept behaviorally consistent by mirrored
invariants (the same regression cases, both proven independently), never
by one calling the other. **There is no second electrical authority**:
the JS solver still owns the WebView's own real-time visual simulation;
`ElectricalSolver` is the sole source of `SolvedElectricalState` for
every Dart-side consumer (Trace Engine now; DMM/diagnostics/visualization
later).

## Where this lives

- `platform/oep_engine/lib/core/simulation/electrical/` — the electrical
  domain model (PRODUCT-READINESS-004) and the solver
  (`electrical_solver.dart`, PRODUCT-READINESS-006).
- `platform/oep_engine/lib/core/trace/` — the Trace Engine
  (PRODUCT-READINESS-005), a pure consumer of `SolvedElectricalState`.
- `platform/oep_engine/lib/simulation/electrical/electrical.dart`,
  `lib/trace/trace.dart` — public barrels, exported transitively via
  `engineering_engine.dart`.
- `platform/oep_studio/lib/diagram_studio/webview/v2_terminal_port_bridge.dart`
  — the production terminal-bridge fix (see "Terminal bridge" below).
- Tests: `platform/oep_engine/test/simulation/electrical/`,
  `platform/oep_engine/test/trace/`,
  `platform/oep_studio/test/diagram_document_test.dart`.

## Terminal bridge — the real Port gap, closed

PRODUCT-READINESS-005 discovered that every real V2-bridged
`EngineeringNode` persists `"ports": []` — all real terminal data lives
only in `metadata['v2Terminals']` (a list of `{n, c}` name/color pairs
with no stable id), a format the `Port`-based model never read. This is
now fixed at the read side: `backfillV2TerminalPorts` (in
`v2_terminal_port_bridge.dart`) reconstructs real `Port`s (1-based index
as id, matching the SAME convention `metadata['sourcePort']`/
`['targetPort']` already use) whenever a document is loaded —
`DiagramDocument.open()` and `.recoverFrom()` both call it. This is
idempotent (a node that already has real ports is untouched) and
non-destructive (nothing is written back to the file). Proven against the
REAL `platform/oep_studio/samples/diagram7.json` — see
`diagram_document_test.dart`'s own §46 test: the real Battery node loads
with 2 real, named `Port`s through the actual production `open()` path,
no test-only reconstruction.

**Not yet done** (disclosed, not silently deferred): the WRITE side
(`legacy_v2_state_adapter.dart`'s `_handleModuleCreated`/
`_handleModulePropertiesChanged`, which stash `v2Terminals` into
`metadata` today) does not also populate `ports` directly at creation
time — a live-created node relies on the read-side backfill applying the
next time the document is loaded/reopened, not immediately in the current
in-memory session. Extending `DiagramEditingHost`'s command surface to
also set `ports` at creation time was judged out of scope for this phase
(a bigger, more foundational Engine-command change, carrying more
regression risk for a live, actively-used bridge than the read-side fix
alone).

A second, related real-data quirk found and fixed in the SAME normalization
pass (test-side, in the TRX300 test fixtures — not yet ported to
`v2_terminal_port_bridge.dart` itself, since that function only backfills
`ports`, not relationship port-reference normalization): a connector pin
reference is written as `"<pin>_IN"`/`"<pin>_OUT"` in real relationship
metadata (confirmed directly on `diagram7.json`'s own
`node_hm2wkv7mtt_9hiy30` wires) — the bare pin number is the real port
identity, matching `_pinNumberOf`'s own `_IN`/`_OUT`-stripping regex in
the Legacy V2 solver. This normalization is currently only applied by the
TRX300 test loaders; a production bridge extending to arbitrary connector-
heavy diagrams would need the same fix applied to real relationship
metadata, not just node ports.

## Electrical topology / terminal model

Unchanged from PRODUCT-READINESS-004/005: a component is not a node — it
is a set of terminals (`ProbePoint`s, `nodeId` + `portId`), each
independently addressable and independently stateful
(`ElectricalTerminalState`). See those phases' own sections below for the
full type inventory; this phase adds no new top-level types to the model,
only the solver that populates it.

## Component behaviors

`ElectricalComponentBehavior` (PRODUCT-READINESS-004) is now backed by a
real set of GENERIC, non-hardcoded implementations:

- `PassThroughElectricalComponentBehavior` — connector, same-pin-only.
- `AlwaysBridgeElectricalComponentBehavior` — splice, unconditional.
- `InlinePassThroughElectricalComponentBehavior` — a plain inline part
  (an intact fuse), always-conducting, near-zero resistance.
- `SwitchElectricalBehavior` — a generic 2-terminal switch, gated by
  `context.activeInputStates[switchId]` (conventionally the switch's own
  node id — no separate id scheme required).
- `MultiPositionSwitchElectricalBehavior` — a generic, DATA-DRIVEN
  multi-position switch (mirrors the Legacy V2 `MultiSwitchBehavior`
  design): the CALLER supplies a `Map<position, Set<ElectricalTerminalPair>>`
  — the class itself has no domain knowledge of what an "ignition switch"
  is.
- `DiodeElectricalBehavior` — real one-way conduction (anode->cathode
  only), enforced via the new `ElectricalComponentBehavior.conductsFrom`
  method (see below), with the Legacy V2 solver's own real forward-drop
  constant (0.65V).
- `ResistiveLoadElectricalComponentBehavior` — a real two-terminal load
  (a lamp/motor): never bridges its own terminals for topology purposes
  (preserves `AP-LAMP-TUNNEL-001`), but supplies a real resistance value
  for Ohm's-law current calculation.

**§29 additive contract extension**:
`ElectricalComponentBehavior.physicallyConnectableTerminalPairs` (added
in PRODUCT-READINESS-005, for the Trace Engine's physical-mode) and
`conductsFrom` (added in PRODUCT-READINESS-006, so a directional
component like a diode is never treated as bidirectional by the solver's
own internal-bridge BFS, which the order-agnostic
`conductingTerminalPairs`/`ElectricalTerminalPair` alone cannot express).
Both are additive, both have working defaults, neither required changing
an existing subclass.

**No component type is hardcoded by node id anywhere in the solver.**
TRX300-specific data (which real node is the ignition switch, its real
closed-pairs table) lives entirely in test/reference fixtures
(`electrical_solver_trx300_test.dart`), dispatched by the node's own
metadata (`v2Category`, `v2Kind`) or terminal NAME SET (matching the
Legacy V2 `MultiSwitchBehavior.match`'s own "recognize by terminal names,
not by id" technique) — never by literal id string comparison in generic
solver code.

## Operating state

Unchanged: `ElectricalOperatingContext` (PRODUCT-READINESS-004) bundles
the existing `OperatingStateDefinition`/`InputStateDefinition` shape. No
second operating-state framework was introduced.

## Solved electrical state

`ElectricalSolver.solve(graph, operatingContext, generationCounter:)` ->
`SolvedElectricalState` is the canonical production entry point.

- **Voltage**: BFS-propagated from source-role terminals (see "Source/
  return roles" below), gated by `conductsFrom` internally and by
  relationship adjacency externally — the direct, terminal-precise
  successor to PRODUCT-READINESS-004's own audited "one voltage per
  node, not per terminal" limitation.
- **Reference/ground voltage**: a STRUCTURALLY reference terminal (a real
  Ground-category node, or a terminal whose own name matches a reference
  pattern — `-`, `−`, `gnd`, `ground`, `neg`, `negative`) reads a real,
  definitional 0V. Deliberately NOT based on general ground-BFS
  reachability for this general-purpose reading (an earlier version was —
  found, on the real TRX300 fixture, to over-fire: transitive splice/
  connector chains reach nearly every terminal on the shared ground bus,
  which would falsely mark plainly non-ground terminals — e.g. a
  headlight's own power-feed pin — as "0V." See `_effectiveVoltageForCurrent`'s
  own doc comment for the narrower, one-hop-only place ground-BFS
  reachability is still legitimately used).
- **Conducting state** (a branch's own continuity): a weaker, boolean
  claim than a specific voltage value — safely based on EITHER resolved
  voltage OR the (still pin-gated) ground-reachability pass, since a
  multi-hop ground-return path is genuinely conducting even when no
  single wire along it resolves a specific 0V value on its own.
- **Current/power** (§19/§20/§49's own deliberately minimal scope): real
  Ohm's law (`I = ΔV/R`, `P = I×ΔV`) computed ONLY at a genuine resistive
  DEAD END (a component whose `conductsFrom` does NOT already bridge the
  pair in question — e.g. a lamp, never a fuse/closed switch/connector/
  splice, all of which "bridge" and would otherwise solve to a real but
  UNINFORMATIVE zero-drop reading at their own two terminals, since the
  voltage BFS gives both ends the identical propagated value by
  construction). The result is then reported on the immediately adjacent
  WIRE too (simple series current conservation) — a genuine, honest, but
  deliberately narrow capability: NOT a general multi-branch/parallel
  Kirchhoff solve.
- **Resistance**: read directly from `ElectricalComponentBehavior
  .resistanceBetween` — never fabricated, `unsupported` when no behavior
  has one.
- **Source voltage**: `ElectricalSourceVoltageResolver` (default: reads
  `EngineeringNode.properties['nominalVoltageV']`) — honestly `unknown`
  when absent. The real, production `diagram7.json` Battery node has NO
  such property authored at all (confirmed) — a real, disclosed gap in
  the source data, not papered over. A caller with real, external
  knowledge (e.g. the Legacy V2 solver's own disclosed
  `BatteryBehavior.VOLTAGE` constants) may supply its own resolver, as
  the TRX300 tests do.

## Source / return roles

`ElectricalSourceRoleResolver`/`ElectricalReferenceRoleResolver` — a
terminal is a source when its own behavior reports `generatesPower` OR
its node's `metadata['v2Category'] == 'power'` / `metadata['v2Kind'] ==
'battery'` (real, already-established V2 bridge signals — confirmed
directly on `diagram7.json`'s own Battery node), excluding its own
negative/ground-shaped terminal. Zero, one, or multiple sources/returns
are all representable — never hardcoded to "the battery."

## Generation

Unchanged: `ElectricalSolutionGeneration`/`ElectricalSolutionGenerationCounter`
(PRODUCT-READINESS-004) — a plain incrementing sequence, never a
timestamp. `ElectricalSolver.solve` takes a caller-owned counter and
returns a state stamped with its `next()` generation.

## Trace Engine integration

`TraceEngine` (PRODUCT-READINESS-005) is now proven against a REAL
`SolvedElectricalState` produced by `ElectricalSolver`, not only hand-
built fixtures — see `test/trace/trace_solver_integration_test.dart`.
`TraceEngine`'s own semantics are unchanged: physical trace never
consults solved state; conducting/current-flow trace read it exactly as
before, now genuinely populated. One refinement made to `TraceEngine`
itself (not a semantics change, a correctness fix once real solver data
existed to test against): current-flow aggregation now prefers the first
WIRE hop with a genuinely VALID current reading along a path, rather than
the first hop with any branch entry at all — a bridging component (a
fuse, a closed switch) always solves to a real-but-uninformative zero-drop
reading at its own two terminals, which was previously (when only
synthetic single-hop fixtures existed) indistinguishable from a
meaningful answer.

## Measurement query boundary

`ElectricalMeasurementRequest`/`ElectricalMeasurementResult`
(PRODUCT-READINESS-004) are now consumed by a real, working
`ElectricalMeasurementQuery.measure()` — see "PRODUCT-READINESS-006B" below
for the full design. (This section's own PRODUCT-READINESS-006 text above
is preserved for history: that phase established the model only.)

## Legacy V2 migration boundary

Restated: the Legacy V2 JS solver remains untouched, remains the
WebView's own real-time visual authority, and remains the ONLY thing
proven against real hardware-adjacent behavior for 3+ days of live user
debugging (PRODUCT-READINESS-002). This native solver's own correctness
is proven independently, against the SAME invariants, via the Dart-side
regression suite and the real TRX300 headlight validation (see
`electrical_solver_trx300_test.dart`) — not by delegating to or calling
the JS solver at any point.

## Persistence / Knowledge Runtime boundaries

Unchanged: `SolvedElectricalState` is never persisted. No Knowledge
Runtime file was touched in this phase.

## PRODUCT-READINESS-006B — arbitrary measurement & the general resistive network

PRODUCT-READINESS-006 closed with two explicit, disclosed gaps: no
`measure()` query existed, and current/power were only ever computed at a
single, isolated resistive dead end (never a genuine multi-branch
network). This phase closes both, additively — `terminalStates`/
`branchStates` (and every PRODUCT-READINESS-006 regression value built on
them) are UNCHANGED; everything below lives in a new, additive field.

### Architecture: one more solved answer, one authority, no second solver

`SolvedElectricalState` gains an additive, nullable field:
`network: ElectricalResistiveNetwork?`, built and attached by
`ElectricalSolver.solve()` itself (`electrical_resistive_network.dart`).
`ElectricalMeasurementQuery.measure()` (`electrical_measurement_query.dart`)
answers every `ElectricalMeasurementRequest` by reading `network` (and,
for VDC only, falling back to the existing `terminalStates` when no
network is attached — e.g. a hand-built test fixture from an earlier
phase). **No new topology or component-behavior decision is made by the
query** — every decision (which pairs conduct, what a component's
resistance is, what a source's voltage is) was already made once, when
`ElectricalResistiveNetwork.build()` ran. This is the same "queries solved
data, does not solve" relationship `TraceEngine` already has to
`SolvedElectricalState` — not a second electrical authority, and not a
second solver alongside `ElectricalSolver` (§43).

### Network solver method: nodal analysis (linear DC resistive)

`ElectricalResistiveNetwork` builds one graph of "supernodes" (terminals
merged only where a behavior reports an EXACT `0Ω` connection — an
unconditional splice junction, a connector's own same-pin passthrough;
both genuinely represent "the same electrical point," not a real
resistor) connected by real resistor edges: every wire (a real,
disclosed, small default resistance — `0.1Ω`, matching the Legacy V2
solver's own "all copper wire is essentially 0Ω" convention, overridable
per-relationship via `ElectricalWireResistanceResolver`) and every
component pair with a real, nonzero `resistanceBetween` (a closed
switch's own contact resistance, a fuse, a real resistive load). A
directional component with no linear resistance (a diode) is excluded
from this resistor network entirely (§49 — no nonlinear I-V solve) but
still counts, respecting its own real one-way direction, in a SEPARATE
structural continuity graph.

Two solves run over this same structure:

- **Operating solve** (`solveOperating`, run once at build time): every
  modeled source/reference terminal is a Dirichlet (fixed-voltage)
  boundary at its own real, declared value; free supernode voltages are
  solved via deterministic dense Gaussian elimination with partial
  pivoting, one linear system per connected component (§32/§33 — a
  component with no fixed boundary at all is genuinely floating,
  reported `unreached`, never solved as if grounded). This is what
  `operatingVoltage()` and every network-solved branch `current`/`power`
  read.
- **Resistance-between** (`resistanceBetween`, run on demand per query):
  the standard "deactivate independent sources" technique for computing
  an equivalent/Thevenin resistance (§8 — every modeled source's own
  source+reference terminal pair is shorted together before this runs,
  so `resistanceBetween` never "calculates nonsensical resistance through
  an ideal voltage source"), then a 1A test current is injected at the
  positive probe and extracted at the negative probe; the resulting
  potential difference numerically equals the resistance in Ω. Restricted
  to the connected component actually reachable from the probe (§32/§33 —
  an unrelated, fully isolated part of a large real diagram must never
  make an otherwise well-posed question singular).

### Supported network class

Series, parallel, and mixed series/parallel resistive networks, PLUS
genuinely cyclic/bridge topologies (§30.W) — nodal analysis handles all of
these uniformly; there is no growing collection of topology-specific
formulas (§11's own explicit instruction). Diode-only paths are excluded
from the linear solve (`unsupported` for resistance, structural-only for
continuity/DIODE mode). SPICE/nonlinear/AC/thermal/electromagnetic
modeling remains explicitly out of scope (§49) — untouched by this phase.

### Current/power/CURRENT-mode semantics

Every resistor edge (a wire, or a component's own resistive pair) now has
its own genuinely network-solved, signed current — a strict superset of
PRODUCT-READINESS-006's own dead-end-only capability, computed the SAME
way for the exact cases that capability already covered (giving identical
answers there) while ALSO correctly handling series chains, parallel
splits (inversely proportional to resistance — §30.J/K), and current
conservation at a junction (§30.L) that the narrower model could not
represent at all.

**Two-terminal `CURRENT`/`POWER` probe semantics (§20/§21 — documented
per that section's own explicit instruction):** answered as a
CONVENTIONAL series-inserted-ammeter lookup — the probe pair must be
EXACTLY the two ends of one identifiable network edge (`edgeBetween`).
There is deliberately no "current between two arbitrary, non-adjacent
nodes" concept (physically meaningless in a branching network — a real
ammeter is inserted in series at a specific point, not touched to two
random nodes); a probe pair that isn't a single edge's own two ends
reports `unsupported` with a note explaining why, never a fabricated or
ambiguous value.

### Resistance/continuity/diode semantics

- **Resistance**: does NOT require a source at all (§8/§30.T — a
  floating, source-less resistor network still has a real, computable
  resistance between its own two ends; only VOLTAGE needs a source).
  Genuinely disconnected terminals (no resistor path AND no structural
  path at all) report `open` — never a numeric `Infinity` (§22). A pair
  connected ONLY through a non-linear component (a diode) reports
  `unsupported`, not `open` — a real connection genuinely exists, this
  solver simply cannot assign it a linear Ω value (§49).
- **Continuity**: pure structural reachability (§18) — a wire always
  connects; a component pair connects only while its own
  `conductsFrom` is true for the CURRENT operating state (respecting an
  open switch, and a diode's own real direction — never symmetric for a
  diode).
- **Diode** (§19): a real, disclosed forward drop when the positive probe
  is on the anode; `open`/OL when reversed. A probe pair with no diode
  directly between them falls back to a plain continuity-style reading —
  a real DMM's own diode-test function reads ~0V across an intact plain
  conductor too, not a fabricated semiconductor I-V curve.

### Polarity, fault, floating/singular systems, numerical tolerance

- **VDC** (§6/§7/§23): `V(positive) - V(negative)`, real polarity —
  reversing the probes reverses the sign (§30.M).
- **Fault** (§32/§33): two different declared source voltages (or a
  source shorted directly to a reference) on the same electrical point is
  detected at build time and reported `fault`, never averaged or silently
  overwritten (§30.R).
- **Floating/singular**: a connected component with no fixed boundary at
  all is `unreached`; a genuinely singular reduction (should not occur for
  a correctly-connectivity-restricted system, but guarded regardless) is
  `unknown`, never silently zeroed (§32/§33).
- **Numerical tolerance** (§31): `kElectricalVoltageToleranceVolts`/
  `kElectricalCurrentToleranceAmps` (`1e-9`) — a computed value within
  tolerance of zero snaps to an exact `0`, avoiding floating-point noise
  (`-1e-16` reading as a spurious nonzero). Gaussian elimination uses
  partial pivoting with a `1e-12` singularity guard; matrix construction
  is fully deterministic (supernode/group ids assigned in a stable,
  sorted order — never dependent on hash-map iteration order).

### A real finding from the real diagram7.json validation

Validating headlight current against the REAL `diagram7.json` (§27/§28)
surfaced a genuine methodological finding, root-caused via a temporary
Dart diagnostic script (removed once understood — not left in the repo):
the DEFAULT `isReferenceTerminal` resolver (matches by terminal NAME —
`"-"`/`"gnd"`/`"neg"`/...) is a reasonable default for a small, isolated,
single-circuit synthetic fixture, but real `diagram7.json` is a real,
multi-circuit, 47-component vehicle harness where SEVERAL unrelated real
components (a voltage regulator/rectifier, an ignition coil, a DC
accessory jack, ...) also happen to have a pin whose name loosely matches
that pattern, none of which has a real component behavior modeled here.
Treating every one of those as an independent, unconditional 0V boundary
condition pulled the general network's own computed headlight voltage
down to an implausible ~1.7V — an artifact of a per-pin-NAME heuristic
applied at full-harness scale, not a real electrical effect, and not a
solver bug (the SAME solver, given the REAL `chassis-ground` node — a
genuine `NodeCategory.ground`/`v2Category: "ground"` node this real data
actually has — as the only reference, produces the expected ~12.4V and a
real current/power close to the naive single-load estimate). The real
TRX300 validation test
(`electrical_solver_trx300_test.dart`) uses the more precise
`isGroundNode`-based resolver for exactly this reason, documented in
place. **This is a real, disclosed limitation of the DEFAULT reference
resolver at full-harness scale** — a caller working with a real,
richly-populated diagram should supply a more precise
`ElectricalReferenceRoleResolver`, exactly as this validation does, rather
than relying on the simple name-based default.

A second, related real finding: the real headlight is a genuine 3-terminal
(`GND`/`LO`/`Hi`) dual-filament bulb — `ResistiveLoadElectricalComponentBehavior`
(a single resistance value applied to ANY pair of a component's own
terminals) is wrong for it, since it would incorrectly also declare a
resistance directly between `LO` and `Hi` (the two filaments are not
connected to each other at all). PRODUCT-READINESS-006B adds
`MultiTerminalResistiveLoadElectricalComponentBehavior` (declares a
resistance per EXPLICIT terminal pair, `unsupported` for any other pair)
for exactly this case — a real, generic, additive behavior, not a
headlight-specific hack.

### TraceEngine relationship

Unchanged: `TraceEngine` continues to consume `SolvedElectricalState`
exactly as before. This phase did not need to touch `TraceEngine` — its
own current-flow trace could be pointed at the new network-solved branch
currents by a future caller wiring `network`'s own per-edge current into
the branch states `TraceEngine` reads, but no such wiring was done here
(kept out of scope — `TraceEngine`'s own contract is unaffected either
way).

### Future DMM boundary

`ElectricalMeasurementQuery.measure()` is exactly the boundary
PRODUCT-READINESS-007 (DMM integration) needs to build on:
`ElectricalMeasurementRequest -> measure() -> ElectricalMeasurementResult`,
fully working, with no UI, no `MultimeterController`, no Android/OIP code
touched by this phase.

## What is NOT integrated yet

- `MultimeterController`/DMM widgets/Android DMM/OIP protocol are
  untouched.
- The write-side terminal-bridge fix (`_handleModuleCreated` populating
  `ports` directly) is not done — only the read-side backfill.
- Connector `_IN`/`_OUT` pin-reference normalization is test-side only,
  not yet in the production bridge.
- `TraceEngine`'s own current-flow trace is not wired to the new
  network-solved per-edge currents (see "TraceEngine relationship" above)
  — it still reads the PRODUCT-READINESS-006 dead-end-only current values
  on `branchStates`, unchanged.
- The real, full-harness `diagram7.json` validation depends on a
  caller-supplied, ground-CATEGORY-based reference resolver, not the
  library's own default (see "A real finding..." above) — no production
  code path in Diagram Studio itself supplies this yet.
- No behaviors are ported to production code for TRX300's real switch/
  lamp/motor/diode components — the real, working behaviors used in
  `electrical_solver_trx300_test.dart` are test/reference-fixture data,
  proving the ARCHITECTURE works end-to-end against real data, not a
  claim that Diagram Studio's live app now uses this solver at all (it
  does not — the JS solver still drives the live WebView UI, unchanged).
- Conducting/current-flow trace against TRX300 now genuinely works (this
  phase closes PRODUCT-READINESS-005's own disclosed gap here) — but only
  when the caller supplies the same real behaviors the tests do; there is
  no default, zero-configuration "just works for any real diagram" path
  yet.
