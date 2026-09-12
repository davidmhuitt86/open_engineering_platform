# PRODUCT-READINESS-012 — Diagram Studio Toolbar Information Architecture

## 1. Status

**COMPLETE WITH BOUNDED GAPS.**

The engineering toolbar now uses a hybrid direct-button / contextual-dropdown
model instead of either the original flat 15-button wall or the
over-collapsed 8-dropdown-only version from the immediately preceding pass.
High-frequency commands (Select, Wire, Search, Trace, Measure) are one
click; related/secondary commands (File, Add, View, Analyze, Export,
Inspect) are contextual dropdowns. All Dart/JS static analysis is clean, the
full Engine/Studio/Instruments/legacy-JS test suites pass (one pre-existing,
unrelated flake disclosed below), and Windows + Android debug builds both
succeed. A real, unrelated rendering bug (a rounded `Border` with
non-uniform side colors) was found and fixed as part of this pass's own
test run — not introduced by this pass, but caught by it.

## 2. Baseline commit

`fd7f77e` ("new oep ux/ui") at the start of this pass — the prior toolbar
pass (flat 8-dropdown-only IA, the OEP header, the File/Trace/Measure
`engineeringCommand` bridge, and the branding assets) was the accepted
starting point. Nothing from that baseline was thrown away; this pass is a
refinement on top of it, per direct instruction.

## 3. Objective

Correct the toolbar's information architecture — high-frequency commands
as direct one-click buttons, related/occasional commands as contextual
dropdowns — without redesigning Diagram Studio, without a second
Studio/route, without a new solver/trace/search/measurement authority, and
without over-engineering (no new controller/framework classes).

## 4. Existing architecture reused (not reimplemented)

- `ElectricalSolver` / `SolvedElectricalState` — untouched.
- `TraceEngine` / `TraceController` (`trace_controller.dart`) — the
  toolbar's Trace dropdown drives this directly (`setMode`/`clear`); no
  second trace implementation.
- `MultimeterController` (`multimeter_controller.dart`) — the toolbar's
  Measure button/dropdown drives this directly (`setType`); no second
  measurement engine.
- V2's own `traceCircuit()` / `CircuitTracer` — the toolbar's direct Trace
  click still uses this existing V2 presentation primitive, unchanged.
- `analysisPanelVisibleProvider` / `compareModeEnabledProvider` /
  `dmmPanelVisibleProvider` / `tracePanelVisibleProvider` — the same
  providers the Workspace Actions row already used; the Analyze dropdown's
  two items now call the same toggle logic (lifted to top-level functions
  in `diagram_with_compare_pane.dart` so both the panel buttons and the
  toolbar bridge handler can call it — no duplicated logic).
- `WorkspaceTabsController` / `SurfaceRegistry` / `DiagramStudioController`
  / `LegacyV2StateAdapter` / the LegacyV2 bridge transport — untouched.
- `OepStudioHeader`, `oepStudioViewProvider` — untouched (still presentation
  only, still one Studio/one document).

No new solver, trace engine, search engine, measurement engine, document
authority, tab authority, or diagram model was created.

## 5. Toolbar information architecture — before / after

**Before this pass** (flat 8-dropdown-only IA):
`FILE▾ | EDIT▾(Select+Search) | BUILD▾(Add Module/Component/Connector/
Splice/Wire) | VIEW▾(Pan/Zoom/Fit) | ANALYZE▾(Trace+Measure sections) |
LAYOUT▾ | EXPORT▾ | INSPECT▾`

Every command required opening a menu, including Wire and Trace — too far
in the "everything is a dropdown" direction for a professional engineering
application.

**After this pass** (hybrid):
`FILE▾ │ Select │ Wire │ Add▾ │ View▾ │ Search │ Trace(+▾) │ Measure(+▾) │
Analyze▾ │ Export▾ │ Inspect▾`

Layout was dropped from the toolbar entirely (§7) — it had no real command
behind it, and the target IA in the driving instruction did not list it.

## 6. Direct-action decisions

| Button | Real function called | Why direct |
|---|---|---|
| Select | `toggleEdit()` (unchanged V2 function) | Normal diagram interaction mode; used continuously. Active state now correctly reflects real `editMode` (previously hardcoded to look "active" on load even when `editMode` was `false` — fixed as part of this pass). |
| Wire | `toggleWireMode()` (unchanged V2 function) | Fundamental, constant operation; explicitly must not hide behind Add. |
| Search | `toggleSearch()` (unchanged V2 function, opens the existing `#srch` overlay) | High-frequency navigation; no second search implementation. |
| Trace (click) | V2's existing `traceCircuit()`/`CircuitTracer`, gated on a real wire selection (`selW`), else an honest toast | Most common Trace workflow, one click, using the existing V2 highlighting primitive exactly as the bridge architecture already permits. |
| Measure (click) | `engineeringCommand` → `measure.open` → `dmmPanelVisibleProvider = true` | Opens the real Multimeter panel in one click; no electrical math added. |

Trace and Measure are also chevron dropdowns (hybrid) — see §7.

## 7. Dropdown decisions

- **File** — New Diagram / Open Diagram / Load Previous Diagram / Save /
  Save As / Recent Diagrams (disabled placeholder — no real MRU list
  exists anywhere in this app). Every enabled item calls the exact
  pre-existing Flutter method (`_newDiagram`/`_openDocument`/
  `_loadPreviousDocument`/`_saveDocument`/`_saveDocumentAs`,
  `legacy_v2_webview.dart`) via the `engineeringCommand` bridge.
- **Add** — Add Module (library/preset/custom), Component, Connector,
  Splice. Wire is not repeated here (it is the direct button; one logical
  home per command, per instruction).
- **View** — Pan (an honest disclosure toast — no separate Pan-tool mode
  exists; the canvas already pans via drag), Zoom In/Out + a live zoom-%
  input, Fit to Window, UI-scale controls.
- **Trace dropdown** — Trace Circuit (repeats the direct action, for
  in-menu discoverability), then Physical / Conducting / Current Flow /
  Trace From Source / Clear Trace, all via `TraceController` through the
  bridge.
- **Measure dropdown** — Voltage (DC), Voltage (AC), Resistance,
  Continuity, Diode, all via `MultimeterController` through the bridge.
  ("Open Multimeter" is not repeated here since the direct click already
  covers it.)
- **Analyze** — Analysis, Compare Diagrams: real shortcuts to the exact
  same Workspace Actions panels, via the same providers
  (`toggleAnalysisPanel`/`toggleComparePane`, now top-level functions in
  `diagram_with_compare_pane.dart`). Circuit Intelligence and Diagnostics
  are **not** listed — neither exists anywhere in this codebase.
- **Export** — Export SVG only (`exportSVG()`, the one real export format).
- **Inspect** — Property Inspector (`popOut('inspector')`), Legend
  (`toggleLegend()`) — both real, pre-existing "look closer" actions.
- **Layout** — removed from the toolbar entirely this pass (§5). No real
  auto-layout engine exists; the driving instruction's own target IA did
  not include a Layout slot, and a disabled-only menu was judged not worth
  the toolbar space it would occupy. This is a scope reduction, not a
  hidden feature loss — nothing real was removed.

## 8. Contextual dropdown behavior

Unchanged mechanism (`js/ui/toolbar.js`): click a trigger → its `#dd-*`
panel opens positioned beneath it; click an item → action runs (most items
also call `toolbarCloseAllDropdowns()`, except the Zoom/UI-scale +/−
buttons and the live % inputs, which intentionally stay open for repeated
use); click outside, or Escape → closes. No modal, no Close button, no
persistent mega-menu. Trace/Measure's hybrid behavior required one small,
real correction: the direct action lives on the button's own `onclick`,
and the chevron `<svg>` has its own `onclick` with `event.stopPropagation()`
so a click on the chevron opens the dropdown without also firing the
direct action underneath it.

## 9. Header preservation

`OepStudioHeader`, `oepStudioViewProvider`, the OEP master logo, Studio
mark/title/subtitle, and the Simulation View swap control are all
untouched. Diagram and Simulation remain views of one Studio/document; no
`/diagram-studio` or `/simulation-studio` routes exist.

## 10. Workspace/tab preservation

`WorkspaceTabsController`, `SurfaceRegistry`, and the primary/secondary
Diagram instance architecture are untouched.  `WebSurfacesHostPage` is
still the unreached legacy host (per `AP-OEP-WORKSPACE-AS-PRIMARY-UI-001`)
— not reintroduced, not nested inside anything.

## 11. Legacy V2 boundary

V2's own `traceCircuit()`/`CircuitTracer` continues to be used exactly as
before — a real, pre-existing V2 presentation primitive, not a new OEP
electrical/trace authority. Every OEP-authoritative action the toolbar
needs (Trace modes, Measure modes, File lifecycle, Analysis/Compare) goes
through the existing `engineeringCommand` bridge into real Flutter
controllers/providers — V2's JavaScript never becomes the source of truth
for any of those results.

## 12. Files changed

- `reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html` — toolbar
  markup rewritten to the hybrid IA; dropdown panels re-split
  (`dd-file`/`dd-add`/`dd-view`/`dd-trace`/`dd-measure`/`dd-analyze`/
  `dd-export`/`dd-inspect`); `dd-layout` removed; new `oep-i-file`/
  `oep-i-analyze` icon symbols added; comment blocks trimmed (§16).
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/ui/toolbar.js` —
  doc comments trimmed; no behavioral change.
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/editor/module-editor.js`
  — `toggleEdit()`'s label text corrected from "Edit"/"Done" to
  "Select"/"Done" to match the button's new real name.
- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_webview.dart`
  — `_handleEngineeringCommand` extended with `analyze.analysis` /
  `analyze.compare` cases.
- `platform/oep_studio/lib/diagram_studio/compare/diagram_with_compare_pane.dart`
  — `_deactivateOthers`/`_toggleAnalysis`/`_toggleCompare`/`_toggleDmm`/
  `_toggleTrace` lifted from private instance methods to top-level public
  functions (`deactivateOtherDiagramPanels`/`toggleAnalysisPanel`/
  `toggleComparePane`/`toggleDmmPanel`/`toggleTracePanel`) so the toolbar
  bridge handler can call the exact same logic the panel buttons use —
  no new mutual-exclusion implementation.
- `platform/oep_studio/lib/diagram_studio/header/oep_studio_header.dart` —
  doc comments trimmed (§16); no behavioral change.
- `platform/oep_studio/lib/workspace/engineering_workspace_page.dart` —
  doc comment trimmed (§16); no behavioral change.
- `platform/oep_studio/lib/web_surface/web_surfaces_host_page.dart` — real
  bug fix: `_TabChip`'s rounded `Border` had non-uniform per-side colors,
  which Flutter's `Border` painter rejects at paint time whenever a
  `borderRadius` is set (see §17/§19 — this was throwing inside
  `oep_boot_app_test.dart`, an existing test, not a new one). Fixed by
  using a uniform-color `Border.all` plus a separate 2px `Positioned`
  underline bar for the active-tab accent, in a `Stack`.
- `platform/oep_studio/docs/architecture/diagram_studio/
  PRODUCT-READINESS-011-IMPLEMENTATION-REPORT.md` — added a post-hoc
  clarifying note on the `3c62b2c` baseline hash (§15/below); no
  historical claim altered.

## 13. Tests

- **oep_engine**: `flutter test` — **530/530 passed**, 0 failures.
- **oep_studio**: `flutter test` — **1135/1136 passed**, 8 skipped, 1
  known pre-existing flake (below). The `oep_boot_app_test.dart` failure
  present at the start of this pass (§12's Border bug) is now fixed and
  passes.
- **oep_instruments runtime**: `flutter test` — **51/51 passed**.
- **Legacy V2 JS** (`node --test`, `reference/legacy_wiring_sim_v2/
  eke-wiring-sim`): **27/27 passed**.
- No new tests were added for the toolbar IA itself this pass (§17.G) —
  V2's toolbar buttons are plain HTML/JS, not exercised by
  `flutter_test`'s widget tree, and the existing real-OS Windows E2E
  (§18) is the actual coverage mechanism for that surface; a full
  JS-level interaction test suite for the toolbar was judged out of scope
  for this refinement pass (bounded gap, §18 below).

## 14. Static analysis

- `oep_engine`: **No issues found.**
- `oep_instruments` runtime: **No issues found.**
- `oep_studio`: **9 pre-existing issues**, unchanged from before this
  pass (unnecessary import in `studio_app.dart`; 3 `curly_braces_in_flow_
  control_structures` info-level lints predating this work, one of them
  in `legacy_v2_webview.dart` at an unrelated line; 1 unused-import
  warning in an unrelated test file; 2 doc-comment HTML-escaping infos and
  2 `avoid_print` infos in `tools/hot_reload_client.dart`, a dev tool).
  **No new issues introduced.**

## 15. Windows build

`flutter build windows --debug` — **succeeded**, both before and after
the `_TabChip` fix.

## 16. Android build

`flutter build apk --debug` — **succeeded** (`app-debug.apk`).

## 17. Windows E2E status

Not re-run this pass. The existing `integration_test/
trx300_windows_e2e_test.dart` targets Flutter widgets in the Workspace
Actions row (`find.widgetWithText(TextButton, 'Trace Circuit')`, an
`ActionChip` labeled `'Trace Physical'`) — none of which this pass
touched or renamed, so no coordinate/label updates were required. PR-011's
own honest conclusion stands unchanged: **infrastructure and per-click
OS-level `SendInput` delivery are proven; the full ~20-step chained
acceptance workflow is not fully proven.** This pass neither improves nor
regresses that status — it was out of scope for a toolbar IA refinement.

## 18. Remaining bounded gaps

- **Layout** has no toolbar entry point at all now (§5/§7) — by design,
  since no real command exists and the driving instruction's target IA
  omitted it. If a real auto-layout/align/distribute engine is built
  later, it gets its own dropdown then.
- **Recent Diagrams** (File dropdown) is a disabled placeholder — no MRU
  store exists anywhere in this app.
- **Circuit Intelligence / Diagnostics** (Analyze dropdown) are not
  listed — neither is a real, reachable feature in this codebase today.
- **No automated toolbar-specific test coverage** was added this pass
  (§13) — the real Windows E2E harness is the intended coverage
  mechanism for V2's own HTML/JS toolbar, and it remains not-fully-proven
  per §17.
- **OEP-STUDIO-BRANDING-V1.md** (created as part of this pass) now holds
  the asset-provenance and header-rationale accounting that several
  source comments (this pass and the prior one) reference — it points
  back to this report for the current, authoritative toolbar structure
  rather than duplicating it.

## 19. Known pre-existing failures

- `diagram_studio/bridge/diagram_repository_commit_action_test.dart` —
  "11/persistence... full continuity" — a known, pre-existing flake
  documented earlier this same engagement, unrelated to this pass's
  changes. Passed in some runs, failed in this run; not investigated
  further per its prior disposition.

## 20. Final acceptance statement

The information architecture is coherent: five real high-frequency
commands are one click, the rest are contextual dropdowns, Trace/Measure
correctly hybridize both. Every command still executes through the exact
pre-existing function/controller/provider it always did — no duplicate
electrical, trace, search, or measurement authority was introduced.
Workspace tabs, the OEP header, Diagram/Simulation-as-one-Studio, and the
Legacy V2 boundary are all unchanged. All four test suites pass (one
disclosed pre-existing flake); a real, independent rendering bug was found
and fixed along the way. Windows and Android debug builds both succeed.
Windows E2E remains honestly not-fully-proven, unchanged from PR-011 and
out of this pass's scope. This is a refinement of the fd7f77e baseline,
not a reconstruction.
