# PRODUCT-READINESS-014 — Diagram Studio WebView Lifetime / No Unnecessary Reloads

## 1. Problem

Ordinary Diagram Studio interaction — opening/closing Trace, DMM, Analysis, or Compare — was disposing and recreating the Primary Legacy V2 WebView's Flutter `State`, which owns the real `WebviewController`, `LegacyV2BridgeTransport`, and `LegacyV2StateAdapter`. Recreating that `State` re-runs `initState()` → `_init()` → `WebviewController.initialize()` → `WebviewController.loadUrl(entryUrl)` — a genuine reload of the real V2 page, not merely a Flutter rebuild. The user separately reported that adding a module also appeared to reload the diagram.

## 2. Root cause

`DiagramWithComparePane.build()` (`lib/diagram_studio/compare/diagram_with_compare_pane.dart`) selected the content area with a `compareEnabled ? Row(...) : analysisEnabled ? Row(...) : dmmEnabled ? Row(...) : traceEnabled ? Row(...) : const LegacyV2WebViewPage()` chain. Every "a panel is active" branch built its own `Row(children: [Expanded(LegacyV2WebViewPage()), ...])`; the final "no panel active" branch built a bare `LegacyV2WebViewPage()` with no `Row`/`Expanded` wrapper at all.

Flutter's element reconciliation decides whether to reuse or replace a `State` by comparing the widget's `runtimeType` (and `key`) at the same tree position across builds (`Widget.canUpdate`). Going from "no panel" to "any panel" (or back) changed the runtimeType at that position from `LegacyV2WebViewPage` to `Row` (or vice versa) — a mismatch `canUpdate` treats as "cannot reuse," so Flutter deactivated and disposed the Primary WebView's entire `State` and built a fresh one in its place. Switching directly between two already-active panels (e.g. Trace → DMM) did **not** trigger this, because both branches built a `Row` at that position and the Primary's own sub-position within it (`Expanded(child: LegacyV2WebViewPage())`, always first) was structurally identical either way — only the *first* open of any panel, or closing the *last* open one, crossed the runtimeType boundary.

`reinitializeForDocument()`/`initializeFromDocument()` (`LegacyV2StateAdapter`) were confirmed, by direct source inspection, to never call `WebviewController.loadUrl()` or touch the WebView `State` at all — they only clear/reseed V2's in-page `MODULES`/`WIRES` arrays via bridge calls. A repo-wide search for every `.loadUrl(` call found exactly two call sites for the Legacy V2 webviews (Primary and Compare), both inside their own `_init()`, called only from `initState()`. This means the *entire* "unintended reload" problem reduced to the Flutter `State`-identity question above — there was no second, independent reload path to find.

## 3. Lifecycle instrumentation

Added, as temporary diagnostics (not removed — see §11):

- `legacy_v2_webview.dart`: a shared, monotonically increasing `_nextV2WebviewLifecycleId`/`nextV2WebviewLifecycleId()` counter and a `logV2WebviewLifecycle(event, {lifecycleId, instance, detail})` helper, emitting lines shaped `[V2-WEBVIEW] <EVENT> lifecycle=<n> instance=<id> [detail]` via `debugPrint`. Never logs document paths/content — only ids (the fixed `primaryDiagramInstanceId` literal, a real but content-free `WorkspaceTab.id`, or the fixed literal `'compare'`).
- `_WindowsLegacyV2WebViewPageState`: `_lifecycleId` assigned once in `initState`; logs `CREATE` (initState), `INIT` (start of `_init`), `LOAD` (right after `loadUrl` resolves), `SEED` (start of `_triggerInitialSeed`, guarded so it only fires on the real first seed), `REINITIALIZE` with `oldDocument=<id> newDocument=<id>` (the `document.id` `ref.listen` callback in `build()`, before calling `_onDocumentChanged`), and `DISPOSE` (start of `dispose`).
- `_WindowsCompareLegacyV2WebViewPageState` (`compare_legacy_v2_webview.dart`): the identical set of events, tagged `instance=compare`, sharing the same counter so Primary/Compare lifecycle ids are directly comparable in one log stream.
- `LegacyV2StateAdapter.initializeFromDocument()`/`reinitializeForDocument()`: one `debugPrint` each at entry, confirming a seed/reseed actually ran independent of the caller's own log line.

## 4. Exact structural change

`DiagramWithComparePane`'s content area is now a single, unconditional `Row` whose first child is always `const Expanded(child: LegacyV2WebViewPage())` — never re-branched. Only the *trailing* children (a `VerticalDivider` plus whichever side panel is active) are chosen by an `if/else if` **collection** (`if (compareEnabled) ...const [...] else if (analysisEnabled) ...const [...] else if (dmmEnabled) ...const [...] else if (traceEnabled) ...const [...]`, with the `if (traceEnabled)` case previously ending the chain now simply producing nothing when no panel is active. Flutter's positional diffing for an unkeyed children list never disturbs index 0 when only trailing entries are added or removed, so the Primary's `Expanded(LegacyV2WebViewPage())` is now the identical widget, at the identical position, on every single build regardless of panel state — its `State` (and therefore its `WebviewController`/transport/adapter) is never disposed by a panel change. No `UniqueKey`/changing key was introduced anywhere; the fix is purely about giving the Primary one permanent host shape.

## 5. Document identity behavior

Investigated, not changed: `_WindowsLegacyV2WebViewPageState.build()`'s `ref.listen(engineeringProjectServiceFamily(_instanceId).select((s) => s.document.id), ...)` — and the identical pattern in `compare_legacy_v2_webview.dart`, `legacy_v2_android_webview.dart`, and `compare_legacy_v2_android_webview.dart` — was already, pre-existing, selecting on `DiagramDocument.id` specifically, not on the document object or its content. `DiagramDocument.id` (`lib/diagram_studio/host/diagram_document.dart`) is a stable per-in-memory-document identifier that is set only by `open()` (reads it from the file) and reset to `null` only by `close()` (regenerated lazily on next access) — no ordinary mutation (add/remove module, add/edit wire, selection, switch state, layout, analysis/trace/measurement results) ever touches it. Every caller of `reinitializeForDocument()` repo-wide is already gated behind either this `document.id` listener or the `documentPath` null→non-null (Save As) listener — never behind a generic "document changed" signal. The Document Identity Rule this task's own Phase 3 describes was therefore already correctly implemented before this pass; nothing needed to change here, and nothing was invented.

## 6. Add-module reload investigation

Traced the real mechanism rather than assumed one: V2's "Add Module" flow (`commitAddModule()`, `js/editor/module-editor.js`) pushes into V2's own `MODULES` array and reports the new module to Dart via the existing bridge (`type: 'moduleCreated'`, `legacy_v2_bridge_script.dart` → `LegacyV2BridgeTransport._dispatch` → `onModuleCreated`), which `LegacyV2StateAdapter` uses to add an ordinary node to the OEP Engine graph — ordinary content, never touching `DiagramDocument.id`, never touching any of the four panel-visibility providers `DiagramWithComparePane` watches. With §2's root cause fixed, nothing in this path can reach a code position with a different `runtimeType` at the Primary WebView's tree slot, so it cannot recreate the Primary `State`. This is a structural conclusion from reading every step of the real call chain (not an assumption): the previous report of "adding a module reloads the diagram" is explained by the same root cause as the panel-toggle case — most plausibly, the user's own module-add happened to coincide with a panel opening/closing (the same "any panel ↔ no panel" transition), not a separate defect in the add-module path itself. This was **not independently confirmed against the real, running Windows app this round** — see §10/§11.

## 7. Compare behavior

Unchanged by design, confirmed correct: `CompareLegacyV2WebViewPage`/`_WindowsCompareLegacyV2WebViewPageState` is a structurally separate class with its own `WebviewController`/`LegacyV2BridgeTransport`/`LegacyV2StateAdapter` (`compare_legacy_v2_webview.dart`'s own doc comment already documents "neither has any static/global state"). Compare's own widget now sits in the trailing, conditionally-present slot of the Row (§4) — it is created when `compareModeEnabledProvider` turns on and can be disposed when it turns off, exactly as this task's own Phase 6 permits ("Compare may produce CREATE lifecycle=8... and later DISPOSE lifecycle=8 while lifecycle 7 remains alive"). Nothing about Compare activating or deactivating touches the Primary's own position in the tree.

## 8. Multi-instance behavior

Unchanged: `LegacyV2WebViewPage`/`_WindowsLegacyV2WebViewPageState` continue to be parameterized purely by `instanceId` (`null` meaning `primaryDiagramInstanceId`), with every family provider (`engineeringProjectServiceFamily`, `diagramStudioControllerFamily`, `legacyV2AdapterFamily`, `legacyV2OperatingContextFamily`) keyed by that same id — this task added no global/singleton WebView state anywhere. `DiagramWithComparePane` itself is only ever instantiated for the Primary Diagram tab (`EngineeringWorkspacePage._buildTabContent`'s `tab.id == primaryDiagramInstanceId` branch); a non-primary Diagram Workspace tab renders a bare, unwrapped `LegacyV2WebViewPage(instanceId: tab.id)` with no Compare pane, per the pre-existing design this task's own architecture rules preserve — untouched by this fix.

## 9. Tests

- Full `oep_studio` suite: **1139/1139 passing** (a clean run with zero failures, including the previously-disclosed pre-existing full-suite-ordering flakes from earlier phases of this engagement — none recurred in this run).
- `oep_engine`: 530/530, unchanged.
- `oep_instruments` runtime: 51/51, unchanged.
- Legacy V2 JS (`node --test`): 27/27, unchanged (no JS/HTML files were touched by this pass).
- Static analysis: `oep_engine` and `oep_instruments` — no issues. `oep_studio` — the same 9 pre-existing info/warning-level issues as before this pass, unchanged; the 4 files this pass touched analyze with zero new issues.

**A dedicated widget-level regression suite for the lifetime contract (this task's own Phase 8) was attempted and then removed.** Mounting `DiagramWithComparePane` directly (bypassing the existing `bootstrapDiagramStudioController` test harness's own two-step "pump a blank Scaffold, await the controller future, then pump real content" pattern) produced a genuine `flutter test` harness deadlock — `tester.runAsync(() => container.read(diagramStudioControllerProvider.future))` never resolved, timing out at the framework's 10-minute per-test ceiling and then poisoning every subsequent test in the same file with "Reentrant call to runAsync() denied." This is a test-infrastructure limitation of that specific mounting order, not evidence of a production bug (the existing, working harness pattern mounts a blank page first for exactly this reason); root-causing it further was out of time budget for this pass, so the file was deleted rather than left in the tree as a hanging/broken test. **This is a disclosed gap, not a silent omission** — see §11.

## 10. Windows validation

A real `flutter run -d windows --debug` session was started and did reach a genuine, interactive launch. Console lifecycle logging confirmed a clean, single boot sequence for the Primary WebView on that real launch:

```
[V2-WEBVIEW] CREATE lifecycle=1 instance=workspace-tab-diagram
[V2-WEBVIEW] INIT lifecycle=1 instance=workspace-tab-diagram
[V2-WEBVIEW] LOAD lifecycle=1 instance=workspace-tab-diagram
[V2-WEBVIEW] SEED lifecycle=1 instance=workspace-tab-diagram
[V2-WEBVIEW] ADAPTER-INITIALIZE-FROM-DOCUMENT begin
```

— exactly one `CREATE`/`INIT`/`LOAD`/`SEED`, no `DISPOSE`, matching the expected "initial creation" acceptance line from this task's own Phase 8, item 1.

**The full manual acceptance sequence (opening/closing Trace, DMM, Analysis, Compare; adding a module; editing wires; searching; tracing; measuring; switch/key state changes — items B through S) was explicitly not performed this round, at direct user instruction ("no need for validation this round just report") after the user asked me to release interactive screen control mid-session.** No claim is made that the full contract was proven end-to-end against the real, running app. What *is* established, with evidence: a fresh launch is clean (one lifecycle id, no spurious create/dispose), and the structural fix (§2/§4) is a general one — it removes the *only* code path capable of producing a runtimeType mismatch at the Primary WebView's tree position, for *any* trigger (panel toggle, add-module's resulting bridge event, or anything else that does not touch `document.id` or the four panel-visibility providers), not a fix narrowly scoped to the specific actions this pass happened to test.

## 11. Remaining limitations

- **Phase 8's automated widget-level regression suite is not present** (§9) — removed after it deadlocked in this harness rather than reliably validating the contract. The existing full `oep_studio` suite passing (§9) confirms no *existing* behavior regressed, but there is no new automated test asserting "panel toggle preserves the Primary WebView's `State` identity" going forward; a future pass should root-cause the `runAsync`/family-future interaction before re-attempting this.
- **The full interactive Windows manual acceptance sequence (items B–S) was not executed this round** (§10), at explicit user direction. The single confirmed real-launch sequence is consistent with, but does not by itself prove, the full contract.
- **Add-module's real-world lifecycle was not independently re-confirmed against the running app this round** (§6/§10) — the conclusion that it is now safe rests on tracing its real call chain end-to-end through source, not on an observed CREATE/DISPOSE-free log during an actual add-module interaction.
- The lifecycle logging added in §3 is temporary diagnostic instrumentation, left in place (not stripped) per this task's own framing ("temporary but useful diagnostics") — it is low-volume, non-sensitive `debugPrint` output with no runtime behavior effect, but a future pass may choose to remove or gate it behind a debug flag once the contract is independently re-verified on real hardware.
