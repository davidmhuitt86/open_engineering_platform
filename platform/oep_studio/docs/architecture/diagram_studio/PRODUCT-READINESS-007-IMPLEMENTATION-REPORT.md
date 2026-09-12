# PRODUCT-READINESS-007

## Status

**COMPLETE WITH BOUNDED GAPS**

Every architectural rule in §1/§28 is satisfied: the DMM/instrument stack now runs through `ElectricalSolver` → `SolvedElectricalState` → `ElectricalMeasurementQuery` → `ElectricalMeasurementResult` as the sole electrical authority, with no duplicate solver introduced anywhere (Flutter widgets, Android/Flutter DMM app, or the V2 WebView bridge). Two items are explicitly **not** fully complete, both disclosed in detail in §18 rather than claimed: (a) the real Windows **WebView2 end-to-end** test (§24) was not built, because Diagram Studio has no rendered DMM UI to drive one through yet — a pre-existing gap this phase did not introduce and was not in scope to fix by building a new UI; (b) **Android reconnect/diode/OL-fault-unsupported display** is proven at the shared-package level (`oep_instruments_runtime`, which the actual `oep_dmm` Flutter-for-Android app consumes verbatim) rather than via an on-device instrumented test, since the "Android DMM" in this repository is a Flutter app, not a native Kotlin one (see §3).

## 1. Scope

Wire the existing, already-validated (PRODUCT-READINESS-006/006B) native Electrical Solution Engine into every consumer that currently produces or displays a DMM measurement: `MultimeterController`, the OIP Host bridge (`OipHostBridgeService`), the OIP wire protocol and its Wi-Fi transport, the Digital Multimeter instrument plugin/panel (shared by every OIP client, including the Android app), and the Legacy V2 WebView measurement bridge. No new solver. No electrical math outside `oep_engine`.

## 2. Baseline

Commit `f862210cb66407688cfe52877b928de3a24d2d72` ("diagramstudiov3"), as specified. Note: `HEAD` has since advanced one commit further, to `3c62b2c` ("Add automated regression tests for solver invariants and TRX300 fixture") — this committed the PRODUCT-READINESS-006B session's own previously-untracked JS test files; it was not made by this session and contains no code this report describes. All PRODUCT-READINESS-007 work in this report remains uncommitted in the working tree. Pre-existing PRODUCT-READINESS-006B baseline: oep_engine 500/500 (0 analysis issues), oep_studio 1041/1041 (8 skipped, 9 pre-existing unrelated analysis issues), Legacy V2 JS 27/27.

## 3. Existing Architecture Audited

Audited via four parallel research passes (one retried after a mid-session rate-limit) before any code was written:

**A. Current DMM request path (Diagram Studio)**: `MultimeterController` (`platform/oep_studio/lib/diagram_studio/instruments/multimeter/multimeter_controller.dart`) called `DiagramSimulationService.measure()` → `SimulationEngine.measure()`/`MeasurementEngine` (the OLD reachability-only engine) exclusively. It had zero imports from `core/simulation/electrical/` anywhere. **No DMM UI is actually mounted in the running Diagram Studio app** — `DiagramStudioPage`, the file that was supposed to construct `MultimeterController`/`InstrumentRegistry`/a concrete `EngineeringInstrument`, does not exist in the tree (referenced only in stale doc comments); `InstrumentsPerspectiveDock` is always constructed with `instruments: []`. This is a real, pre-existing gap this phase did not create and was not in scope to fix by building a new page (§32's "do not make unrelated UI redesigns").

**B. Current V2 bridge path**: `LegacyV2StateAdapter._handleMeasurementRequested` → `LegacyV2Channel.queryLiveMeasurement` → the embedded Legacy V2 JS (`LiveSim.readWireMeasurement`) → `V2LiveMeasurementResult` → `adapter.onLiveMeasurement` callback. That callback was never set anywhere in `lib/` — a fully working, tested plumbing path with no consumer wired to it yet (its own doc comment calls this "the seam a DMM host page wires into `MultimeterController` once one exists — deliberately deferred").

**C. Current OIP request path**: `OipHostBridgeService._handleMeasurementRequest` called `SimulationEngine.measure()` directly (the actual live authority for the real, running Android/Flutter OIP client) — the primary migration target named explicitly in the task. No request/response correlation existed beyond a shared `sessionId`; every failure path (no graph, no engine, unknown type, missing probe) was a **silent drop**, never an error response. The bridge was hardcoded to a single "primary" diagram instance (`engineeringProjectServiceProvider`) even though the underlying state (`engineeringProjectServiceFamily`) is already multi-instance-capable.

**D. Current Android request path**: **the "Android DMM app" (`platform/oep_instruments/apps/android/`) is a Flutter app, not native Kotlin** — its only Kotlin file is a 3-line `FlutterActivity` wrapper. All DMM logic (measurement model, mode selector, formatting, OIP client, transport) lives in the shared `oep_instruments_runtime` Dart package this Flutter app depends on. `DigitalMultimeterPlugin.requestMeasurement()`/`receiveMeasurement()` had no request/response correlation (`OipMessage.messageId` was generated but never echoed back); Diode mode had a button that sent a real request, but no `measurement.diode` capability was declared and no diode-aware display formatting existed; `WifiOipTransport` detected a dropped socket (`onDone`/`onError` → `disconnected`) but never attempted to reconnect — a `reconnect()` method existed but nothing ever called it.

**E. Current result path**: `Measurement` (`oep_instruments_runtime`) carried only `value: Object?` + the pre-existing, lifecycle-only `MeasurementState` enum (`requested/pending/.../unavailable/invalid/...`) — no concept of OL/overload/fault/unsupported/unreached as distinct from "unavailable," and no range-value representation (a V2 AC range like `"13-16"` had no structured home at all, though nothing in the current code actually mis-parsed one with `parseFloat` — the gap was that ranges simply weren't representable yet).

**F/G. `SimulationEngine.measure()`/`DiagramSimulationService.measure()` call sites**: exactly two non-test live call sites existed — `MultimeterController.measure()` (A above) and `OipHostBridgeService._handleMeasurementRequest` (C above). Both are addressed below (§17).

**H. Nullable-value-only result representations**: `Measurement.value: Object?` with only the coarse `MeasurementState`/`MeasurementQuality` pair to distinguish "no value" cases; the OIP wire payload itself (`{value, unit, quality, state}`) had the same limitation.

**I/J. Missing correlation / missing diagram identity**: confirmed in C/D above — `OipMessage` had no `replyTo`; `EngineeringSession.diagramId` existed as a field but was never populated or read anywhere.

## 4. DMM Architecture Implemented

```
DiagramDocument / live V2-synced graph
        |
        v
ElectricalSolver.solve(graph, operatingContext, generationCounter)
        |
        v
SolvedElectricalState  (includes the additive `network` field, PRODUCT-READINESS-006B)
        |
        v
ElectricalMeasurementQuery.measure(solvedState, ElectricalMeasurementRequest)
        |
        v
ElectricalMeasurementResult
        |
        +-----------------------------+
        |                             |
        v                             v
MultimeterController            OipHostBridgeService
(Diagram Studio, additive          (OIP wire protocol)
 `electricalResult` field)               |
                                          v
                                  DigitalMultimeterPlugin/Panel
                                  (shared by every OIP client,
                                   including the Android app)
```

No component below `ElectricalMeasurementQuery` computes a volt, ohm, or amp. `MultimeterController` and `OipHostBridgeService` each construct an `ElectricalSolver`/generation counter and call `solve()` + `measure()` — they orchestrate *when* to ask, never *what the answer is*.

## 5. MultimeterController Integration

Extended **additively** (`platform/oep_studio/lib/diagram_studio/instruments/multimeter/multimeter_controller.dart`): a new `electricalResult: ElectricalMeasurementResult?` field and `measureElectrical({graph, solver, generationCounter, operatingContext})` method, sharing the SAME `probeA`/`probeB`/`selectedType` selection state the existing `measure()`/`latestResult` path already uses. The existing `measure()`/`latestResult`/history/bookmarks/`relatedFindings(VerificationReport)` machinery is **completely unchanged** — it is a genuinely distinct capability (reachability-based path-highlighting/verification-report cross-referencing, built on `DiagramSimulationService`), locked in by 10 pre-existing tests this phase did not touch. A real electrical DMM reading now comes *only* from `measureElectrical`/`electricalResult`.

- `setProbeA`/`setProbeB`/`setType` now clear `electricalResult` and bump an internal monotonic `_electricalRequestSeq` (§6.9/§7): a stale-in-flight `measureElectrical` call (the underlying solve is synchronous today, but the guard is real and exercised) is discarded if the selection changed before it completed.
- No solver-specific logic (`V=IR`, equivalent resistance, diode direction, ...) exists in this file — confirmed by `dart analyze` finding no such computation and by the new tests asserting the returned `ElectricalReading` is exactly what `ElectricalMeasurementQuery` produced.

Tests: `platform/oep_studio/test/instruments/multimeter_controller_test.dart` — 3 new tests (real valid reading, honest UNREACHED on a genuinely floating pair, clear-on-probe-change), all 10 pre-existing tests unchanged and passing.

## 6. V2 Integration

`platform/oep_studio/lib/diagram_studio/webview/v2_measurement_bridge.dart` (new file): the §9 chain `v2WireId → V2 wire endpoints → ProbePoint → ElectricalMeasurementRequest`, implemented as pure functions (`normalizeV2PortRef`, `v2WireEndpointProbePoint`, `v2WireMeasurementTerminals`) plus one integration entry point, `measureV2WireViaNativeEngine(adapter, v2WireId, mode, {solver, generationCounter, operatingContext})`, which solves the LIVE, already-adapter-synced graph (`adapter.controller.engine.editing.session.graph` — no separate "get current graph" call needed) and answers through `ElectricalMeasurementQuery`.

**The existing LiveSim-backed path is completely untouched** (§8/§9's own explicit instruction): `LegacyV2Channel.queryLiveMeasurement`/`applyMeasurementResult`, `V2MeasurementRequestedMessage`, and `legacy_v2_live_measurement_bridge_test.dart`'s own 9 tests are unmodified and still pass. `v2_measurement_bridge.dart` is a **second, additive** entry point for a caller that wants the native-Engine-backed answer instead — not a replacement, and not wired into `onLiveMeasurement` (which would have silently changed already-tested behavior).

**Disclosed limitation** (documented in the file's own doc comment): V2's live switch/key state (`selK`) is not bridged into Dart at all (confirmed: `LegacyV2StateAdapter`'s own doc comment says "there is nothing to additionally bridge" for the *existing* LiveSim path, which reads switch state inside the WebView directly) — this NEW path has no equivalent access and solves against `ElectricalOperatingContext.none` unless a caller supplies a real one. A switch-gated circuit's OFF state cannot yet be distinguished from ON through this specific path. The existing LiveSim path remains the one that correctly reflects live V2 switch state today.

Tests: `platform/oep_studio/test/diagram_studio/webview/v2_measurement_bridge_test.dart` (new, 5 tests) — pure-function unit tests plus one full-integration test that creates real V2 module/wire-created events through a real `LegacyV2StateAdapter` + real `DiagramStudioController`, then solves the resulting live graph through the real native Engine (9V source → 0.1Ω wire → real ground; asserted exactly).

## 7. OIP Changes

`platform/oep_studio/lib/diagram_studio/instruments_host/oip_host_bridge_service.dart` — rewritten:

- `SimulationEngine`/session-map dependency **removed entirely**. Constructor now takes `electricalSolver: ElectricalSolver` (default: generic/structural) and `operatingContextProvider: ElectricalOperatingContext Function(String? diagramInstanceId)` (default: `.none`, disclosed limitation — real UI switch state is not yet bridged into this service either, matching §6).
- `start()` gained `graphProviderByInstance: EngineeringGraph? Function(String diagramInstanceId)?`, consulted when a request payload carries `diagramInstanceId`; falls back to the existing `graph`/`graphProvider` (the "primary" diagram) when it does not — full backward compatibility for every existing caller.
- Structured protocol errors (§12): `missingDiagramInstance`, `unknownMeasurementType`, `invalidTarget` — each a real `OipMessage` (`category: error`, payload = `OipError.toJson()`, `replyTo` set) instead of a silent drop.
- Response correlation: every `measurementResult`/error response now sets `replyTo` to the request's own `messageId`.
- Response payload gained `electricalState` (the Engine's own `ElectricalReadingState.name`), `note`, and `solutionGeneration` (§7: "a result should be traceable to... solution generation"), alongside the pre-existing `value`/`unit`/`quality`/`state` fields (kept for backward compatibility with any client not yet reading `electricalState`).
- Optional additive request payload fields: `probeRedPortId`/`probeBlackPortId` (terminal-precise addressing — see §18 for the disclosed gap this closes only half of) and `diagramInstanceId`.

`platform/oep_studio/lib/diagram_studio/instruments_host/instrument_bridge_provider.dart` — `engineProvider` removed (no longer needed); added `instrumentBridgeGraphForInstance(ref, diagramInstanceId)`. `diagram_studio_settings_page.dart`'s `_start()` now passes both `graphProvider` and `graphProviderByInstance`.

`platform/oep_instruments/platform/oep_instruments/lib/protocol/oip_message.dart` — additive `replyTo: String?` field, included in `toJson()` only when non-null, defaults to `null` on `fromJson()` for any message that predates this field.

Tests: `platform/oep_studio/test/instruments_host/oip_host_bridge_service_test.dart` — fully rewritten (the 2 pre-existing tests asserted against the now-removed `SimulationEngine` dependency and were migrated, not preserved-as-stale) to 9 tests, all real TCP loopback, real native Engine solves, real hand-verified numbers (a `battery --0.1Ω-- lamp --0.1Ω-- chassisGround` fixture with no resistive `lamp` behavior: VDC at `lamp` = 6.3V exactly, a voltage divider between two equal wire resistances; RES(battery, chassisGround) = 0.2Ω exactly; CURRENT(battery, lamp) = 63A exactly — all confirmed by the actual test run, not asserted from hand-derivation alone). Covers: real VDC/RES/CURRENT/CONT, real UNSUPPORTED for VAC, both new error paths, both new diagram-instance-routing paths (unknown instance → error; known instance → answered against *that* instance's own graph, proven distinct from the "primary" graph). `platform/oep_instruments/platform/oep_instruments/test/protocol/oip_message_test.dart` (new) — `replyTo` round-trip + backward-compatibility.

## 8. Android Changes

Since the "Android DMM" is the shared `oep_instruments_runtime` package (§3.D), all changes live there and apply identically to every OIP client built on it, including `platform/oep_instruments/apps/android/` (built and verified — see §15):

- `lib/measurement/measurement_range.dart` (new): `MeasurementRange(low, high)` — a real structured value `Measurement.value` may hold instead of a `num`, so a V2 AC range never needs string-parsing (§13's own explicit prohibition on `parseFloat("13-16")`).
- `lib/measurement/measurement.dart`: additive `electricalState: String?` field (the Engine's `ElectricalReadingState` name, carried as a plain string — this package has, and must keep, zero dependency on `oep_engine`, per its own "completely independent from engineering computation" pubspec doc comment).
- `lib/instruments/digital_multimeter/digital_multimeter_plugin.dart`: declared `measurement.diode` capability; `requestMeasurement()` now records the sent `messageId` as the one outstanding request; `receiveMeasurement()` rejects a response whose `replyTo` names a *different*, superseded request (§7's own "request #41/#42" example, implemented literally) and parses `electricalState`/`valueRange` from the payload.
- `lib/instruments/digital_multimeter/digital_multimeter_panel.dart`: `_formatValue` now branches on `electricalState` first — `open`/`overload` → `"OL"`, `fault` → `"FAULT"`, `unsupported` → `"UNSUPP"`, `unknown`/`unreached` → the pre-existing `"----"` — before falling through to numeric/BEEP-OPEN formatting; a `MeasurementRange` renders as `"low-high"` built from the real numeric bounds, never from a pre-rendered string. Problem states render in red.
- `lib/transports/wifi_oip_transport.dart`: automatic, bounded-backoff (1s→2s→4s→8s→16s, capped) reconnect on an unexpected socket drop, guarded against ever running more than one reconnect loop at once and against reconnecting after a deliberate `disconnect()`. New `stateChanges` stream (uses the pre-existing, previously-unused `TransportConnectionState.reconnecting` value).

Tests (all in `oep_instruments_runtime`, package-level — see §14 for why no on-device instrumented test was added): `wifi_oip_transport_test.dart` (+2, real TCP loopback: server-initiated drop → automatic reconnect proven via a *second* real TCP connection accepted by the same still-listening server; manual disconnect proven to *never* auto-reconnect), `digital_multimeter_plugin_test.dart` (+3: diode capability, stale-response rejection via `replyTo`, `electricalState`/`MeasurementRange` parsing; +1 widget test rendering all four new display states plus a range).

## 9. Diagram Instance Routing

Reused the existing, already-approved multi-instance architecture (`AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001`) rather than inventing a new one: `engineeringProjectServiceFamily(instanceId)`, keyed by `WorkspaceTab.id`. `OipHostBridgeService.start(graphProviderByInstance:)` is the new routing seam; `instrumentBridgeGraphForInstance(ref, diagramInstanceId)` resolves it. A request naming an unknown/unopened instance id is a real protocol error (`missingDiagramInstance`), never silently answered against the wrong diagram (proven by `oip_host_bridge_service_test.dart`'s two diagram-instance-routing tests — one confirming the error path, one confirming a *known* instance id is answered against *that instance's own graph*, numerically distinct from the "primary" graph in the same test run). No global singleton measurement state was introduced; the "primary" fallback for a request with no `diagramInstanceId` is the same backward-compatible default `OipHostBridgeService` already had.

## 10. Structured Measurement States

`ElectricalReadingState` (`valid/unknown/unreached/open/overload/fault/unsupported`) now flows unmodified end to end: `ElectricalMeasurementResult.reading.state` → OIP wire payload `electricalState` (string) → `Measurement.electricalState` → `DigitalMultimeterPanel`'s own distinct `OL`/`FAULT`/`UNSUPP`/`----` labels. A legitimate `0` (e.g. chassis-ground's own real 0V, or the TRX300 `matched-potential` zero-current case from PRODUCT-READINESS-006B) is `state: 'valid', value: 0` throughout — never collapsed into the same representation as `open`/`unreached`, proven by dedicated tests at every layer (Engine: existing PRODUCT-READINESS-006B fixture I; OIP: this phase's `CONT reports real continuity...` test; Android display: the widget test's own OL/FAULT/UNSUPP assertions alongside the pre-existing `'----'`-for-null case).

## 11. Stale Result Protection

Three independent, real mechanisms, none using a wall-clock timestamp for ordering:

1. **Engine generation** (unchanged, PRODUCT-READINESS-004/006): `ElectricalSolutionGenerationCounter`, one per diagram instance in `OipHostBridgeService` (`Map<String, ElectricalSolutionGenerationCounter>` keyed by resolved instance id), attached to every `ElectricalMeasurementResult.generation`.
2. **OIP-level request/response correlation** (new): `OipMessage.replyTo`. `DigitalMultimeterPlugin` tracks `_pendingRequestId` and discards a response whose `replyTo` names a superseded request — proven with a real two-in-flight-requests scenario over a real TCP loopback connection (§8).
3. **`MultimeterController`-level local sequencing** (new, §5): `_electricalRequestSeq`, guarding `measureElectrical()` against a probe/mode change that superseded it.

## 12. Real TRX300 Validation

Extended `platform/oep_engine/test/simulation/electrical/electrical_solver_trx300_test.dart` (real `diagram7.json`, real production `DiagramDocument`-equivalent loading, real `ElectricalMeasurementQuery`) with a new `§23` group — every test records probe(s)/mode/expected-vs-actual state/generation in its own assertions and doc comment:

| Item | Probe(s) | Mode | Result |
|---|---|---|---|
| B. Chassis ground reference | `chassis-ground:1` ↔ itself | VDC | valid, exactly 0V; `result.generation == state.generation` (traceability proven) |
| I. Resistance across a passive path | `headlight.LO` ↔ `headlight.GND` | RES | valid, ≈120Ω (the real, declared filament resistance), true regardless of ignition position (resistance needs no source) |
| K. Open-circuit behavior | `battery.+` ↔ `headlight.LO`, ignition OFF | RES then CONT | both `open` |
| L. Fault/unsupported | `battery.+` ↔ `chassis-ground:1` | VAC | `unsupported` (the native Engine has no AC model at all — §49's own scope limit; a genuinely honest answer, not a defect) |
| J. Diode | — | DIODE | **not performed** — no `DiodeElectricalBehavior` is modeled for any real TRX300 component in this codebase (the real "regulator-rectifier" node exists in the data but has no diode behavior assigned); disclosed rather than fabricated. Diode semantics remain validated only via PRODUCT-READINESS-006B's synthetic fixtures O/P. |

Battery voltage, headlight low/high beam, key OFF/ON, lights OFF, and continuity across closed paths were already validated by PRODUCT-READINESS-006B's own TRX300 tests (unchanged, still passing) and are not re-litigated here. Real headlight CURRENT/POWER (also PRODUCT-READINESS-006B) remain validated with their own previously-disclosed caveat (a caller-supplied ground-category reference resolver, not the library default, is required for correct results at real multi-circuit-harness scale).

## 13. WebView2 E2E Validation

**Not performed — disclosed bounded gap, not a blocker for the rest of the phase.** Root cause: Diagram Studio has no DMM UI mounted in the running app at all (§3.A) — `DigitalMultimeterPanel` exists only in the shared `oep_instruments_runtime` package and is never instantiated anywhere in `oep_studio/lib`; `DiagramStudioPage`, the file that was meant to wire `MultimeterController`/`InstrumentRegistry`/a concrete `EngineeringInstrument` together, does not exist in the tree. A genuine WebView2 E2E test needs a real, running, on-screen chain ending in "displayed result" (§24's own wording) — there is currently nothing on screen to display it in. Building that UI was judged out of scope: §32 explicitly says "do not make unrelated UI redesigns... keep the implementation narrowly scoped," and wiring a first DMM page into Diagram Studio is a UI feature, not an instrument-measurement-architecture change. No `integration_test` package or harness exists anywhere in this repository either (confirmed by search), so there was no existing scaffold to extend.

What **was** proven, real and non-mocked, covering every other link in the chain §24 describes:
- WebView leg: `v2_measurement_bridge_test.dart`'s integration test (real `DiagramStudioController`, real `LegacyV2StateAdapter`, real module/wire-created events, real native-Engine solve).
- OIP/Android leg: `oip_host_bridge_service_test.dart` (real TCP socket, real `WifiOipTransport`, real native-Engine solve, real correlated response) and `wifi_oip_transport_test.dart`'s new reconnect tests (real TCP loopback, a real second connection after a real server-side drop).
- Stale-result protection specifically (§24's own example — request A, then B, A arrives after B, A must not win): proven at the OIP layer in `digital_multimeter_plugin_test.dart`'s new stale-response test, using two real, distinct in-flight requests over a real transport.

This is not a substitute for §24 and is not represented as one — no mocked WebView2 control was built or claimed as the E2E proof.

## 14. Tests

- **Unit/integration (all real, no mocks, run via `flutter test`)**: see §5–§8, §12 above for the new ones. Every new test hits real TCP sockets, a real native `ElectricalSolver` solve, or a real `DiagramStudioController`/`LegacyV2StateAdapter` — none stub out the Engine.
- **Real diagram tests**: §12 (real `diagram7.json`).
- **Real WebView2 tests**: not performed — §13.
- Exact counts and commands: §15.

## 15. Builds

Exact commands executed this session, in order, with results:

```
# oep_engine
cd platform/oep_engine
dart analyze                     ->  No issues found!
flutter test                     ->  505/505 passed
flutter build windows --debug    ->  (not applicable — oep_engine is a library package)

# oep_instruments_runtime
cd platform/oep_instruments/platform/oep_instruments
flutter analyze lib/ test/       ->  No issues found!
flutter test                     ->  49/49 passed

# oep_studio
cd platform/oep_studio
dart analyze                     ->  9 pre-existing, unrelated issues (unchanged from baseline)
flutter test                     ->  1055 passed, 8 skipped, 1 failed on the full run
flutter test test/diagram_studio/bridge/diagram_repository_commit_action_test.dart
                                  ->  13/13 passed in isolation (confirms the 1 full-run
                                      failure is a pre-existing file-I/O flake in an
                                      UNTOUCHED test file, not a regression from this phase)
flutter build windows --debug    ->  Built build\windows\x64\runner\Debug\oep_studio.exe
flutter build apk --debug        ->  Built build\app\outputs\flutter-apk\app-debug.apk

# oep_instruments/apps/android (the actual "oep_dmm" Android client)
cd platform/oep_instruments/apps/android
flutter build apk --debug        ->  Built build\app\outputs\flutter-apk\app-debug.apk

# Legacy V2 JS
cd reference/legacy_wiring_sim_v2/eke-wiring-sim
node --test                      ->  27/27 passed (unmodified)
```

## 16. Static Analysis

- oep_engine: 0 issues (unchanged — 0 both before and after).
- oep_instruments_runtime: 0 issues (previously not tracked as a baseline in this report chain; 0 found on every run this session).
- oep_studio: 9 issues, byte-for-byte the same 9 pre-existing, unrelated issues from the PRODUCT-READINESS-006B baseline (an unused import in an untouched test file, 3 missing-curly-braces infos in untouched files, 2 doc-comment-HTML infos and 2 `avoid_print` infos in an untouched tool script). **Zero new issues introduced.**

## 17. Old Measurement Paths Removed/Migrated

- `OipHostBridgeService._handleMeasurementRequest`: **migrated** — no longer calls `SimulationEngine.measure()`; the `SimulationEngine`/session-map dependency was removed from the class entirely (§7).
- `MultimeterController.measure()`/`latestResult`: **not migrated, deliberately kept** — still calls `DiagramSimulationService.measure()`/`SimulationEngine.measure()`, because it serves a genuinely different, still-valid capability (reachability-based path-highlighting + `VerificationReport` cross-referencing for the "Historical/Comparison" DMM modes), locked in by its own 10 pre-existing tests. The new `measureElectrical()` method is the ONLY electrical-DMM-value path on this controller now; `measure()`/`latestResult` are not represented, in this report or in the code's own doc comments, as an electrical authority.
- No other live call site of `SimulationEngine.measure()`/`DiagramSimulationService.measure()` exists (confirmed by the audit, §3.F/G) — `MeasurementEngine`/`SimulationEngine` itself is untouched and remains valid for its own, non-electrical reachability/verification purpose.

## 18. Remaining Limitations

1. **No rendered DMM UI in Diagram Studio** — pre-existing, not introduced or fixed by this phase (§3.A/§13). `MultimeterController.measureElectrical()` is real and tested but has no on-screen consumer in the actual running app yet.
2. **WebView2 E2E not performed** — §13, root-caused to limitation #1.
3. **Real UI switch/key state is not bridged into either new native-Engine-backed path** (`OipHostBridgeService`'s `operatingContextProvider`, `v2_measurement_bridge.dart`'s `operatingContext`) — both default to `ElectricalOperatingContext.none`. A real switch-gated reading (e.g. "is the ignition on") is only correctly reflected by the pre-existing LiveSim-backed V2 path today.
4. **Terminal precision over OIP is half-closed**: the wire protocol now accepts optional `probeRedPortId`/`probeBlackPortId` (§7), but `DigitalMultimeterPlugin`'s own `Probe` model still only carries a bare `currentTargetId` (node id) — no UI exists yet to let a user pick a specific pin on a multi-terminal component through the Android/Flutter DMM app. Every OIP-driven measurement today addresses a component by node id only.
5. **VAC is honestly UNSUPPORTED end-to-end** — not a defect; the native Engine is DC-resistive-only by design (PRODUCT-READINESS-006B §49). The V2 WebView's own JS `LiveSim` path remains the only source of a real AC value, unchanged, reachable only through the pre-existing LiveSim-backed bridge.
6. **CURRENT/POWER two-terminal semantics remain narrow** (PRODUCT-READINESS-006B's own disclosed decision, unchanged by this phase): only a probe pair that is exactly one identifiable network edge's own two ends returns a value; anything else is `unsupported`, never fabricated.
7. **No on-device Android instrumented test** — the "Android DMM" is a Flutter app built on `oep_instruments_runtime`; every behavioral change (reconnect, diode, structured states) is proven at the package level with real TCP sockets and a real Flutter widget tree, and the actual `platform/oep_instruments/apps/android` app was built successfully (§15) with these changes, but no `adb`-driven on-device test was run in this session.
8. **1 pre-existing, unrelated file-I/O test flake** observed in the full-suite `oep_studio` run (`diagram_repository_commit_action_test.dart`), confirmed to pass 13/13 in isolation and untouched by this phase (§15).

## 19. Architectural Decisions

**ADR: DMM / Instrument Measurement Flow.** Decision: the authority chain is `ElectricalSolver → SolvedElectricalState → ElectricalMeasurementQuery → ElectricalMeasurementResult`, consumed by exactly two orchestration points (`MultimeterController`, `OipHostBridgeService`) and one adapter (`v2_measurement_bridge.dart`), none of which perform electrical computation. Rejected alternative: restoring/extending `SimulationEngine.measure()` as the live path — rejected per explicit task instruction and because it cannot represent OL/fault/unsupported/resistance-network semantics at all (it is reachability-only). Rejected alternative: giving `MultimeterController` two competing "measure" methods that both try to be authoritative — resolved by keeping `measure()`/`latestResult` explicitly scoped to its own, non-electrical, already-tested capability and adding `measureElectrical()`/`electricalResult` as the sole electrical path, documented in the class's own doc comment.

**Protocol change: OIP measurement correlation.** Additive `OipMessage.replyTo: String?` (request never sets it; response sets it to the request's own `messageId`). Chosen over inventing a separate `requestId` field because `messageId` was already present, already unique per message, and already exactly what a `replyTo` needs to reference — no new identifier concept was introduced. Fully backward compatible: `toJson()` omits the key when `null`; `fromJson()` defaults to `null`.

**Protocol change: structured measurement results.** Additive `electricalState: String` (plus `note`, `solutionGeneration`) alongside the pre-existing `value`/`unit`/`quality`/`state` — the coarse pair is kept, unmodified, for backward compatibility; a client that understands `electricalState` gets the full 7-state distinction, one that doesn't still gets the same coarse answer as before.

**Protocol change: diagram-instance routing.** Additive, optional `diagramInstanceId` in the request payload, resolved via a new `graphProviderByInstance` callback layered on top of (never replacing) the existing single-graph-provider default — chosen specifically so every existing caller/test needed zero changes to keep working.

**Decision: no new solver, no new measurement engine, anywhere.** Verified by construction (every new/changed file either calls into `oep_engine`'s existing `ElectricalSolver`/`ElectricalMeasurementQuery` or is a pure data/protocol type) and by `dart analyze` finding no stray electrical-computation code in any touched Flutter/Dart file outside `oep_engine`.

## 20. Recommended Next Phase

1. Build the actual Diagram Studio DMM page/instrument (wiring `MultimeterController` + a rendered `DigitalMultimeterPanel`-equivalent into `InstrumentsPerspectiveDock`) — this closes limitation #1 and is the direct prerequisite for a genuine §24 WebView2 E2E test.
2. Bridge real UI/V2 switch state into an `ElectricalOperatingContext` for both new native-Engine-backed paths (limitation #3) — likely the single highest-value follow-up, since it's the gap between "the native Engine answers correctly" (already true) and "the native Engine answers correctly for the circuit's *actual current state*."
3. Extend `Probe`/OIP payload UI to let a user address a specific terminal, not just a component (limitation #4).
4. An on-device or emulator-driven Android instrumented test pass, now that the underlying package behavior (reconnect, diode, structured states) is proven (limitation #7).
