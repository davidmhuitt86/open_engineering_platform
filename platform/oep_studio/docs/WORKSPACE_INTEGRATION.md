# Workspace Integration

How `DiagramStudioPage` fits into Studio's existing workspace, toolbar,
panel, and settings patterns (WORK_PACKAGE_024, ENGINE-TASK-000108/
000112/000113/000114/000115).

## Routing

`StudioDestination.diagram` (`lib/core/routing/studio_destination.dart`)
+ a `GoRoute` in `lib/core/routing/app_router.dart`, inserted between
`knowledge` and `repository` — the same enum-value-plus-route shape
every other destination uses. Navigating to `/diagram` renders
`DiagramStudioPage` inside the same persistent `StudioShell`; there is
no floating window and no second navigation system.

## The workspace page

`DiagramStudioPage` (`ConsumerStatefulWidget`) owns:

* One `EngineHost` (created in `initState`, disposed in `dispose`).
* One `DiagramDocument` (open/save/save-as/close/dirty state).
* The full interaction state a professional diagram editor needs: node/
  port/wire/annotation dragging, box-select, drag-to-connect/reconnect,
  "Edit Route" mode, smart alignment guides — ported directly from the
  Engineering Engine's own Demonstration Host (`example/lib/main.dart`),
  adapted to call through `EngineHost`/`DiagramDocument` instead of a
  bare `EngineeringEngine` field, and to bridge selection into the
  shared Property Inspector (`docs/PROPERTY_INSPECTOR_INTEGRATION.md`).

This mirrors the Demonstration Host's own `_HostShellState` almost
method-for-method — that class is the proven, tested reference
implementation for "how do you drive `EngineeringEngine`'s editing API
from a Flutter UI," and WP024's job is porting that proven shape to
Studio's chrome, not re-deriving it.

## Toolbars — nine groups

`lib/diagram_studio/toolbars/diagram_toolbars.dart` defines nine small,
independent toolbar-row widgets: `SelectionToolbar`,
`DiagramNavigationToolbar` (named to avoid colliding with Flutter's own
`widgets.NavigationToolbar`), `PlacementToolbar`, `WireEditingToolbar`,
`LayersToolbar`, `AnnotationsToolbar`, `ViewToolbar`, `SearchToolbar`,
`ConstraintsToolbar`. Each is styled with `StudioColors` rather than the
Demonstration Host's Material defaults, and each is a direct port of the
Demonstration Host's `DemoToolbar`/`SecondaryToolbar` behavior — same
Engine calls, Studio-appropriate presentation. They live inside
`DiagramStudioPage`'s own content area, never inside the global
`StudioToolbar`.

A slim `_DocumentBar` (New/Open/Save/Save As/Close + dirty indicator)
sits above the toolbars — not one of the nine groups, since document
lifecycle is a Repository Integration concern
(`docs/REPOSITORY_INTEGRATION.md`), not an editing one.

## Panels — six, via `KnowledgePanel` chrome

Diagram Explorer, Layer, Search, Validation, Annotation, and Recent
Commands panels each wrap their content in the existing `KnowledgePanel`
widget (`lib/knowledge/widgets/knowledge_panel.dart`) — the same titled,
bordered chrome every Knowledge Studio panel already uses. "Reuse the
existing docking framework" means reusing *this* pattern: there is no
other docking framework in Studio to integrate with (panels are a fixed
`Row`/`Column` split with draggable resize handles, not a floating/
rearrangeable dock). Diagram Explorer sits on the left; the other five
panels stack in a resizable column on the right, inside Diagram
Studio's own content area — the global Property Inspector (always
docked at the shell level, see `PROPERTY_INSPECTOR_INTEGRATION.md`)
remains untouched and is not part of this page's own widget tree.

Layer and Search panels can be toggled via their toolbar group; the
other three (Validation, Annotation, Recent Commands) are always
visible, matching the lower cognitive overhead of "always know what
your undo stack/annotations/validation state is."

## Settings

`DiagramStudioSettingsProvider` (`lib/diagram_studio/settings/`)
implements the existing `SettingsProvider` interface and is appended to
`SettingsRegistry.defaultRegistry`, following `KnowledgeStudioSettingsProvider`'s
own template. Its `pageId` (`'diagram_studio'`) is a Diagram-Studio-
owned string rather than one of `CoreSettingsPageIds`'s eleven core
constants — `SettingsProvider`'s own doc comment explicitly allows "a
future provider's own unique id."

Its actual preferences (new-document default grid/snap/guides
visibility) are deliberately **not** folded into `UserConfiguration` —
that schema is versioned via `SettingsMigrationService` for Knowledge
Studio's own settings shape, and Diagram Studio's preferences have no
reason to share that lifecycle. They persist to their own file,
`diagram_studio_settings.json`, in the same root directory
(`SettingsStorage.root()`) but independently of `settings.json`.

## Workspace persistence

`DiagramWorkspaceState`/`WorkspaceStateStorage`
(`lib/diagram_studio/persistence/`) persist, to their own file
(`diagram_studio_workspace.json`, same root directory): the last-open
document's path, Layer/Search panel visibility, panel widths, and the
current `ViewState` (zoom/pan/grid/guides/constraints/theme — already
serializable via `ViewState.toJson()`/`fromJson()`, added in
WORK_PACKAGE_022). Restored on the next launch: if a last-open document
path is present and still resolves, it's reopened and its ViewState is
reapplied via `ViewStateService`'s existing public setters
(`setGridSettings`, `setZoom`, `setPan`, `setGuidesVisible`,
`setConstraints`, `setTheme` — there's no single bulk-restore method,
so restoration calls each one explicitly); otherwise Diagram Studio
opens to a fresh, blank document using the Settings page's own new-
document defaults.

The Engineering Graph and Diagram Layout are never stored in this file
— they belong to the diagram document (`docs/REPOSITORY_INTEGRATION.md`).
Storing them in two places would create two sources of truth for the
same content.
