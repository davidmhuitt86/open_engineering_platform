# AP-DIAGRAM-V2-BRIDGE-006 — V2 Multimeter / Simulation Bridge

> Builds on the wire bridge established by AP-DIAGRAM-V2-BRIDGE-004/005
> (`DIAGRAM_STUDIO_V2_WIRE_BRIDGE_ARCHITECTURE.md`) — wire identity
> (`v2WireId` ↔ `EngineeringRelationship.id`), the readiness gate, and the
> document-lifecycle guarantees are reused unchanged, not rebuilt. This
> document does not rewrite any of that document's conclusions.

## 1. V2 Multimeter Architecture (source-verified this task)

**Files**: `js/ui/meter-panel.js` (the entire multimeter — UI + lookup),
`js/editor/wire-editor.js` (authored `R` table), `index.html` (markup),
`js/simulator/meter-engine.js`/`js/simulator/state-manager.js` (dead code
relative to the live meter — see below).

- **Opened**: not a modal — a permanently docked sidebar tab
  (`sidebarTab('meter')`), rendering a fixed SVG LCD.
- **Mode selection**: exactly 5 buttons — `VDC`, `VAC`, `CONT`, `RES`,
  `DIODE` (`ML`/`MU` maps in `meter-panel.js`). **No current/amps mode
  exists anywhere in V2** — confirmed by reading the mode maps directly.
- **Measurement point**: **the selected wire, and only the selected
  wire** (`selW`). `updateMeter()` (`meter-panel.js:75-93`) reads
  `selW.R[keyPos]` and nothing else. `leadR`/`leadB` (`{m, t}`
  module+terminal pairs, placed via `autoPlaceLeads`/manual terminal
  clicks) are **cosmetic location labels only** — `updateLeadLocDisplay()`
  writes them to a text field and highlights `.t-dot` elements; they are
  never read by `updateMeter()`'s lookup. This was the single most
  important finding of Phase 1: V2's multimeter is **not** a two-probe
  instrument in any sense that affects the reading — it is a per-wire,
  per-key-state table lookup with a two-probe *display* layered on top for
  verisimilitude.
- **Calculate vs. lookup**: **lookup, not calculation.**
  `rd = SWPACK.getReading(selW.id, keyPos) || selW.R[keyPos]`. No solver
  is invoked. `meter-engine.js`'s own doc comment discloses this
  explicitly: *"Phase 1: reading lookup ... lives in app.js ... Phase 2
  goal: MeterEngine class below becomes the authority"* — i.e. V2's own
  source says a real solver was aspirational and never wired in. Files
  named `electrical-solver.js`/`voltage-propagator.js`/
  `continuity-solver.js` exist in the tree but are dead code relative to
  the meter path.
- **Key states**: fixed 4-position array, `keyPos` (bare global,
  0-3), labels `['Key off','Key on','Cranking','Running']`
  (`wire-editor.js`'s `R` array construction). A separate
  `SimulatorStateManager` class exists with identical labels but its own
  comment says state still lives as bare `app.js` globals — not the live
  source of truth.
- **Displayed values**: raw authored strings per key-state/mode
  (`'0.00'` + unit suffix), or sentinels `'OPN'` (continuity open, red)
  and `'OL'` (resistance over-limit/open). CONT mode additionally
  reformats `'000'`/`'0.00'` → `'· · ·'` (cyan).
- **Open/short representation**: pure convention in authored data
  (`CONT:'OPN'`, `RES:'OL'`), not computed. No distinct "short circuit"
  sentinel exists — a short is whatever number the author typed.
- **Invalid measurement**: no wire selected → `updateMeter()` returns
  immediately, LCD unchanged. No lead placed → location label shows
  `'—'` (display only, does not affect the reading).
- **Live updates**: yes — `updateMeter()` fires on every `setKey`,
  `setMode`, `setLeadMode`, terminal click, and wire selection. No
  explicit "take a reading" action.
- **Persistence**: none. `js/storage/project-saver.js`'s `saveLayout()`
  does not serialize `keyPos`/`meterMode`/`leadR`/`leadB` — these are
  pure transient UI globals. (The per-wire `R` table itself *is*
  persisted, but that is authored circuit data belonging to the wire,
  not meter session state — confirmed unchanged from the wire bridge
  doc's own findings.)

## 2. OEP Simulation Architecture (source-verified this task)

- **`MeasurementEngine`** (`platform/oep_engine/lib/core/simulation/measurement/measurement_engine.dart`):
  `MeasurementResult measure(graph, faults, {required ProbePoint probeA,
  required ProbePoint probeB, required MeasurementType type, ...})`. Its
  own doc comment explicitly discloses it performs **no analog/SPICE
  computation** — continuity/resistance are fault-gated graph
  reachability queries; voltage/current/power/etc. report the graph's
  own authored `properties['expectedValue']`, gated by reachability
  (0/unreachable otherwise), each such result carrying a disclosure
  string in `notes`. This is an honest, already-documented scope
  boundary in OEP's own source — not something this task discovered as a
  problem, and not something this task papers over.
- **`SimulationEngine`** (`.../simulation/simulation_engine.dart`): the
  facade over sessions, playback, faults, verification, diagnostics, and
  `measure`.
- **`DiagramSimulationService`**
  (`platform/oep_studio/lib/diagram_studio/simulation/diagram_simulation_service.dart`):
  the Studio-facing, already-existing wrapper — `hasSession`,
  `currentSession`, `createSession(graph, ...)`,
  `Future<MeasurementResult> measure({probeA, probeB, type, mode})`. This
  is the exact "existing Controller-facing API" Phase 2 asked to look
  for — reused as-is, no new Engine-facing surface added.
  `diagramSimulationServiceProvider` (`Provider<DiagramSimulationService?>`)
  makes it reachable from any Riverpod-aware widget, including
  `LegacyV2WebViewPage`.
- **`ProbePoint({required nodeId, portId, relationshipId})**: a real,
  already-existing two-point addressing mechanism. `portId` is optional
  (references `Port.id` when available); `relationshipId` lets a probe be
  associated with a specific wire, with `nodeId` as the nearer endpoint
  for traversal.
- **Measurement types**: `voltageDc, voltageAc, resistance, continuity,
  current, diode, frequency, dutyCycle, power, groundPotential,
  capacitance, temperature` — `capacitance`/`temperature` are explicitly
  unimplemented placeholders in the engine itself (unrelated to this
  bridge, since V2 never requests either).
- **Operating/input state**: real, not a UI shell —
  `OperatingStateDefinition`/`InputStateDefinition`/`DomainProfile`
  (`.../simulation/state/`), `SimulationSession.setOperatingState`/
  `setInputState`, gating `blockedRelationshipIds` during propagation.
  Crucially, this set is **open-ended and document/author-defined**, not
  a fixed universal enum (§5 below).
- **Port/relationship precision — confirmed still exactly as the wire
  bridge documented**: `EngineeringRelationship.sourceNode`/`targetNode`
  are plain node-id strings, no port field; `EngineeringNode.ports`
  defaults to `const []` and is never populated on a bridge-created node.
  Nothing in this task changes that — this bridge measures at node-level
  precision, the same classification the wire-creation bridge already
  established and documented (§3/§14 of the wire bridge doc).
- **Sync/async**: `MeasurementEngine.measure`/`SimulationEngine.measure`
  are synchronous plain Dart calls; `DiagramSimulationService.measure`
  wraps that in a `Future` for a consistent async contract (the
  service's own doc comment discloses this is not real background
  execution).

## 3. Compatibility Matrix

| V2 capability | OEP capability | Classification |
|---|---|---|
| Measurement mode (VDC/VAC/RES/CONT/DIODE) | `MeasurementType.{voltageDc,voltageAc,resistance,continuity,diode}` | **DIRECT** (1:1 enum mapping) |
| Current measurement | `MeasurementType.current` | **NOT APPLICABLE** (V2 has no current mode to bridge) |
| Source/target probe (V2: cosmetic `leadR`/`leadB`, never read by the lookup) | `ProbePoint.nodeId`/`relationshipId` | **ADAPTER REQUIRED** — the bridged relationship's own `sourceNode`/`targetNode`, not V2's cosmetic leads (§4) |
| Key state (`keyPos`, fixed 4-position) | `OperatingStateDefinition` (open-ended, author-defined) | **OPEN** — no deterministic universal mapping exists (§5) |
| Power state | folded into key state above | **OPEN**, same reason |
| Open circuit (`'OPN'`/`'OL'`) | `MeasurementResult.reachable == false` | **ADAPTER REQUIRED** (translated per-mode, §8) |
| Short circuit | no distinct OEP/V2 sentinel either side | **NOT APPLICABLE** — V2 never had one to bridge |
| Fault state | `FaultOverlay`/`SimulationFault` (already reflected in `reachable`/measured values) | **DIRECT** (already folded into the measurement result the bridge reads) |
| Live update | V2: reactive on every UI action; OEP: request/response | **ADAPTER REQUIRED** — poll-diffed on `(selW.id, meterMode)`, §9 |
| Display units | `MeasurementResult.unit` | **DIRECT** |
| Measurement error/unavailable | thrown exception / no session | **ADAPTER REQUIRED** — translated to V2's own `'—'`/note, never a fabricated number |
| Disconnected probe | no wire selected → V2 sends no request at all | **NOT APPLICABLE** (nothing to bridge — V2's own `updateMeter()` is already a no-op here) |

## 4. Terminal / Port Fidelity

Re-confirmed: no Engine schema change was needed or made, and none was
attempted. Because V2's actual reading depends only on the **selected
wire** (§1) — not on `leadR`/`leadB` — there is no terminal-precise "point
A vs. point B" concept in V2 to bridge at all. This measurement bridges
across the wire's own two node endpoints
(`relationship.sourceNode`/`targetNode`), using `ProbePoint(nodeId: ...,
relationshipId: <the bridged relationship>)` for each side. `portId` is
left `null` — never fabricated. This reuses, at the exact same
precision, the classification the wire-creation bridge already
established and documented as **ADAPTER REQUIRED** (node-level, not
terminal-level) — not a new decision, a continuation of an existing one.

## 5. Key-State Mapping — Classified OPEN, Not Bridged

V2's `keyPos` is a fixed, built-in 4-position enum
(`['Key off','Key on','Cranking','Running']`) with no per-document
configuration. OEP's `OperatingStateDefinition` set is open-ended and
authored per document/`DomainProfile` — there is no guarantee any given
document defines states with matching count, order, or semantics, and no
existing convention pairs a V2 key-position index with a specific OEP
state id. A universal, deterministic `keyPos -> operatingStateId`
mapping therefore does not exist and was not fabricated.

**Decision**: key-state is **not bridged**. V2's key-position buttons
continue to control only V2's own cosmetic bulb-glow display (unchanged,
still purely local). A measurement reflects whatever operating/input
state is **already active** in OEP's current session — set independently
through OEP's own existing Simulation Center controls, unmodified by
this task. This is a real, disclosed limitation, not a workaround: it
does not silently reinterpret V2's key state as an OEP one, and it does
not force OEP to grow a fixed 4-state model to match V2. Per Phase 5's
own instruction ("if OEP already has a superior state model, V2 should
consume that model rather than forcing OEP to mimic V2"), the smaller,
honest scope was to bridge the measurement value at whatever state OEP
is already in, and leave state selection itself as a separate concern
the user drives from OEP's own UI.

## 6/7. Request Flow and Message Model

```
V2 (selW/meterMode change, poll-diffed)
    -> LegacyV2BridgeTransport: 'measurementRequested' { id, mode }
    -> LegacyV2StateAdapter._handleMeasurementRequested
       - resolve v2WireId -> relationshipId (existing wire-identity map, §17)
       - resolve mode -> MeasurementType
       - resolve a live DiagramSimulationService (resolver, not a captured
         reference — see the adapter's own doc comment on why)
       - if no session: apply 'unavailable' result immediately, done
       - else: ProbePoint(sourceNode, relationshipId) / ProbePoint(targetNode, relationshipId)
         -> DiagramSimulationService.measure(...) -> MeasurementResult
    -> LegacyV2StateAdapter: translate MeasurementResult -> V2 display vocabulary
    -> LegacyV2BridgeTransport.applyMeasurementResult(v2WireId, mode, displayValue, unit, note)
    -> V2: __oepBridgeApplyMeasurementResult writes the same LCD DOM
       elements updateMeter() itself writes, IF V2 hasn't since moved on
       to a different wire/mode (stale-reply guard)
```

Message shapes actually implemented (V2's own field names, not the
task prompt's placeholder shape, per Phase 7's own instruction to use
what source inspection found):

- Inbound: `measurementRequested { id: <selW.id>, mode: <one of VDC/VAC/CONT/RES/DIODE> }`
- Outbound: a direct function call (`applyMeasurementResult`), not a
  second message type — `(v2WireId, mode, displayValue, unit, note)`,
  where `displayValue`/`unit`/`note` are pre-formatted V2-vocabulary
  strings the adapter already computed. No generic event bus, no
  generalized simulation protocol — exactly the two V2-specific
  concepts this feature needs.

**No new outbound V2 apply-function beyond this one was added.** The
transport stays exactly as OEP-unaware as every other method on it —
`displayValue`/`unit`/`note` are opaque strings to the transport.

## 8. Result Semantics

`LegacyV2StateAdapter._formatMeasurementForV2` (the sole place this
translation happens):

- **Continuity / diode** (when `MeasurementResult.continuous` is set):
  `true` → V2's own `'000'` code (already rendered as `'· · ·'` by V2's
  existing CONT-mode display logic) — `false`/unreachable → V2's own
  `'OPN'`.
- **Voltage/resistance, unreachable**: V2's own `'OL'` — extending the
  convention V2's authored table already uses for resistance-mode open
  circuits to voltage modes as well, for the same "cannot complete the
  measurement" reason. This is not a value OEP invented; `reachable:
  false` is exactly what triggers it.
- **Reachable, but no `measuredValue`** (a legitimate "this type has no
  numeric reading" case per `MeasurementResult`'s own doc comment):
  displays `'—'` (em dash) with the engine's own `notes` explaining why —
  never `'0.00'`.
- **No simulation session reachable at all**: `'—'` with an explicit
  note ("No active OEP simulation session — start one from the
  Simulation Center."), not a fabricated reading and not silence.
- **Measurement throws**: caught, `'—'` with `"Measurement failed:
  <error>"` in the note — the WebView is never left uninformed or
  crashed.

OEP is always authoritative: V2's own locally-computed value (from its
own static table) is what the user sees first, because `updateMeter()`
already ran synchronously before the request even left the WebView —
this bridge's answer overwrites it moments later once the async round
trip completes. This latency (bounded by the same 400ms poll interval
every other event in this bridge uses) is expected and disclosed, not a
bug — V2's static-table answer is never the *last* word once a session
is active.

## 9. Live Measurement / Performance

Poll-diffed on the combined key `selW.id + '|' + meterMode`, inside the
**existing** 400ms poll loop (`_kBridgeScript`'s `setInterval`) — no new
timer, no new WebView subscription, no per-frame Flutter rebuild, no
Riverpod rebuild pressure. `simulationServiceResolver` is a plain
closure call, not a `ref.watch` — the adapter does not rebuild on
simulation state changes; it only reads the current service when a
request actually needs to be answered. `LegacyV2WebViewPage` gains no
new `setState` calls for this feature — the outbound
`applyMeasurementResult` writes directly into V2's own DOM via
`executeScript`, bypassing Flutter's widget tree entirely, exactly like
every other authoritative-sync-back method already in this transport.

## 10. Probe/Lead Interaction

V2 always selects by module **terminal** (`{m, t}`) for lead placement,
never a wire segment or coordinate — but as established in §1/§4, these
leads do not feed the measurement at all. No terminal identity was
invented; `leadR`/`leadB` are not read, transmitted, or represented in
any bridge message.

## 11. Authority

Enforced exactly as required: a `reachable: false` result is never
displayed as a plausible number, and a `MeasurementResult` from OEP is
what's shown, not V2's static table, whenever a session exists (§8).

## 12. Error Handling

- Unknown/unbridged `v2WireId`: no-op, no crash (same pattern every
  other handler in this adapter already uses).
- Unmapped mode: none exist — V2 only ever sends one of its 5 known mode
  codes; `_measurementTypeForV2Mode` returning `null` is a defensive
  no-op should that ever change.
- No live session: explicit `'unavailable'`-shaped result (§8), not a
  crash, not silence.
- `measure()` throwing: caught, explicit error result (§8).
- Stale document / WebView reload / document switching: see §13.

## 13. Document Lifecycle

No new document-identity mechanism was created. `_handleMeasurementRequested`
is gated by the existing `_ready` flag exactly like every other handler,
and resolves `v2WireId` through the same `_v2ToOepRelationshipId` map
that `initializeFromDocument`/`reinitializeForDocument` already own — a
request cannot resolve against a stale document's relationship id
because that map is fully rebuilt (not merged) on every
reinitialization, the same guarantee the wire bridge already documented
and tested. `simulationServiceResolver` reads the **current** session at
request time (not a captured one), so a document switch that also
tears down/rebuilds the simulation session is reflected automatically,
without any additional plumbing.

## 14. Persistence

V2's meter/probe state (`keyPos`, `meterMode`, `leadR`/`leadB`) is
confirmed transient UI state only (§1) — **not persisted**, and this
task adds no persistence for it either. No new metadata key was added
anywhere. The measurement result itself is not a durable engineering
fact (it is a point-in-time read of already-authored/simulated state) —
nothing to persist, no second source of truth created.

## 15. Tests

`test/diagram_studio/webview/legacy_v2_state_adapter_test.dart` (extended,
at the end of the existing single `testWidgets` body, same
LIFO-undo-safety convention prior tasks in this file established):

1. Measurement request decoding/dispatch — `_FakeChannel.simulateMeasurementRequested`.
2. Mode mapping — `RES`/`CONT` exercised end-to-end.
3. Measurement-point mapping — via the real bridged relationship's node endpoints (no fake calculation).
4. No-session path — explicit `'unavailable'`-shaped result, asserted verbatim, not a crash.
5. Unmapped/unbridged wire id — asserted no-op (no call to `applyMeasurementResult`).
6. **A real `SimulationEngine`/`DiagramSimulationService`** (not a fake) wired through a second adapter/channel, session created from the real bootstrapped graph, exercising the actual `MeasurementEngine.measure` path end-to-end for a continuity request — asserts the result is one of V2's own two sentinel codes (`'000'`/`'OPN'`), never a fabricated number, and that the no-session message is not present.
7. Existing wire bridge tests (creation/selection/deletion/property-edit/undo) — all still pass, unmodified in behavior.
8. Existing module bridge tests — all still pass.

Broader suites run this task: `flutter test test/diagram_studio/
test/instruments/ test/simulation/` (187 passed) and, at the Engine
level, `test/simulation/measurement_engine_test.dart`/
`simulation_engine_test.dart` in `oep_engine` (28 passed, unmodified —
this task made zero Engine changes).

## 16. Performance

Verified: no new `setInterval`/timer (reuses the existing 400ms poll),
no new WebView message subscription (reuses the existing
`webMessage.listen`), no new Riverpod provider watched reactively (the
resolver is a plain `ref.read`-style closure invoked only per request,
not a `ref.watch` that would rebuild `LegacyV2WebViewPage`), and the
authoritative write path bypasses the Flutter widget tree entirely
(direct `executeScript` into V2's own DOM, matching every prior
authoritative-sync-back method in this transport).

## 17. Remaining Gaps

- **Key-state bridging is OPEN** (§5) — the single largest remaining gap.
  A future task could close it only if a document-specific,
  author-declared mapping from V2 key positions to OEP operating-state
  ids were introduced — that is new authored data, not something this
  bridge can infer.
- Terminal/port-level measurement precision remains **ADAPTER REQUIRED
  at node level**, same as the wire bridge — unaddressed for the same
  reason (§4), not re-litigated here.
- Short-circuit has no distinct representation on either side — not a
  gap this task introduced (V2 never had one).
- `capacitance`/`temperature` measurement types are unimplemented in the
  Engine itself, unrelated to V2 (which never requests them).

## 18. Exact Classification Summary

| Item | Classification |
|---|---|
| Measurement mode mapping (VDC/VAC/RES/CONT/DIODE) | **DIRECT** |
| Current measurement | **NOT APPLICABLE** |
| Probe/measurement-point mapping (node-level, via bridged relationship) | **ADAPTER REQUIRED** |
| Terminal/port-precise measurement | **ADAPTER REQUIRED at node level** (full port precision remains the same **ENGINE EXTENSION** gap the wire bridge already documented — not reopened, not solved here) |
| Key-state mapping | **OPEN** (not bridged, documented reason) |
| Open circuit / unreachable result | **ADAPTER REQUIRED** |
| Short circuit | **NOT APPLICABLE** |
| Live update mechanism | **ADAPTER REQUIRED** (poll-diffed, existing loop) |
| Display units | **DIRECT** |
| Error/unavailable handling | **ADAPTER REQUIRED** |
| Persistence | **NOT APPLICABLE** (V2 state is transient; nothing to persist) |

No STOP CONDITION was triggered. The bridge does not duplicate V2's
static lookup table as an authority (it reaches the real
`MeasurementEngine`), does not require modifying V2 source (the outbound
apply function only ever *adds* a DOM write after V2's own synchronous
local write, the same pattern Save-interception already established for
runtime function reassignment), does not require an Engine model change,
and does not create a second simulation authority.
