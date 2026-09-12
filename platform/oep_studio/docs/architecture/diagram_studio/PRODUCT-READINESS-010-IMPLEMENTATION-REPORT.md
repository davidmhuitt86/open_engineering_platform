# PRODUCT-READINESS-010

## Status: COMPLETE WITH BOUNDED GAPS

Diagram Studio can now answer "What circuit is this?" end to end: search the currently open diagram for a component, terminal, or wire; select a result to navigate to the real object; discover its circuit (Physical/Conducting/Current Flow, reusing `TraceEngine` exclusively); inspect source/return, real component/wire/branch counts, and blocked-path diagnostics; see parallel branches as a real tree; jump to any step in the real diagram; fit the camera to the traced region; and hand a resolved terminal or an unambiguous source/return pair straight to the existing DMM. One real, disclosed Engine gap was found in the course of building the real TRX300 acceptance matrix and closed with the smallest possible change. The only remaining bounded gap is the same literal OS-click WebView2 E2E gap PR-007/008/009 already disclosed and did not remove.

---

## 1. Scope

Turn the existing, authoritative electrical graph and `TraceEngine` into a product feature: search for an engineering object, discover the circuit it belongs to, see its real branch structure, source, return, and blocking diagnostics, and navigate/highlight/measure from the result — without creating a second solver, a second trace engine, or a persisted `Circuit` object as electrical authority.

## 2. Baseline

PR-009 ("COMPLETE WITH BOUNDED GAPS") built `TraceController`/`TraceInspectorPanel`/`TraceHighlightPlan`, wired as a fourth toggle in `DiagramWithComparePane`, reusing `TraceEngine` for Physical/Conducting/Current-Flow tracing against the real TRX300 fixture. PR-010 builds directly on top of that same panel and controller — no parallel trace surface was created.

## 3. Search Architecture Audited

Audited before writing any code: a real, layered search system already existed but had never been extended to circuit-oriented terminal search: `SearchProvider`/`SearchService` (`oep_engine`, graph-aware — substring matches over `EngineeringGraph` nodes/relationships and `DiagramLayoutState` symbols/annotations/layers) feeding `UnifiedSearchService`/`UnifiedSearchResult` (`oep_studio`, a cross-scope merge with Foundation/Knowledge search) and a global `SearchPage`. Also confirmed: no `NavigationService`-class camera/viewport API is actually wired to the real, user-visible diagram (the real rendering is the Legacy V2 WebView, not any native canvas) — `EngineRegistry.selection.selectNode`/`.selectRelationship` (via `unified_navigation.dart`'s `goToDiagramElement`, and PR-009's own `TraceInspectorPanel._selectInDiagram`) remains the one real "navigate to an object" mechanism. No scoped "fit to a subset" viewport capability existed anywhere — only the whole-diagram `zReset()`/`initViewport()` V2 JS functions, reached via the existing `executeRawScript` bridge escape hatch. §44's audit found **no pre-existing `Circuit` class/type anywhere in the repository** (`NodeCategory.circuit` is an unrelated enum tag; `CircuitTracer` is Legacy V2 JS, reference-only, untouched) — so no legacy object needed auditing/preserving; the new `CircuitSummary`/`CircuitBranchNode` types introduced here are the first of their kind.

## 4. Circuit Intelligence Architecture

**Engine-owned** (pure, deterministic, no new solver/traversal):
- `searchTerminals(EngineeringGraph, String)` → `TerminalSearchMatch` (§8) — a small, deliberately separate addition alongside `SearchService` rather than widening the shared `SearchResultKind` enum (which is consumed by several exhaustive `switch`es in both `oep_engine`'s example app and `oep_studio`'s `UnifiedSearchResult` mapping).
- `CircuitSummary.derive(TraceResult, {SolvedElectricalState?})` (§12/§31) — real component/wire/branch counts, aggregate conducting state, and (only when genuinely valid) solved current/source-voltage, all read straight off already-computed `TraceResult`/`ElectricalTerminalState` data.
- `buildCircuitBranchTree(List<TracePath>)` (§15) — merges already-computed `TracePathStep` sequences that share a prefix into one real tree; discovers no new connectivity.

**Studio-owned** (presentation/orchestration only):
- `searchCircuitEntities(...)` (`circuit_search.dart`) — combines `SearchService` + `searchTerminals` against the CURRENTLY OPEN diagram's own graph/layout, never cross-diagram.
- `TraceInspectorPanel` extended with a search box, richer summary, branch-tree rendering, Fit Circuit, Measure Circuit, and a "Trace from source" toggle (§33) — the same single panel PR-009 built, not a new surface.
- `TraceController.lastSolvedState` (new field) — kept only so the summary can show a genuinely solved source voltage; the controller performs no additional electrical computation.

**V2-owned**: real diagram rendering; a new, minimal `window.__oepBridgeFitToNodes` JS function (§17) computes a bounding box over the real, already-rendered module cards and reuses V2's own existing `scale`/`tx`/`ty`/`applyT()` pan-zoom primitives — the same ones `zReset()` already uses, just scoped to a subset.

## 5. Search

`searchCircuitEntities` returns `CircuitSearchEntry` values, each wrapping either a real `SearchResult` (node/relationship) or a real `TerminalSearchMatch` — never a flattened string (§6). Ranking is deterministic (§27): terminal matches first, rank-sorted by exact/prefix/substring match; then node/relationship matches in `SearchService`'s own order. Symbol/annotation/layer results are filtered out — out of Circuit Intelligence's own explicit scope (§4). A nonexistent query returns an empty list, never throws (§40); duplicate display names (e.g. two "Headlight" nodes) each produce their own distinguishable result, keyed by real node id (§39).

## 6. Component Navigation

Selecting a search result calls the exact same `engine.registry.selection.selectNode`/`.selectRelationship` PR-009's own path-step click already uses — no new navigation authority. A terminal result navigates to its own real component (§7/§8).

## 7. Circuit Discovery

"Discover Circuit" is the search result's own Trace Physical/Trace Conducting/Trace Current Flow actions (§10/§11/§36) — each sets `TraceController.setTarget`/`setMode` and lets the existing trigger/solve/highlight pipeline run. No `CircuitDiscoveryMode` was created — `TraceMode` already provides the required semantics (§11).

## 8. Physical Trace

Unchanged from PR-009 — verified against the real TRX300 headlight (TEST C, §37).

## 9. Conducting Trace

Unchanged solver/engine path from PR-009. §33's own finding — conducting-mode tracing from a **load** only ever reports the nearest wire as blocked, while tracing from the **source** identifies the real blocking switch — is now a first-class, disclosed UI option ("Trace from source (why isn't it working?)"), never a cosmetic rename inside `TraceEngine` itself. Verified against real Key OFF/ON states (TEST D/E, §37).

## 10. Current-Flow Trace

See §21 (Real Engine Fix) — closes a real gap that otherwise left this mode unable to report any current at all on the real TRX300 headlight circuit. Verified against real LOW/HIGH BEAM states (TEST F/G, §37).

## 11. Circuit Inspector

The Circuit Summary now shows, using only values the Engine actually produced: path count, SOURCE/RETURN (or "Not resolved," never guessed, §13), STATE, CURRENT (only when a path carries genuinely valid solved current), VOLTAGE (only when a genuinely valid solved source-terminal voltage is available), COMPONENTS/WIRES/BRANCHES (real counts, §30), and BLOCKED (Yes/No). Blocked-path diagnostics name the real blocking component and reason (§34).

## 12. Branch Representation

`buildCircuitBranchTree` renders as a real, indented tree in the panel — a splice/junction with two real children (e.g. LH/RH headlights) shows a split icon and two distinct branches, never one collapsed series path (§15/§24, verified against real TRX300 parallel headlights).

## 13. Source / Return

Read verbatim from `TraceResult.sourceTerminals`/`returnTerminals` — no new source-detection algorithm (§13). `isRecognizedSourceComponent` (the same production classifier the DMM/solver already use) is reused, not reimplemented, for the "Trace from source" option's own nearest-source lookup (§33).

## 14. Diagnostic / Blocking Paths

`TracePath.blockingStep`/`blockingReason` surfaced directly in the summary and in the branch tree (the blocked step renders in a distinct warning color) — never "no path" (§34/§41). No fault inference beyond what the Engine reports: a blocked switch is reported as "switch open," never "switch defective" (§35).

## 15. DMM Integration

A terminal search result's own "Measure" action arms the existing `MultimeterController`'s red probe with the real `ProbePoint` (§20) — the search/circuit layer never solves anything itself. "Measure Circuit" is enabled only when a circuit result has exactly one source and one return terminal (§21); otherwise it stays disabled rather than guessing. `TraceEngine` and `MultimeterController` remain fully independent — both consume `ProbePoint`/`ElectricalSolver`/`SolvedElectricalState`, neither imports the other.

## 16. Operating-State Integration

Unchanged trigger mechanism from PR-009 (`TraceInspectorPanel._maybeScheduleTrace`'s signature already includes the live operating context and the graph object identity) — a real V2 switch change or a topology edit automatically invalidates and recomputes Conducting/Current-Flow results; Physical mode is untouched by operating-state changes, as required (§22/§23).

## 17. Navigation / Fit Circuit

"Fit Circuit" pans/zooms the real V2 viewport to the bounding region of the real, currently-highlighted module cards (`window.__oepBridgeFitToNodes`, computed from each card's own real `positions[id]` origin and `offsetWidth`/`offsetHeight` — deliberately not `getBoundingClientRect()`, which would already reflect the current transform). Disabled until a real highlight plan has actually been applied (verified by widget test) — never a silent no-op on tap. Never moves engineering objects or touches persisted layout — pure transient viewport state, reusing V2's own existing pan/zoom primitives.

## 18. TRX300 Validation

New `test/diagram_studio/electrical/trx300_circuit_intelligence_acceptance_test.dart`, loaded through the real, production `DiagramDocument.open()` path, using the exact production `buildStudioElectricalSolver()`/`buildStudioTraceEngine()`/`searchCircuitEntities` the real UI uses.

| Test | Result |
|---|---|
| A/B — Search "Headlight" returns both real LH/RH nodes; resolves to real objects | PASS |
| C — Discover Physical circuit reaches the real upstream harness | PASS |
| D — Discover Conducting circuit, Key OFF: blocked at the real ignition switch | PASS |
| E — Discover Conducting circuit, Key ON: the conducting path genuinely changes | PASS |
| F — Discover Current Flow, LOW BEAM: real current, direction, source/return | PASS |
| G — Discover Current Flow, HIGH BEAM: path moves to the Hi filament | PASS |
| H — LH/RH parallel branches preserved (real branch-tree split) | PASS |
| I/J — Battery + identified as source; chassis ground as return | PASS |
| K — Blocking switch diagnostics name the real ignition switch | PASS |
| M — Fit Circuit's `allNodeIds` covers the real traced region | PASS |
| §38 — search cases (Battery, Chassis GND, Headlight LO/HI) resolve correctly | PASS |
| §40 — nonexistent search term returns no results | PASS |

**12/12 passing.** (L — path-step click navigates to the real object — is proven at the unit level here via `_selectInDiagram`'s reuse of `engine.registry.selection`, already covered by PR-009's own selection-navigation precedent, and exercised directly in the widget-test suite below.)

## 19. Tests

| Suite | Result |
|---|---|
| `oep_engine` (full suite, after the §21 Engine fix) | **530/530 passed** (505 baseline + 12 `circuit_summary_test.dart` + 6 `circuit_branch_tree_test.dart` + 7 `terminal_search_test.dart`) |
| `oep_studio` (full suite) | **1128 tests; 5 failures in the full parallel run, all confirmed pre-existing flakes** (`diagram_repository_commit_action_test.dart` — the exact flake PR-008's own report already disclosed; `diagram_tabs_controller_test.dart` Test D/E; `settings_service_test.dart` ×2) — all pass cleanly when re-run in isolation; none touch a file this phase changed |
| `oep_instruments_runtime` | **49/49 passed** |
| Legacy V2 JS (`node --test`) | **27/27 passed** |
| `trx300_circuit_intelligence_acceptance_test.dart` (new) | **12/12 passed** |
| `trx300_trace_acceptance_test.dart` (PR-009, re-verified) | **7/7 passed, unchanged** |
| `trx300_dmm_acceptance_test.dart` (PR-008, re-verified) | **10/10 passed, unchanged** |
| `terminal_search_test.dart` (new, `oep_engine`) | **7/7 passed** |
| `circuit_summary_test.dart` (new, `oep_engine`) | **12/12 passed** |
| `circuit_branch_tree_test.dart` (new, `oep_engine`) | **6/6 passed** |
| `circuit_search_test.dart` (new, `oep_studio`) | **7/7 passed** |
| `trace_highlight_plan_test.dart` (extended) | **12/12 passed** |
| `trace_inspector_panel_test.dart` (extended) | **11/11 passed** |

## 20. WebView2 Validation

**Not run as a literal OS-click-driven Windows WebView2 end-to-end test** — the same, unresolved gap PR-007/008/009 already disclosed: no `integration_test` dependency and no OS-level input-injection utility for the native WebView2 HWND exist in this repository. This phase adds one new bridge function (`__oepBridgeFitToNodes`) via the exact same `executeRawScript`/typed-channel pattern PR-009 already established and verified not to regress the Legacy V2 JS suite (27/27). What is proven real: the search→circuit-discovery→highlight pipeline end to end against the real TRX300 fixture (§18); the highlight-plan translation layer independently unit-tested; the injected JS verified not to break the existing reference suite. No OS-level E2E result is claimed.

## 21. Real Engine Fix (Bounded Gap Policy, §52)

**Exact defect found** while building the real TRX300 current-flow acceptance test: `TraceMode.currentFlow` could not report any valid solved current on the real TRX300 headlight circuit at all. Root cause: `ElectricalBranchState.current` (which `TraceEngine` reads) is computed by `ElectricalSolver._resistiveCurrentFor`/`_effectiveVoltageForCurrent`, which resolves a load's return-terminal voltage via only (a) ideal propagation, or (b) a deliberately narrow one-hop "direct wire to a Ground node" check — a scope intentionally narrowed in an earlier phase after two broader heuristics were tried and found, on this exact real fixture, to falsely mark unrelated terminals as grounded. The real headlight's own GND terminal sits several splice-hops from chassis-ground, so neither fallback resolved it.

**Smallest correction made**: a third fallback, tried only after the first two fail — `SolvedElectricalState.network.operatingVoltage(terminal)` (PR-006B's own real, disclosed-resistance circuit solve, already trusted by `ElectricalMeasurementQuery` for real DMM readings). This is architecturally distinct from the two rejected heuristics: it is an actual resistor-network voltage-divider computation, not a reachability guess. `ElectricalResistiveNetwork.build(...)` was moved earlier in `ElectricalSolver.solve()` so it could be threaded into this fallback. **Verified**: full `oep_engine` suite (530/530) identical before and after — purely additive, only ever converts a previously-unsupported answer into a valid one. File: `platform/oep_engine/lib/core/simulation/electrical/electrical_solver.dart`.

## 22. Build Results

| Target | Result |
|---|---|
| `oep_studio` — `flutter build windows --debug` | **Success** — `build\windows\x64\runner\Debug\oep_studio.exe` |
| `oep_studio` — `flutter build apk --debug` | **Success** — `build\app\outputs\flutter-apk\app-debug.apk` |
| `oep_instruments/apps/android` (real Android DMM client) — `flutter build apk --debug` | **Success** — `build\app\outputs\flutter-apk\app-debug.apk` |

## 23. Files Changed

**New:**
- `platform/oep_engine/lib/core/search/terminal_search.dart`
- `platform/oep_engine/lib/core/trace/circuit_summary.dart`
- `platform/oep_engine/lib/core/trace/circuit_branch_tree.dart`
- `platform/oep_engine/test/search/terminal_search_test.dart`
- `platform/oep_engine/test/trace/circuit_summary_test.dart`
- `platform/oep_engine/test/trace/circuit_branch_tree_test.dart`
- `platform/oep_studio/lib/diagram_studio/trace/circuit_search.dart`
- `platform/oep_studio/test/diagram_studio/trace/circuit_search_test.dart`
- `platform/oep_studio/test/diagram_studio/electrical/trx300_circuit_intelligence_acceptance_test.dart`

**Modified:**
- `platform/oep_engine/lib/core/simulation/electrical/electrical_solver.dart` (§21 — the one real Engine fix)
- `platform/oep_engine/lib/services/services.dart` (export `terminal_search.dart`)
- `platform/oep_engine/lib/trace/trace.dart` (export `circuit_summary.dart`/`circuit_branch_tree.dart`)
- `platform/oep_studio/lib/diagram_studio/trace/trace_controller.dart` (`lastSolvedState`)
- `platform/oep_studio/lib/diagram_studio/trace/trace_highlight_plan.dart` (`allNodeIds`, for Fit Circuit)
- `platform/oep_studio/lib/diagram_studio/trace/trace_inspector_panel.dart` (search box, richer summary, branch tree, Fit/Measure Circuit, Trace-from-source)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_state_adapter.dart` (`fitTraceHighlight`)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_bridge_transport.dart` (`LegacyV2Channel.fitToTraceHighlight`, Windows implementation)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_android_bridge_transport.dart` (Android implementation)
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_bridge_script.dart` (`__oepBridgeFitToNodes`)
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/app.js`, `js/diagram/renderer.js` — no changes this phase (PR-009's `nativeFlowWires` addition remains; PR-010 reused `applyT()`/`scale`/`tx`/`ty` unmodified)
- `platform/oep_studio/test/diagram_studio/trace/trace_highlight_plan_test.dart` (new `allNodeIds` test)
- `platform/oep_studio/test/diagram_studio/trace/trace_inspector_panel_test.dart` (new Circuit Intelligence tests)
- 6 test fake-channel files updated with no-op `fitToTraceHighlight` (`legacy_v2_live_measurement_bridge_test.dart`, `legacy_v2_persistence_e2e_support.dart`, `legacy_v2_state_adapter_document_lifecycle_test.dart`, `legacy_v2_state_adapter_persistence_test.dart`, `legacy_v2_state_adapter_test.dart`, `v2_measurement_bridge_test.dart`)

## 24. Known Limitations

- **§20 real OS-driven WebView2 E2E** remains a bounded gap, unchanged from PR-007/008/009.
- **§33's "Trace from source" toggle is a UI option the user must choose**, not an automatic heuristic — the panel does not yet auto-detect "why isn't this working?" intent from a blocked-load trace and prompt the user to retry from the source. A reasonable, disclosed next-phase refinement.
- **Fit Circuit's bounding-box math is a real, minimal JS addition** (`__oepBridgeFitToNodes`) but, like all V2 bridge calls, cannot be verified against the real, rendered WebView2 pixels without the same OS-click infrastructure §20 discloses as missing — verified instead via the Legacy V2 JS regression suite (unaffected) and the highlight-plan's own real `allNodeIds` content (§18 TEST M).
- Symbol/annotation/layer search results (real `SearchService` kinds) are deliberately out of Circuit Intelligence's own scope (§4) and filtered out of `searchCircuitEntities` — the global cross-scope `SearchPage`/`UnifiedSearchService` remains the place to reach those.

## 25. Architectural Decisions

- **No new solver, no new trace engine, no persisted `Circuit` object** — `CircuitSummary`/`CircuitBranchNode` are transient view models derived on every call from `TraceResult`/`SolvedElectricalState`, never stored, never a second source of truth (§2).
- **Terminal search deliberately does not widen the shared `SearchResultKind` enum** — that type is consumed by several exhaustive `switch` statements outside this phase's own scope; a small, separate `TerminalSearchMatch` result type avoids that blast radius while still reusing `ProbePoint` identity and living in the same Engine-owned `core/search/` location.
- **Fit Circuit reuses V2's own existing pan/zoom primitives** (`scale`/`tx`/`ty`/`applyT()`) rather than the orphaned, unwired `ViewStateService.fitSelection` (a real, registered Engine capability found during the audit to have zero consumers anywhere in the actually-rendered diagram surface — the same "built but never wired to the real UI" situation PR-008 found with `InstrumentRegistry`).
- **The one real Engine fix (§21) is additive and narrowly scoped**, consulted only after two more specific, already-validated checks fail, verified not to alter a single existing test result.

## 26. Recommended Next Phase

1. Close the long-standing WebView2 OS-level E2E gap (shared by PR-007 through PR-010) with `integration_test` + a Win32 input-injection or JS-dispatched synthetic-event approach.
2. Consider auto-suggesting "Trace from source" when a Conducting/Current-Flow discovery from a load comes back fully blocked, rather than requiring the user to already know to toggle it.
3. Consider wiring `ViewStateService`/`NavigationService` (real, registered, currently-unconsumed Engine capabilities) into whatever native canvas consumer eventually needs them, now that their own real disconnection from the WebView-based production UI is documented.
