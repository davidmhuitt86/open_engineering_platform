# Perspective Framework — How-To (WP-DS-006, Phase 1)

See `ENGINEERING_WORKBENCH.md` for the overall shell architecture. This
document is the practical "how do I add X" reference.

## Adding a new Perspective

A `Perspective` (`lib/workbench/perspective/perspective.dart`) is a plain,
immutable value object:

```dart
final myPerspective = Perspective(
  id: 'my-perspective',       // stable forever — used as the persisted
                               // layout file name (workbench_layouts/<id>.json)
  title: 'My Perspective',
  icon: Icons.something_outlined,
  centerBuilder: (context) => const MyCenterWidget(),
  toolbarProvider: (context) => const MyToolbar(),      // optional
  leftPanelProvider: (context) => const MyLeftPanel(),  // optional
  rightPanelProvider: (context) => const MyRightPanel(), // optional
  bottomPanelProvider: (context) => const MyBottomPanel(), // optional
  defaultLayout: const PerspectiveLayout(bottomVisible: true),
  suppressWorkbenchStatusBar: false, // true only if centerBuilder already
                                      // renders equivalent status chrome
);
```

Register it by adding it to the list in
`lib/workbench/perspectives/workbench_perspectives.dart`
(`workbenchPerspectives`) — that is the only file that needs to change.
`EngineeringWorkbenchPage`, `WorkbenchSidebar` (the left sidebar navigation
that superseded the original horizontal `PerspectiveSelector`), and
`PerspectiveManager` itself never need editing: they all iterate whatever
list they're given. A Perspective with real sidebar sub-items (e.g. Diagram's
recent-documents list) additionally sets `sidebarSubItemsProvider` — see
`ENGINEERING_WORKBENCH.md`'s WorkbenchSidebar section for the two real
examples and `PerspectiveSidebarItem`'s own doc comment for the shape.
`PerspectiveManager.register` throws `StateError` on a duplicate `id`, so
picking an already-used id fails loudly at registration time (in a test or
at app start), not silently.

For a test, build a small fixture list instead of importing
`workbenchPerspectives`, and pass it (plus injected `PerspectiveManager`/
`WorkbenchLayoutManager` pointed at temp files) into
`EngineeringWorkbenchPage`'s constructor — see
`test/workbench/engineering_workbench_page_test.dart`.

## `PerspectiveManager` persistence

`PerspectiveManager` (`lib/workbench/perspective/perspective_manager.dart`)
persists only the *active* perspective id, to
`SettingsStorage.root()/workbench_active_perspective.json`:

```json
{ "activePerspectiveId": "diagram" }
```

- `register`/`registerAll` — add Perspectives; throws on duplicate `id`.
- `activate(id)` — switches the active Perspective, notifies listeners,
  fire-and-forgets a write of the file above (same "cheap, small JSON,
  write on every change" precedent as `InstrumentDockController`/
  `WorkspaceStateStorage` elsewhere in this codebase). A no-op if `id`
  isn't registered or already active.
- `restoreLastPerspective({fallbackId})` — call once, after every
  `register`/`registerAll`, before the shell first builds. Reads the file
  above; if it's missing, corrupt, or names an id that's no longer
  registered, falls back to `fallbackId` (if registered) or the first
  registered Perspective.

## `WorkbenchLayoutManager` persistence

`WorkbenchLayoutManager` (`lib/workbench/layout/workbench_layout_manager.dart`)
persists one `PerspectiveLayout` per Perspective, to its own file under
`SettingsStorage.root()/workbench_layouts/<perspectiveId>.json` — e.g.
`diagram.json`, `simulation.json`, `inspection.json`, `publishing.json`.
Changing one Perspective's layout (dock visibility/size) never touches
another Perspective's file, and never touches
`workbench_active_perspective.json` (`PerspectiveManager`'s own, separate
file).

- `layoutFor(perspective)` — the live layout, or `perspective.defaultLayout`
  if nothing has been loaded/changed yet this session.
- `load(perspective)` — loads the persisted layout from disk (or falls
  back to `perspective.defaultLayout` if missing/corrupt). Idempotent;
  `EngineeringWorkbenchPage` calls it every time a Perspective is
  activated.
- `update(perspective, (current) => current.copyWith(...))` — updates the
  live layout and fire-and-forgets a persist to that Perspective's own
  file.

## `DockManager` / `DockRegion` / `DockPanelClient` — for any future
dockable content

These three pieces (`lib/workbench/dock/`) are content-agnostic: nothing
in them knows what a "dock" actually shows. They generalize WP-DS-005A's
`EngineeringInstrument`/`InstrumentRegistry`/`InstrumentDock` trio to be
usable for any future dockable content, not just Engineering Instruments
— see `instruments_perspective.dart` for a worked example
(`InstrumentDockPanelClient` adapting an existing `EngineeringInstrument`).

**1. Implement `DockPanelClient`** for whatever you want to dock:

```dart
class MyPanelClient extends DockPanelClient {
  const MyPanelClient();
  @override String get id => 'my-panel';
  @override String get title => 'My Panel';
  @override IconData get icon => Icons.something;
  @override Widget buildPanel(BuildContext context) => const MyPanelWidget();
}
```

**2. Register it into a `DockPanelClientRegistry`** — one registry per
dock region, matching `InstrumentRegistry`'s own "one per owning page"
convention:

```dart
final registry = DockPanelClientRegistry()..register(const MyPanelClient());
```

**3. Create (or load) a `DockManager`**, giving it a stable, app-unique
`dockId` — this is the file name under `workbench_docks/<dockId>.json`,
so it must never change once shipped:

```dart
final manager = await DockManager.load('my-dock-id');
```

**4. Render it** with `DockRegion`:

```dart
DockRegion(manager: manager, registry: registry)
```

`DockRegion` handles everything: Left/Right/Bottom/Floating/Hidden
placement (`DockSide`), Auto-hide (collapses to a thin tab strip when not
hovered), Resize (drag grips on docked sides), and Tabs (one tab per
`DockPanelClient` in the registry, switch via `manager.selectClient(id)`).
`DockManager`'s own methods (`show`/`hide`/`toggleVisible`/`selectClient`/
`setSide`/`setAutoHide`/`setSize`/`setFloatingBounds`) persist every change
to `dockId`'s own file, fire-and-forget, same precedent as
`PerspectiveManager`/`WorkbenchLayoutManager` above.

**Disclosed boundary** (same one WP-DS-005A's own `InstrumentDock` already
had): `DockSide.floating` renders an in-app, movable/resizable `Positioned`
surface (`_FloatingFrame`), not a real second OS window — Flutter desktop
multi-window isn't wired into this Studio anywhere.

## Instruments Perspective as a worked example

`lib/workbench/perspectives/instruments_perspective.dart` puts all of the
above together: `InstrumentsPerspectiveDock` owns one `DockManager`
(`dockId: 'instruments-perspective'`) and one `DockPanelClientRegistry`,
populated by wrapping whatever `EngineeringInstrument`s it's given in
`InstrumentDockPanelClient`. See `ENGINEERING_WORKBENCH.md`'s "Instruments
Perspective's dock-adapter approach" section for why it currently has
zero instruments to show (a disclosed, honest constraint, not a bug) and
what it renders instead.
