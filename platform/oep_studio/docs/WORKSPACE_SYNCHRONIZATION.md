# Workspace Synchronization

How Diagram Studio's `EngineHost`/editing session/selection/validation
report became reachable from every route instead of only from
`DiagramStudioPage`'s own private `State`, and what "synchronized"
does and does not mean as a result (WORK_PACKAGE_025,
ENGINE-TASK-000118/000119).

## The problem this solves

Through WORK_PACKAGE_024, `DiagramStudioPage` created its own
`EngineHost` in `initState` and disposed it in `dispose`. That made the
Engineering Engine instance — and therefore the live editing session,
selection, and validation report — unreachable from anywhere except
that one page. A global Validation page, a unified Search page, and
Project Explorer all need to read (and, for selection, sometimes
write) that same live state from routes other than `/diagram`. That
was structurally impossible before this work package.

## The fix: hoist ownership into a Riverpod `Notifier`

`EngineeringProjectNotifier`/`engineeringProjectServiceProvider`
(`lib/core/services/engineering_project_service.dart`) now owns the
`EngineHost`, the `DiagramDocument`, and mirrors of the Engine's own
`EditingSession`/`GraphSelection`/`ViewState`/`ValidationReport`
streams, sibling to the existing `foundationRuntimeServiceProvider`.
`ensureEngineStarted()` is idempotent — safe to call every time
`DiagramStudioPage` mounts — and the Engine keeps running when the
user navigates away to Knowledge Studio, Validation, Search, or
Project Explorer.

`DiagramStudioPage` became a *reader*, not an *owner*. Its previous
private fields (`_engineHost`, `_document`, `_session`, `_report`,
`_selection`, `_viewState`) are now plain getters reading through
`ref.read(engineeringProjectServiceProvider)` — since Dart getters are
syntactically transparent at call sites, the page's ~900 lines of
existing gesture/editing-action methods needed no changes to their
bodies, only to how those six values are obtained. Document lifecycle
methods (new/open/save/save-as/close/mark-dirty) moved onto
`EngineeringProjectNotifier` itself, for the same reachability reason.

Purely visual/gesture-local state — the box-select rectangle, drag
deltas, the canvas `TransformationController`, panel widths — stayed
in `DiagramStudioPage`'s own `State`. It is genuinely page-local and
hoisting it would have added indirection for no benefit.

## What "synchronized" means in practice

* **Selection** is a single, Engine-owned `GraphSelection`. Selecting a
  node from anywhere that can reach the shared Engine (a canvas click
  in Diagram Studio, `goToDiagramElement`, a Validation finding's
  click-to-navigate) updates the same value everyone reads.
* **Validation** recomputes automatically on every `sessionChanges`
  event (`host.engine.validate(s.graph)`), so the global Validation
  page and Project Explorer's Validation branch both show the current
  report without polling or a manual refresh — `revalidate()` on the
  Notifier exists only to give a "Revalidate" button something
  concrete to call; it is not required for the report to be live.
* **Recent history** (`RecentHistoryEntry`/`recordHistory`,
  ENGINE-TASK-000119) is a single capped (50-entry) list on
  `EngineeringProjectState`, appended to only by the navigation helpers
  in `docs/WORKSPACE_SYNCHRONIZATION.md`'s sibling,
  `shared/navigation/unified_navigation.dart` — plain workspace
  switches via the Navigation Rail do **not** append to it, since they
  are not "navigating to" any particular object.

## What is not synchronized, and why

The Property Inspector's `selectedEngineeringInspectable` (on
`FoundationServiceState`) is bridged from Engine selection changes by
`DiagramStudioPage`'s **own**, page-local stream subscription
(`_syncPropertyInspectorSelection`, set up in `_bootstrap()`,
cancelled in `dispose()`) — not by
`EngineeringProjectNotifier`. This is deliberate: `EditingService.
sessionChanges`, `SelectionService.changes`, and `ViewStateService.
changes` are all `StreamController.broadcast()`, so both the Notifier
(updating shared state) and the page (bridging into the Property
Inspector) can subscribe independently. Practical effect: a selection
made while Diagram Studio is *not* mounted (e.g. directly through the
Engine, or via a navigation helper while on another route) updates the
shared selection immediately, but the Property Inspector only reflects
it once `DiagramStudioPage` next mounts and runs its "sync once
immediately on revisit" call — it does not update live in the
background while the user is looking at, say, the Validation page. The
Engine selection itself is never lost or reset by navigating away;
only the Property Inspector's *display* of it is deferred until the
page housing that bridge is visible again.
