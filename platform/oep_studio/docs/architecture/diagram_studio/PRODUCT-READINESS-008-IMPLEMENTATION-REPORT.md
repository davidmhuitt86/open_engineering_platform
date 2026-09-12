# PRODUCT-READINESS-008 — Diagram Studio DMM UI + Live Operating Context Integration

## Status: COMPLETE WITH BOUNDED GAPS

The real Digital Multimeter instrument UI now exists inside Diagram Studio, wired to the native `ElectricalSolver`/`MultimeterController` path (never the WebView's own JS solver), with a real, generic V2-switch-state → `ElectricalOperatingContext` bridge. The real TRX300 acceptance matrix (§27), the full regression suite (Engine, Studio, Instruments runtime, Legacy V2 JS), static analysis, and all three required debug builds pass. Two items are explicitly bounded rather than faked: a literal OS-click-driven Windows WebView2 E2E test (§29) and a fully manual, human-operated acceptance run (§28) — both require a capability (real input injection into a native WebView2 HWND, or an actual human at the keyboard) that does not exist in this session or this repository's test infrastructure. Both are documented below with the exact architectural reason, per §35.

---

## 1. Scope

Close the two most important user-facing gaps left by PR-007: (A) a real, rendered DMM UI in Diagram Studio, and (B) a live bridge from the interactive V2 diagram's electrical/switch state into the native Engine solver, so a user can select a mode, place probes, read a structured measurement, change a switch, and see the measurement update — all backed by the real `ElectricalSolver`, never a UI-side reimplementation.

## 2. Baseline

PR-007 ("COMPLETE WITH BOUNDED GAPS", `PRODUCT-READINESS-007-IMPLEMENTATION-REPORT.md`) left 5 disclosed gaps: no rendered DMM UI, no WebView2 DMM E2E, V2 switch state not bridged to the native Engine (defaulted to `ElectricalOperatingContext.none`), OIP addressing was node- not terminal-oriented, native VAC unsupported by design. This phase closes gaps 1 and 3 fully, narrows gap 2 to a specific bounded sub-case, and leaves VAC honestly unsupported (unchanged, by design).

## 3. Existing Architecture Audited

Audited before writing any code: `MultimeterController`/`electricalResult`/`measureElectrical()` (PR-007, additive); `EngineeringInstrument`/`InstrumentRegistry` (confirmed never instantiated with real instruments anywhere in the running app — `InstrumentsSurfacePage` is always built with `instruments: []` by its own honest doc comment, and its own existing test pumps it with **no** `ProviderScope`, relying on that emptiness); the real Diagram Studio content tree (`StudioShell` → `EngineeringWorkspacePage` → `DiagramWithComparePane`, which already had an established "one side-panel slot shared by Analysis/Compare" pattern via `analysisPanelVisibleProvider`/`compareModeEnabledProvider`); `EngineRegistry.selection`/`SelectionService`, with `EngineeringProjectServiceNotifier.ensureEngineStarted` as the real, working precedent for mirroring diagram selection into Studio state; the real V2 JS live switch/key state (`LiveSim`'s `switchStates`/`multiSwitchStates`, `app.js`'s `keyPos` bridged via `setKey()`); the bridge script's single `setInterval(400ms)` poll-and-diff loop; `LegacyV2Channel`/`LegacyV2BridgeTransport`/`LegacyV2AndroidBridgeTransport` and their 6 test fakes; `LegacyV2StateAdapter`'s existing `oepNodeIdFor`/`oepRelationshipIdFor` translation helpers and its live-synced `graph`; `ElectricalSolver`/`SolvedElectricalState`/`ElectricalOperatingContext`/`ElectricalMeasurementQuery`/`ProbePoint`/`ElectricalTerminalPair` (PR-004/005/006/006B/007).

## 4. DMM UI

New instrument: `DigitalMultimeterInstrument` (id `digitalMultimeter`) + `DigitalMultimeterInstrumentPanel`, hosted inside `DiagramWithComparePane` via a third toggle button ("Multimeter") alongside the pre-existing Analysis/Compare toggles, sharing the same one-slot-at-a-time pattern via a new `dmmPanelVisibleProvider` (`StateProvider<bool>`). This is the one place in the app with a guaranteed-live diagram session and WebView — `InstrumentsSurfacePage`/`InstrumentRegistry` were deliberately **not** wired to the DMM (see §18, Known Limitations) because they have no live diagram session reachable and wiring them would have broken an existing test that relies on that emptiness.

The panel shows: mode selector (VDC/VAC/RES/CONT/DIODE/A/W as `ChoiceChip`s), red/black probe controls (arm → pick a terminal → attached, or "Not placed"), the structured measurement display (§17), and a collapsible debug panel (§26, hidden by default behind a "Details" toggle).

## 5. Probe Architecture

Probe placement reuses `EngineRegistry.selection`/`SelectionService` — the same selection-mirroring mechanism `EngineeringProjectServiceNotifier` already established — never a new probe-address type. Canonical representation is the existing `ProbePoint(nodeId, portId)`. Placing a probe arms it (`_armedProbe`), then the next diagram selection assigns it. No mutation of `DiagramDocument`/`EngineeringGraph` ever occurs from probe placement — probes are pure widget state in `DigitalMultimeterInstrumentPanel`'s `State`.

## 6. MultimeterController Integration

`DigitalMultimeterInstrumentPanel` observes `MultimeterController` (via the existing `multimeterRuntimeServiceProvider`) and calls the existing, additive `measureElectrical({graph, solver, generationCounter, operatingContext})` on every mode/probe/operating-context change — no local electrical computation in the widget. Measurement triggering is deferred via `WidgetsBinding.instance.addPostFrameCallback` (both to avoid a Riverpod build-phase-mutation error and to naturally debounce to widget-build cadence, not raw frame rate), matching §8.

## 7. Operating Context Integration

`DigitalMultimeterInstrumentPanel` watches `legacyV2OperatingContextFamily(primaryDiagramInstanceId)` (a new `StateProvider.family<ElectricalOperatingContext, String>`) and passes the live context straight into `measureElectrical`. `ElectricalOperatingContext.none` is no longer hardcoded — it is now the real, honest default only until a real V2 message has arrived.

## 8. V2 State Bridge

New, additive message flow, following the existing `measurementRequested` bridge pattern exactly:

1. `live-runner.js`: new `getLiveOperatingState()` — returns `{switchStates, multiSwitchStates}` from the module's own existing private state (no new V2-side state).
2. `legacy_v2_bridge_script.dart`: new poll-diff block (same `setInterval(400ms)` loop) posts `{type:'operatingStateChanged', payload}` only when the state actually changed.
3. `legacy_v2_bridge_transport.dart`/`legacy_v2_android_bridge_transport.dart`: new `V2OperatingStateChangedMessage`, a new `onOperatingStateChanged` setter on the `LegacyV2Channel` interface (implemented by both real transports and all 6 test fakes), dispatched on `case 'operatingStateChanged'`.
4. `legacy_v2_state_adapter.dart`: new `_translateOperatingState()` maps each V2 module id to its real OEP node id (via the existing `oepNodeIdFor`) and folds simple switch booleans / multi-switch group maps into `ElectricalOperatingContext.activeInputStates` — a `Map<String, Object?>` keyed by real OEP node id, not V2's own internal switch ids (§22: no V2 internals leaked into the Engine).
5. `legacy_v2_webview.dart`/`legacy_v2_android_webview.dart`: registers the adapter's callback, writes into the new `legacyV2OperatingContextFamily` provider (deferred via `addPostFrameCallback` — see §16, Errors and Fixes).

## 9. Native Solver Integration

TRX300-specific switch continuity data and the precise ground-reference resolver — previously test-only fixture code (PR-006) — were moved into real, generic production code in `oep_engine`, satisfying §11/§12's "the Engine must remain generic, no `if (diagram == trx300)`" requirement:

- `platform/oep_engine/lib/simulation/electrical/reference/trx300_v2_switch_behaviors.dart` (new): `Trx300IgnitionSwitchBehavior`, `Trx300HandlebarSwitchBehavior` (both read live `Map<String, Object?>` operating-context values directly — not a precomputed table, since a plain Dart `Map` has no value-equality suitable as a table key for live, JSON-sourced state), plus `trx300ElectricalBehaviorFor(EngineeringNode)`, a dispatcher that recognizes components purely by their real terminal **name sets** (matching the real V2 JS `MultiSwitchBehavior.match()` technique) — never by hardcoded node id.
- `electrical_node_roles.dart`/`electrical_solver.dart`: `preciseIsReferenceTerminal` (previously test-only in PR-006B, now real production code) replaces the old broad name-based `defaultIsReferenceTerminal` heuristic that PR-006B's own report disclosed as over-firing on a real multi-circuit harness.

The DMM panel's own solver configuration (in `digital_multimeter_instrument_panel.dart`) uses exactly these same production functions — no parallel copy.

## 10. TRX300 Validation

New file `test/diagram_studio/electrical/trx300_dmm_acceptance_test.dart` — loads the real `samples/diagram7.json` through the real, production `DiagramDocument.open()` path (no test-only graph reconstruction), and runs the §27 4-state matrix (Key OFF/Lights OFF, Key ON/Lights OFF, Key ON/LOW BEAM, Key ON/HIGH BEAM) plus a VAC-unsupported check. **29/29 tests pass** (including `diagram_document_test.dart` run alongside it).

A genuine, previously-undiscovered real-data bug was found and fixed while building this test (see §16). A second finding, initially mistaken for a bug, was diagnosed as **correct** electrical behavior and the test's own expectations were corrected instead of the production code (see §16).

## 11. WebView2 E2E — BOUNDED GAP

**Not run as a literal OS-click-driven Windows WebView2 end-to-end test.** Exact reason: this repository has no `integration_test` package dependency and no OS-level input-injection utility for the native WebView2 HWND. `webview_flutter_windows`'s `WebviewController`/`Webview` composites the WebView2 control as a native child HWND, not as part of Flutter's own Skia-rendered surface — so `WidgetTester.tap()` at a coordinate does not deliver a real click to content inside it. Producing a genuine OS-level click into that surface requires either (a) adding the `integration_test` package plus a new Win32 `SendInput`/`PostMessage`-based utility targeting the WebView2 HWND's real screen coordinates, or (b) a human physically clicking the running app. Neither exists today; this is the same gap PR-007 disclosed ("no `integration_test` harness existed and no DMM UI existed") — the DMM UI now exists, narrowing the gap to purely the input-injection capability.

What **is** proven real and end-to-end, without any mock:
- The real V2 JS (`getLiveOperatingState`) → real bridge script → real `V2OperatingStateChangedMessage` → real `LegacyV2StateAdapter._translateOperatingState` → real `ElectricalOperatingContext`, proven in `test/diagram_studio/webview/v2_measurement_bridge_test.dart`'s new §12/§14 test, which drives a real (non-mock) fake-channel implementation of the exact same dispatch path the real `LegacyV2BridgeTransport` uses.
- The real translated context → real `ElectricalSolver` (with the real, production `trx300ElectricalBehaviorFor`/`preciseIsReferenceTerminal`) → real `SolvedElectricalState` → real `ElectricalMeasurementQuery`, proven against the real `diagram7.json` in `trx300_dmm_acceptance_test.dart`.
- The real `MultimeterController.measureElectrical` → real structured display states (VALID/OPEN/UNSUPPORTED, §17), proven in `test/diagram_studio/instruments/multimeter/digital_multimeter_instrument_panel_test.dart` against a real `MultimeterController` instance (not a mock).

Every link in the chain is proven real and correct individually; only the literal "a human/OS clicks a pixel inside a live WebView2 control" step is unautomated. **Recommended next phase**: add `integration_test` as a dev dependency and a small Win32 input-injection helper (or, more tractably, drive the V2 side of the test via the same `runJavaScript` mechanism the bridge itself already uses — dispatching a synthetic DOM `click`/`change` event is how V2's own click handlers are invoked internally regardless of the input's origin, and is a substantially smaller new capability than OS-level `SendInput`).

## 12. Stale Result Validation

New test `test/instruments/multimeter_controller_test.dart`: **"§9/§30 an older, now-superseded electrical request never overwrites a newer one"**. `ElectricalSolver.solve()` is fully synchronous (no `await` inside `measureElectrical`), so a genuine out-of-order completion cannot occur through normal async interleaving under the current implementation — the test instead uses a real `_ReentrantOnceElectricalSolver` (a real `ElectricalSolver` subclass, delegates to `super.solve()` for the actual computation) whose `solve()` reaches back into the controller before returning, exactly reproducing the §9 worked example (an older "request 101" whose own correlation check runs only after a newer "request 102" has already completed and moved `_electricalRequestSeq` on). Exercises the real `if (requestSeq != _electricalRequestSeq) return;` guard in `multimeter_controller.dart`, not a reimplementation of it. Passes.

## 13. Diagram Instance Isolation

Unchanged from PR-007 — `primaryDiagramInstanceId` routing and the `.family` providers (`legacyV2AdapterFamily`, `legacyV2OperatingContextFamily`) key every new piece of per-diagram state by instance id, following the exact pattern PR-007 established for `oip_host_bridge_service.dart`/`instrument_bridge_provider.dart`. No cross-instance test regression.

## 14. Tests

| Suite | Result |
|---|---|
| `oep_engine` (`flutter test`) | **505/505 passed** |
| `oep_studio` (`flutter test`, full suite) | **1074 passed** (8 skipped, pre-existing) |
| `oep_instruments_runtime` (`flutter test`) | **49/49 passed** |
| Legacy V2 JS (`node --test`) | **27/27 passed** |
| `trx300_dmm_acceptance_test.dart` + `diagram_document_test.dart` together | **29/29 passed** |
| `multimeter_controller_test.dart` (incl. new §9/§30 test) | **14/14 passed** |
| `digital_multimeter_instrument_panel_test.dart` (new) | **7/7 passed** |

## 15. Build Results

| Target | Result |
|---|---|
| `oep_studio` — `flutter build windows --debug` | **Success** — `build\windows\x64\runner\Debug\oep_studio.exe` |
| `oep_studio` — `flutter build apk --debug` | **Success** — `build\app\outputs\flutter-apk\app-debug.apk` |
| `oep_instruments/apps/android` (real Android DMM client) — `flutter build apk --debug` | **Success** — `build\app\outputs\flutter-apk\app-debug.apk` |

## 16. Static Analysis

`oep_engine`: **0 issues**. `oep_studio`: **9 issues, all pre-existing** (verified: none touch lines modified in this phase) — 6 `info`-level lint suggestions, 1 pre-existing unused-import warning in an unrelated test file, 2 `avoid_print` infos in `tools/hot_reload_client.dart`. **Zero newly-introduced issues.**

## 17. Files Changed

**New:**
- `platform/oep_engine/lib/simulation/electrical/reference/trx300_v2_switch_behaviors.dart`
- `platform/oep_studio/lib/diagram_studio/instruments/multimeter/digital_multimeter_instrument.dart`
- `platform/oep_studio/lib/diagram_studio/instruments/multimeter/digital_multimeter_instrument_panel.dart`
- `platform/oep_studio/lib/diagram_studio/webview/v2_measurement_bridge.dart` *(PR-007, listed for completeness — unchanged this phase)*
- `platform/oep_studio/test/diagram_studio/electrical/trx300_dmm_acceptance_test.dart`
- `platform/oep_studio/test/diagram_studio/instruments/multimeter/digital_multimeter_instrument_panel_test.dart`

**Modified:**
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/simulation/live-runner.js` (`getLiveOperatingState`)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_bridge_script.dart`
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_bridge_transport.dart`
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_android_bridge_transport.dart`
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_state_adapter.dart`
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_webview.dart`
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_android_webview.dart`
- `platform/oep_studio/lib/diagram_studio/webview/v2_terminal_port_bridge.dart` (`normalizeV2RelationshipPortReferences`, new function)
- `platform/oep_studio/lib/diagram_studio/host/diagram_document.dart` (wires the new normalization into `open()`/`recoverFrom()`)
- `platform/oep_studio/lib/diagram_studio/compare/diagram_with_compare_pane.dart` (`dmmPanelVisibleProvider`, third toggle)
- `platform/oep_studio/lib/diagram_studio/instruments/multimeter/multimeter_controller.dart` *(PR-007, unchanged this phase; listed as touched by `git status`)*
- `platform/oep_studio/lib/workbench/perspectives/instruments_perspective.dart` (doc comment only — see §18)
- `platform/oep_engine/lib/core/simulation/electrical/electrical_node_roles.dart` (`preciseIsReferenceTerminal` and helpers)
- `platform/oep_engine/lib/core/simulation/electrical/electrical_solver.dart` (`defaultIsReferenceTerminal` now delegates to the shared helper)
- `platform/oep_engine/lib/simulation/electrical/electrical.dart` (export)
- `platform/oep_engine/test/simulation/electrical/electrical_solver_trx300_test.dart` (imports production behaviors instead of local duplicates)
- `platform/oep_studio/test/instruments/multimeter_controller_test.dart` (new §9/§30 test + `_ReentrantOnceElectricalSolver` helper)
- 6 test fake-channel files updated with `onOperatingStateChanged` (`legacy_v2_live_measurement_bridge_test.dart`, `legacy_v2_persistence_e2e_support.dart`, `legacy_v2_state_adapter_document_lifecycle_test.dart`, `legacy_v2_state_adapter_persistence_test.dart`, `legacy_v2_state_adapter_test.dart`, `v2_measurement_bridge_test.dart`)

**Found already modified in the working tree, not caused by this phase's own test runs** (`DiagramDocument.open()` is read-only — confirmed by reading its source): `platform/oep_studio/samples/diagram7.json`. Its diff (backfilled `ports`, normalized relationship port references) is consistent with — but not produced by — the same `backfillV2TerminalPorts`/`normalizeV2RelationshipPortReferences` functions now in production; left untouched rather than reverted, since there is no basis to treat it as erroneous and reverting an already-present, plausibly-intentional working-tree change would be a destructive action outside this phase's scope.

## 18. Known Limitations

- **`InstrumentsSurfacePage`/`InstrumentRegistry` were not wired to the DMM.** That dock has no reachable live diagram session (its own doc comment says so) and its own existing test (`engineering_instruments_surface_migration_test.dart`) pumps it with no `ProviderScope`, relying on the zero-instrument short-circuit. Wiring the DMM there would have broken that test. The DMM is instead reached via `DiagramWithComparePane`'s own toggle, which does have a live session. `DigitalMultimeterInstrument` still exists and self-identifies correctly (proven by a dedicated unit test) so it is ready to be surfaced through `InstrumentRegistry` once that dock gains a real diagram-session wiring — a natural follow-on, not part of this phase's bounded scope.
- **VAC remains unsupported on the native path**, honestly (never fabricated) — unchanged from PR-007, confirmed by a dedicated test in the new acceptance suite.
- **§29 WebView2 E2E and §28 manual acceptance** are both bounded gaps — see §11 above and §35 disclosure below.
- The real headlight-resistance and headlight-idle-voltage acceptance-test values reflect genuine real TRX300 harness topology (parallel LH/RH headlights sharing a rail and ground bus) discovered while building the acceptance test — documented inline in the test file, not silently adjusted.

## 19. Architectural Decisions

- **TRX300 switch behavior moved to production, keyed by terminal-name signature, not node id** — satisfies §11/§12's explicit prohibition on `if (diagram == trx300)` inside the generic solver while still eliminating duplicate test/production switch tables.
- **Operating context transport uses semantic V2 module→group/position data, translated to OEP node ids at the adapter boundary** — no V2-internal switch ids reach the Engine (§22).
- **DMM hosted inside `DiagramWithComparePane`, not `InstrumentsSurfacePage`** — matches the one place with a real live diagram session, rather than forcing a currently-unwired dock to gain new capability out of scope for this phase.
- **Stale-result guard tested via real reentrancy, not a fabricated delay** — since the current solver is genuinely synchronous end-to-end, this is the only way to exercise the real correlation-check code path without inventing an artificial async seam that doesn't exist in production.

## 20. Recommended Next Phase

1. Add `integration_test` as a dev dependency and a minimal Win32 input-injection (or JS-dispatched synthetic-event) utility to close the §29 WebView2 E2E gap for real.
2. Wire a live-diagram-session-aware path into `InstrumentsSurfacePage`/`InstrumentRegistry` so the DMM (and future instruments) can be reached through the originally-intended instrument dock, not only `DiagramWithComparePane`'s side panel.
3. If/when an AC solver capability is added to `oep_engine`, revisit VAC support in the DMM — until then it should remain honestly unsupported.
