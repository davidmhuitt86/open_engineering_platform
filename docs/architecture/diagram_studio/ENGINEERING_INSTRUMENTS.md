# Engineering Instruments Framework

**Work Package:** WP-DS-005A. **Architecture Phase:** AP-DS-005.

## Purpose

Engineering Instruments are a permanent subsystem of Diagram Studio —
available regardless of editing, verification, simulation, or
inspection mode, not a mode you switch into. The Framework provides
instrument registration, dock management, layout persistence,
visibility, toolbar integration, and keyboard shortcuts; each
instrument (Digital Multimeter first) plugs into it.

## Architectural principle

> Engineering Instruments shall remain presentation and interaction
> components. Engineering calculations shall remain inside the
> Simulation Engine, Verification Engine, and Engineering Intelligence
> Platform. Diagram Studio shall never compute engineering
> measurements.

Concretely: every instrument requests a reading through
`DiagramSimulationService.measure` (`lib/diagram_studio/simulation/
diagram_simulation_service.dart`), which is a thin, async pass-through
to the real `SimulationEngine.measure` (`oep_engine`,
`lib/core/simulation/simulation_engine.dart`), which itself delegates
to `MeasurementEngine`. No file under `lib/diagram_studio/instruments/`
computes a measurement value — search it and you will not find one.

## `EngineeringInstrument`

`lib/diagram_studio/instruments/core/engineering_instrument.dart`.

```dart
abstract class EngineeringInstrument {
  String get id;
  String get title;
  IconData get icon;
  String? get shortcutLabel => null;
  Widget buildPanel(BuildContext context);
}
```

`id` must be stable — it is used as the dock tab key and persisted in
dock layout state (`activeInstrumentId`). `buildPanel` returns the
instrument's own UI, rendered inside whichever dock surface (bottom or
floating) is currently showing it.

## `InstrumentRegistry`

A `ChangeNotifier` holding every instrument available to the current
Diagram Studio session: `register`, `unregister`, `byId`, `all`,
`isEmpty`. One registry per open diagram, created once in
`DiagramStudioPage._initInstruments()` and disposed with the page —
the same "one service instance per diagram" pattern
`DiagramSimulationService`/`DiagramIntelligenceService` already
established. `register` throws `StateError` on a duplicate id, so a
second instrument accidentally reusing an id fails loudly at
registration time rather than silently overwriting the first.

## Instrument Dock

`lib/diagram_studio/instruments/dock/`. See `instrument_dock.dart`'s
own doc comment for the authoritative list of what is real vs.
disclosed as a placeholder; in short:

| Requirement | Status |
|---|---|
| Bottom dock | Real |
| Floating window | Real, but an in-app movable/resizable surface, not a second OS window |
| Dock left / Dock right | Modeled in persisted state (`DockPosition.left`/`.right`); rendered as the bottom dock today |
| Auto-hide | Real — collapses to the tab strip when not hovered |
| Resize | Real — drag grip on the bottom dock; drag corner on the floating frame |
| Multiple instruments / Tabbed instruments | Real |
| Layout persistence | Real — `instrument_dock_layout.json` under `SettingsStorage.root()` |

`InstrumentDockState` (`instrument_dock_state.dart`) is the persisted
shape: position, visibility, auto-hide, size, floating bounds, active
instrument id. `InstrumentDockController` (`instrument_dock_controller.dart`)
is the live `ChangeNotifier` wrapper — every mutating method persists
immediately via `InstrumentDockStorage` (same file-per-concern JSON
storage shape as `WorkspaceStateStorage`, WORK_PACKAGE_024).
`InstrumentDock` (`instrument_dock.dart`) is the widget: it renders
nothing when hidden or the registry is empty, a tabbed bottom strip
(auto-hide aware) or a draggable/resizable floating frame otherwise.

## Toolbar integration and keyboard shortcuts

`DiagramStudioPage` renders an `_InstrumentToolbar` entry (dock
toggle, Probe A/Probe B arm buttons) inside its existing toolbar
`Wrap`, and binds `Ctrl+M` to `InstrumentDockController.toggleVisible`
inside the page's existing `CallbackShortcuts` scope — no new shortcut
infrastructure was added; this reuses what
`diagram_studio_page.dart` already had for Undo/Redo/etc.

## Reachability

Because the dock is initialized in `_bootstrap()` immediately after the
engine starts (not deferred to a first toggle), the Instrument Dock and
Digital Multimeter are reachable from the moment a diagram opens —
matching the spec's "shall remain available regardless of ... mode"
requirement literally, not just by intent.

## What is deferred

* Only the Digital Multimeter instrument exists. The Framework has no
  code specific to any instrument beyond `EngineeringInstrument`'s
  contract, so adding Oscilloscope/Logic Probe/etc. later is a new
  `EngineeringInstrument` implementation plus a `register()` call, not
  a Framework change.
* Session state beyond dock layout (e.g. "was the dock open when I last
  closed this specific document") is not tracked per-document — the
  dock's visibility/position/size is one Studio-wide setting.
* Settings (per-instrument preferences beyond dock layout) were not
  built — the Digital Multimeter has no settings panel of its own.
