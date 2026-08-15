# Diagram Studio Composition Boundary (AP-DIAGRAM-W2, Wave 2 — Stage 1)

**Status:** classification only. No implementation code was moved, edited, or
refactored to produce this document. This is the plan the later Wave 2 stages
execute against.

**Authority:** `docs/DIAGRAM_STUDIO_RECONSTRUCTION_AUDIT.md` (§2.3, §9, §11,
§12, §13, §14, §15) and `docs/DIAGRAM_STUDIO_V2_RECONSTRUCTION_SPEC.md`
(§3.1–§3.7). Where this document and those disagree, those win.

**Subject:** every responsibility currently living in
`lib/diagram_studio/workspaces/diagram_studio_page.dart` (3590 lines:
`DiagramStudioPage`, `_DiagramStudioPageState`, and the 14 private widgets/
value types declared in the same file).

---

## 1. Classification scheme

| Class | Name | Meaning |
|---|---|---|
| **A** | COMPOSITION ROOT | Stays in `diagram_studio_page.dart`, but only as wiring: obtain state, construct/obtain the controller, hand it to presentation. Target for the whole class: audit §11.5's "<200 lines". |
| **B** | CONTROLLER | Moves into `controller/diagram_studio_controller.dart` (the existing Wave 1 execution gateway) or a named sibling controller under `controller/`. Never a second execution pathway. |
| **C** | PROVIDER / SERVICE | Moves into a Riverpod provider or a UI-agnostic service. Application/session state that must outlive one widget mount, or that other routes must reach. May call **into** the controller; never duplicates it. |
| **D** | PRESENTATION | Moves into `presentation/` as a widget or view-model. Pure render + intent-emission. |
| **E** | TEMPORARY LEGACY PRESENTATION | Presentation that must keep working during the migration but is scheduled for replacement by the V2 chrome. Move it verbatim now; delete it at its own audit-assigned wave. |
| **F** | ENGINE RESPONSIBILITY | Already lives in `oep_engine` / a frozen component. The page's job is to *call* it, not to reimplement it. **Every direct `engine.*` call from the page is listed here** so the code-moving stage can verify they all disappear from the page. |
| **G** | REMOVE / DEPRECATE LATER | Dead, duplicated, or superseded. Not removed in Wave 2; recorded so it is not carried forward by accident. |

### 1.1 Wave 1 boundary — preserved

`DiagramStudioController` is already the Diagram Studio execution gateway for
interactive editing (`engine.editing.execute`, `engine.editing.resetSession`,
undo/redo/clipboard via the composed `StudioCommandActions`), and as of the
Wave 2 work already landed in that file it additionally owns bootstrap
sequencing, document lifecycle, tab lifecycle, and the workspace-persistence
write. **No class-B or class-C destination in this document introduces a second
path to the Engine.** Where a new provider is proposed, it either (a) holds
Flutter-free session state and calls the controller for anything mutating, or
(b) hosts the controller itself so it outlives widget rebuilds.

### 1.2 The four persistence categories — not conflated

Per spec §3.6 / audit §12.4, these are classified **separately** throughout this
document and must never be merged:

| Category | Owner | Storage file |
|---|---|---|
| Engineering data (graph + layout + metadata + autosave/recovery) | `host/diagram_document.dart` → `DiagramDocument` | user's own `.json`, plus `autosave/<id>.autosave.json` |
| UI state (panel visibility/widths + ambient `ViewState`) | `persistence/diagram_workspace_state.dart` → `DiagramWorkspaceState` | `diagram_studio_workspace.json` |
| Temporary workspace state (open tabs, active tab, recently closed) | `tabs/diagram_tabs_storage.dart` → `DiagramTabsStorage` | `diagram_studio_tabs.json` |
| User preferences (new-document `ViewState` defaults) | `settings/diagram_studio_settings.dart` → `DiagramStudioSettings` | `diagram_studio_settings.json` |

A fifth, adjacent one exists and is likewise kept separate: instrument dock
layout (`instruments/dock/instrument_dock_storage.dart`).

### 1.3 Column meanings

Each entry table carries: **Location** (file + line range + member),
**Responsibility**, **Dest** (A–G), **Target** (the specific controller method
or new provider/service, for B/C), **Reason**, **Dependencies**, **Lifecycle
change?** (yes/no + why), **Must remain available to current UI?** (yes/no).

"Lifecycle change" means: does moving this alter *when* it runs, *how long* it
lives, or *what tears it down* — relative to today's `initState`/`build`/
`dispose` semantics.

---

## 2. Entry index

| Section | Entries | Theme |
|---|---|---|
| §3 | 1–14 | Widget identity, fields, and provider access |
| §4 | 15–34 | Bootstrap / init ordering |
| §5 | 35–48 | Subscriptions and listeners |
| §6 | 49–62 | Teardown / dispose |
| §7 | 63–77 | Document lifecycle |
| §8 | 78–90 | Tab lifecycle |
| §9 | 91–96 | Workspace persistence orchestration |
| §10 | 97–103 | Property Inspector bridge |
| §11 | 104–116 | Intelligence |
| §12 | 117–129 | Simulation + domain profile |
| §13 | 130–139 | Instruments + probes |
| §14 | 140–152 | Viewport / transform / framing |
| §15 | 153–171 | Editing delegations (already Wave 1) |
| §16 | 172–186 | Selection interaction |
| §17 | 187–192 | Contextual menu |
| §18 | 193–204 | Node drag, guides, resize |
| §19 | 205–216 | Ports, connections, wire creation |
| §20 | 217–221 | Drag-to-reconnect |
| §21 | 222–230 | Annotations |
| §22 | 231–243 | Wire route editing |
| §23 | 244–247 | Search |
| §24 | 248–271 | `build()` structure, panels, chrome |
| §25 | 272–288 | Private widgets declared in the same file |

**Total: 288 classified responsibility entries.**

Class totals are summarised in §26. Engine-call callout is §27. Flutter-owned
"must remain widget-owned" list is §28. Ambiguities and hazards are §29.

---

---

## 3. Widget identity, fields, and provider access

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 1 | `diagram_studio_page.dart:78–83` — `DiagramStudioPage` (`ConsumerStatefulWidget`) | The public Studio entry point registered as a workspace; addressed **by name** by `workbench/perspectives/diagram_perspective.dart`, `app/studio_shell.dart`, and 12 workflow tests | **A** | — | Audit §11.5 is explicit: this class keeps its name and remains the entry point; only its body shrinks | Riverpod `ProviderScope` above it | No | Yes |
| 2 | `:85` — `_DiagramStudioPageState extends ConsumerState` | The single `State` holding everything below | **A** | — | Survives as the composition root's state, reduced to: controller handle, loading flag, and the genuinely widget-owned resources in §28 | Flutter element tree, `WidgetRef` | No | Yes |
| 3 | `:91` — `DiagramStudioController? _controller` | Nullable handle to the Wave 1 controller, assigned in `_bootstrap` | **C** | New `diagramStudioControllerProvider` under `controller/`, exposing the already-constructed controller | Audit §11.5 step 2: the controller must be a provider so it outlives rebuilds and is reachable from the Command Registry / Ribbon, which today gets a *thinner* document pipeline than the page (entry 63) | `WidgetRef`, live `EngineeringEngine` | **Yes** — today the controller is created per page mount and dropped on unmount; as a provider it outlives navigation away and back, matching how `engineeringProjectServiceProvider` already outlives the page. Must be verified against the `isFirstStart` guard (entry 21) | Yes |
| 4 | `:97–98` — `controllerForTest` (`@visibleForTesting`) | Test-only accessor for the controller | **G** | — | Once the controller is a provider (entry 3), tests read the provider directly. Do not delete until the tests are re-pointed | — | No | No (test-only) |
| 5 | `:100` — `final TransformationController _transformController` | Backs `InteractiveViewer`'s matrix inside `GraphViewPanel` | **D** | Stays widget-owned; §28 item 1 | A `TransformationController` is a `ChangeNotifier` bound to one widget subtree's `InteractiveViewer`; it cannot live in a Flutter-free controller (spec §3.4: `Matrix4` never crosses) | Flutter gesture/animation layer | No | Yes |
| 6 | `:102` — `bool _loading` | Gates the `CircularProgressIndicator` until `_bootstrap` completes | **A** | — | A composition root legitimately owns "am I bootstrapped yet" | `_bootstrap` completion | No | Yes |
| 7 | `:103` — `int _spawnCounter` | Cycles the spawn position for toolbar-added nodes (6 across, 40px step) | **B** | `DiagramStudioController` — fold into `addNode(symbolId)` (dropping the `position` parameter) or add `addNodeAtNextSpawnSlot(symbolId)` | Placement *policy*, not Flutter state; it is the only reason `_addNode` still exists as a page method (entry 153) | None (pure counter) | **Yes** — the counter resets on unmount today, so spawn positions restart at the origin after navigating away and back. A provider-hosted controller makes it survive. Decide explicitly; if undesired, reset it when a document opens/closes | No |
| 8 | `:385–386` — `_cachedDocumentPath`, `_cachedViewState`, refreshed in `build()` at `:2058–2059` | A build-time snapshot of the shared provider's document path + ViewState so `dispose()` can persist workspace state without `ref.read` (Riverpod marks `ConsumerStatefulElement` disposed before the framework calls `dispose()`) | **G** | — | This mirror exists *only* to work around persisting from `dispose()`. If the persist moves to a provider with `ref.onDispose` (entry 91), the workaround is dead code | `ref.watch` result in `build()` | **Yes** — the final persist stops happening inside the widget's `dispose()`; see entry 49 | No |
| 9 | `:415` — `late final FoundationRuntimeNotifier _foundationNotifier` | Captured once in `initState`, for the same Riverpod-in-`dispose` reason as entry 8 | **C** | Fold every use into a new `diagramInspectorBridgeProvider` (entries 97–98); the page stops holding a notifier reference | The page holds this only to (a) push selection into the shared Property Inspector, (b) read `bridge` for Intelligence construction and the Sessions-panel gate — all application concerns | `foundationRuntimeServiceProvider` | **Yes** — the deferred `scheduleMicrotask` clear in `dispose()` (entry 55) is a direct consequence of holding it here; `ref.onDispose` removes the need for that hack | No |
| 10 | `:456` — `EngineeringEngine get engine => _controller!.engine` | Page-level engine accessor | **F** (accessor) / **A** (removal) | — | The engine is Engine-owned and already reached *through* the controller. Goal state: the page has **no** `engine` getter at all — every remaining use is enumerated in §27 | `_controller` | No | No |
| 11 | `:457–461` — `_document`, `_session`, `_selection`, `_viewState`, `_isDirty` | Read-through accessors onto `EngineeringProjectState` via the controller | **A** | — | Correct shape already (page → controller → provider, never page → provider). Each individual *use* is classified separately below | `_controller` | No | Yes (until the presentation split lands) |
| 12 | `:278` — `DiagramSimulationService get _simulationService` (`ref.read(...)!`) | Non-null accessor onto the shared simulation runtime | **C** | Already a provider; the `!` and the "safe only after `ensureEngineStarted()`" precondition move behind a `SimulationViewModel?` | The `!` encodes a precondition in a doc comment rather than in the type | `diagramSimulationServiceProvider`, engine started | No | Yes |
| 13 | `:293` — `MultimeterController? get _multimeter` | Accessor onto the shared `autoDispose` multimeter runtime | **C** | Already a provider — no move; only the call sites relocate with their widgets | `multimeterRuntimeServiceProvider` | No | Yes |
| 14 | `:922` — `ViewStateService get _viewStateService => engine.registry.viewState as ViewStateService` | Downcast accessor onto the Engine's viewport service | **F** | — | `ViewStateService` is Engine-owned (frozen). The **downcast** is already duplicated verbatim at `controller/diagram_studio_controller.dart:102`; the page's copy is deleted and the controller's becomes the only one | `engine.registry.viewState` | No | No |

---

## 4. Bootstrap / init ordering

Current order: `initState` → capture `_foundationNotifier` → fire-and-forget
`_bootstrap()` → `DiagramStudioController.bootstrap(ref:)` (internally: engine
start → tabs restore → workspace load → document restore → ViewState restore →
seed-tab fallback) → instruments → intelligence → UI-field application → mode
defaults → subscriptions → initial transform → initial inspector sync →
`_loading = false`.

Entries 16–22 record what **already** moved into the controller in Wave 2's
landed work, so the code-moving stage **verifies** rather than re-moves them.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 15 | `:503–508` — `initState()` | `super.initState()`, capture `_foundationNotifier`, fire `unawaited(_bootstrap())` | **A** | — | `initState` is a Flutter lifecycle hook only a `State` can provide; its body reduces to kicking off the provider-hosted bootstrap and awaiting it via the loading gate | Flutter `State` lifecycle | No | Yes |
| 16 | `:522–523` — `_bootstrap()` head; `await DiagramStudioController.bootstrap(ref: ref)` | The whole engine/document/tab bootstrap sequence | **B** (already done) | `DiagramStudioController.bootstrap` (`controller/…:427–471`) | Already extracted verbatim in Wave 2 — verify no regression | `WidgetRef` | No | — |
| 17 | `controller/…:428–431` — `ensureEngineStarted()` + controller construction | Engine startup coordination; records `isFirstStart` **before** starting | **B** (already done) | `bootstrap` step 1 | Engine start is idempotent and provider-owned (`EngineeringProjectNotifier.ensureEngineStarted`); the controller only sequences it | `engineeringProjectServiceProvider.notifier` | No | — |
| 18 | `controller/…:438–440` — `await ensureRestored()` then read `diagramTabsProvider` | Tab restoration, awaited before any fallback so async restore cannot race a seeded tab | **B** (already done) | `bootstrap` step 2 | `DiagramTabsNotifier._restore()` is async and would silently overwrite a seeded tab; the await is load-bearing ordering | `diagramTabsProvider` | No | — |
| 19 | `controller/…:442` — `await WorkspaceStateStorage.load()` | Workspace (UI-state) restoration read | **B** (already done) | `bootstrap` step 3; the loaded value is *returned* to the page, which applies its own UI-only fields | Keeps `DiagramWorkspaceState`'s UI fields out of the controller, per §1.2 | `WorkspaceStateStorage` (file I/O) | No | — |
| 20 | `controller/…:449–461` — `isFirstStart`-guarded document restore + `restoreViewState` | Document restoration (persisted tab path wins over `workspace.lastDocumentPath`), initial viewport restoration, and the try/catch fallback for a moved/deleted last-open file | **B** (already done) | `bootstrap` step 4 | Unifies restoration under one authoritative source; the guard is what stops a revisit from discarding live edits | `EngineeringProjectNotifier.openDocument`, `ViewStateService` | No | — |
| 21 | `controller/…:449` — the `isFirstStart` guard | "Only restore a document on the engine's very first start in this Studio session" | **B** (already done) — **highest-risk interaction in the Wave** | `bootstrap` | Correct today because the controller is per-mount and the engine outlives it. **If entry 3 makes the controller provider-hosted, re-verify**: `isFirstStart` derives from `engineHost == null`, which is engine-scoped, not controller-scoped, so it *should* remain correct — but this must be tested, not assumed | `engineeringProjectServiceProvider` | No, provided the derivation stays engine-scoped | — |
| 22 | `controller/…:466–468` — seed-tab fallback | Opens a tab for whatever document is now open, only when restoration found none (first launch ever) | **B** (already done) | `bootstrap` step 5 | Tab-list seeding is temporary-workspace-state orchestration, not UI | `diagramTabsProvider.notifier.openTab`, `titleForPath` | No | — |
| 23 | `:529` — `unawaited(_initInstruments())` | Fires instrument registry + dock construction without awaiting | **C** | New `diagramInstrumentsProvider` (async) exposing `(InstrumentRegistry, InstrumentDockController)` | Instruments are a "permanent subsystem" per WP-DS-005A and must be available "regardless of mode"; page-mount-scoped construction contradicts that | `multimeterRuntimeServiceProvider`, `InstrumentDockController.load()` (file I/O) | **Yes** — today the dock's persisted layout reloads from disk on every mount and is disposed on every unmount; a provider loads it once per app session. A behaviour improvement, but observable — call it out | Yes |
| 24 | `:296–309` — `_initInstruments()` | Builds `InstrumentRegistry`, registers `DigitalMultimeterInstrument` (with a `verificationReport: () => _simVerification` closure over page state), awaits `InstrumentDockController.load()`, `setState`s both in | **C** | Same provider as entry 23 | The only genuinely page-coupled part is the `_simVerification` closure — itself simulation state that should be provider-owned (entry 121), so the coupling dissolves | `MultimeterController`, `_simVerification`, `mounted` guard | **Yes** — as entry 23; the `if (!mounted) return` guard becomes meaningless in a provider and must be replaced with provider-disposal semantics | Yes |
| 25 | `:539–541` — bridge read + `DiagramIntelligenceService` construction | One `DiagramIntelligenceService` per open document, with `DiagramRepositoryService(bridge)`; stays `null` when the Foundation bridge has not started | **C** | New `diagramIntelligenceProvider` (nullable, watching `foundationRuntimeServiceProvider`) | Audit §13 row 29 keeps the service KEEP but moves its triggers to the controller. Its *lifecycle* is page-mount-scoped today, which is wrong for a per-document service | `FoundationBridge`, `DiagramRepositoryService` | **Yes** — constructed on mount, disposed on unmount today, so navigating away discards Intelligence state mid-document. Also latent bug: a bridge that starts *after* the page mounts leaves Intelligence permanently null until remount; a provider that watches the bridge fixes that. Flag as a deliberate behaviour change | Yes |
| 26 | `:547` — `_controller!.intelligence = _intelligence` | Hands the controller the same service reference so `markDirty()` can drive the debounced sync | **B/C seam** | The controller reads `diagramIntelligenceProvider` itself instead of taking a mutable field assignment | The mutable field exists only because the page owns the lifecycle. After entry 25, `DiagramStudioController.intelligence` becomes a `ref.read` and the settable field is deleted | `_controller`, `_intelligence` | No (same object, same timing) | No |
| 27 | `:553–556` — `_showLayerPanel`/`_showSearchPanel`/`_explorerWidth`/`_sidePanelsWidth` applied from the loaded workspace | Workspace restoration of **UI-state** fields | **C** | New `diagramStudioLayoutController` (audit §11.1 names it) — a Riverpod notifier owning all panel visibility/geometry, loading from and saving to `DiagramWorkspaceState` | These four are UI state (§1.2 category 2), correctly excluded from the controller — but they are not *widget* state either: they are persisted, and the V2 panel model (audit §13 row 46) grows them substantially | `DiagramWorkspaceState` from `bootstrap` | **Yes** — panel layout currently resets to persisted values on every mount; a provider keeps it live across navigation. Persisted values themselves unaffected | Yes |
| 28 | `:561` — `_applyModeDefaults(activeTab?.mode ?? edit)` | Applies mode-driven panel-visibility defaults for the restored active tab's mode | **C** | `diagramStudioLayoutController.applyModeDefaults(mode)` | Same owner as entry 27; it mutates exactly those fields | `diagramTabsProvider`, entry 27's fields | No (same trigger point) | Yes |
| 29 | `:492–501` — `_applyModeDefaults(DiagramStudioMode)` body | View mode collapses Object Explorer/Layers/Search/Annotations/Recent Commands; Edit/Simulate restore them. Wrapped in `setState` | **C** | `diagramStudioLayoutController.applyModeDefaults` | "MODE DETERMINES WHAT IS VISIBLE" is a layout policy with three call sites (bootstrap, tab activation, mode switch) — exactly a controller method's shape | `DiagramStudioMode` (from `core/context/`) | No | Yes |
| 30 | `:563–566` — `_selectionSub` creation | See entry 35 | **C** | — | — | — | — | — |
| 31 | `:567` — `_viewStateSub` creation | See entry 38 | **D** | — | — | — | — | — |
| 32 | `:570` — `_applyTransformFromViewState(_viewState)` | Establishes the `TransformationController` matrix immediately rather than waiting for the first `ViewState` change — **initial viewport restoration into the widget layer** | **D** | Stays widget-owned; §28 item 1 | Writes a `Matrix4` into a Flutter `TransformationController`; spec §3.4 forbids `Matrix4` crossing the boundary | `_transformController`, `_viewState` | No | Yes |
| 33 | `:574` — `_syncPropertyInspectorSelection()` | Initial selection restoration into the *shared Property Inspector* on (re)mount, because another workspace may have left it showing something else | **C** | `diagramInspectorBridgeProvider` (entries 97–98) | Cross-workspace shared-state sync is an application concern, not a render concern | `_foundationNotifier`, `_session`, `_selection` | **Yes** — a provider owning this would keep the Inspector in step even while Diagram Studio is unmounted, which is *not* today's behaviour (today it deliberately clears on unmount, entry 55). The intended semantics must be **decided**, not assumed — §29 item 6 | Yes |
| 34 | `:576` — `setState(() => _loading = false)` | Flips the loading gate after all of the above | **A** | — | Pure widget-render gate; the last line of the composition root's bootstrap | `_bootstrap` completion. **Not `mounted`-guarded** — §29 item 5 | No | Yes |

---

## 5. Subscriptions and listeners

Complete inventory. Note that **the page owns only two stream subscriptions**;
the rest of the reactive surface is Riverpod `watch`, `ChangeNotifier`
`AnimatedBuilder`s, or subscriptions owned elsewhere (recorded here so the
code-moving stage does not mistake them for page-owned).

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 35 | `:425` field + `:563–566` — `StreamSubscription<GraphSelection>? _selectionSub` on `engine.registry.selection.changes` | Page-local reaction to selection change: re-seed "Edit Route" working points, and push the new selection into the shared Property Inspector | **Split C + D** | The Inspector push → `diagramInspectorBridgeProvider` (entry 97). The wire-edit re-seed → stays with the wire-edit interaction state (entry 232), which is gesture state and may stay widget/controller-local | Two unrelated reactions ride one subscription today. They have different owners and must be split before either moves | `engine.registry.selection.changes` (broadcast), `_wireEditModeActive` | **Yes** for the Inspector half (see entry 33). **No** for the wire-edit half if the wire-edit buffer stays widget-local | Yes |
| 36 | `:563` — the listener's unused `s` parameter | Listener ignores the emitted `GraphSelection` and re-reads `_selection` instead | **G** | — | Harmless but misleading: it implies the callback is value-driven when it is actually a change *notification*. Clean up when split | — | No | No |
| 37 | `core/services/engineering_project_service.dart:113–115` — `EngineeringProjectNotifier._selectionSub` | The **second, independent** listener on the same broadcast stream, relaying selection into `EngineeringProjectState` | **C** (already correct) | — | Recorded so the code-moving stage does not "consolidate" the two: they have different lifetimes (provider vs page) and different purposes. Do not merge | `engineeringProjectServiceProvider` | No | — |
| 38 | `:447` field + `:567` — `StreamSubscription<ViewState>? _viewStateSub` on `_viewStateService.changes` → `_applyTransformFromViewState` | Mirrors every `ViewState` zoom/pan change into `_transformController.value` (Fit All, Fit Selection, Center Selection, View Reset, Go Back/Forward, background space-drag pan) | **D** | Stays widget-owned; §28 item 1 | Its whole purpose is writing a `Matrix4` into a Flutter controller. Spec §3.4 lists `Matrix4` as never crossing the boundary | `_viewStateService.changes`, `_transformController`, `mounted` | No | Yes |
| 39 | `core/services/engineering_project_service.dart:110–112` — `_sessionSub` on `engine.editing.sessionChanges` | Relays each new `EditingSession` into `EngineeringProjectState` **and recomputes `validationReport` on every session change** | **C** (already correct) | — | The page has no session subscription of its own — it reacts via `ref.watch`. Recorded because the *automatic revalidation* on every edit lives here, not in the page, and must not be duplicated into the controller | `engineeringProjectServiceProvider` | No | — |
| 40 | `core/services/engineering_project_service.dart:116–118` — `_viewStateSub` | Relays `ViewState` into `EngineeringProjectState` | **C** (already correct) | — | Third subscription on the same Engine streams; again do not consolidate with entry 38 (different purpose: state relay vs matrix mirroring) | — | No | — |
| 41 | `:2057` — `ref.watch(engineeringProjectServiceProvider)` in `build()` | The page's rebuild subscription to session/selection/viewState/validation, including changes made from *other* routes | **A** | — | Composition roots watch; this is exactly the shape audit §11.5 step 1 prescribes | `WidgetRef` | No | Yes |
| 42 | `:2062` — `ref.watch(diagramTabsProvider)` in `build()` | Rebuild subscription for the tab bar and mode switcher | **A** | — | Same as entry 41 | `WidgetRef` | No | Yes |
| 43 | `:2085–2087`, `:2116`, `:2370` — implicit reads of `_simulationService.currentSession` during `build()` | The page reads live simulation session state synchronously in `build()` with **no subscription at all**; refresh depends on some other `setState` happening | **C** | `diagramSimulationServiceProvider` exposed as a watchable view-model | This is a real correctness gap, not just a style issue: `DiagramSimulationService` is a `ChangeNotifier` that the page deliberately does **not** watch (see the long comment at `:262–277`, which explains the choice as a rebuild-cost trade-off). Any state change not accompanied by a manual `setState` is silently not rendered | `diagramSimulationServiceProvider` | **Yes** if converted to a watch — that is precisely the rebuild-frequency change the existing comment warns about. Must be done as a scoped `select`/view-model, not a blanket `watch`, or the page rebuilds on every measurement | Yes |
| 44 | `:2375`, `:2564`, `:2570` — reads of `_intelligence!.busy` / `_multimeter!.latestResult` during `build()` | Same pattern as entry 43 for Intelligence and the multimeter | **C/D** | `diagramIntelligenceProvider` view-model; the multimeter reads already have an `AnimatedBuilder` in `_ImmersiveMeterPane` (entry 277) but **not** at these canvas-overlay call sites | Inconsistent: the same `ChangeNotifier` is observed properly in one place and read unobserved in another | `_intelligence`, `_multimeter` | **Yes** if converted — same caution as entry 43 | Yes |
| 45 | `:2396–2398`, `:2808` — reads of `_dockController!.state.visible` during `build()` | Dock visibility read without watching `InstrumentDockController` (a `ChangeNotifier`) | **C** | `diagramInstrumentsProvider` (entry 23) | Same class of gap as entries 43–44 | `_dockController` | **Yes** if converted | Yes |
| 46 | `:2101`, `:2116`, `:2370`, and ~30 other inline `setState(() {})` / `onChanged: () => setState(() {})` callbacks | UI-local "something changed, repaint" notifications from child widgets and dialogs | **D** | Replaced by real observation of the underlying notifier/provider | These exist *because* of entries 43–45: the page compensates for not subscribing by having children poke it. Each one disappears when its source is watched properly | child widget callbacks | **Yes** — repaint timing changes from "when a child says so" to "when the state actually changes". Behaviourally equivalent or better, but visible in widget tests that count rebuilds | Yes (until the underlying watch lands) |
| 47 | `:1189–1206` — the `unawaited(() async { … })()` continuation after `showDiagramContextMenu` | Post-contextual-command reaction: `setState(() {})` + `_reactToExternalEdit()` | **B** | `DiagramStudioController.markDirty()` is already the call; only the `setState` is presentational | The Contextual Command System executes Engine commands **outside** the controller by design (spec §3.5); this continuation is the sanctioned fold-back point and must be preserved exactly | `mounted`, `_controller` | No | Yes |
| 48 | *(absent)* — no `didChangeDependencies`, no `WidgetsBindingObserver`, no `AnimationController`, no page-owned `Timer` | — | **A** | — | Recorded as a **negative finding**, deliberately: the Wave 2 brief asks for timer cancellation and animation-controller disposal. **The page owns neither.** The only debounce timer lives inside `DiagramIntelligenceService` (disposed via entry 52); the only periodic timer lives inside `MultimeterController` (torn down by its `autoDispose` provider). There is no `TickerProvider` mixin on this `State` | — | No | — |

---

## 6. Teardown / dispose

`dispose()` is `:599–631`. Every statement is classified.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 49 | `:607` — `unawaited(_persistWorkspaceState(useCached: true))` | Final workspace-state write on unmount, using the cached path/ViewState (entry 8) because `ref.read` is unusable in `dispose()` | **C** | `diagramStudioLayoutController` persists on change and/or via `ref.onDispose` | Persisting UI state is not a widget responsibility; the `useCached` workaround exists only because it is performed here | `WorkspaceStateStorage`, `_cachedDocumentPath`, `_cachedViewState` | **Yes, materially** — today the write happens on *unmount*. Moving it to a provider changes it to "on change" and/or "on provider disposal", which fires at app teardown rather than navigation. Since every mutating path already calls `_persistWorkspaceState()` eagerly (entries 63–77, 92), the unmount write is largely redundant belt-and-braces; **confirm that before removing it** | No |
| 50 | `:608` — `_selectionSub?.cancel()` | Cancels the selection subscription | **Split C + D** | Follows entry 35's split: the Inspector half's cancellation becomes `ref.onDispose` in the provider; the wire-edit half stays in `dispose()` | Subscription cancellation must travel with the subscription | `_selectionSub` | **Yes** for the Inspector half — it would stop being cancelled on unmount and start being cancelled on provider disposal. **This is the single most likely source of a leak or a double-fire regression in Wave 2** | Yes |
| 51 | `:609` — `_viewStateSub?.cancel()` | Cancels the ViewState→matrix subscription | **D** | Stays in `dispose()` | Its subscription stays widget-owned (entry 38), so its cancellation must too | `_viewStateSub` | No | Yes |
| 52 | `:610` — `_intelligence?.dispose()` | Disposes `DiagramIntelligenceService`, which owns the **debounced sync timer** | **C** | `ref.onDispose` inside `diagramIntelligenceProvider` (entry 25) | The service's lifetime is per-document, not per-mount | `_intelligence` | **Yes** — the debounce timer currently dies on unmount; under a provider it dies when the document/provider does. A pending debounced sync could therefore now complete *after* navigating away. That is arguably correct (the edit really happened) but is a real behaviour change | No |
| 53 | `:617` — `_instruments?.dispose()` | Disposes `InstrumentRegistry` | **C** | `ref.onDispose` inside `diagramInstrumentsProvider` (entry 23) | Follows its construction | `_instruments` | **Yes** — instruments survive navigation instead of being rebuilt per mount; this is the stated intent of "permanent subsystem" but is a change from today | No |
| 54 | `:618` — `_dockController?.dispose()` | Disposes `InstrumentDockController` | **C** | Same provider as entry 53 | Follows its construction | `_dockController` | **Yes** — as entry 53; dock position/visibility stops resetting on remount | No |
| 55 | `:626–629` — `scheduleMicrotask(foundationNotifier.clearEngineeringInspectableSelection)` | Clears the shared Property Inspector's selection on unmount, **deferred by a microtask** because Riverpod forbids mutating provider state while the tree is finalising (e.g. a GoRouter navigation away) | **C** | `ref.onDispose` inside `diagramInspectorBridgeProvider` (entry 97) | The microtask is a workaround for doing provider mutation from `dispose()`. A provider that owns the sync can clear itself without it | `_foundationNotifier` | **Yes** — and the *policy* changes too: should the Inspector clear when Diagram Studio unmounts at all? See §29 item 6. Do not silently change this; decide it | Yes (behaviour), No (mechanism) |
| 56 | `:611–616` — comment: `_multimeter` deliberately **not** disposed here | Documents that the multimeter's `autoDispose` provider owns its teardown (including its live-mode timer) | **C** (already correct) | — | Recorded so nobody "fixes" the apparent omission by adding a dispose call | `multimeterRuntimeServiceProvider` | No | — |
| 57 | `:619–622` — comment: Instrument Bridge deliberately **not** stopped here | The bridge is app-wide (`instrumentBridgeServiceProvider`, controlled from Settings) and must survive page unmount/remount | **C** (already correct) | — | Same reason as entry 56 | `instrumentBridgeServiceProvider` | No | — |
| 58 | `:601–606` — comment: the Engine outlives the page | `engineeringProjectServiceProvider` disposes the `EngineHost`, not this page | **C** (already correct) | — | WORK_PACKAGE_025 resolution; recorded so no stage reintroduces page-owned engine teardown (audit R1) | `engineeringProjectServiceProvider` | No | — |
| 59 | **`_transformController` is never disposed** (declared `:100`, absent from `dispose()`) | A `TransformationController` is a `ChangeNotifier` and should be disposed | **D** — **defect** | Add `_transformController.dispose()` in `dispose()` when the page is rewritten | Verified by inspection: `dispose()` (`:599–631`) contains no reference to it. Leaks a listener-bearing object per page mount | — | No (fixing it is a pure leak fix) | Yes |
| 60 | `:1745` — `TextEditingController` created inside `_editAnnotationText` | Created per invocation for the annotation-edit dialog and **never disposed** | **D** — **defect** | Dispose it after the dialog completes, or use a `StatefulWidget` dialog that owns it | Same class of defect as entry 59, per dialog invocation | `showDialog` | No | Yes |
| 61 | *(absent)* — no focus-node disposal | The page uses `Focus(autofocus: true)` (`:2136–2137`) with **no explicit `FocusNode`** | **D** | — | Recorded as a negative finding against the Wave 2 brief's "focus-node disposal": there is no page-owned `FocusNode`; `Focus` creates and disposes its own internally. Nothing to move | Flutter focus system | No | Yes |
| 62 | *(absent)* — no listener-removal calls | No `addListener`/`removeListener` pairs exist on the page; all `ChangeNotifier` observation is via `AnimatedBuilder` (entry 277) or unobserved reads (entries 43–45) | **D** | — | Negative finding against the brief's "listener cleanup". Nothing to move — but entries 43–45 mean listeners will be *added* by this Wave, and those must arrive with their own disposal | — | — | — |

---

## 7. Document lifecycle

**Do not conflate.** This section is about `DiagramDocument` only — the
engineering-data envelope (graph + layout + metadata + autosave). Tab entries
are §8; `DiagramWorkspaceState` is §9; `DiagramStudioSettings` is entry 128.

Every method below already delegates its *sequencing* to
`DiagramStudioController` (Wave 2 landed). What remains page-side in each is
the same three things: the `BuildContext`-bound confirmation/file-picker
dialog, the `_persistWorkspaceState()` call, and a bare `setState(() {})`.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 63 | `:794–799` — `_newDocument()` | Dirty-check → confirm → `_controller!.newDocument()` → persist workspace → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.newDocument()` (`controller/…:499–502`) | Sequencing already moved. The residue is dialog + persist + repaint. **Note the standing gap** documented at `:2826–2835`: the Ribbon's `diagram.newDocument` command is a *thinner* implementation that skips both the confirmation and the persist — a real divergence this Wave should close by routing the Ribbon through the same controller | `context` (dialog), `_isDirty`, `_controller` | No | Yes |
| 64 | `:801–814` — `_confirmDiscardChanges()` | The "Discard unsaved changes?" `AlertDialog`, returning `bool` | **D** | Stays page/presentation-side; §28 item 3 | Needs a `BuildContext`, which spec §3.4 lists as never crossing into the controller. Must remain evaluated at exactly the same point in each sequence as today | `context`, `Navigator` | No | Yes |
| 65 | `:816–823` — `_openDocument()` | Dirty-check → confirm → `openFile(...)` picker → `_controller!.openDocument(path)` → persist → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.openDocument(path)` (`controller/…:504–507`) | As entry 63 | `context`-free `openFile` from `file_selector`, `_diagramFileTypeGroup` (`:60`) | No | Yes |
| 66 | `:60` — `const _diagramFileTypeGroup = XTypeGroup(label: 'Diagram', extensions: ['json'])` | The file-picker type filter for open/save-as | **D** | Moves with the picker call sites | It is a picker-UI descriptor, not document schema | `file_selector` | No | Yes |
| 67 | `:825–833` — `_saveDocument()` | If `path == null` delegate to Save As; else `_controller!.saveDocument()` → persist → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.saveDocument()` (`controller/…:509`) | The `path == null` branch is a genuine *policy* decision ("Save on a never-saved document means Save As") that arguably belongs in the controller — but it is currently the trigger for a `BuildContext`-bound picker, so it must stay where the picker is reachable | `_document.path`, `_saveAsDocument` | No | Yes |
| 68 | `:835–841` — `_saveAsDocument()` | `getSaveLocation(...)` picker (suggested name `diagram.json`) → `_controller!.saveDocumentAs(path)` → persist → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.saveDocumentAs(path)` (`controller/…:511–514`), which also calls `updateActiveTabDocument(path:, title:)` | Sequencing already moved, **including the tab-title update** — that is the single point where document lifecycle legitimately touches tab state | `file_selector`, `_controller` | No | Yes |
| 69 | `:843–853` — `_closeDocument()` | If a tab is active, delegate entirely to `_closeTab(activeId)`; otherwise dirty-check → confirm → `_controller!.closeDocument()` → persist → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.closeDocument()` (`controller/…:516`) | The tab-delegation branch is why document-close and tab-close cannot be classified independently; the tab path is the real one in practice since bootstrap always seeds a tab (entry 22) | `_controller!.activeTabId`, `_closeTab` | No | Yes |
| 70 | `controller/…:499–502` — `newDocument()` | `EngineeringProjectNotifier.newDocument()` then `openTab(path: null, title: 'Untitled Diagram')` | **B** (already done) | — | Verify | `engineeringProjectServiceProvider`, `diagramTabsProvider` | No | — |
| 71 | `controller/…:504–507` — `openDocument(path)` | `EngineeringProjectNotifier.openDocument(path)` then `openTab(path:, title: titleForPath(path))` | **B** (already done) | — | Verify | as above | No | — |
| 72 | `controller/…:401–406` — `static String titleForPath(String?)` | Basename extraction for tab titles; `null` → `'Untitled Diagram'` | **B** (already done) | — | Moved verbatim from the page's former `_titleForPath`. **Note the duplication**: `DiagramDocument._titleFromPath` (`host/diagram_document.dart`) does the same job but additionally strips the `.json` extension, for document *metadata* title. Two different titles by design — do not "unify" them | — | No | — |
| 73 | `host/diagram_document.dart` — `open`/`save`/`saveAs`/`close`/`markDirty`/`autosave`/`findRecovery`/`recoverFrom` | The actual engineering-data persistence: JSON envelope (`schemaVersion`, `documentId`, `graph`, `layout`, `metadata`), autosave to a *separate* recovery file, recovery discovery | **C** (already correct — KEEP, audit §13 rows 5, §12.4) | — | Platform component with a studio-shaped path (audit §12.3(b)). Never add UI state to this envelope | `EngineeringGraph.toJson`, `DiagramLayoutState.toJson`, `SettingsStorage.root()` | No | — |
| 74 | `core/services/engineering_project_service.dart:141–175` — `newDocument`/`openDocument`/`saveDocument`/`saveDocumentAs`/`closeDocument` | The provider-level document operations the controller calls: engine session reset/`beginEditingSession`, `_applyNewDocumentViewStateDefaults`, state republish | **C** (already correct — **frozen by audit §13.2**) | — | This file is on the explicit "not to be touched" list. The controller may only *call* it | `EngineHost`, `DiagramDocument`, `diagramStudioSettingsProvider` | No | — |
| 75 | `core/services/engineering_project_service.dart:135–140` — `_applyNewDocumentViewStateDefaults` | Applies `DiagramStudioSettings` (grid/snap/guides defaults) to `ViewStateService` on every new/closed document | **C** (already correct) | — | **This is the only consumer of `DiagramStudioSettings` in the document path.** Classified here explicitly so it is not confused with `DiagramWorkspaceState.viewState` (entry 94), which restores the *last session's* viewport rather than the *preference defaults*. Two different mechanisms writing the same `ViewStateService` | `diagramStudioSettingsProvider` | No | — |
| 76 | `core/services/engineering_project_service.dart:177–182` — `markDocumentDirty()` | Sets `DiagramDocument.isDirty` and republishes state, guarded so it only republishes on a false→true transition | **C** (already correct) | — | The single dirty-state writer. `DiagramStudioController.markDirty()` (`controller/…:117–120`) is its single Diagram-Studio caller, closing audit hazard §9.4 / risk R2 | `engineeringProjectServiceProvider` | No | — |
| 77 | `:690` — `void _reactToExternalEdit() => _controller!.markDirty()` | The one remaining page-local dirty trigger: folds the Contextual Command System's side effects into Diagram Studio's dirty/Intelligence pathway | **B** | `DiagramStudioController.markDirty()` — already the call; the page-side wrapper disappears with the context menu's move (entry 192) | Sanctioned by spec §3.5 as the fold-back point for the intentionally-outside-the-controller contextual command system | `_controller` | No | Yes |

---

## 8. Tab lifecycle

**Do not conflate.** `DiagramTab` is a *reference* (id/path/title/pinned/mode) to
a document; `DiagramTabsStorage` persists the open list, active id, and recently
closed. `DiagramTabsNotifier` is deliberately document-lifecycle-agnostic (see
its own doc comment) — it never opens, closes, or saves a document. That
separation is load-bearing and must survive.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 78 | `:863–869` — `_closeTab(id)` | Reads `wasActive` **before** deciding on the dialog; dirty-check → confirm (only when closing the *active* tab) → `_controller!.closeTab(id, wasActive:)` → persist → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.closeTab(id, wasActive:)` (`controller/…:525–540`) | The `wasActive`-before-dialog ordering is load-bearing: closing a *background* tab has nothing live to lose, so it must not prompt | `_controller!.isActiveTab`, `_isDirty`, `context` | No | Yes |
| 79 | `controller/…:525–540` — `closeTab` body | If active: `closeDocument()` → `tabs.closeTab(id)` → reload the newly-active tab's real document via `openDocument`/`newDocument` | **B** (already done) | — | This is the "single shared engine holds one document" reconciliation. Verify it is not duplicated anywhere | `engineeringProjectServiceProvider`, `diagramTabsProvider` | No | — |
| 80 | `:877–888` — `_activateTab(id)` | No-op if already active → dirty-check → confirm → `_controller!.activateTab(id)` → `_applyModeDefaults(returnedMode)` → persist → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.activateTab(id)` returning `DiagramStudioMode?` (`controller/…:546–557`) | The controller returns the mode precisely so the page can re-apply panel defaults without the controller owning panel state. After entry 27/29, `_applyModeDefaults` becomes a layout-controller call and this line stays as a two-controller hand-off | `context`, `_controller` | No | Yes |
| 81 | `controller/…:546–557` — `activateTab` body | Looks up the target tab; opens its real document (or a new one for `path == null`); then `tabs.activate(id)`; returns its mode | **B** (already done) | — | Ordering matters: the document is loaded *before* the tab is marked active | as above | No | — |
| 82 | `:893–898` — `_reopenRecentlyClosed(entry)` | Dirty-check → confirm → `_controller!.reopenRecentlyClosed(entry)` → persist → `setState` | **A** (residual) + **B** (already done) | `DiagramStudioController.reopenRecentlyClosed(DiagramTab)` (`controller/…:559–568`) | Reopens via the same open pipeline, then removes the history entry — never a second document model | `context`, `_controller` | No | Yes |
| 83 | `:906–918` — `_showRecentlyClosedMenu(BuildContext)` | Reads `diagramTabsProvider.recentlyClosed`, computes a global position via `context.findRenderObject()`, shows a `showMenu`, and reopens the chosen entry | **D** | Moves with the tab bar into `presentation/chrome/` | `findRenderObject`/`showMenu` are `BuildContext`-bound UI. **Exception to note:** this is currently the page's *only* direct `ref.read(diagramTabsProvider)` for data (as opposed to via the controller); a view-model should supply the list | `context`, `RenderBox`, `diagramTabsProvider` | No | Yes |
| 84 | `:2191` — `onTogglePin: (id) => _controller!.togglePin(id)` | Pin toggle wired straight to the controller | **B** (already done) | `DiagramStudioController.togglePin` (`controller/…:576`) | Single unsequenced tab mutation; exists purely so the page never reads `diagramTabsProvider.notifier` directly | `_controller` | No | Yes |
| 85 | `:2203–2207` — mode-switcher `onModeChanged` | `_controller!.setTabMode(activeId, mode)` then `_applyModeDefaults(mode)` | **B** + **C** | `DiagramStudioController.setTabMode` (`controller/…:578`) + `diagramStudioLayoutController.applyModeDefaults` | Two distinct concerns (persisted tab mode vs transient panel visibility) that must stay separately owned — audit §11.4's two-dimension model depends on it | `_controller`, tabs state | No | Yes |
| 86 | `tabs/diagram_tabs_controller.dart` — `DiagramTabsNotifier` (`openTab`/`activate`/`closeTab`/`togglePin`/`setMode`/`updateActiveTabDocument`/`removeFromRecentlyClosed`/`clearRecentlyClosed`) | Pure tab-list/history state, each mutation auto-persisting via `unawaited(_persist())` | **C** (already correct — KEEP, audit §13 row 75) | — | Deliberately document-lifecycle-agnostic. **Do not add document calls to it** — that is what avoids a second document model | `DiagramTabsStorage` | No | — |
| 87 | `tabs/diagram_tabs_controller.dart:47–63` — `build()` / `ensureRestored()` / `_restore()` | Tab restoration: kicks off async load in `build()`, exposes an awaitable so bootstrap cannot race it | **C** (already correct) | — | The awaitable is the fix for the seed-vs-restore race (entry 18) | `DiagramTabsStorage.load()` | No | — |
| 88 | `tabs/diagram_tabs_storage.dart` — `DiagramTabsStorage` | Temporary-workspace-state persistence (`diagram_studio_tabs.json`), capped at `maxRecentlyClosed = 10` | **C** (already correct — §1.2 category 3) | — | Separate file, separate category from workspace state and settings | `SettingsStorage.root()` | No | — |
| 89 | `tabs/diagram_tab.dart` — `DiagramTab` | The tab value type: `id`, nullable `path`, `title`, `pinned`, `mode` | **C** (already correct — KEEP, audit §13 row 73) | — | `path == null` maps to a genuinely unsaved document, matching `DiagramDocument.path`'s real nullability | `DiagramStudioMode` | No | — |
| 90 | `tabs/diagram_tabs_controller.dart:78–92` — `openTab`'s path-dedup | A tab already representing the same path is reused and activated, not duplicated | **C** (already correct) | — | Recorded because it is the reason `openDocument` is safe to call repeatedly from bootstrap, activate, and reopen paths without leaking tabs | — | No | — |

---

## 9. Workspace persistence orchestration

**Do not conflate.** `DiagramWorkspaceState` is UI state plus *ambient* session
`ViewState` — deliberately never graph/layout (§1.2 category 2). Audit §12.4
rules this mixture correct and requires the exclusion to be preserved.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 91 | `:586–597` — `_persistWorkspaceState({bool useCached = false})` | Assembles a `DiagramWorkspaceState` from the page's own panel fields plus document path + ViewState, then hands it to `_controller!.persistWorkspaceState(...)` | **C** | `diagramStudioLayoutController.persist()` — the notifier owns the panel fields (entry 27) and calls the controller for the write | The *assembly* is the page's only remaining reason to know these fields exist. Once the layout controller owns them, assembly moves with them. The controller keeps owning the disk write (correct: it is the sequencing/IO side) | `_controller`, panel fields, `_document.path`/`_viewState` or their cached twins | **Yes** — see entry 49; the `useCached` parameter disappears entirely | No |
| 92 | `:797, 821, 831, 839, 851, 867, 886, 896, 2324, 2346` — the ten `unawaited(_persistWorkspaceState())` call sites | Eager persistence after every document/tab operation and after the Layers/Search panel toggles | **C** | Same as entry 91 | Note the **asymmetry**: only two of the eleven panel-visibility toggles persist (Layers at `:2322–2325`, Search at `:2344–2347`). The other nine (`_showObjectExplorerPanel`, `_showAnnotationsPanel`, `_showRecentCommandsPanel`, `_showLegendPanel`, `_showMiniMap`, and the five Intelligence panels) only `setState` and are lost on restart — because `DiagramWorkspaceState` has no fields for them. Do not "fix" this silently; it is an intentional schema limit that audit §13 row 46 schedules for the V2 panel-layout schema | `_persistWorkspaceState` | No | No |
| 93 | `persistence/diagram_workspace_state.dart` — `DiagramWorkspaceState` | The UI-state value type: `lastDocumentPath`, `showLayerPanel`, `showSearchPanel`, `explorerWidth`, `sidePanelsWidth`, `viewState` | **C** (ADAPT — audit §13 row 46) | Schema grows to the V2 panel model at its own wave | Deliberately excludes graph/layout. Keep both that exclusion **and** the `ViewState` inclusion when the schema changes | `ViewState` | No | — |
| 94 | `persistence/diagram_workspace_state.dart` — the `viewState` field specifically | Ambient session viewport (zoom/pan/grid/guides), restored at bootstrap by `controller.restoreViewState` (`controller/…:386–394`) | **C** (already correct) | — | Classified separately from entry 93 because it is the one field that is *not* UI chrome, and because it collides conceptually with `DiagramStudioSettings`' new-document defaults (entry 75). Both write `ViewStateService`; only their triggers differ | `ViewStateService` | No | — |
| 95 | `persistence/workspace_state_storage.dart` — `WorkspaceStateStorage.load/save` | File I/O for `diagram_studio_workspace.json` under `SettingsStorage.root()`, with `FormatException` → defaults | **C** (already correct — KEEP) | — | UI-agnostic storage; the controller's `persistWorkspaceState` (`controller/…:485`) is a one-line delegate to it | `SettingsStorage.root()` | No | — |
| 96 | `:150–174` — `_panelSlot`, `_slotSize`, `_movePanel`, `_resizeSlot` | Which `PanelDockSlot` each `DockablePanel` occupies, and one shared thickness per slot (clamped 80–640) — explicitly **runtime-only, not persisted** | **C** | `diagramStudioLayoutController` (entry 27), whose persisted schema should absorb them at the V2-panel-model wave | Audit §12.4 flags this as duplicating `instruments/dock/instrument_dock_storage.dart`'s category and directs unification into a single V2 panel model. Until then it stays unpersisted — do not add a second storage file | `PanelDockSlot`, `DockablePanel` | **Yes** if persisted — panel arrangement would begin surviving restart, which it does not today. That is the intended end state but is a user-visible change; land it deliberately | Yes |

---

## 10. Property Inspector bridge

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 97 | `:635–671` — `_syncPropertyInspectorSelection()` | Translates the Engine's `GraphSelection` into an `EngineeringInspectable` for the **shared, app-wide** Property Inspector: single-selection only, in priority order node → relationship → group → annotation; clears otherwise | **C** | New `diagramInspectorBridgeProvider` — a notifier that watches selection + session and writes `FoundationRuntimeNotifier.selectEngineeringInspectable`/`clear…` | This is cross-workspace application state synchronisation (`shared/widgets/property_inspector_panel.dart` is on audit §13.2's do-not-touch list, and its notifier is app-wide). It is not rendering, and it is not an Engine command | `_foundationNotifier`, `_session.graph.nodes/relationships/groups`, `_session.layout.annotationOf`, `_selection` | **Yes** — see entries 33 and 55. Today it runs only while the page is mounted and clears on unmount. As a provider it can outlive the page. **Decide the policy first** (§29 item 6) | Yes |
| 98 | `:673–675` — `_selectLayerInInspector(DiagramLayer)` | Pushes a `DiagramLayer` into the same shared Inspector — the one inspectable kind not reachable through `GraphSelection` | **C** | Same provider as entry 97, as an explicit `selectLayer(layer)` intent | Layers have no representation in `GraphSelection`, so this is a genuinely separate entry point, not a special case of entry 97 | `_foundationNotifier`, `EngineeringInspectable.layer` | **Yes** — same as entry 97 | Yes |
| 99 | `:2662` — `DiagramLayerPanel.onSelectLayer: _selectLayerInInspector` | Layers panel wiring for entry 98 | **D** | Moves with the Layers panel (audit §13 row 35 → toggled floating panel) | Pure intent wiring | entry 98 | No | Yes |
| 100 | `:2009` — `_goToSearchResult`'s `SearchResultKind.layer` case calling `_selectLayerInInspector` | The second caller of entry 98 | **B/D seam** | The search-result navigation moves to the controller (entry 246); the Inspector push is an intent it emits | Recorded separately so the layer-inspector coupling is not lost when search navigation moves | entry 98 | No | Yes |
| 101 | `core/models/engineering_inspectable.dart` — `EngineeringInspectable` factories (`node`/`relationship`/`group`/`annotation`/`layer`) | The value type crossing into the shared Inspector | **C** (already correct) | — | An immutable value type — exactly what spec §3.4 permits to cross the boundary | — | No | — |
| 102 | `inspector/*.dart` (8 files) — `EngineeringNodeProperties` etc. | The shared Property Inspector's per-kind modes | **D** (already correct — KEEP untouched, audit §12.3(c)) | — | On the presentation side but belonging to the *shared* Inspector, not to Diagram Studio. The V2 sidebar inspector (entries 274–276) is a **second, Studio-local** presentation of the same selection, not a replacement | — | No | — |
| 103 | `:2764`, `:2772` — `_foundationNotifier.bridge` reads gating the Engineering Sessions panel | Panel visibility additionally gated on a live `FoundationBridge` | **C/D seam** | The `bridge != null` gate becomes a view-model field; the panel stays presentation | The page should not read a runtime notifier to decide whether to render a panel | `foundationRuntimeServiceProvider` | No | Yes |

---

## 11. Intelligence

`DiagramIntelligenceService` is the sole point of contact with the Engineering
Intelligence Platform and is KEEP (audit §13 row 29); only its lifecycle and
triggers move.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 104 | `:243` — `DiagramIntelligenceService? _intelligence` | The per-document service handle | **C** | `diagramIntelligenceProvider` (entry 25) | Lifecycle is document-scoped, not mount-scoped | `FoundationBridge` | **Yes** — entry 25 | Yes |
| 105 | `:244–245` — `_validationOutcome`, `_analysisOutcome` (`({OepWorkflowResult result, List<String> objectIds})?`) | The last validation/analysis results, cached for the canvas overlays | **C** | Same provider as entry 104, as observable state | These are application results with a document-scoped lifetime, not per-frame render state; they are exactly what a view-model exposes | `DiagramIntelligenceService` | **Yes** — results currently vanish on unmount; under a provider they persist for the document. Likely desirable, but observable | Yes |
| 106 | `:704–716` — `_validateNow()` | "Manual validation": immediate `sync(title, graph, layout)` bypassing the debounce, then immediate `validate()`, then `setState` | **B** | `DiagramStudioController.validateNow()` — it already owns the debounced counterpart in `_scheduleIntelligenceSync` (`controller/…:122–131`) | Splitting manual and automatic validation across two owners is exactly the divergence hazard the Wave 1 centralisation was meant to close | `_intelligence`, `_session`, `_document.path`, `mounted` | No (same trigger, same order) | Yes |
| 107 | `:721–742` — `_analyzeSelectedNode()` | Single-node analysis; on `ArgumentError` (node not yet synced) it syncs once and retries exactly once | **B** | `DiagramStudioController.analyzeSelectedNode()` | The sync-and-retry-once recovery is application policy, not presentation. Preserve the retry semantics **verbatim** — it is the fix for a silently-ignored button press | `_intelligence`, `_selection.nodeIds`, `_session`, `mounted` | No | Yes |
| 108 | `controller/…:117–120` — `markDirty()` | dirty-mark + debounced Intelligence sync, the single authoritative pathway | **B** (already done) | — | Wave 1's core extraction; verify all ~30 former call sites still route here (audit risk R2) | `engineeringProjectServiceProvider`, `intelligence` | No | — |
| 109 | `controller/…:122–131` — `_scheduleIntelligenceSync()` | Debounced sync with `title: _document.path ?? 'Untitled Diagram'` | **B** (already done) | — | Note the title fallback is duplicated verbatim at `:709` and `:734` in the page (entries 106–107); they converge when those move | `intelligence`, `session` | No | — |
| 110 | `:769–774` — `Set<String> get _validationMarkerNodeIds` | Translates Foundation object ids from `_validationOutcome` into canvas node ids via `DiagramIntelligenceService.nodeIdFor`, dropping non-node objects | **C** | View-model field on `diagramIntelligenceProvider` | It is a derived projection over service state, recomputed on every `build()` today. A view-model computes it once per change | `_intelligence.nodeIdFor`, `_validationOutcome` | No | Yes |
| 111 | `:778–783` — `Set<String> get _analysisHighlightNodeIds` | Same translation for `_analysisOutcome` | **C** | Same as entry 110 | Same | as above | No | Yes |
| 112 | `:762` — `String? get _singleSelectedNodeId` | `selection.nodeIds.length == 1 ? single : null` | **B/D** | A view-model field; trivial either way | Used to gate the Analyze button and to pass a "selected node" to five Intelligence panels | `_selection` | No | Yes |
| 113 | `:246–250` — `_showRecommendationPanel`, `_showEngineeringExplorerPanel`, `_showKnowledgeGraphPanel`, `_showQueryConsolePanel`, `_showSessionsPanel` | Visibility flags for the five Intelligence panels; **not persisted** (entry 92) | **C** | `diagramStudioLayoutController` (entry 27) | Same category as every other panel-visibility flag; they are currently scattered across two field groups only for historical reasons | — | **Yes** if persisted (entry 92 caveat) | Yes |
| 114 | `:480–490` — `bool get _anySidePanelVisible` | Whether the right-hand secondary column has anything to show — when everything is off, the column and its resize handle are omitted entirely rather than rendering an empty strip | **D** | Presentation (a layout view-model getter) | Pure layout arithmetic over visibility flags. **Note** it also reaches `_foundationNotifier.bridge != null` for the Sessions panel — that dependency moves per entry 103 | visibility flags, `_intelligence`, `_foundationNotifier` | No | Yes |
| 115 | `:2373–2389` + `:3519–3585` — `_IntelligenceToolbar` construction and widget | Validate-now / Analyze buttons plus five panel toggles; busy spinner | **E** | Move verbatim to `presentation/`; superseded by the V2 action row (audit §13 row 78, Wave 3) | Presentation that must keep working now, scheduled for replacement | `_intelligence!.busy`, `_singleSelectedNodeId`, visibility flags | No | Yes |
| 116 | `:2716–2775` — the five `if (_intelligence != null && _show…Panel)` panel mounts (`RecommendationPanel`, `EngineeringExplorerPanel`, `KnowledgeGraphPanel`, `QueryConsolePanel`, `KnowledgeSessionsPanel`) | Conditional mounting of the Intelligence panels inside `KnowledgePanel` wrappers | **E** | Audit §13 rows 40, 42–45: ADAPT into "secondary Intelligence surfaces" at Wave 7 — they leave the primary workspace | Every removal from the visible surface must be a *relocation* with a recorded destination (audit R7), never a deletion | `_intelligence!`, `_selectAndFrameNode`, `_singleSelectedNodeId`, `_foundationNotifier.bridge` | No | Yes |

---

## 12. Simulation and domain profile

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 117 | `:279` — `bool _showSimulationOverlay` | Whether the simulation state overlay renders | **C** | Simulation view-model on `diagramSimulationServiceProvider` | It is set only by `_refreshSimulationOverlay` (entry 121) as a derived consequence of session existence, never independently by the user — so it is service-derived state, not a UI toggle | entry 121 | No | Yes |
| 118 | `:280` — `SimulationStateSnapshot? _simSnapshot` | Cached snapshot for the overlay (never recomputed synchronously in `build()`) | **C** | Same view-model | An immutable Engine value type cached at the application layer; §3.4 permits it to cross to presentation | `DiagramSimulationService.currentSession.state` | **Yes** — cached per mount today; under a provider it survives navigation, matching the session that produced it | Yes |
| 119 | `:281` — `VerificationReport? _simVerification` | Cached verification result; **also closed over by `DigitalMultimeterInstrument`** at `:301` | **C** | Same view-model | The multimeter instrument reaching into page state via a closure is the clearest single argument for provider-hosting this (entry 24) | `DiagramSimulationService.verify()` | **Yes** — as entry 118 | Yes |
| 120 | `:282` — `Set<String> _simFaultNodeIds` | Node ids with active non-relationship faults, for overlay marking | **C** | Same view-model | Derived projection over `currentSession.activeFaults.active` | as above | **Yes** — as entry 118 | Yes |
| 121 | `:311–338` — `_refreshSimulationOverlay()` | Reads the service; if no session, clears all four fields and hides the overlay; otherwise captures snapshot, `await verify()`, computes fault node ids, and shows the overlay | **C** | `DiagramSimulationService`-backed view-model method, e.g. `refreshOverlay()` | This is session-state projection with an `await` in the middle — application logic, not rendering. The page's two `mounted` guards become provider-disposal checks | `diagramSimulationServiceProvider`, `mounted` | **Yes** — the `if (!mounted)` early-outs must be replaced with correct provider semantics, or a refresh in flight during navigation silently drops its result | Yes |
| 122 | `:340–348` — `_openSimulationCenter()` | Opens `SimulationCenterDialog` with the service, graph, `onSelectNode: _selectAndFrameNode`, `onSessionStateChanged:` → refresh; refreshes again on dismissal | **D** (dialog) + **C** (refresh) | The dialog stays presentation (audit §13 row 67: KEEP, entry point moves to the V2 action row); the refresh callbacks call the view-model | `SimulationCenterDialog.show` needs a `BuildContext` | `context`, `_simulationService`, `_session!.graph` | No | Yes |
| 123 | `:193` — `DomainProfile? _domainProfile` | The loaded operating profile; explicitly runtime-only and page-local, `null` is the honest default | **C** | Simulation view-model | It parameterises simulation sessions and feeds `SimulationControlsToolbar`; it is application state that happens to have no persistence yet | `DomainProfile` | **Yes** — currently reloaded per app launch *and lost on page unmount*; a provider keeps it for the session. That is almost certainly the intent, but it is a change | Yes |
| 124 | `:195–232` — `_loadDomainProfile()` | File picker → parse `DomainProfile` JSON → `setState` → **delete any existing simulation session** → **create a new session** from `_session!.graph` with the profile's operating/input states → `setState` → success/failure `SnackBar` | **Split C + D** | Parse + session replacement → simulation view-model method `loadDomainProfile(profile)`; the picker and the two `SnackBar`s stay presentation | This single method mixes a file picker, JSON parsing, **destructive simulation-session replacement**, and user messaging. The session replacement is the part that must not stay in a widget callback: it deletes the user's live session as a side effect of loading a profile | `openFile`, `jsonDecode`, `_simulationService`, `_session!.graph`, `context` (SnackBar), `mounted` | **Yes** — session replacement moves out of a widget callback. Preserve the delete-then-create order exactly; it is what makes the Key States row work outside Simulate mode | Yes |
| 125 | `:2085–2087` — `showKeyStates` computation in `build()` | Gates the KEY STATES dock panel on the session actually having operating or input states | **D** | Layout view-model | Presentation gating over service state; recorded separately because it enforces the "no fabricated default" rule at the panel-frame level, not just inside the row widget | `_simulationService.currentSession` | No | Yes |
| 126 | `:2366–2372` — `SimulationControlsToolbar` mount (Simulate mode only) | The Simulate-mode runtime control strip, passed the service, graph, `onChanged: () => setState(() {})`, and `_domainProfile` | **E** | Audit §13 row 77: ADAPT — merge into the V2 topbar KEY row at Wave 3 | Presentation that must keep working now | `_simulationService`, `currentGraph`, `_domainProfile` | No | Yes |
| 127 | `:2544–2555` — `SimulationStateOverlay` mount | Canvas overlay for snapshot/verification/fault nodes, positioned with the same pan/zoom as the canvas | **E** | Audit §13 row 71: ADAPT — re-host on the new canvas transform, add V2 flow animation and trace dimming, Wave 4 | Presentation | `_effectiveLayout()`, `_viewState.pan/zoom`, entries 118–120 | No | Yes |
| 128 | `settings/diagram_studio_settings*.dart` — `DiagramStudioSettings`, its notifier, its storage | **User preferences** (§1.2 category 4): new-document defaults for grid/snap/guides visibility | **C** (already correct — KEEP/ADAPT, audit §13 rows 60–63) | — | Classified here explicitly to keep it distinct from the three other persistence categories. **The page never reads it** — its only consumer is `EngineeringProjectNotifier._applyNewDocumentViewStateDefaults` (entry 75). Nothing about it moves in Wave 2 | `SettingsStorage.root()` | No | — |
| 129 | `simulation/diagram_simulation_service.dart` — `DiagramSimulationService` | Sole point of contact with the Engine's `SimulationEngine`, reached via `engine.registry.simulationEngine` | **C** (already correct — KEEP, audit §13 row 64) | — | Recorded so no stage constructs a second `SimulationEngine` | `EngineRegistry` | No | — |

---

## 13. Instruments and probes

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 130 | `:291–292` — `InstrumentRegistry? _instruments`, `InstrumentDockController? _dockController` | Handles for the instrument subsystem, created once in `initState` because the dock's persisted layout loads asynchronously before first paint | **C** | `diagramInstrumentsProvider` (entry 23) | "Permanent subsystem … available regardless of mode" contradicts mount-scoped ownership | `InstrumentDockController.load()` | **Yes** — entries 23, 53, 54 | Yes |
| 131 | `:294` — `ProbeSlot? _armedProbeSlot` | Which probe (A/B) is armed for click-to-place; `null` = not arming | **B** or **D** | Audit §11.3 explicitly lists "armed probe slot" as controller-owned interaction state. If the interaction state stays widget-local (see §29 item 3), it stays with the other gesture state — but it must not be split from it | It is transient interaction state with the same lifetime as drag/connect state | — | No | Yes |
| 132 | `:1033–1038` — armed-probe branch in `_handleNodeTap` | A node tap places the armed probe (`ProbeOverlay.placeByNodeTap`) instead of changing selection, then disarms | **B** | Controller/gesture router — the same owner as the tap it intercepts | Interception order is behaviourally load-bearing: it must run *before* selection handling | `ProbeOverlay.placeByNodeTap`, `_multimeter` | No | Yes |
| 133 | `:1540–1545` — armed-probe branch in `_handlePortDragStart` | Same interception at a specific terminal (`ProbeOverlay.placeByPortTap`) | **B** | As entry 132 | Duplicated deliberately because a zero-movement click never reaches `onPanStart` | as above | No | Yes |
| 134 | `:1564–1569` — armed-probe branch in `_handlePortTap` | The third copy of the same interception, for the plain-tap path | **B** | As entry 132 | Three copies of one rule. When they move, they should converge to a single guard in the gesture router — but only if the resulting order is verified identical | as above | No | Yes |
| 135 | `:2390–2403` + `:3479–3517` — `_InstrumentToolbar` construction and widget | Dock visibility toggle + Probe A/B arm buttons; deliberately always present, not gated on Intelligence or a simulation session | **E** | Move verbatim; superseded by V2 chrome (audit §13 rows 18–21, 24, Wave 6) | Presentation that must keep working now | `_dockController!.state.visible`, `_armedProbeSlot` | No | Yes |
| 136 | `:2164–2166` — `Ctrl+M` shortcut → `_dockController!.toggleVisible('digital_multimeter')` | Keyboard toggle for the dock | **D** | Moves with the keymap (entry 253) | The hard-coded instrument id `'digital_multimeter'` is a presentation-level binding | `_dockController` | No | Yes |
| 137 | `:2804–2809` — `InstrumentDock` mount at the outermost `Stack` level | The dock is layered above the whole page, not just the canvas, so it is reachable regardless of open side panels | **E** | Audit §13 row 18: ADAPT at Wave 6 (keep floating-frame/resize-grip behaviour, drop auto-hide strip and dock tab bar) | Presentation; the outermost-`Stack` placement is deliberate and must be preserved through the move | `_instruments!`, `_dockController!` | No | Yes |
| 138 | `:2563–2585` — `ProbeOverlay` mount + the `latestResult != null` continuity-path `SimulationStateOverlay` | Probe markers plus, in Continuity Mode, an automatic highlight of the last measured path (reusing `SimulationStateOverlay.propagationPathNodeIds` rather than a second path renderer) | **E** | Audit §13 row 26: ADAPT at Wave 6 | Presentation; the reuse of the existing overlay is a deliberate anti-duplication choice to preserve | `_multimeter!`, `_effectiveLayout()`, `_viewState`, `engine.registry.symbols`, `_nodeSize` | No | Yes |
| 139 | `instruments/multimeter/multimeter_controller.dart`, `instruments/core/engineering_instrument.dart`, `instruments_host/*` | The instrument runtime, the `EngineeringInstrument` contract, and the app-wide Instrument Bridge | **C** (already correct — KEEP, audit §13 rows 17, 25, 27, 28) | — | `DigitalMultimeterInstrument`'s registration and the `EngineeringInstrument` contract must not change (audit risk R13, which cascades into the Workbench Instruments Perspective) | — | No | — |

---

## 14. Viewport, transform, and framing

`ViewState` is the single authoritative source for zoom/pan (AP-DS-001A item 2).
The two-way reconciliation with Flutter's `TransformationController` is the one
place where an Engine value type and a `Matrix4` legitimately meet — and per
spec §3.4 that meeting point must be **on the widget side**.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 140 | `:924–932` — `_applyTransformFromViewState(ViewState)` | ViewState → `Matrix4`: `translate(pan)..scale(zoom)`, written to `_transformController` only if changed | **D** | Stays widget-owned; §28 item 1 | Produces a `Matrix4` for a Flutter controller. Round-trips exactly with entry 141 | `_transformController`, `mounted` | No | Yes |
| 141 | `:934–941` — `_syncViewStateFromTransform()` | `Matrix4` → ViewState on `onInteractionEnd`: `getMaxScaleOnAxis()` → `setZoom`, `getTranslation()` → `setPan` | **D** (call) + **F** (effect) | Stays widget-owned; the `setZoom`/`setPan` are Engine service calls it emits | Deliberately reconciles only at gesture end so it does not fight the pinch recognizer mid-gesture. **Preserve that timing exactly** | `_transformController`, `_viewStateService` | No | Yes |
| 142 | `:943–948` — `_ensureViewportSize(width, height)` | Pushes the canvas's measured size into `ViewStateService.setViewportSize` via `addPostFrameCallback`, skipping when unchanged | **D** (call) + **F** (effect) | Stays widget-owned; §28 item 2 | The size comes from `LayoutBuilder` constraints — a genuinely Flutter-layout-derived value that cannot be known before layout. The post-frame deferral avoids mutating Engine state during build | `LayoutBuilder` constraints, `WidgetsBinding`, `mounted` | No | Yes |
| 143 | `:950–964` — `Rect2D? _selectionBounds(DiagramScene)` | Combined bounding box of the selected nodes, from `DiagramScene` node visuals (position + width/height) | **B** | Controller/viewport controller — takes the `DiagramScene` as a parameter (an immutable Engine value type, so it may cross) | Pure geometry over Engine value types, with no Flutter dependency. Audit §11.1 names a `DiagramStudioViewportController` for exactly this | `DiagramScene`, `_selection` | No | Yes |
| 144 | `:966` — `_fitAll(scene)` → `_viewStateService.fitAll(contentWidth, contentHeight)` | Fit-all framing | **B** | Viewport controller | Engine service call with an Engine-derived argument; no Flutter involvement | `DiagramScene`, `ViewStateService` | No | Yes |
| 145 | `:968–971` — `_fitSelection(scene)` | Bounds → `ViewStateService.fitSelection`, no-op when nothing selected | **B** | Viewport controller | As entry 144 | entry 143 | No | Yes |
| 146 | `:973–976` — `_centerSelection(scene)` | Bounds → `ViewStateService.centerSelection`, no-op when nothing selected | **B** | Viewport controller | As entry 144 | entry 143 | No | Yes |
| 147 | `:981` — `void resetView()` (**public**) | `ViewStateService.resetView()`; public so toolbars can call it, also bound to `Ctrl+0` | **B** | Viewport controller | Its public-ness exists only to expose it to toolbars, which is what a controller is for | `ViewStateService` | No | Yes |
| 148 | `:2284–2285` — `onGoBack`/`onGoForward` → `_viewStateService.goBack`/`goForward`, gated on `canGoBack`/`canGoForward` | Viewport navigation history | **B** (gating + call) + **F** (implementation) | Viewport controller exposes `canGoBack`/`goBack` etc. | The page currently reaches through `_viewStateService` directly for both the capability check and the action | `ViewStateService` | No | Yes |
| 149 | `:2023–2046` — `Rect2D? _boundsForNodes(Set<String>)` | Combined bounds for a node id set, using tracked position/size with `DiagramLayout.compute` and `_nodeSize`/`Size2D` fallbacks | **B** | Viewport controller (shared by the multi-node search cases, entry 246) | Same class as entry 143 but sourced from `session.layout` rather than a rendered scene. **Note the duplication with entry 143** — two bounding-box implementations with different sources; converge only if the fallback behaviour is verified identical | `_session.layout`, `DiagramLayout.compute`, `_nodeSize` | No | Yes |
| 150 | `:58` — `const double _nodeSize = 100` with the comment "DiagramLayout.nodeSize, mirrored for hit-testing" | A **mirrored copy of an Engine constant**, used by hit-testing, port anchoring, bounds maths, and the probe overlay | **F** — **hazard** | Read the Engine's own constant instead of mirroring it | This is exactly audit §9.4's class of preservation hazard: a duplicated Engine value that silently diverges if the Engine changes. Verify `DiagramLayout.nodeSize` is publicly reachable before removing the mirror; if it is not, record that as an Engine gap rather than keeping the copy unremarked | `DiagramLayout` | No | Yes |
| 151 | `:59` — `const double _nodeSpawnStep = 40` | Spawn-grid step for entry 7 | **B** | Moves with the spawn counter | Placement policy | — | No | No |
| 152 | `:2280–2287` — `DiagramNavigationToolbar` mount | Fit All / Fit Selection / Center Selection / Back / Forward / Reset, with selection-based enablement | **E** | Move verbatim; superseded by the V2 action row (audit §13 row 78, Wave 3) | Presentation; the enablement predicates move to the viewport controller | entries 144–148 | No | Yes |

---

## 15. Editing delegations (already routed through the Wave 1 controller)

Every entry in this section is **already** a thin delegation to
`DiagramStudioController`. They are catalogued so the code-moving stage can
confirm that none of them regains an Engine call, and so that the page-local
computation still riding along with each is visible.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 153 | `:994–1001` — `_addNode(symbolId)` | Increments `_spawnCounter`, computes the spawn `Point2D`, calls `controller.addNode(symbolId, position)` | **B** | `DiagramStudioController.addNode` (`controller/…:189–201`) — absorb the position computation per entry 7 | The only page-local residue is the spawn arithmetic | `_spawnCounter`, `_controller` | No | Yes |
| 154 | `:1003` — `_deleteSelection()` | → `controller.deleteSelection()` (`controller/…:182–185`) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 155 | `:1005` — `_groupSelection()` | → `controller.groupSelection()` (`controller/…:203–214`; no-op below 2 nodes) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 156 | `:1007` — `_ungroupSelection()` | → `controller.ungroupSelection()` (`controller/…:216–222`) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 157 | `:1009` / `:1011` — `_undo()` / `_redo()` | → `controller.undo()`/`redo()` (`controller/…:135–143`), each `markDirty()`-ing | **B** (done) | — | Verify | `_controller` | No | Yes |
| 158 | `:1013` / `:1015` — `_copy()` / `_cut()` | → `controller.copy()`/`cut()` (`controller/…:150–162`), including the `Clipboard.setData` OS-clipboard fallback | **B** (done) | — | The in-process `ClipboardProvider` stays the primary path; the OS clipboard is a cross-instance fallback. Preserve that ordering | `_controller` | No | Yes |
| 159 | `:1017` — `_paste()` | → `controller.paste()` (`controller/…:164–175`): if no in-process clipboard content, decode from the OS clipboard first | **B** (done) | — | Verify the `hasClipboardContent`-first ordering survives | `_controller` | No | Yes |
| 160 | `:1019` — `_duplicateSelection()` | → `controller.duplicateSelection()` (`controller/…:177–180`) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 161 | `:1913` / `:1915` — `_rotateSelection(deg)` / `_mirrorSelection(axis)` | → `controller.rotateSelection`/`mirrorSelection` (`controller/…:291–301`) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 162 | `:1917–1927` — `_openArrayPlacement()` | `showArrayPlacementDialog(context)` → `controller.arrayPlace(countX:, countY:, spacingX:, spacingY:)` (`controller/…:303–318`) | **D** (dialog) + **B** (done) | The dialog stays presentation (`BuildContext`); the command is already delegated | Correct split already; §28 item 3 | `context`, `_selection`, `_controller` | No | Yes |
| 163 | `:1929` — `_replaceSymbol(symbolId)` | → `controller.replaceSymbol` (`controller/…:320–324`; single-selection only) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 164 | `:1942` — `alignSelection(mode)` (**public**) | → `controller.alignSelection` (`controller/…:328–332`; no-op below 2 nodes) | **B** (done) | — | Public so a toolbar can call it — same rationale as entry 147 | `_controller` | No | Yes |
| 165 | `:1947` — `distributeSelection(axis)` (**public**) | → `controller.distributeSelection` (`controller/…:334–338`; no-op below 3 nodes) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 166 | `:1951` — `_createLayer()` | → `controller.createLayer()` (`controller/…:342–351`; names it `Layer N+1`, order = count) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 167 | `:1953` — `_deleteLayer(layerId)` | → `controller.deleteLayer` (`controller/…:353–356`) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 168 | `:1955` / `:1957` — `_toggleLayerVisible` / `_toggleLayerLocked` | → `controller.toggleLayerVisible`/`toggleLayerLocked` (`controller/…:358–370`) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 169 | `:2340–2341` — named-layout `onLoad`/`onReset` | → `controller.loadNamedLayout(layout)` / `controller.resetLayout()` (`controller/…:378–384`), both via `engine.editing.resetSession` | **B** (done) | — | **Preserve the documented anomaly**: neither call marks the document dirty today. That is existing behaviour, explicitly not changed by Wave 1/2. Do not "fix" it as a drive-by | `_controller` | No | Yes |
| 170 | `:2335–2342` — `showNamedLayoutsDialog(context, layoutProvider: engine.registry.layout, …)` | The named-layouts dialog, handed the Engine's layout provider directly plus `currentLayout: () => _session!.layout` | **D** (dialog) + **F** (`engine.registry.layout`) | The dialog stays presentation; the provider access moves behind the controller | This is one of the remaining direct `engine.*` reads from the page — §27 row 12 | `context`, `engine.registry.layout`, `_session` | No | Yes |
| 171 | `commands/studio_command_actions.dart` — `StudioCommandActions` | The UI-agnostic undo/redo/clipboard facade, **composed** (not duplicated) by the controller | **C** (already correct — KEEP, audit §13 row 3) | — | Reachable from Diagram Studio only via `controller.commands`; nothing in `workspaces/` may construct one | `EngineeringEngine` | No | — |

---

## 16. Selection interaction

Selection truth is Engine-owned (`engine.registry.selection`). Every call below
is a **direct Engine call from the page today** and is repeated in §27.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 172 | `:1023–1026` — `_additiveModifierPressed`, `_toggleModifierPressed`, `_spacePressed` | Reads `HardwareKeyboard.instance` for Shift/Ctrl/Space state | **D** | Presentation/interaction layer (audit §11.1's `KeyMap`/`GestureRouter`) | `HardwareKeyboard` is `package:flutter/services` — Flutter, so it cannot cross into a Flutter-free controller. The *policy* (Shift = additive, Ctrl = toggle) should be expressed as a resolved intent parameter instead | `HardwareKeyboard` | No | Yes |
| 173 | `:1028–1047` — `_handleNodeTap(nodeId)` | Armed-probe interception (entry 132) → clear `_lastPortTap` → `toggleNode` / `selectNode(additive:)` / `selectNode` per modifiers | **B** | Controller/gesture router, taking a resolved `additive`/`toggle` intent rather than reading the keyboard itself | Selection semantics are engineering-adjacent interaction (audit §9.3), not decoration | `engine.registry.selection`, modifiers, `_armedProbeSlot` | No | Yes |
| 174 | `:1049–1069` — `_handleBackgroundTap(localPosition, scene)` | Clear `_lastPortTap` → cancel a pending connection if any → hit-test a relationship (`DiagramHitTesting.relationshipAt`) and select/toggle it → otherwise `deselectAll` unless additive | **B** | Controller/gesture router | Contains three distinct rules (connection cancellation, wire hit-select, empty-click deselect) whose **order** is behaviourally load-bearing | `DiagramHitTesting`, `engine.registry.selection`, `_connectFromPort` | No | Yes |
| 175 | `:1702–1710` — `_handleAnnotationTap(id)` | Toggle/additive/replace annotation selection per modifiers | **B** | As entry 173 | Same rule set as node tap, applied to annotations | `engine.registry.selection` | No | Yes |
| 176 | `:184` — `PortReference? _lastPortTap` | The last port a plain click landed on, so the Inspector can show port-specific detail; cleared by any other selection-changing interaction so it can never show stale detail | **B** | Interaction state alongside the other gesture state | It is selection-adjacent interaction state with an explicit invalidation rule that must move as one unit with its clearers (entries 173, 174, 209) | — | No | Yes |
| 177 | `:2148–2149` — `Ctrl+A` → `engine.registry.selection.selectAll(currentGraph, layout:)` | Select-all shortcut | **B** (call) + **D** (binding) | Controller method `selectAll()`; the key binding stays in the keymap | Direct Engine call from a widget callback | `engine.registry.selection`, `_session` | No | Yes |
| 178 | `:2255` — `SelectionToolbar.onSelectAll` → the same `selectAll` call | The toolbar duplicate of entry 177 | **B** (call) + **E** (toolbar) | Same controller method | Two literal copies of the same Engine call; they converge on one controller method | as above | No | Yes |
| 179 | `:2256` — `SelectionToolbar.onDeselectAll` → `engine.registry.selection.deselectAll()` | Deselect-all from the toolbar | **B** (call) + **E** (toolbar) | Controller `deselectAll()` | Direct Engine call | `engine.registry.selection` | No | Yes |
| 180 | `:2152–2162` — `Escape` handler | If a connection is pending, cancel it (three fields) and stop; otherwise `deselectAll()` | **B** + **D** | The cancel-pending-connection half is interaction state; the deselect half is entry 179's controller method | Order is load-bearing: Escape must not deselect while a connection is being drawn | `_connectFromPort`, `engine.registry.selection` | No | Yes |
| 181 | `:1209–1217` — `_handleBackgroundPanStart(localPosition)` | If Space is held, capture `_panStartPan` for a space-drag pan; otherwise begin a box-select rect | **B/D** | Gesture router | Two mutually exclusive gestures dispatched on a modifier | `_spacePressed`, `_viewState.pan` | No | Yes |
| 182 | `:1219–1230` — `_handleBackgroundPanUpdate(localPosition, delta)` | Space-drag: `setPan(pan.translate(delta.dx * zoom, delta.dy * zoom))`. Otherwise update the box-select rect | **B** (pan) + **D** (rect) | Pan → viewport controller; rect → interaction state | **Ambiguity flagged** — the delta is *multiplied* by `zoom`. Screen-to-scene conversion normally *divides* by zoom, so panning likely accelerates when zoomed in. Not changed here; recorded in §29 item 2 for verification against real behaviour before anything moves | `_viewStateService`, `_viewState`, `_boxSelectStart` | No | Yes |
| 183 | `:1232–1248` — `_handleBackgroundPanEnd(scene)` | Space-drag: clear `_panStartPan`. Otherwise `DiagramHitTesting.nodesInRect(scene, rect)` → `selectMany(nodeIds:, additive:)` (only when non-empty), then clear the rect | **B** | Controller/gesture router | The "only select when the hit set is non-empty" rule means an empty box-drag preserves the existing selection — deliberate, and easy to lose in a rewrite | `DiagramHitTesting`, `engine.registry.selection` | No | Yes |
| 184 | `:350–352` — `_boxSelectRect`, `_boxSelectStart`, `_panStartPan` | Box-select preview rect, its origin, and the pan-gesture origin | **B/D** | Interaction state (audit §11.3 lists "box-select rect" as controller-owned) | Transient gesture state | — | No | Yes |
| 185 | `:1250–1262` — `_handleHover(localPosition)` | Tracks `_cursorScenePosition`; in Wire mode with a pending connection, moves the preview endpoint; otherwise a bare `setState` to repaint | **D** | Presentation/interaction | The bare `setState(() {})` on every hover is a per-pointer-move full-page rebuild — a real performance concern for audit risk R6. Recorded, not fixed here | `_wireCreateModeActive`, `_connectFromPort` | No | Yes |
| 186 | `:366` — `Point2D? _cursorScenePosition` | The cursor's scene-space position; feeds the coordinate readout and the annotation spawn position | **B/D** | Interaction state (audit §11.3 lists "cursor scene position" as controller-owned) | Two consumers with different needs (display vs placement) | entry 185 | No | Yes |

---

## 17. Contextual menu

Per spec §3.5, the cross-studio Contextual Command System executes its own
Engine commands **outside** this controller, by design. That is the one
sanctioned second execution pathway and must not be "fixed".

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 187 | `:1087–1112` — `_handleSecondaryTap(local, global, scene)` | Right-click target detection: `_nodeAt(point)`, else `DiagramHitTesting.relationshipAt`, else canvas; builds a `CursorTarget` plus a human-readable `contextIdentity` (relationship identity includes both endpoint display names) | **B** | Controller/hit-tester (audit §11.1 names a `HitTester`) | It decides *what the user pointed at* — interaction logic, not rendering. The **documented gap** (no standalone port/annotation hit-testing exists anywhere in the codebase, so right-click on a port or annotation via this path is unsupported) is scheduled to close with the new `HitTester` (audit §13 row 4) | `_nodeAt`, `DiagramHitTesting`, `_session.graph` | No | Yes |
| 188 | `:1120–1127` — `_handleNodeSecondaryTap(nodeId, global)` | Right-click landing directly on a node body, because `SymbolNodeWidget`'s opaque `GestureDetector` sits above the background handler | **B** | As entry 187 | A separate path for a real hit-testing reason, not redundancy | `_session.graph.nodes` | No | Yes |
| 189 | `:1134–1152` — `_handlePortSecondaryTap(port, global)` | Right-click on a port marker; resolves the symbol port to get a display name; builds a `CursorTarget` with `ownerNodeId` | **B** | As entry 187 | Uses the already-established `PortReference` association rather than a new lookup. **Contains a direct `engine.registry.symbols.resolve` call** — §27 row 6 | `engine.registry.symbols`, `_session.graph.nodes` | No | Yes |
| 190 | `:1158–1168` — `_handleAnnotationSecondaryTap(annotationId, global)` | Right-click on an annotation, reusing `AnnotationWidget`'s own hit region; identity falls back to type name then id | **B** | As entry 187 | Same | `_session.layout.annotations` | No | Yes |
| 191 | `:1170–1188` — `_openContextualMenu`'s `buildContext()` closure + resolver construction | Builds an `EngineeringInteractionContext` via `EngineeringInteractionContextBuilder` with `studioId`/`route` = `StudioDestination.diagram.path` and **`mode` threaded from the active tab** (a real bug fix recorded in the comment: the mode was previously never threaded, so every menu resolved as Edit mode); constructs `ContextualCommandResolver(commands: initialContextualCommands)` | **B** | Controller — it needs `ref`, tab state, and studio identity, none of which are render concerns | The mode threading is a correctness fix that must be preserved verbatim through the move | `ref`, `diagramTabsProvider`, `core/context/*`, `StudioDestination` | No | Yes |
| 192 | `:1189–1207` — the `showDiagramContextMenu` call and its continuation | Shows the menu (`BuildContext` + `globalPosition`), then on dismissal `setState(() {})` and `_reactToExternalEdit()` | **D** (menu) + **B** (fold-back) | The menu stays presentation (audit §13 row 4: ADAPT to V2 `#ctx` at Wave 5); the `markDirty` fold-back is entry 77 | The menu needs `BuildContext`; the fold-back is the sanctioned seam between the two execution pathways (spec §3.5) | `context`, `globalPosition`, `mounted`, `_controller` | No | Yes |

---

## 18. Node drag, alignment guides, and resize

Audit §4.9 flags this whole block as "interaction-model logic worth preserving
verbatim (currently inside the monolith)", and audit §9.3 classes it as
engineering semantics rather than decoration. It moves as a unit, unchanged.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 193 | `:354–357` — `_dragNodeIds`, `_dragStartPositions`, `_dragTotalDelta`, `_activeGuides` | Multi-node drag session state and the currently-displayed alignment guides | **B** | Controller interaction state (audit §11.3 lists "drag … gesture state" explicitly) | Transient interaction state with engineering meaning (snap results feed a real command) | — | No | Yes |
| 194 | `:1271–1283` — `_siblingBounds(excludingNodeIds)` | Bounds of every node **not** being dragged, for guide comparison — the exclusion set is the whole dragged selection so a multi-node drag never guides against itself | **B** | Controller | Pure geometry over `session.graph`/`session.layout`; the self-exclusion rule is subtle and load-bearing | `_session`, `_nodeSize` | No | Yes |
| 195 | `:1293–1313` — `_draggedGroupBounds(nodeIds, startPositions, totalDelta)` | Combined bounding box of the dragged set at its current offset — the single "dragged rectangle" fed to `AlignmentGuideComputer` | **B** | Controller | Extends single-node guides to multi-node drags *without touching the Engine's algorithm* (AP-DS-001A item 1). That restraint must survive | `_nodeSize` | No | Yes |
| 196 | `:1315–1329` — `_handleNodeDragStart(nodeId)` | Chooses drag targets (whole selection if the grabbed node is in a multi-selection, else just that node), selects the node if it was not selected, snapshots start positions | **B** | Controller | The target-set rule is real interaction semantics | `_selection`, `engine.registry.selection`, `_session.layout` | No | Yes |
| 197 | `:1331–1345` — `_handleNodeDragUpdate(delta)` | Accumulates the total delta and, only when `viewState.guidesVisible`, recomputes `AlignmentGuideComputer.computeGuides` | **B** | Controller | Guides are gated on the Engine's own `guidesVisible` — a real Engine-state dependency, not a UI toggle | `AlignmentGuideComputer` (Engine), `_viewState` | No | Yes |
| 198 | `:1353–1375` — `_snappedDragPositions(...)` | Computes one guide-snap delta from the **combined** bounds (so relative spacing inside the selection never changes), applies it uniformly, then grid-snaps each node independently via `GridComputer.snap` | **B** | Controller | The group-snap-then-per-point-grid-snap split is precise engineering behaviour; audit §9.4 lists this class of logic as a silent-breakage hazard | `AlignmentGuideComputer.snapToGuides`, `GridComputer.snap`, `_viewState.grid` | No | Yes |
| 199 | `:1377–1389` — `_handleNodeDragEnd()` | Computes final snapped positions → `controller.moveNodes(newPositions)` → clears drag state and guides | **B** (command already delegated) | `DiagramStudioController.moveNodes` (`controller/…:224–227`) | Command already routed correctly; the surrounding state management moves with entries 193–198 | `_controller` | No | Yes |
| 200 | `:1391–1404` — `_effectiveLayout()` | The **preview layout**: real `session.layout` overlaid with in-progress drag positions and in-progress resize position/size | **B** | Controller — audit §11.3 names "effective layout" as a controller-exposed derived view model | Called **five times per build** (`:2071`, `:2523`, `:2547`, `:2568`, `:2577`), each recomputing the drag preview. A controller-computed value memoised per gesture frame is both correct and a real performance fix (audit risk R6) | `_session.layout`, drag/resize state | No | Yes |
| 201 | `:1411` — `static const double _minNodeSize = 24` | Client-side minimum node size, keeping a node hit-testable and its ports spaced | **B** | Controller | Mirrors how wire editing enforces `constraints.minimumWireLength`; it is a constraint, not a style value | — | No | No |
| 202 | `:359–364` — `_resizingNodeId`, `_resizeHandle`, `_resizeStartPosition`, `_resizeStartSize`, `_resizeTotalDelta` | Resize gesture state | **B** | Controller interaction state (audit §11.3: "resize … gesture state") | As entry 193 | — | No | Yes |
| 203 | `:1413–1428` — `_handleNodeResizeStart` / `_handleNodeResizeUpdate` | Starts a resize only for a single selected node; snapshots position/size with `DiagramLayout.compute` and `_nodeSize` fallbacks; accumulates delta | **B** | Controller | The single-selection guard and the fallbacks are behavioural | `_selection`, `_session.layout`, `DiagramLayout.compute` | No | Yes |
| 204 | `:1435–1495` — `_previewResize()` and `_handleNodeResizeEnd()` | Corner-drag geometry (dragging a top/left handle moves the opposite edge), `_minNodeSize` clamping per handle, then one atomic `controller.resizeNode(id, size, newPosition:)` so a single undo reverts the whole gesture | **B** (command already delegated) | `DiagramStudioController.resizeNode` (`controller/…:229–232`) | The `movedPosition == start ? null : position` decision is what keeps the command atomic; preserve it exactly | `_controller`, entry 202 | No | Yes |

---

## 19. Ports, connections, and wire creation

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 205 | `:1499–1515` — `_portAnchor(PortReference)` | Resolves a port's scene position: prefers the Symbol's authored port geometry, else `fallbackPorts(node.ports, exit: metadata['exit'] ?? 'down')`, else the node centre | **B** | Controller/hit-tester | Uses the *same* real-port-derived geometry that pin rendering and wire-endpoint anchoring already use, so a drag starts exactly where the pin is drawn. **Contains a direct `engine.registry.symbols.resolve`** — §27 row 7 | `engine.registry.symbols`, `fallbackPorts`, `_nodeSize` | No | Yes |
| 206 | `:1517–1526` — `String? _nodeAt(Point2D)` | Point-in-node hit test, scanning `session.layout.positions` with a fixed `_nodeSize` box | **B** | Controller/hit-tester (audit §11.1) | **Note the inconsistency**: this uses a fixed `_nodeSize` square and ignores per-node `sizeOf`, while `_boundsForNodes` (entry 149) honours `sizeOf`. Resized nodes are therefore hit-tested at their original size. Recorded in §29 item 4; not changed here | `_session.layout.positions`, `_nodeSize` | No | Yes |
| 207 | `:1528–1529` — `_handlePortHoverEnter` / `_handlePortHoverExit` | → `_viewStateService.hoverPort(port)` / `hoverPort(null)` | **B** (call) + **F** (state) | Controller | Hover truth lives in the Engine's `ViewStateService`; the page is just relaying | `ViewStateService` | No | Yes |
| 208 | `:368–370` — `_connectFromPort`, `_connectionCurrentPoint`, `_connectionValid` | Pending-connection state driving the preview line and its valid/invalid styling | **B** | Controller interaction state (audit §11.3: "connect … gesture state") | Shared by the drag path *and* the two-click Wire-mode path — a single state machine with two entry points | — | No | Yes |
| 209 | `:1531–1551` — `_handlePortDragStart(port)` | Armed-probe interception (entry 133), else arm a pending connection anchored at `_portAnchor(port)` | **B** | Controller | — | entries 205, 208 | No | Yes |
| 210 | `:1563–1576` — `_handlePortTap(port)` | Armed-probe interception (entry 134) → Wire-mode branch → otherwise fall through to `_handleNodeTap(port.nodeId)` and record `_lastPortTap` | **B** | Controller | Exists because a zero-movement click never reaches `onPanStart`; before it, probes always landed on node centres. Preserve the fall-through ordering exactly | entries 173, 176, 211 | No | Yes |
| 211 | `:1586–1605` — `_handleWireCreateModePortTap(port)` | Two-click wire creation: first tap arms (identical state to the drag path); second tap on a *different* node runs `ConnectionValidator.canConnect` and calls `controller.createRelationship`; a same-node second tap is ignored and leaves the pending connection armed | **B** (command already delegated) | `DiagramStudioController.createRelationship` (`controller/…:236–244`) | Deliberately reuses the drag path's validator and command — never a second connection mechanism | `ConnectionValidator` (Engine), `_controller` | No | Yes |
| 212 | `:406` — `bool _wireCreateModeActive` | Whether explicit two-click Wire mode is on | **B** | Controller — this is the V2 "tool mode" dimension audit §11.4 formalises (`normal`/`layout`/`wire`/`route`) | Today it is an ad-hoc boolean alongside `_wireEditModeActive`; the two should converge into one mutually-exclusive tool-mode enum, but **not** silently — §11.4 schedules it | — | No | Yes |
| 213 | `:1607–1615` — `_handlePortDragUpdate(delta)` | Moves the preview endpoint and continuously re-evaluates `ConnectionValidator.canConnect` against whatever node is under it | **B** | Controller | Live validity feedback is engineering semantics | `_nodeAt`, `ConnectionValidator` | No | Yes |
| 214 | `:1617–1632` — `_handlePortDragEnd()` | On release, hit-test the target node, validate, and `controller.createRelationship`; clear pending state either way | **B** (command already delegated) | `controller.createRelationship` | Same command as entry 211 — one mechanism, two gestures | `_nodeAt`, `ConnectionValidator`, `_controller` | No | Yes |
| 215 | `:2314–2319` — Wire-mode toggle in `WireEditingToolbar` | Flips `_wireCreateModeActive` and clears any pending connection | **B** (state) + **E** (toolbar) | Controller tool-mode setter | Clearing the pending connection on mode exit is a real invariant | entries 208, 212 | No | Yes |
| 216 | `:1461` (`GraphViewPanel.connectionPreviewFrom/To/Valid` at `:2461–2463`) | Feeds the pending-connection preview into the canvas | **D** | Presentation | Pure render input, derived from entry 208 | entries 205, 208 | No | Yes |

---

## 20. Drag-to-reconnect

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 217 | `:372–374` — `_reconnectRelationshipId`, `_reconnectIsSourceEnd`, `_reconnectCurrentPoint` | Reconnect gesture state | **B** | Controller interaction state (audit §11.3: "reconnect … gesture state") | Transient interaction state | — | No | Yes |
| 218 | `:1636–1643` — `_reconnectingWire(DiagramScene)` | Finds the single selected relationship's `DiagramWireVisual` in the scene, so the canvas can draw reconnect handles | **B** | Controller (derived view model) | A linear scan over `scene.wires` performed on **every build**; a controller can compute it once per scene | `DiagramScene`, `_selection` | No | Yes |
| 219 | `:1645–1655` — `_handleReconnectDragStart(isSourceEnd)` | Captures the relationship, which end is being dragged, and an initial point at the anchor node's centre | **B** | Controller | Note `_selection.relationshipIds.single` is unguarded — it relies entirely on the canvas only offering handles for a single selection | `_session.graph.relationships`, `_session.layout`, `_nodeSize` | No | Yes |
| 220 | `:1657–1660` — `_handleReconnectDragUpdate(delta)` | Accumulates the dragged endpoint position | **B** | Controller | — | entry 217 | No | Yes |
| 221 | `:1662–1679` — `_handleReconnectDragEnd()` | Hit-tests the drop target and calls `controller.reconnectRelationship(id, newSourceNode:/newTargetNode:)`; clears state | **B** (command already delegated) | `DiagramStudioController.reconnectRelationship` (`controller/…:246–253`) | **Note the asymmetry with connection creation**: reconnect does **not** run `ConnectionValidator.canConnect`. Verified by inspection. Whether that is intended is unclear — §29 item 7 | `_nodeAt`, `_controller` | No | Yes |

---

## 21. Annotations

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 222 | `:388–390` — `_draggingAnnotationId`, `_annotationDragStartPosition`, `_annotationDragTotalDelta` | Annotation drag state | **B** | Controller interaction state | As entry 193 | — | No | Yes |
| 223 | `:1683–1695` — `_effectiveAnnotations()` | The annotation-preview list: real annotations with the dragged one shifted by the current delta | **B** | Controller (derived view model, alongside `_effectiveLayout`) | The annotation analogue of entry 200 | `_session.layout.annotations`, entry 222 | No | Yes |
| 224 | `:1697–1700` — `_addAnnotation(type)` | Places a new annotation at `_cursorScenePosition ?? (40, 40)` via `controller.addAnnotation` | **B** (command already delegated) | `DiagramStudioController.addAnnotation` (`controller/…:262–272`) | The cursor-position default is placement policy that should move with entry 186 | `_cursorScenePosition`, `_controller` | No | Yes |
| 225 | `:1712–1721` — `_handleAnnotationDragStart(id)` | Selects the annotation if not already selected, snapshots its start position | **B** | Controller | Mirrors `_handleNodeDragStart`'s select-if-unselected rule | `engine.registry.selection`, `_session.layout.annotationOf` | No | Yes |
| 226 | `:1723–1726` — `_handleAnnotationDragUpdate(delta)` | Accumulates delta | **B** | Controller | — | entry 222 | No | Yes |
| 227 | `:1728–1740` — `_handleAnnotationDragEnd()` | Grid-snaps the final position (`GridComputer.snap` with `viewState.grid`) → `controller.moveAnnotation` → clears state | **B** (command already delegated) | `DiagramStudioController.moveAnnotation` (`controller/…:274–277`) | Grid snapping applies here as it does to nodes — but **without** alignment-guide snapping. That asymmetry is existing behaviour; preserve it | `GridComputer`, `_viewState.grid`, `_controller` | No | Yes |
| 228 | `:1742–1760` — `_editAnnotationText(id)` | Shows an `AlertDialog` with a `TextField` (autofocus, 3 lines) and calls `controller.updateAnnotationText` on save | **D** (dialog) + **B** (command already delegated) | Dialog stays presentation (§28 item 3); `DiagramStudioController.updateAnnotationText` (`controller/…:279–282`) | Needs `BuildContext`. **Leaks its `TextEditingController`** — entry 60 | `context`, `_session.layout.annotationOf`, `_controller` | No | Yes |
| 229 | `:1762` — `_deleteAnnotation(id)` | → `controller.deleteAnnotation` (`controller/…:284–287`, a `DeleteManyCommand`) | **B** (done) | — | Verify | `_controller` | No | Yes |
| 230 | `:2328` — `AnnotationsToolbar` mount (Edit mode only) | Add-annotation controls | **E** | Move verbatim; superseded by the V2 action row (audit §13 row 78) | Presentation | entry 224 | No | Yes |

---

## 22. Wire route editing ("Edit Route" mode)

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 231 | `:392–395`, `:407–409` — `_wireEditModeActive`, `_wireEditWorkingPoints`, `_wireEditSelectedVertex`, `_wireDragCornerIndex`, `_wireDragSegmentIndex`, `_wireDragBasePoints`, `_wireDragTotalDelta` | Route-edit mode flag, the working point buffer, the selected vertex, and corner/segment drag state | **B** | Controller interaction state (audit §11.3: "route-edit gesture state") | The working-point buffer is a genuine editing buffer with an invalidation contract (entry 232), not render state | — | No | Yes |
| 232 | `:1768–1790` — `_reseedWireEditPoints()` | Re-seeds the working points from the current scene's wire; **exits route-edit mode entirely** when the selection is no longer exactly one relationship. Driven by the selection subscription (entry 35) | **B** | Controller | The auto-exit-on-selection-change rule is the buffer's invalidation contract and must move together with the buffer. **Renders the entire scene** (`engine.diagramView.render`) just to read one wire's points — §27 row 10, and a performance note for audit risk R6 | `engine.diagramView`, `engine.registry.routing/symbols`, `_selection` | No | Yes |
| 233 | `:1766` — `bool get _wireEditActive` | `_wireEditModeActive && selection.relationshipIds.length == 1` | **B** | Controller | The derived gate every route-edit affordance checks | `_selection` | No | Yes |
| 234 | `:1792–1804` — `_toggleWireEditMode()` | Off → clears the buffer and vertex; On → requires exactly one selected relationship, then re-seeds | **B** | Controller (converges with the tool-mode enum, entry 212) | — | entry 232 | No | Yes |
| 235 | `:1806` — `_handleWireVertexTap(index)` | Selects a vertex | **B/D** | Controller interaction state | Pure selection within the editing buffer | entry 231 | No | Yes |
| 236 | `:1808–1822` — `_insertWireVertex()` | Inserts a vertex at the midpoint of the segment after the selected vertex (clamped), via `WireEditing.insertVertex`, then `controller.setWireRoute` and re-points the selection at the new vertex | **B** (command already delegated) | `DiagramStudioController.setWireRoute` (`controller/…:255–258`) | Midpoint/clamp arithmetic is editing semantics; `WireEditing` is Engine-owned | `WireEditing` (Engine), `_controller` | No | Yes |
| 237 | `:1824–1835` — `_removeWireVertex()` | `WireEditing.removeVertex` → `controller.setWireRoute` → clears the selected vertex | **B** (command already delegated) | as above | — | as above | No | Yes |
| 238 | `:1837–1842` — `_restoreAutomaticRouting()` | `controller.setWireRoute(id, null)` (drops the manual route) then re-seeds from the engine's own routing | **B** (command already delegated) | as above | The `null` payload is the documented "revert to automatic routing" contract | `_controller`, entry 232 | No | Yes |
| 239 | `:1844–1852` — `_handleWireCornerDragStart(index)` | Snapshots base points and begins a corner drag | **B** | Controller | — | entry 231 | No | Yes |
| 240 | `:1854–1864` — `_handleWireCornerDragUpdate(delta)` | `WireEditing.dragCorner(base, index, candidate, minimumWireLength: viewState.constraints.minimumWireLength)` | **B** | Controller | Enforces the Engine's own minimum-wire-length constraint — engineering, not decoration | `WireEditing`, `_viewState.constraints` | No | Yes |
| 241 | `:1866–1876` — `_handleWireCornerDragEnd()` | Commits via `controller.setWireRoute`, clears drag state | **B** (command already delegated) | as above | — | `_controller` | No | Yes |
| 242 | `:1878–1897` — `_handleWireSegmentDragStart` / `Update` | Segment drag via `WireEditing.dragSegment` with the same minimum-length constraint | **B** | Controller | — | `WireEditing`, `_viewState.constraints` | No | Yes |
| 243 | `:1899–1909` — `_handleWireSegmentDragEnd()` | Commits via `controller.setWireRoute`, clears drag state | **B** (command already delegated) | as above | — | `_controller` | No | Yes |

---

## 23. Search

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 244 | `:1961` — `List<SearchResult> _runSearch(String)` → `engine.registry.search.search(graph, layout, query)` | Runs a search against the Engine's `SearchService` | **B** (call) + **F** (implementation) | Controller method `search(query)` | A direct Engine call passed as a function reference into a panel — §27 row 11. `SearchService` itself is Engine-owned and frozen | `engine.registry.search`, `_session` | No | Yes |
| 245 | `:1963–2018` — `_goToSearchResult(SearchResult)` — node / relationship / annotation cases | Select-and-frame per result kind: node → select + centre on a `_nodeSize` box; relationship → select only (no framing); annotation → select + centre on a 40×20 box | **B** | Controller (with entries 143–149's viewport methods) | Per-kind navigation policy, including the deliberate hard-coded annotation frame size | `engine.registry.selection`, `_viewStateService`, `_session.layout` | No | Yes |
| 246 | `:1989–2016` — the `symbol` and `layer` cases | `symbol`: selects **every** node using that symbol and frames them all. `layer`: pushes the layer into the Inspector (entry 100), selects every node/annotation on it via `entitiesOnLayer`, and frames the nodes | **B** | Controller | These generalise "select and focus" to sets; the layer case additionally crosses into the Property Inspector, which is why entry 100 exists separately | `engine.registry.selection.selectMany`, `_boundsForNodes`, entry 98 | No | Yes |
| 247 | `:749–760` — `_selectAndFrameNode(nodeId)` | The shared select-then-centre action driven by every Intelligence panel's `onSelectNode`, both canvas overlays' click-to-inspect, and the Simulation Center | **B** | Controller — the single "reveal this node" intent | Six-plus call sites already converge on it; it is the clearest existing example of a controller-shaped method still sitting in the page | `engine.registry.selection`, `_session.layout`, `_viewStateService`, `_nodeSize` | No | Yes |

---

## 24. `build()` structure, panels, and chrome

`build()` is `:2050–2812` — 762 lines, roughly 21% of the file. Audit §11.5
targets the whole page at under 200 lines, so almost everything here relocates.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 248 | `:2057–2063` — the two `ref.watch` calls, cache refresh, and `activeMode` derivation | Establishes rebuild subscriptions and derives the active tab's mode | **A** | — | Exactly audit §11.5 steps 1–2 | `WidgetRef` | No | Yes |
| 249 | `:2065–2067` — `if (_loading || _session == null) return CircularProgressIndicator()` | The bootstrap loading gate | **A** | — | Composition-root render gate. Note it also guards `_session == null`, so it doubles as a null-safety gate for the ~90 `_session!` uses below | `_loading`, `_session` | No | Yes |
| 250 | `:2068–2075` — `engine.diagramView.render(graph, layout: _effectiveLayout(), routing:, symbols:, selection:)` | Renders the `DiagramScene` — **the boundary object itself** ("DiagramScene in, Engine Commands out") | **F** (render) + **B** (invocation) | The controller exposes the `DiagramScene` as a derived view model (audit §11.3: "Emits … a `DiagramScene` + effective layout for rendering") | The Engine owns rendering to a scene; the page must not call it directly. §27 row 9 | `engine.diagramView`, `engine.registry.routing/symbols` | No | Yes |
| 251 | `:2077` — `symbolChoices` from `engine.registry.symbols.all` | Symbol identifiers for the placement toolbar | **B** (call) + **D** (use) | Controller/view-model | Direct Engine registry read — §27 row 13 | `engine.registry.symbols` | No | Yes |
| 252 | `:2088–2132` — `dockPanels` map and `panelsInSlot(slot)` | Builds the three dockable panels (inspector, key states, legend) keyed by stable id, and groups them by current slot | **D** | Presentation (`panels/panel_manager.dart` per audit §11.2) | Pure layout composition over entry 96's state | entries 96, 125 | No | Yes |
| 253 | `:2136–2167` — `Focus(autofocus: true)` + `CallbackShortcuts` with 13 bindings | The keyboard model: Ctrl+Z/Y/Shift+Z, Ctrl+C/X/V/D/S/A, Delete, Backspace, Escape, Ctrl+0, Ctrl+M | **D** | `presentation/` keymap (audit §11.1's `KeyMap`; §10.12 "Keyboard model" is listed as rebuild) | Key bindings are presentation; the actions they invoke are controller methods. Audit §6.3 requires the binding table be **preserved verbatim** through the rebuild | `CallbackShortcuts`, entries 154–160, 147, 136, 177, 180 | No | Yes |
| 254 | `:2179–2239` — the immersive top strip `Container` (surface0 + amber bottom border) wrapping the tab bar, mode switcher, and document actions bar | V2-styled top chrome | **E** | `presentation/chrome/top_bar.dart`; superseded by the real V2 top bar (spec §6) | Explicitly "STRUCTURE/THEME ONLY this increment" per its own comment — a known-partial implementation | `_ImmersiveColors`, child widgets | No | Yes |
| 255 | `:2186–2195` — `DiagramTabBar` mount | Tab strip wired to `_activateTab`, `_closeTab`, `togglePin`, `_newDocument`, `_showRecentlyClosedMenu` | **E** | Audit §13 row 74: ADAPT — restyle into the V2 top strip at Wave 3 | Presentation over entries 78–84 | tabs state | No | Yes |
| 256 | `:2201–2208` — `DiagramModeSwitcher` mount | View/Edit/Simulate switch | **E** | Audit §13 row 72: REPLACE at Wave 3, on the two-dimension mode model (§11.4) | Presentation over entry 85 | `activeMode` | No | Yes |
| 257 | `:2210–2228` — `_DocumentActionsBar` mount | Dirty indicator plus New/Open/Save/Save As/Load Profile/Publish/Simulate/Close | **E** | `presentation/chrome/action_row.dart` | Presentation over entries 63–69, 122, 124. **`onPublish` constructs `PublishingCenterDialog.show(context, diagramKey: _document.path ?? 'untitled', graph:, layout:, intelligence:)` inline** — a dialog invocation embedded in a callback argument, which should become a named intent | `context`, `_document`, `_session`, `_intelligence` | No | Yes |
| 258 | `:2240–2405` — the `Wrap` toolbar container and its 13 conditional toolbar groups | The entire legacy toolbar surface: Selection, EditActions, Navigation, AlignDistribute, Placement, WireEditing, Layers, Annotations, View, Search, Panels, Constraints, SimulationControls, Intelligence, Instruments — each with mode gating and selection-based enablement | **E** | Audit §13 rows 77–78: one group ADAPT, eleven REPLACE, at Wave 3. **Audit risk R8 requires the `Wrap` be deleted in the same change that introduces the V2 action row** — no indefinite coexistence | Presentation. The `Wrap` (rather than a scrolling row) is deliberate: a horizontal scroll made late buttons unreachable and broke existing interaction tests. Preserve reachability at any width | `activeMode`, `_selection`, `_controller` capabilities | No | Yes |
| 259 | `:2261–2262`, `:2270`, `:2288`, `:2293`, `:2306`, `:2328`, `:2357`, `:2366` — the `activeMode == edit` / `!= edit` gates | "MODE DETERMINES WHAT IS VISIBLE": structural editing tools are Edit-only; selection/navigation/view/search/instruments stay available in every mode | **D** | Presentation, driven by a mode view-model | This is a command-*availability* policy that also feeds `ContextualCommandResolver` (entry 191). Audit §11.4 keeps the document-mode dimension authoritative | `activeMode` | No | Yes |
| 260 | `:2272–2278` — `EditActionsToolbar` enablement predicates (`canUndo`, `canRedo`, `selection.isEmpty`, `hasClipboardContent`) | Button enablement derived from controller capabilities | **B** (predicates) + **E** (toolbar) | Controller already exposes `canUndo`/`canRedo`/`hasClipboardContent` (`controller/…:80–82`) | Correct shape already | `_controller` | No | Yes |
| 261 | `:2321–2327`, `:2344–2347`, `:2348–2354` — `LayersToolbar`, `SearchToolbar`, `PanelsToolbar` toggle callbacks | Panel visibility toggles; the first two additionally persist workspace state, the third does not (entry 92) | **C** (state) + **E** (toolbar) | `diagramStudioLayoutController` | The persistence asymmetry lives here and must be resolved deliberately, not by accident | entries 27, 91, 113 | No | Yes |
| 262 | `:2329–2343` — `ViewToolbar` mount | Grid/snap/guides toggles wired straight to `ViewStateService`, plus the grid-settings and named-layouts dialogs | **B** (calls) + **E** (toolbar) | Controller viewport methods | Four more direct `_viewStateService` calls plus two `BuildContext` dialogs — §27 rows 12, 14 | `_viewStateService`, `context` | No | Yes |
| 263 | `:2357–2361` — `ConstraintsToolbar` mount (Edit mode only) | Orthogonal-movement / axis-lock constraints, wired to `_viewStateService.setConstraints` | **B** (call) + **E** (toolbar) | Controller | Editing-drag constraints have no meaning outside Edit mode — a real semantic gate | `_viewState.constraints`, `ViewStateService` | No | Yes |
| 264 | `:2406–2432`, `:2780–2796` — the four dock-slot bands (top/bottom rows, left/right columns) and their resize handles | The permanent-slot layout around the canvas | **D** | `presentation/panels/panel_manager.dart` | Pure layout; audit §5.5/§13 rows 18–21 unify this with the instrument dock into one V2 panel model | entries 96, 252 | No | Yes |
| 265 | `:2433–2447` — Object Explorer column (`KnowledgePanel` + `DiagramExplorerPanel`) with its width resize handle | A fixed left column, width `_explorerWidth`, clamped 150–400 | **E** | Audit §13 row 33: ADAPT — relocate **out of** the diagram workspace at Wave 7. Also drops `knowledge/widgets/knowledge_panel.dart` (Diagram Studio stops using it; Knowledge Studio still does — do not delete it) | Presentation | `_explorerWidth`, `currentGraph`, `_selection` | No | Yes |
| 266 | `:2448–2451`, `:2609–2610` — `LayoutBuilder` wrapping the canvas | Supplies measured constraints to `_ensureViewportSize` and to the minimap's viewport size | **D** | Presentation; §28 item 2 | Constraints are only knowable during Flutter layout | `LayoutBuilder` | No | Yes |
| 267 | `:2454–2509` — the `GraphViewPanel` call site with **48 callback/parameter bindings** | The canvas host: scene, viewState, symbols, guides, box-select rect, transform controller, connection/reconnect previews, annotations, wire-edit points, and every gesture callback in §§16–22 | **D** → **REPLACE** | Audit §6.2/§13 row 79: the new Studio **stops importing** `oep_engine/lib/views/widgets/` and renders `DiagramScene` itself (`presentation/canvas/`). The Engine widgets are neither modified, moved, nor deleted (spec §3.1, audit §12.3(a)) | This single call site is the largest concentration of intent-callback wiring in the file and is the natural seam between the controller and the new canvas | everything in §§16–22 | No | Yes |
| 268 | `:2505` — `resizingNodeId: _selection.nodeIds.length == 1 ? _selection.nodeIds.single : null` | Which node shows resize handles — **the single selected node, not `_resizingNodeId`** | **D** | Presentation | Verified by inspection: despite the parameter name, this passes the *selection*, not the in-progress resize target. It is almost certainly correct (handles appear on the selected node), but the naming collision with the page's own `_resizingNodeId` field is a genuine trap — §29 item 8 | `_selection` | No | Yes |
| 269 | `:2521–2532` — `DiagramIntelligenceOverlay` mount | Validation/analysis markers positioned with the same pan/zoom as the canvas; empty sets render nothing | **E** | Audit §13 row 34: ADAPT — re-host on the new canvas transform, V2 dim+glow language, Wave 4 | Additive `Stack` layer, deliberately never a modification to the frozen `GraphViewPanel` | entries 110, 111, `_effectiveLayout()`, `_viewState` | No | Yes |
| 270 | `:2600–2613` — `DiagramMiniMap` mount, wrapped in `IgnorePointer` | Fixed-size (180×120) floating overlay pinned to the canvas's bottom-right, deliberately **not** a dock-slot member; currently passive/click-through | **E** | Audit §13 row 36: ADAPT — **restore click-to-centre by dropping the `IgnorePointer` at this call site**, Wave 4 | The `IgnorePointer` is the reason the minimap is non-interactive today; the audit names removing it as the fix | `scene`, `_viewState`, `LayoutBuilder` constraints | No | Yes |
| 271 | `:2614–2643` — the coordinate/zoom readout | A status-bar-style label showing scene x/y and zoom percent, with `FontFeature.tabularFigures()`; em-dashes when the cursor is off-canvas | **E** | `presentation/chrome/status_bar.dart` (spec §4.5) | Presentation; the tabular-figures detail prevents digit jitter and should carry over | `_cursorScenePosition`, `_viewState.zoom`, `StudioColors` | No | Yes |

### 24.1 Side-panel column (`:2649–2779`)

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 272 | `:2649–2652` — `_anySidePanelVisible` gate, resize handle, and the `_sidePanelsWidth` `SizedBox` (clamped 240–480) | The right-hand secondary-panel column and its width | **C** (width) + **D** (layout) | `diagramStudioLayoutController` owns the width (it is persisted); the layout is presentation | Entry 114's gate is what avoids an empty strip | entries 27, 114 | No | Yes |
| 273 | `:2655–2708` — Layers, Search, Annotations, Recent Commands panel mounts | Four conditional `Expanded(KnowledgePanel(...))` panels | **E** | Audit §13 rows 35, 38, 32, 37: Layers/Annotations → toggled floating panels (Wave 7); Search → floating `/`-triggered overlay (Wave 5); Recent Commands → **REPLACE** with an undo-history dropdown / Output Panel (Wave 7) | Every removal must be a *relocation* with a recorded destination (audit risk R7). **Recent Commands reads `engine.editing.recentDescriptions` directly** — §27 row 15. Note also the recorded absence: the old Validation panel was already removed in favour of the shared Output Panel's Validation tab — do not reintroduce it | `_session.layout`, `_selection`, `engine.editing` | No | Yes |

---

## 25. Private widgets and value types declared in the same file

All fourteen are declared below `_DiagramStudioPageState` in the same file and
are covered by audit §6.4 ("private chrome widgets inside the monolith",
REPLACE). Each moves out of `workspaces/` regardless of its eventual fate.

| # | Location | Responsibility | Dest | Target | Reason | Dependencies | Lifecycle change? | Must remain for current UI? |
|---|---|---|---|---|---|---|---|---|
| 274 | `:2843–2848` — `_ImmersiveColors` (`surface0`, `surface1`, `amber`) | Three colour tokens modelled on the V2 reference's CSS custom properties, scoped to Diagram Studio's own chrome rather than shared `StudioColors` | **E** | `presentation/theme/v2_tokens.dart` | **Audit risk R10 names this exact class**: "a V2 look built on three tokens". The mitigation is to extract the full `main.css` token set (both themes) before building chrome — so this file is *replaced by* the real token set, not carried forward | — | No | Yes |
| 275 | `:2850` — `enum _ImmersiveSidebarTab { inspector, meter }` | Which sidebar tab is active | **D** | `presentation/chrome/left_sidebar.dart` | Presentation enum; its state lives at `:136` (`_immersiveSidebarTab`), which is genuinely widget-local UI state | — | No | Yes |
| 276 | `:2860–2916` — `_ImmersiveInspectorSidebar` | The always-visible left sidebar with Inspector/Meter tabs (spec §4.3) | **E** | `presentation/chrome/left_sidebar.dart` | Presentation. **Audit risk R11**: this is a *second* presentation of the same selection alongside the shared `PropertyInspectorPanel`; if both are kept, both must read `EngineeringInspectable` from the same notifier (entry 97) | `selection`, `graph`, `multimeter`, `lastPortTap` | No | Yes |
| 277 | `:2918–2947` — `_ImmersiveSidebarTabButton` | A tab button with an amber selected-underline | **E** | Same file as entry 276 | Presentation | `_ImmersiveColors` | No | Yes |
| 278 | `:2955–2998` + `:3000–3014` — `_ImmersiveInspectorPane` and `_wireInspector` | Wire Inspector for exactly one selected relationship; honest placeholder for empty/multi selection | **E** | `presentation/chrome/wire_inspector.dart` | Presentation reading only real graph data — the "never a fabricated description" discipline must carry over | `graph.relationships` | No | Yes |
| 279 | `:3016–3051` — `_portInspector` | Port detail (pin/component/direction/type) plus connected wires, found via the `metadata['sourcePort']`/`['targetPort']` convention | **E** | `presentation/chrome/wire_inspector.dart` | **Preserve the port-reference convention exactly** — it is shared with `StateConditionResolver` and `VerificationEngine`; inventing a second one would diverge from Engine behaviour | `graph.relationships`, `Port` | No | Yes |
| 280 | `:3053–3064` — `_moduleInspector` | Node detail (label/category/ports) | **E** | `presentation/chrome/module_inspector.dart` | Presentation | `EngineeringNode` | No | Yes |
| 281 | `:3066–3084` — `_inspectorField(label, value)` | The shared label/value row primitive | **E** | Moves with entries 278–280 | Presentation primitive | `StudioColors` | No | Yes |
| 282 | `:3086–3140` — `_ImmersiveMeterPane` | Compact meter summary: probe placements and `latestResult` (or `OL` when unreachable), wrapped in an `AnimatedBuilder` on the `MultimeterController` | **E** | `presentation/chrome/meter_instrument.dart`; audit §13 row 24 REPLACEs the DMM panel with a V2 photoreal instrument at Wave 6 — **keeping `DigitalMultimeterInstrument`'s registration** | Presentation. **This is the file's only correct `ChangeNotifier` observation** — contrast entries 43–45 | `MultimeterController` | No | Yes |
| 283 | `:3142–3247` — `_KeySwitchesRow` (with `_iconFor`) | KEY/SWITCHES row: one group per real `availableOperatingStates` (single-select) and per `availableInputStates`, driving `DiagramSimulationService.setOperatingState`/`setInputState`; renders nothing when the session has no real states | **E** | Merges into the V2 topbar KEY row (spec §7, audit §13 row 77, Wave 3) | Presentation over real session state. **`_iconFor`'s keyword→icon mapping deliberately lives in Studio presentation**, never in `oep_engine` (Phase 9's "no domain terminology in the engine" rule) — that placement must be preserved | `DiagramSimulationService`, `SimulationSession` | No | Yes |
| 284 | `:3248–3280` — `_KeySwitchGroup` | A labelled group of key/switch buttons | **E** | With entry 283 | Presentation | — | No | Yes |
| 285 | `:3282–3319` — `_KeySwitchButton` | An individual state button with active styling | **E** | With entry 283 | Presentation | `_ImmersiveColors` | No | Yes |
| 286 | `:3321–3359` — `_DiagramLegendPanel` | Category→stripe-colour legend derived from the categories actually on canvas; deliberately supplies no title/border of its own because `DockablePanel` provides them | **E** | `presentation/chrome/legend_overlay.dart` (spec §4.5) | Presentation over `categoryStripeColor` (Engine-side colour mapping) | `NodeCategory`, `categoryStripeColor` | No | Yes |
| 287 | `:3361–3424` — `_DocumentActionsBar` | The slim document-identity + action bar (entry 257's widget) | **E** | `presentation/chrome/action_row.dart` | **Carries the most important comment in the file** (`:2826–2835`): New/Save/Close are kept here rather than delegated to the Ribbon because the Ribbon's `diagram.newDocument`/`saveDocument`/`closeDocument` commands are *thinner* — they skip the discard confirmation and the workspace persist. Removing these buttons would be a silent functionality regression. **This Wave should close that gap by routing the Ribbon through `DiagramStudioController`**, which is exactly why the controller must become a provider (entry 3) | `StudioColors` | No | Yes |
| 288 | `:3426–3444` + `:3446–3477` — `_ResizeHandle` / `_VerticalResizeHandle` | Thin draggable dividers (6px) with the correct resize cursors, for column widths and slot heights | **E** | `presentation/panels/` | Presentation primitives; used at seven call sites | `MouseRegion`, `GestureDetector` | No | Yes |

---

## 26. Class totals

| Class | Count | Notes |
|---|---|---|
| **A** COMPOSITION ROOT | 10 | Entries 1, 2, 6, 10 (partial), 11, 15, 34, 248, 249, plus the residual shells of 63/65/67/68/69/78/80/82 |
| **B** CONTROLLER | 106 | Of which **41 are already done** (Wave 1 + the landed Wave 2 work) and are listed for verification only |
| **C** PROVIDER / SERVICE | 47 | Of which 21 are already-correct existing providers/services listed for boundary confirmation |
| **D** PRESENTATION | 52 | Includes the 6 entries in §28 that must stay widget-owned permanently |
| **E** TEMPORARY LEGACY PRESENTATION | 41 | Each carries its audit-assigned replacement wave |
| **F** ENGINE RESPONSIBILITY | 21 | Enumerated in full in §27 |
| **G** REMOVE / DEPRECATE LATER | 5 | Entries 4, 8, 36, plus the defects in 59 and 60 (fix, not remove) |
| **Total** | **288** | Some entries carry a split classification (e.g. **B** + **D**) and are counted under their primary class |

---

## 27. Direct Engine calls in `diagram_studio_page.dart` — the disappearance checklist

**Purpose:** after the code-moving stages, `grep -n "engine\." lib/diagram_studio/workspaces/diagram_studio_page.dart` must return **zero** results (other than comments). This table is the checklist.

There is **no `engine.editing.execute` and no `engine.editing.resetSession` call
left in the page** — Wave 1 already removed all of them, and Wave 2 moved
`loadNamedLayout`/`resetLayout` (the two `resetSession` callers) into the
controller. Verified by inspection of every `engine.` occurrence in the file.
What remains is selection, symbols, rendering, search, viewport, layout-provider,
and editing-history *reads and service calls* — none of which are command
execution, but all of which still cross the boundary from the page.

| Row | Line(s) | Call | Kind | Entry | Destination |
|---|---|---|---|---|---|
| 1 | `:563` | `engine.registry.selection.changes.listen(...)` | Selection stream subscription | 35 | Split C/D |
| 2 | `:750`, `:1966` | `engine.registry.selection.selectNode(id)` | Selection command | 247, 245 | B — controller |
| 3 | `:1041`, `:1043`, `:1045`, `:1321` | `toggleNode` / `selectNode(additive:)` / `selectNode` | Selection commands (node tap, drag start) | 173, 196 | B — controller |
| 4 | `:1062`, `:1064`, `:1977` | `toggleRelationship` / `selectRelationship` | Selection commands | 174, 245 | B — controller |
| 5 | `:1068`, `:2161`, `:2256` | `deselectAll()` | Selection command (background tap, Escape, toolbar) | 174, 180, 179 | B — controller |
| 6 | `:1138` | `engine.registry.symbols.resolve(node.symbolId!).ports` | Symbol registry read (port secondary tap) | 189 | B — controller/hit-tester |
| 7 | `:1509` | `engine.registry.symbols.resolve(node.symbolId ?? '')` | Symbol registry read (port anchoring) | 205 | B — controller/hit-tester |
| 8 | `:1241`, `:2000`, `:2014` | `selection.selectMany(nodeIds:, annotationIds:, additive:)` | Selection command (box select, symbol/layer search) | 183, 246 | B — controller |
| 9 | `:1778–1782`, `:2069–2075` | `engine.diagramView.render(graph, layout:, routing:, symbols:, selection:)` | **Scene rendering — the boundary object** | 232, 250 | B invocation; controller exposes the `DiagramScene` |
| 10 | `:1778–1782` specifically | The wire-edit re-seed renders the **entire scene** to read one wire's points | Performance hazard (audit R6) | 232 | B — controller; consider a targeted route query |
| 11 | `:1961` | `engine.registry.search.search(graph, layout, query)` | Search service call | 244 | B — controller |
| 12 | `:2337` | `layoutProvider: engine.registry.layout` | Layout provider handed to a dialog | 170 | B — controller supplies it |
| 13 | `:2077`, `:2296` | `engine.registry.symbols.all` / `.resolve(id).name` | Symbol registry reads (toolbar) | 251 | B — controller/view-model |
| 14 | `:2149`, `:2255` | `selection.selectAll(graph, layout:)` | Selection command (Ctrl+A, toolbar) | 177, 178 | B — controller |
| 15 | `:2706` | `engine.editing.recentDescriptions` | Editing-history read | 273 | B — controller/view-model |
| 16 | `:1704`, `:1706`, `:1708`, `:1715`, `:1979` | `toggleAnnotation` / `selectAnnotation(additive:)` / `selectAnnotation` | Selection commands (annotations) | 175, 225, 245 | B — controller |
| 17 | `:2457`, `:2578` | `symbols: engine.registry.symbols` passed to `GraphViewPanel` / `ProbeOverlay` | Symbol registry handed to widgets | 267, 138 | Supplied by the controller's view model |
| 18 | `:922` | `engine.registry.viewState as ViewStateService` | Downcast accessor | 14 | Deleted; the controller's copy is the only one |
| 19 | `:753`, `:938–940`, `:946`, `:966`, `:970`, `:975`, `:981`, `:1221`, `:1528–1529`, `:1969`, `:1982`, `:2002`, `:2016`, `:2284–2285`, `:2331–2333`, `:2360` | `_viewStateService.*` — `centerSelection`, `setZoom`, `setPan`, `setViewportSize`, `fitAll`, `fitSelection`, `resetView`, `hoverPort`, `goBack`, `goForward`, `canGoBack`, `canGoForward`, `toggleGrid`, `toggleSnap`, `setGuidesVisible`, `setConstraints` | Viewport service calls (~24 sites) | 140–148, 182, 207, 245–247, 262, 263 | B — viewport controller, **except** the two in `_syncViewStateFromTransform` (entry 141) and `_ensureViewportSize` (entry 142), which stay widget-side per §28 |
| 20 | `:1597`, `:1613`, `:1623` | `ConnectionValidator.canConnect(graph, a, b)` | Engine validator (static) | 211, 213, 214 | B — controller |
| 21 | `:1059`, `:1090`, `:1239` | `DiagramHitTesting.relationshipAt` / `nodesInRect` | Engine hit-testing (static) | 174, 187, 183 | B — controller/hit-tester |

**Also Engine-owned and called statically from the page** (not `engine.*` but
equally on the Engine side of the boundary, and equally scheduled to leave):
`AlignmentGuideComputer.computeGuides`/`snapToGuides` (entries 197–198),
`GridComputer.snap` (entries 198, 227), `WireEditing.insertVertex`/
`removeVertex`/`dragCorner`/`dragSegment` (entries 236–243),
`DiagramLayout.compute` (entries 149, 203), `fallbackPorts` (entry 205),
`offsetToPoint`/`rectFromOffsets` (entries 174, 181, 185),
`categoryStripeColor` (entry 286).

---

## 28. What Flutter requires to remain widget-owned

These map exactly to the class **D** entries marked "must remain". Each is here
because Flutter — not preference — requires it.

1. **`TransformationController` and both directions of its reconciliation.**
   (Entries 5, 32, 38, 51, 140, 141.) A `TransformationController` is a
   `ChangeNotifier` whose value is a `Matrix4` consumed by a specific
   `InteractiveViewer` in a specific subtree. Spec §3.4 lists `Matrix4` on the
   "never crosses" line, so neither the controller object nor the matrix
   conversion may move into `DiagramStudioController`. The **effects** it emits
   (`setZoom`/`setPan`) are Engine service calls and do move; the matrix
   arithmetic does not. It must also be disposed in `dispose()` — see entry 59,
   which is currently missing.

2. **Viewport-size propagation via `LayoutBuilder` + `addPostFrameCallback`.**
   (Entries 142, 266.) The canvas's pixel size is only knowable during Flutter
   layout, and mutating Engine state during `build()` is illegal — hence the
   post-frame deferral. Both the measurement and the deferral are Flutter
   mechanics with no controller equivalent.

3. **Every `BuildContext`-bound dialog, menu, and snackbar.** (Entries 64, 66,
   83, 122, 124, 162, 170, 192, 228, 257, 262.) `showDialog`, `showMenu`,
   `ScaffoldMessenger.of(context)`, `Navigator.of(context)`,
   `context.findRenderObject()`, and the `file_selector` pickers all need a
   `BuildContext`, which spec §3.4 forbids from crossing into the controller.
   The **decision points** these dialogs gate (dirty-check ordering,
   confirm-then-sequence) already sit correctly on the page side of each
   controller call and must stay at the same point in each sequence.

4. **Keyboard binding registration.** (Entries 172, 253.) `CallbackShortcuts`,
   `Focus`, `SingleActivator`, and `HardwareKeyboard.instance` are all
   `package:flutter` types. The bindings stay presentation; the actions they
   invoke become controller calls. Audit §6.3 requires the binding table be
   preserved verbatim across the rebuild.

5. **`setState` and the `mounted` guard itself.** (Entries 34, 46, and the ~60
   inline `setState` closures throughout §§16–22.) Only a `State` can call
   `setState`. Every responsibility that currently *lives inside* a `setState`
   closure is classified on its own merits above; what stays is the `setState`
   call, reduced to reacting to controller/provider notifications.

6. **`Focus(autofocus: true)`.** (Entry 61.) Focus acquisition on mount is a
   widget-tree operation. Note there is no page-owned `FocusNode` to dispose —
   `Focus` manages its own.

**Explicitly *not* on this list**, despite the Wave 2 brief asking about them:
there is no `TickerProvider`/`AnimationController` in this page, no page-owned
`Timer`, no `didChangeDependencies`, and no `WidgetsBindingObserver`
(entry 48). Nothing in those categories needs to remain widget-owned because
nothing in those categories exists.

---

## 29. Ambiguities, hazards, and decisions required before code moves

Recorded rather than resolved, per the brief's instruction not to assert
unverified reasons.

1. **Controller lifetime is the pivotal decision.** (Entries 3, 21.) Making
   `DiagramStudioController` provider-hosted is required by audit §11.5 and by
   the Ribbon-parity gap (entry 287), but it changes the lifetime of everything
   the controller reaches. The `isFirstStart` guard (`controller/…:449`)
   *should* remain correct because it derives from `engineHost == null`
   (engine-scoped, not controller-scoped) — but this must be **tested**, not
   assumed. If it regresses, a revisit to Diagram Studio would re-open the
   persisted document over live edits.

2. **`_handleBackgroundPanUpdate` multiplies the pan delta by zoom**
   (`:1221–1224`). Screen-to-scene conversion conventionally *divides* by zoom.
   This may be intentional compensation for where the delta originates, or it
   may be a bug that makes space-drag panning accelerate when zoomed in. **Not
   changed here.** Verify against real behaviour before the gesture handling
   moves, because a "cleanup" during the move would silently alter feel.

3. **Where does interaction state actually live?** Audit §11.3 assigns drag/
   resize/connect/reconnect/route-edit/box-select/hover/armed-probe/cursor state
   to the **controller**. Today all of it is `State` fields mutated inside
   `setState`. Moving it to a Flutter-free controller means every gesture frame
   must notify the widget tree through a provider instead of `setState` — a real
   rebuild-path change across ~40 handlers. §§18–22 classify these as **B** per
   the audit, but the *mechanism* (notifier granularity, per-frame rebuild cost)
   is unspecified and interacts directly with audit risk R6. Decide the
   notification mechanism before moving the first handler, not during.

4. **`_nodeAt` ignores per-node size** (`:1517–1526`): it hit-tests a fixed
   `_nodeSize` square from `layout.positions`, while `_boundsForNodes`
   (`:2023–2046`) honours `layout.sizeOf`. Resized nodes are therefore
   hit-tested at their original footprint. Verified by inspection; **whether
   this is a known limitation or a bug is not determinable from the code or its
   comments.** Do not silently unify the two during the move.

5. **`setState(() => _loading = false)` at `:576` is not `mounted`-guarded**,
   unlike every other post-await `setState` in `_bootstrap`'s vicinity
   (`_initInstruments`, `_refreshSimulationOverlay`, `_validateNow`, and
   `_analyzeSelectedNode` all guard). A fast navigate-away during bootstrap
   could therefore throw. Low likelihood, trivially fixed when the method moves.

6. **Should the shared Property Inspector clear when Diagram Studio unmounts?**
   Today it does (entry 55's microtask). Once the bridge becomes a provider
   (entry 97), it *can* keep the Inspector in step across navigation — but
   whether it *should* is a product decision, not a refactoring detail. The
   opposite choice (keep clearing) is equally implementable. **Decide
   explicitly; do not let the mechanism choose the behaviour.**

7. **Reconnect does not validate.** (Entry 221.) `_handleReconnectDragEnd`
   calls `controller.reconnectRelationship` without running
   `ConnectionValidator.canConnect`, while both wire-creation paths do validate.
   Verified by inspection. Whether the asymmetry is deliberate (reconnecting an
   existing wire has different rules) or an oversight is not stated anywhere.
   Flag to the owner; do not change behaviour during a move.

8. **`resizingNodeId:` at `:2505` is passed the selection, not the resize
   target.** (Entry 268.) It reads
   `_selection.nodeIds.length == 1 ? _selection.nodeIds.single : null` while the
   `State` separately holds `_resizingNodeId`. The behaviour is almost certainly
   intended (handles render on the selected node), but the name collision is a
   trap for anyone rewriting the canvas call site.

9. **Panel-persistence asymmetry.** (Entry 92.) Two of eleven panel toggles
   persist; nine do not, because `DiagramWorkspaceState` has no fields for them,
   and `_panelSlot`/`_slotSize` are explicitly runtime-only (entry 96). The V2
   panel-model wave fixes this by schema extension. Until then, **do not add
   persistence piecemeal** — that would create exactly the category drift audit
   §12.4 / risk R14 warns against.

10. **`_nodeSize = 100` is a mirrored Engine constant** (entry 150), duplicated
    from `DiagramLayout.nodeSize` with only a comment binding them. It feeds
    hit-testing, port anchoring, bounds maths, search framing, and the probe
    overlay. This is precisely audit §9.4's silent-breakage shape. Confirm the
    Engine constant is publicly reachable; if it is not, record an Engine gap
    rather than leaving the copy unremarked.

11. **Unobserved `ChangeNotifier` reads.** (Entries 43–46.) The page reads
    `DiagramSimulationService`, `DiagramIntelligenceService`,
    `InstrumentDockController`, and `MultimeterController` state synchronously
    in `build()` without watching them, compensating with ~30 manual
    `setState(() {})` callbacks from children. Converting these to real
    observation is correct but changes rebuild frequency — which the existing
    comment at `:262–277` explicitly warns about as a behavioural change. Use
    scoped `select`/view-models, not blanket `watch`.

12. **Two undisposed resources.** `_transformController` (entry 59) and the
    per-dialog `TextEditingController` in `_editAnnotationText` (entry 60). Both
    are leaks today. Fix them when the owning code moves — but as *named* fixes
    in the change description, so they are not mistaken for refactoring noise.

13. **Ribbon vs page divergence.** (Entry 287.) The shell's
    `diagram.newDocument`/`saveDocument`/`closeDocument` commands skip the
    discard confirmation and the workspace persist that the page's own buttons
    perform. This is documented in the code as a Command Framework gap that was
    deliberately not resolved unilaterally. **Wave 2 is the right time to close
    it** (route the Ribbon through the provider-hosted controller), but doing so
    changes shell behaviour and must be agreed, not assumed.

14. **`DiagramWorkspaceState.viewState` and `DiagramStudioSettings` both write
    `ViewStateService`.** (Entries 75, 94.) One restores the last session's
    viewport at bootstrap; the other applies preference defaults on every
    new/closed document. They are separate categories doing similar things to
    the same Engine service. No conflict was observed in the current ordering,
    but any change to bootstrap sequencing must re-check which one wins.

---

## 30. What this document does not decide

- The V2 tool-mode enum (`normal`/`layout`/`wire`/`route`) and its relationship
  to `DiagramStudioMode` — audit §11.4 owns that; entries 212 and 234 only note
  that `_wireCreateModeActive` and `_wireEditModeActive` are its precursors.
- The V2 panel-layout schema — audit §13 row 46 owns it; entries 92, 96, and
  113 only record what must feed into it.
- Which canvas renderer replaces `GraphViewPanel` — audit §6.2/§13 row 79 owns
  it; entry 267 only marks the seam.
- Any change to `oep_engine`, `oep_foundation`, the Engine diagram renderer, the
  routing provider, the engineering model, or the repository model. All frozen
  (spec §3.1, §3.7; audit §13.2, §15).

