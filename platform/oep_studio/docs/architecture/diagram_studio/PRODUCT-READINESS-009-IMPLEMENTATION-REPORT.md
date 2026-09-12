# PRODUCT-READINESS-009

## Status: COMPLETE WITH BOUNDED GAPS

The interactive electrical trace feature now exists inside Diagram Studio: select a component (or a wire, or a specific terminal) and trace it Physically, Conducting-ly, or by Current Flow, using the existing, unmodified `TraceEngine` as the sole trace authority. Results highlight the real, rendered V2 diagram (never a synthesized replacement), a Trace Inspector shows every path/step/source/return/blocking diagnostic, and clicking a step selects the real diagram object. Real TRX300 acceptance tests (physical, conducting at Key OFF/ON, current-flow at LOW/HIGH BEAM, parallel headlight preservation, chassis-ground return) all pass against `samples/diagram7.json`. One real, disclosed Engine gap was found and fixed with the smallest possible change (§9 below). The only remaining bounded gap is the same one PR-007/PR-008 already disclosed and did not remove: a literal OS-click-driven Windows WebView2 E2E test, which still requires input-injection infrastructure this repository does not have.

---

## 1. Scope

Expose the existing native `TraceEngine`'s electrical intelligence through the real Diagram Studio user experience: select a component, trace its circuit, see the actual electrical path highlighted on the real diagram, inspect source/return/blocking diagnostics, and see solved current direction — using the already-built `TraceEngine`/`ElectricalSolver`/`SolvedElectricalState` as the sole authority, never a second solver or traversal engine.

## 2. Baseline

PR-008 ("COMPLETE WITH BOUNDED GAPS") established the DMM instrument inside `DiagramWithComparePane`, the V2 switch-state → `ElectricalOperatingContext` bridge, and the production TRX300 reference behaviors (`trx300ElectricalBehaviorFor`, `preciseIsReferenceTerminal`) in `oep_engine`. `TraceEngine` itself (built in an earlier phase, PR-005, documented in `docs/architecture/diagram_studio/ELECTRICAL_TRACE_ENGINE.md`) existed fully-featured but had **zero consumers anywhere in oep_studio** — this phase's job was purely to build that missing consumer.

## 3. Existing Trace Architecture Audited

Audited before writing any code (three parallel research passes): `TraceEngine.trace({graph, target, mode, solvedState, operatingContext}) → TraceResult`; `TraceMode` (physical/conducting/currentFlow) and `TraceTarget` (component/terminal/relationship, via `TraceTargetKind`); `TraceResult` (paths, sourceTerminals, returnTerminals, componentIds, relationshipIds, diagnostics); `TracePath` (steps, conductingState, currentDirection, current, blockingStep, blockingReason) and `TracePathStep` (terminal, viaRelationshipId, isInternalBridge); `TraceDiagnostic`/`TraceDiagnosticCode`; the pre-existing, extensive `oep_engine/test/trace/` suite (component/terminal/relationship targets, physical/conducting/current-flow modes, blocked paths, source/reference identification, deterministic ordering, parallel branches, splices, connectors — all already covered, requiring **no new Engine-side test additions** for coverage, only regression confirmation). Also audited: the Studio selection system (`SelectionService`/`GraphSelection`/`EngineRegistry.selection`, mirrored into `EngineeringProjectState.selection` exactly as PR-008's DMM already established); confirmed **no context-menu system and no generic command bus exist anywhere in Diagram Studio** — direct widget wiring (PR-008's own established pattern) is the only option; the `diagram_with_compare_pane.dart` three-way toggle pattern to extend to four; and the Legacy V2 JS reference (`CircuitTracer`/`PathFinder`/`PowerPath`/`GroundPath`/`PathHighlighter`, reference-only) — found a real, reusable, currently-unbridged rendering primitive (`tracedWires` + `drawWires()`) that the new native bridge drives directly, without invoking any of V2's own BFS traversal code.

## 4. DS Trace Architecture

New `TraceController extends ChangeNotifier` (`lib/diagram_studio/trace/trace_controller.dart`) — target/mode/result state, a real `TraceEngine` instance, and the same request-correlation stale-result guard `MultimeterController` established in PR-008. Scoped via `traceRuntimeServiceProvider`, gated on a live diagram session exactly like `multimeterRuntimeServiceProvider`. A new shared `lib/diagram_studio/electrical/studio_electrical_solver.dart` factors the one production `ElectricalSolver` **and** `TraceEngine` configuration (`buildStudioElectricalSolver()`, `buildStudioTraceEngine()`) used by both the DMM and the Trace feature — the DMM panel was refactored to use it too, eliminating what would otherwise have become a second, independently-maintained copy of the TRX300 reference-behavior wiring (§33).

## 5. Component Trace Workflow

Selecting a component (or wire) in the live diagram automatically becomes the trace target (`TraceInspectorPanel._deriveTargetFromSelection`, mirroring the DMM's own selection-mirroring pattern) — no wire-first requirement, satisfying §5's explicit departure from the Legacy V2 UI. A genuinely multi-terminal component additionally shows a terminal picker (`_TerminalPicker`) offering "Whole component" or a specific terminal, never silently guessing. Mode is switched via three `ChoiceChip`s without losing the target (tested). Clear resets both target and result and clears the diagram highlight.

## 6. Physical Trace

`TraceMode.physical` — no `SolvedElectricalState` passed, independent of operating state, exactly as `TraceEngine` already implements it. Verified against the real TRX300 headlight: reaches the real upstream battery/ignition-switch/handlebar-switch/chassis-ground topology (TEST A).

## 7. Conducting Trace

`TraceMode.conducting` — `TraceController.runTrace` solves via `ElectricalSolver` first, then traces the solved state. A real, previously-undocumented-until-now finding from building the real TRX300 test: `TraceEngine`'s conducting-mode traversal stops exploring at the very first non-conducting hop (correct, deliberate behavior — there is no value in enumerating structure that provably can't conduct) — which means tracing **from a load** (e.g. the headlight) toward its source always reports the *nearest* wire as "blocked," identically, regardless of which switch further upstream is actually open. Tracing **from the source** (the battery) instead walks forward and correctly names the real blocking switch by id, exactly matching the spec's own "Path blocked at: Ignition Switch" example — this is how TEST B/C are written, and is a general, useful piece of Trace Inspector guidance (tracing toward a load from its source gives more actionable diagnostics than tracing from the load itself) that is disclosed here rather than silently discovered and left unexplained.

## 8. Current-Flow Trace

`TraceMode.currentFlow` — solves, then asks `TraceEngine` for paths carrying real, solved current, oriented via `ElectricalBranchState.currentDirection` exclusively (§7). See §9 for the real Engine gap found and fixed to make this mode produce any informative result at all on the real TRX300 fixture, and §14 for the real TEST D/E results this unlocked.

## 9. Engine Change Made (Bounded Gap Policy, §43)

**Exact defect found**: `ElectricalBranchState.current` (what `TraceEngine.currentFlow` reads via `SolvedElectricalState.branchState(relId)`) is computed by `ElectricalSolver._resistiveCurrentFor`/`_effectiveVoltageForCurrent`, which resolves a resistive load's own two terminal voltages using only (a) the ideal-propagation value, or (b) a narrow, deliberately-one-hop-only "is there a direct wire to a Ground node" check — a scope explicitly, deliberately narrowed in an earlier phase after two separate broader heuristics were tried and found to *falsely* mark unrelated terminals as grounded on this exact real fixture (both documented in the file's own comments). On the real `diagram7.json`, the LH headlight's own GND terminal is several splice-hops from chassis-ground — neither fallback resolves it, so `_effectiveVoltageForCurrent` returned `unreached` and every wire's `current` came back `unsupported`, meaning `TraceMode.currentFlow` could report **no current anywhere**, for a real, correctly-wired, currently-lit circuit.

**Smallest Engine change made**: added a **third** fallback to `_effectiveVoltageForCurrent`, consulted only after the first two already fail — `SolvedElectricalState.network` (`ElectricalResistiveNetwork`, PR-006B's real, disclosed-resistance circuit solve, already computed and already trusted by `ElectricalMeasurementQuery` for real DMM readings) via its own `operatingVoltage(terminal)`. This is architecturally distinct from the two rejected heuristics: it is not a reachability guess, it is an actual resistor-network voltage-divider computation using the same real, disclosed component/wire resistances the DMM already relies on. `ElectricalResistiveNetwork.build(...)` was moved earlier in `ElectricalSolver.solve()` (before the branch-state loop, previously built after it) so it can be threaded into this fallback; no other behavior changed. **Verification**: full `oep_engine` suite (505/505) before and after the change is bit-for-bit identical — the fallback is purely additive and only ever converts a previously-`unreached`/`unsupported` answer into a valid one, never changes an already-valid one. Files: `platform/oep_engine/lib/core/simulation/electrical/electrical_solver.dart`.

## 10. Trace Inspector

`lib/diagram_studio/trace/trace_inspector_panel.dart` — mode selector, target summary with Clear, terminal picker, result summary (path count, SOURCE/RETURN using real graph names, blocked-path diagnostics with real component names), and a path list (`ExpansionTile` per `TracePath`) listing every `TracePathStep` with its real terminal/relationship id. Hosted as a fourth toggle in `diagram_with_compare_pane.dart` ("Trace Circuit"), sharing the existing one-slot side panel with Analysis/Compare/DMM, following that file's own established mutual-exclusion pattern exactly.

## 11. Visualization / Highlighting

`lib/diagram_studio/trace/trace_highlight_plan.dart` — a pure function (`buildTraceHighlightPlan`) translating a `TraceResult` into real OEP relationship/node ids to highlight (never V2 ids at this layer, keeping it independently unit-testable). `LegacyV2StateAdapter.applyTraceHighlight`/`clearTraceHighlight` translate those OEP ids to V2 ids (new `v2ModuleIdFor`/`v2WireIdFor` reverse lookups) and push through the existing `LegacyV2Channel`/`executeScript` bridge (new `applyTraceHighlight`/`clearTraceHighlight` methods on the channel interface, both real transports, and all 6 test fake channels). The injected bridge script (`legacy_v2_bridge_script.dart`) defines `window.__oepBridgeApplyTraceHighlight`/`__oepBridgeClearTraceHighlight`, which set V2's own existing `tracedWires` global and call its existing `drawWires()` — the exact same rendering primitive `PathHighlighter` itself uses, never invoking `CircuitTracer`/`PathFinder`. New CSS classes (`.trace-source`/`.trace-return`/`.trace-blocked`) mark source/return/blocked module cards distinctly from plain selection.

## 12. Current-Flow Animation

A new global `nativeFlowWires` (declared in `app.js`, alongside `tracedWires`) is consulted **first** by the existing `wireHasFlow`/`wireFlowDir` functions in `renderer.js`; when `null` (no active native current-flow trace), both fall back to their original, completely unmodified legacy behavior. When set, animation is gated exclusively on genuinely solved current/direction from the native trace — never V2's own legacy `VDC != 0` heuristic. The actual marching-dash animation loop (`startFlowAnim`/`stopFlowAnim`, a `requestAnimationFrame` loop) is pre-existing, unmodified V2 code — Dart never drives per-frame animation, satisfying §31/§32 by construction: the native side pushes a highlight/flow plan once per new `TraceResult`, and the animation itself runs entirely in JS.

## 13. Operating-State Integration

`TraceInspectorPanel._maybeScheduleTrace`'s trigger signature includes the live `ElectricalOperatingContext` (watched via the same `legacyV2OperatingContextFamily` PR-008 established) — a real V2 switch/key change automatically re-triggers Conducting/Current-Flow traces, with no manual reload, satisfying §18.

## 14. Topology Invalidation

The same trigger signature also includes the graph object itself — a document edit (a new immutable `EngineeringGraph` instance, the existing architecture-wide convention) changes the signature and triggers a fresh trace automatically, satisfying §19 without polling.

## 15. TRX300 Validation

New `test/diagram_studio/electrical/trx300_trace_acceptance_test.dart`, loaded through the real, production `DiagramDocument.open()` path (no test-only graph reconstruction), using `buildStudioElectricalSolver()`/`buildStudioTraceEngine()` — the exact same production configuration the real Trace Inspector uses.

| Test | Result |
|---|---|
| TEST A — Physical headlight trace reaches real upstream harness | PASS |
| TEST B — Key OFF conducting trace blocked at the real ignition switch | PASS |
| TEST C — Key ON conducting path genuinely changes (reaches further, blocks at the lights switch) | PASS |
| TEST D — LOW BEAM current-flow: valid current, real direction, real source/return, real wires+direction highlighted | PASS |
| TEST E — HIGH BEAM: path changes to the Hi filament, LO no longer carries current | PASS |
| §24 — Parallel LH/RH headlight branches both present, never collapsed | PASS |
| §16/§27 — continuity/diagnostics sanity | PASS |

**7/7 passing.**

## 16. Tests

| Suite | Result |
|---|---|
| `oep_engine` (full suite, after the §9 Engine change) | **505/505 passed** |
| `oep_studio` (full suite) | **1105 tests; 2 unrelated pre-existing flakes** (`settings_service_test.dart`, `workspace_tabs_controller_test.dart`) confirmed to pass cleanly in isolation — neither touches any file changed in this phase |
| `oep_instruments_runtime` | **49/49 passed** |
| Legacy V2 JS (`node --test`) | **27/27 passed** |
| `trx300_trace_acceptance_test.dart` | **7/7 passed** |
| `trx300_dmm_acceptance_test.dart` (re-verified after the §9 Engine change) | **10/10 passed, unchanged** |
| `trace_controller_test.dart` (new) | **9/9 passed** — target/mode changes, physical/conducting modes, relationship and terminal targets, clear, stale-result guard |
| `trace_highlight_plan_test.dart` (new) | **11/11 passed** — wire/source/return/blocked collection, current-flow direction (forward, reversed, backward-traversed wire, none/unknown excluded, non-currentFlow-mode excluded), parallel branches |
| `trace_inspector_panel_test.dart` (new) | **7/7 passed** — no-session message, placeholder, mode switching without losing target, real trace rendering, empty-result handling, Clear |

## 17. WebView2 Validation

**Not run as a literal OS-click-driven Windows WebView2 end-to-end test** — this is the same, unresolved gap PR-007/PR-008 already disclosed and did not remove: no `integration_test` dependency and no OS-level input-injection utility for the native WebView2 HWND exist in this repository (`webview_flutter_windows` composites WebView2 as a native child window outside Flutter's own hit-testing). This phase does not change that. What **is** proven real: the highlight-bridge translation layer (OEP → V2 ids, direction computation) is fully, independently unit-tested (`trace_highlight_plan_test.dart`); the real production solver/trace chain is proven against the real TRX300 fixture (§15); the injected JS functions (`__oepBridgeApplyTraceHighlight`/`__oepBridgeClearTraceHighlight`) and the minimal `wireHasFlow`/`wireFlowDir` edit were verified not to regress the existing 27/27 Legacy V2 JS suite. No OS-level E2E result is claimed.

## 18. Build Results

| Target | Result |
|---|---|
| `oep_studio` — `flutter build windows --debug` | **Success** — `build\windows\x64\runner\Debug\oep_studio.exe` (first attempt failed on a stale, already-running `oep_studio.exe` holding a file lock — an unrelated leftover process, not a code issue; terminated and rebuilt successfully) |
| `oep_studio` — `flutter build apk --debug` | **Success** — `build\app\outputs\flutter-apk\app-debug.apk` |
| `oep_instruments/apps/android` (real Android DMM client) — `flutter build apk --debug` | **Success** — `build\app\outputs\flutter-apk\app-debug.apk` |

## 19. Static Analysis

`oep_engine`: **0 issues** (including the modified `electrical_solver.dart`). `oep_studio`: **9 issues, all pre-existing** (verified identical to PR-008's own baseline; none touch a file modified in this phase). `oep_instruments_runtime`: **0 issues**. **Zero newly-introduced issues** across all three packages.

## 20. Files Changed

**New:**
- `platform/oep_studio/lib/diagram_studio/electrical/studio_electrical_solver.dart`
- `platform/oep_studio/lib/diagram_studio/trace/trace_controller.dart`
- `platform/oep_studio/lib/diagram_studio/trace/trace_highlight_plan.dart`
- `platform/oep_studio/lib/diagram_studio/trace/trace_inspector_panel.dart`
- `platform/oep_studio/test/diagram_studio/trace/trace_controller_test.dart`
- `platform/oep_studio/test/diagram_studio/trace/trace_highlight_plan_test.dart`
- `platform/oep_studio/test/diagram_studio/trace/trace_inspector_panel_test.dart`
- `platform/oep_studio/test/diagram_studio/electrical/trx300_trace_acceptance_test.dart`

**Modified:**
- `platform/oep_engine/lib/core/simulation/electrical/electrical_solver.dart` (§9 — the one real Engine change)
- `platform/oep_studio/lib/diagram_studio/instruments/multimeter/digital_multimeter_instrument_panel.dart` (refactored to use the new shared `buildStudioElectricalSolver()`)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_state_adapter.dart` (`v2ModuleIdFor`/`v2WireIdFor` reverse lookups, `applyTraceHighlight`/`clearTraceHighlight`)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_bridge_transport.dart` (`LegacyV2Channel.applyTraceHighlight`/`clearTraceHighlight`, Windows implementation)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_android_bridge_transport.dart` (Android implementation)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_bridge_script.dart` (`__oepBridgeApplyTraceHighlight`/`__oepBridgeClearTraceHighlight`)
- `platform/oep_studio/lib/diagram_studio/compare/diagram_with_compare_pane.dart` (`tracePanelVisibleProvider`, fourth toggle)
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/app.js` (`nativeFlowWires` global)
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/diagram/renderer.js` (`wireHasFlow`/`wireFlowDir` minimal native-first fallback)
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/css/main.css` (`.trace-source`/`.trace-return`/`.trace-blocked`)
- 6 test fake-channel files updated with no-op `applyTraceHighlight`/`clearTraceHighlight` (`legacy_v2_live_measurement_bridge_test.dart`, `legacy_v2_persistence_e2e_support.dart`, `legacy_v2_state_adapter_document_lifecycle_test.dart`, `legacy_v2_state_adapter_persistence_test.dart`, `legacy_v2_state_adapter_test.dart`, `v2_measurement_bridge_test.dart`)

## 21. Known Limitations

- **§17/§28 real OS-driven WebView2 E2E** remains a bounded gap, unchanged from PR-007/PR-008's own disclosure — see §17 above for the exact reason and what is proven instead.
- **Conducting-mode "blocked at" diagnostics are most informative when tracing from the source, not the load** — a genuine, disclosed characteristic of `TraceEngine`'s own (correct, deliberate) traversal stop-on-block behavior, not a defect; documented in §7 and reflected in how the real TRX300 acceptance tests are written. The Trace Inspector itself does not currently steer the user toward source-side tracing for this reason — a natural, small follow-on UX refinement, not implemented in this phase.
- **Animation-lifecycle/disposal is proven by code review and by the same clearing code path already covered by the "Clear" widget test**, not by a dedicated live-WebView2 disposal test — the actual `requestAnimationFrame` loop lives entirely in pre-existing V2 JS and is not independently unit-testable from Dart without a live browser context, the same constraint underlying §17.
- Multi-instance isolation reuses PR-008's own already-validated `primaryDiagramInstanceId` scoping pattern verbatim (no new isolation mechanism introduced) rather than being independently re-tested from scratch in this phase.

## 22. Architectural Decisions

- **No new solver, no new trace engine, no new probe/target/measurement-mode abstraction** — `TraceTarget`/`TraceMode`/`TracePath`/`TracePathStep`/`TraceDiagnostic`/`ElectricalBranchState`/`ElectricalCurrentDirection`/`ProbePoint` are all reused exactly as PR-005/006/006B built them.
- **The one Engine change (§9) is additive and narrowly scoped** — a third, principled (non-heuristic) fallback consulted only after two existing, more specific checks already fail, verified not to alter a single existing test result.
- **Highlighting reuses V2's own existing `tracedWires`/`drawWires()` rendering primitive** rather than building a parallel Flutter-side overlay renderer, and reuses the existing `LegacyV2Channel`/bridge-script pattern rather than inventing a new message-passing mechanism.
- **Trace state lives entirely in `TraceController` (a `ChangeNotifier`), never in `DiagramDocument`** — highlight state, target, mode, and result are all transient UI state, matching §20's explicit requirement.
- **`TraceEngine` and `MultimeterController` remain fully independent** (§22) — both consume the same `ProbePoint`/`ElectricalSolver`/`SolvedElectricalState` types, but neither imports or depends on the other; the DMM and Trace features share only the `studio_electrical_solver.dart` configuration factory, not each other.

## 23. Recommended Next Phase

1. Add `integration_test` + a Win32 input-injection (or JS-dispatched synthetic-event) utility to finally close the long-standing WebView2 OS-level E2E gap — now shared by PR-007, PR-008, and PR-009 alike.
2. Consider a small Trace Inspector UX refinement that defaults conducting-mode target selection toward the nearest recognized source component when one is reachable, so "blocked at" diagnostics are maximally informative without the user needing to know to trace from the battery specifically.
3. Consider surfacing `TraceDiagnostic.code`s (`multipleSources`, `multipleReturns`, `cycleDetected`, etc.) with friendlier, mode-aware copy in the Trace Inspector, beyond the current raw `code.name`/`message` fallback.
