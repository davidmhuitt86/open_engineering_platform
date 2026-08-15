# Implementation Status

## Work Package 001 — Application Shell + Dashboard

Status: Implemented

Tasks:

* STUDIO-TASK-000001 — Application Shell — Complete
* STUDIO-TASK-000002 — Dashboard — Complete

---

## What Exists

* Application shell: top toolbar, permanent left Navigation Rail (SDD-003),
  central Primary Workspace, bottom Status Bar (SDD-004 regions in scope
  for this work package).
* Routing via `go_router`, one route per navigation destination, all
  rendered inside a single persistent shell (`ShellRoute`). Only one
  Primary Workspace is visible at a time; navigation never opens a
  floating window, per SDD-003/SDD-004.
* Placeholder pages for Repository, Objects, Relationships, Search,
  Graph, Validation, Packages, and Settings.
* Dashboard implementing the approved `001-OEP-STUDIO-DASHBOARD-v1.0`
  mockup: Welcome header, Open Repository, Create Repository,
  Repository Status, Recent Repositories, Foundation Version,
  Installed Packages, and Getting Started, all with placeholder /
  disconnected-state data.
* Dark theme (SDD-002 Design Language): single sans-serif family,
  status-communicating color palette, monospace style reserved for
  technical data.
* `flutter_riverpod` wired at the app root (`ProviderScope`); no
  providers are defined yet — Work Package 001 has no state to manage
  beyond navigation, which `go_router` owns.

## What Is Explicitly Not Implemented

Per Work Package 001's architecture rules:

* `lib/core/foundation/` — Foundation Bridge — placeholder only, no
  FFI code.
* `lib/core/services/` — Studio Services — placeholder only.
* `lib/core/models/` — placeholder only.
* No Foundation references, no FFI, no engineering business logic
  anywhere in `lib/`.

## Repository Structure

```
lib/
  app/                 Application shell, theme wiring (StudioApp, StudioShell)
    widgets/            StudioNavRail, StudioToolbar, StudioStatusBar
  core/
    foundation/         Foundation Bridge — placeholder (SDD-006)
    models/              Studio domain models — placeholder
    routing/             StudioDestination enum, go_router config
    services/            Studio Services — placeholder (SDD-001/004)
    theme/                StudioColors, StudioTheme (SDD-002)
  features/
    dashboard/           Dashboard (SDD-007) — implemented
    repository/          Placeholder
    objects/             Placeholder
    relationships/        Placeholder
    search/               Placeholder
    graph/                 Placeholder
    validation/            Placeholder
    packages/              Placeholder
    settings/              Placeholder
  shared/
    widgets/              DashboardCard, PlaceholderWorkspace, ResponsiveCardGrid
```

`features/*` never imports `core/foundation` directly — only
`core/services` would, once implemented. This boundary is enforced by
folder convention today; nothing in this work package crosses it since
`core/services` has no Foundation-facing code yet.

## Verification

Environment note: this environment had no Flutter SDK installed at
the start of this work package. Flutter 3.44.6 (stable) was installed
via `git clone https://github.com/flutter/flutter.git -b stable` to
`C:\flutter` and added to PATH before any verification below was run.

* `flutter analyze` — no issues found.
* `flutter test` — 1/1 passing (`test/widget_test.dart`: app launches
  on the Dashboard, navigates to Settings via the rail, placeholder
  page renders).
* `flutter build windows` — succeeded;
  `build\windows\x64\runner\Release\oep_studio.exe` produced.
* Manual launch on Windows desktop — confirmed: app opens directly to
  the Dashboard, dark theme renders, Navigation Rail highlights the
  active destination, clicking a destination swaps the Primary
  Workspace and updates the Toolbar title with no floating window
  created.
* Manual resize — confirmed at 1000×720 (below the Dashboard's
  900px wide-layout breakpoint): the three-column card grid collapses
  to a single column, and the Toolbar/Status Bar shrink without
  overflow (both were fixed to use `Expanded`/`Flexible` and
  horizontally-scrollable regions after `flutter test`'s default
  800×600 surface first caught a `RenderFlex` overflow in all three —
  see Flutter-Specific Recommendations).

## Architectural Observations

* SDD-004 Workspace Framework lists five regions (Top Toolbar,
  Navigation Rail, Primary Workspace, Property Inspector, Status Bar).
  Work Package 001 scoped four of the five — Property Inspector is
  intentionally absent, matching both the work package's explicit
  requirements list and the approved Dashboard mockup, which does not
  show one. Flagging this so it is not mistaken for an oversight when
  Property Inspector is implemented in a later work package.
* `docs/UI_MOCKUPS.md` now records mockup status: 001 (Dashboard) and
  002 (Application Shell) are approved; the earlier tabbed/docked "IDE
  Shell Concept" is explicitly archived. This resolves the
  single-workspace-vs-tabs ambiguity flagged during the architecture
  review — SDD-004's single-workspace model is confirmed authoritative.
* The Foundation Bridge's eventual FFI implementation still has
  nothing to bind to: `oep_foundation/platform/api` (Public C API) and
  `specifications/sdk` remain placeholders as of this work package.
  This does not block Work Package 001 (no FFI is implemented here)
  but will block the first real Foundation Bridge work package until
  Foundation exposes a flat C ABI.

## Flutter-Specific Recommendations

* Keep `StudioDestination` as the single source of truth for
  navigation — the rail, router, and any future command palette should
  all read from it rather than duplicating the destination list.
* The Dashboard, Toolbar, and Status Bar were all initially written
  with fixed-width `Row` layouts and overflowed under `flutter test`'s
  default 800×600 surface. All three were corrected to shrink
  gracefully (`Expanded`/`Flexible`/`TextOverflow.ellipsis`, and
  horizontally-scrollable regions for the toolbar action group and
  status bar). Any new toolbar- or status-bar-style widget should be
  built and tested at a narrow width from the start rather than
  discovered via overflow errors later — Windows desktop windows are
  user-resizable down to very small sizes.
* `ResponsiveCardGrid` is a minimal hand-rolled solution for the
  Dashboard's card layout. If more Studio surfaces need responsive
  grids (Object Explorer, Search Results), consider promoting this to
  a shared, more general widget rather than each feature reinventing
  column-collapse logic.

---

## Work Package 002 — Foundation Bridge + Open Repository Workflow

Status: Implemented

Tasks:

* STUDIO-TASK-000003 — Foundation Bridge — Complete
* STUDIO-TASK-000004 — Open Repository Workflow — Complete

### What Exists

* `native/foundation_bridge/` — a CMake project, built as part of
  `flutter build windows`, that produces `oep_foundation_bridge.dll` by
  linking OEP Foundation's `oep_api` static library into a shared
  library `dart:ffi` can open. Compiles Foundation's existing CMake
  modules from the sibling `oep_foundation` checkout unmodified; no
  Foundation source file is changed. See `docs/FOUNDATION_BRIDGE.md`
  for why a `.def` file was needed instead of
  `WINDOWS_EXPORT_ALL_SYMBOLS`.
* `lib/core/foundation/` — the Foundation Bridge: `dart:ffi` bindings,
  plain-Dart types, and the public `FoundationBridge` class. Consumes
  only `oep_api.h`.
* `lib/core/services/foundation_runtime_service.dart` — the Studio
  Service owning Runtime State and Repository State (a Riverpod
  `Notifier`). Connects automatically on first read (app startup),
  auto-closes an already-open repository before opening a different
  one (`oep_runtime_open_repository` is only valid from Initialized or
  RepositoryClosed), and shuts the Runtime down cleanly via
  `ref.onDispose`.
* Dashboard: "Open Repository" now opens a native folder picker
  (`file_selector`), calls the Foundation Runtime Service, and shows a
  translated error dialog on failure. Repository Status, Foundation
  Version, and Installed Packages cards are reactive
  (`ConsumerWidget`/`ref.watch`) and reflect live Foundation state.
  "Create Repository" remains a placeholder — `oep_api.h` does not
  expose repository creation, only open/close.
* Status Bar: replaced "Foundation: Not Connected" with "Runtime:
  Connected"/"Runtime: Disconnected"; displays Runtime, Repository,
  Theme, and Studio Version per Work Package 002. Foundation Version
  moved to the Dashboard only.

### What Is Explicitly Not Implemented

* Repository creation (Public C API doesn't expose it yet).
* Recent Repositories persistence (no local storage layer exists yet;
  still an empty-state placeholder).
* Validation Status in the Status Bar (not in Work Package 002's
  explicit field list; deferred).

### Repository Structure Additions

```
native/
  foundation_bridge/
    CMakeLists.txt              Builds oep_foundation_bridge.dll from sibling oep_foundation
    oep_foundation_bridge.def   Explicit export list (see FOUNDATION_BRIDGE.md)
    src/bridge_stub.cpp         Empty — exists only so the SHARED target has a source
lib/
  core/
    foundation/
      oep_api_native_types.dart      dart:ffi structs/typedefs mirroring oep_api.h
      oep_api_bindings.dart          DynamicLibrary.open + lookupFunction
      oep_api_types.dart             Plain Dart enums/classes (no Pointer above this line)
      foundation_bridge_exception.dart  Error translation
      foundation_bridge.dart         Public FoundationBridge class
    services/
      foundation_runtime_state.dart    Immutable service-level state
      foundation_runtime_service.dart  Riverpod Notifier owning the FoundationBridge
```

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 1/1 passing. Note: `flutter test` runs against the
  host Dart VM, not the built Windows app bundle, so
  `oep_foundation_bridge.dll` is not on its DLL search path — connecting
  throws a raw `dart:ffi` `ArgumentError` rather than
  `FoundationBridgeException`. This surfaced a real bug (an
  uncaught-exception crash) rather than just a test-environment quirk,
  since the same failure mode applies to any real machine missing the
  DLL; `_connect()` now catches broadly and degrades to a visible
  Disconnected/error state instead of crashing. See Architectural
  Observations.
* `flutter build windows` — succeeded after fixing a CMake ordering bug
  (see Architectural Observations) — produced `oep_studio.exe` with
  `oep_foundation_bridge.dll` copied alongside it.
* Manual verification against the built exe, using a real repository
  generated by Foundation's own `oep init` (at
  `%TEMP%\oep_smoke_wp011\smoke-repo`):
  * Fresh launch — Dashboard shows "Connected" (green), Foundation
    Version 0.1.0, API Version 1, ABI Version 1, Runtime State
    "Initialized"; Status Bar shows "Runtime: Connected". "Open
    Repository" is enabled only once connected.
  * Opening the real repository — Repository Status updates live:
    Active Repository "smoke-repo", Runtime State "Repository Open",
    the repository's actual UUID, Version "1.0.0", Loaded Packages 0;
    Status Bar updates to "Repository: smoke-repo".
  * Opening an invalid folder — a translated AlertDialog appears
    ("Couldn't Open Repository" / "The selected folder doesn't contain
    a valid OEP repository."), Studio stays fully responsive, and no
    native path or error code is shown.
  * Resize to 1000×720 with a repository open — single-column
    Dashboard collapse still works, no `RenderFlex` overflow.
  * A second, independent process launch reconnects cleanly from
    Uninitialized, confirming the sequence isn't dependent on
    leftover state from a prior run.

### Architectural Observations

* **A Riverpod `Notifier.build()` return value silently overwrites any
  `state = ...` assignment made earlier in the same `build()` call.**
  The first implementation of `_connect()` set `state = ...` on success
  or failure, then `build()` unconditionally `return`ed a separate
  "connecting" placeholder afterward — which became the actual initial
  state regardless of what `_connect()` had just computed. This wasn't
  a build/analyzer error; it manifested at runtime as the Dashboard
  being permanently stuck on "Connecting…" (caught during manual
  verification, not by `flutter test`, since the widget test never
  asserts on Foundation connection state). Fixed by having `_connect()`
  return the resulting `FoundationServiceState` directly and having
  `build()` return that value, rather than mutating `state` and
  separately returning something else. Any future `Notifier` in this
  codebase whose `build()` needs to run fallible setup logic should
  follow the same pattern: compute and return the state, don't assign
  `state` from inside `build()`.
* **CMake `add_custom_command(TARGET ...)` requires same-directory
  scope.** The first attempt placed the DLL-copy step in the top-level
  `windows/CMakeLists.txt`, referencing the `oep_studio` executable
  target — which is actually created inside `runner/CMakeLists.txt`, a
  child subdirectory. CMake rejected this ("TARGET 'oep_studio' was not
  created in this directory"). Fixed by moving the copy step into
  `runner/CMakeLists.txt` itself, and moving `add_subdirectory` for
  `native/foundation_bridge` to *before* `add_subdirectory("runner")`
  so the `oep_foundation_bridge` target already exists when
  `runner/CMakeLists.txt` references it.
* **`WINDOWS_EXPORT_ALL_SYMBOLS` doesn't reach into linked static
  libraries.** It only scans a target's own object files for
  exportable symbols. Since `oep_foundation_bridge`'s only own source
  is an empty stub (the real code comes from linking `oep_api`), this
  produced a DLL with zero exports — confirmed with `dumpbin /EXPORTS`
  before switching to an explicit `.def` file, which re-exports a
  symbol regardless of which linked object file it resolves to. Any
  future "wrap a static lib in a DLL" work in this codebase should use
  a `.def` file, not this CMake property.
* **Foundation's Public C API is a genuine architectural fit for this
  boundary.** `oep_api.h` (implemented since the Work Package 001
  review, when it was a placeholder) is exactly the pure-C, exception-free,
  pointer-free-struct surface a Bridge needs — no changes to Foundation
  were necessary to build a working Bridge.
* **`oep_repository_status_t` is intentionally thin.** It exposes
  `repository_id`/`name`/`version`/`loaded_package_count` — no path, no
  last-modified timestamp, no object/relationship counts. The Dashboard's
  Repository Status card was written to only show fields the API
  actually provides, rather than inventing placeholders for data
  Foundation doesn't expose yet.

### Flutter-Specific Recommendations

* Struct-by-value FFI returns (`OepResultNative` returned directly from
  `oep_runtime_initialize` et al.) worked without issue on Dart
  3.12/Flutter 3.44 — no workaround (e.g. out-parameter struct pointers)
  was needed for the result type, only for `oep_repository_status_t`,
  which the C API itself defines as an out-parameter.
  `_decodeFixedCString`/`decodeFixedCString`-style helpers are needed
  anywhere a fixed `char[]` is embedded directly in a struct (as opposed
  to a `Pointer<Utf8>`, which has `.toDartString()` built in via
  `package:ffi`) — there's no built-in Array-to-String helper.
  Consider a small shared `dart:ffi` utility if a third such struct
  appears.
  * A single `FoundationBridge`/`FoundationRuntimeNotifier` pair is
  enough for Work Package 002's scope (one Runtime, one repository at a
  time). If a future work package needs multiple concurrent
  repositories, the Notifier's single `_bridge` field is the thing that
  will need to become a collection — flagged here rather than
  speculatively built now.

---

## Work Package 003 — Repository Explorer, Object Explorer, Property Inspector, Connection Manager

Status: Implemented

Tasks:

* STUDIO-TASK-000005 — Repository Explorer — Complete
* STUDIO-TASK-000006 — Object Explorer — Complete

### What Exists

* `lib/features/repository/repository_page.dart` — Repository Explorer:
  shows the open repository's name, all six categories (Components,
  Documents, Diagrams, Procedures, Images, Projects — matching
  Foundation's `ObjectType` enum exactly), expand/collapse per
  category, an incremental filter over category labels, and a "No
  Repository Open" state with a button that returns to the Dashboard.
  Category counts always read "—" — see § Missing Public API.
* `lib/features/objects/objects_page.dart` +
  `lib/features/objects/object_list_query.dart` — Object Explorer: a
  "No Category Selected" prompt when navigated to directly, otherwise
  a sortable (Name/Type/Author), filterable (author, incremental name
  search; type filtering supported by the same pure `ObjectListQuery`
  logic but not exposed as a separate control here since the list is
  already scoped to one category) object list. The list is always
  empty in practice — see § Missing Public API — but the sort/filter
  pipeline itself is fully implemented and unit-tested against
  synthetic data (`test/object_list_query_test.dart`, 8 cases).
* `lib/shared/widgets/property_inspector_panel.dart` — a new persistent
  right-hand region added to `StudioShell` (SDD-004's fifth region,
  deferred in Work Package 001), showing the selected object's Name/
  Object Type/Author/Version/Description/Tags, or "No Object Selected".
* `docs/CONNECTION_MANAGER.md` (new) — documents
  `FoundationRuntimeNotifier`/`FoundationServiceState` (introduced in
  Work Package 002, not renamed) as fulfilling the "Connection
  Manager" role Work Package 003 introduces, extended with
  `selectedCategory`/`selectedObject` (Current Selection). Selection is
  automatically cleared on repository open/close and on category
  change.
* Status Bar: added "Selected Object: <name/None>".
* `lib/core/models/object_category.dart` /
  `engineering_object_summary.dart` — plain Dart models mirroring
  Foundation's `ObjectType`/`EngineeringObject` shape, used for UI
  structure and the sort/filter pipeline. Not populated from real
  Foundation data (see below).
* `windows/runner/win32_window.cpp` — added a `WM_GETMINMAXINFO`
  handler enforcing a 1000×700 logical-pixel minimum window size (see
  Architectural Observations).

### What Is Explicitly Not Implemented

Per Work Package 003's Public API rule ("If additional Public API
functionality is required: Document it. Do not implement it.") — see
`docs/CONNECTION_MANAGER.md` § Missing Public API for full detail:

* Real category object counts (Repository Explorer always shows "—").
* Real object listing (Object Explorer's list is always empty; sort/
  filter logic is implemented and tested, just has no live data to
  operate on yet).
* Real object detail (Property Inspector only ever shows "No Object
  Selected" in practice, since no object can be selected without a
  real list to select from).

No changes were made to `oep_foundation` to work around this — the gap
is documented, not implemented around.

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 12/12 passing: the existing app-shell test (extended
  with Property Inspector/Status Bar assertions), the two new
  navigation tests (Repository Explorer's "No Repository Open" →
  Dashboard round trip; Object Explorer's "No Category Selected" →
  Repository Explorer round trip), and 8 `ObjectListQuery` unit tests
  (sort by name/type/author, filter by type/author/tag, incremental
  search, non-mutation, combined-filter AND semantics, empty input).
* `flutter build windows` — succeeded twice (once before, once after
  the Status Bar flex-weighting fix below), producing `oep_studio.exe`
  with the native Foundation Bridge and the new `WM_GETMINMAXINFO`
  minimum-size behavior both included.
* Manual verification against the built exe with a real open
  repository (`smoke-repo`): Repository Explorer lists all six
  categories with correct icons and honest "—" counts; clicking a
  category navigates to Object Explorer with the category name in the
  header and an honest "No objects found in this category." state;
  Object Explorer's "No Category Selected" prompt correctly routes back
  to Repository Explorer when navigated to directly via the nav rail;
  Property Inspector is visible on every page, always reads "No Object
  Selected" (nothing is ever selectable yet); Status Bar shows
  "Selected Object: None".
* Manual resize verification: attempted to resize the window to
  500×400 via a programmatic `MoveWindow` call (bypasses the
  interactive-drag path but still routes through `WM_GETMINMAXINFO`
  via `DefWindowProc`) — confirmed the OS clamped it to the enforced
  1000×700 logical minimum (1250×875 physical at this machine's 125%
  DPI scale) rather than allowing an unusably small window.

### Architectural Observations

* **The Status Bar's two `Flexible` regions competed equally for space
  by default, silently clipping the newer (and more important) left
  group.** At the enforced 1000px minimum width with a real repository
  open, "Ready | Repository: smoke-repo | Runtime: Connected |
  Selected Object: None" (~465px) didn't fit in an equal 1/3 share of
  the available row width, and `SingleChildScrollView` clipped from
  the end — silently dropping "Selected Object: None" entirely rather
  than throwing a `RenderFlex` overflow error (which is why `flutter
  test` didn't catch it; it was only caught by capturing a screenshot
  at the real minimum size against a real open repository). Fixed by
  weighting the left `Flexible` at `flex: 3` against the right side's
  default `flex: 1`, and marking the right side `reverse: true` so
  *its* clipping (if any) drops the less-important leading label
  rather than the trailing version string. General lesson carried
  forward from Work Package 001/002: a passing `flutter test` run does
  not guarantee no visual clipping — narrow-width manual verification
  against real (not just placeholder) content remains necessary.
* **The desktop window previously had no enforced minimum size** —
  `flutter create`'s default `win32_window.cpp` doesn't set one. Added
  a `WM_GETMINMAXINFO` handler (1000×700 logical pixels, matching the
  width this and prior work packages have already established as the
  practical minimum for the Navigation Rail + Property Inspector +
  Primary Workspace layout). This is a real Win32 mechanism that
  constrains interactive drag-resizing directly; it was also confirmed
  to constrain programmatic `MoveWindow` calls via manual testing.
* **`docs/CONNECTION_MANAGER.md` documents an existing class under a
  new name rather than renaming it.** `FoundationRuntimeNotifier`/
  `foundationRuntimeServiceProvider` (Work Package 002) already
  fulfilled everything Work Package 003 asks of a "Connection
  Manager" except Current Selection, which was added to the same
  class. Renaming the symbols themselves was judged unnecessary
  churn — the work package asks to "introduce" the concept and
  document it, which is satisfied by documentation plus the additive
  extension, without disrupting working, tested code.

### Flutter-Specific Recommendations

* `ObjectListQuery` (pure sort/filter logic, no widget dependencies) is
  a pattern worth repeating: whenever a feature's real data source
  doesn't exist yet, separating the data-transformation logic from the
  widget that displays it means the logic can still be genuinely unit
  tested, rather than leaving "sort/filter works" as an unverified
  claim until Foundation catches up.
* When adding a new persistent shell region (Property Inspector), the
  `StudioShell` `Row` needed restructuring — the `Column`
  (workspace + status bar) that was previously the sole `Expanded`
  child of the outer `Row` now needs to sit *between* the Nav Rail and
  the new fixed-width panel, with the Status Bar pulled out to a
  `Column` that spans the *full* shell width (below the Nav
  Rail+Workspace+Inspector `Row`), not just the workspace's width, so
  the Status Bar's Runtime/Repository/Selected Object/Theme/Version
  content isn't squeezed by the new sidebar. Any future
  five-region-layout change should keep this structure (side panels
  inside the row, status bar outside/below it) in mind.

---

## Work Package 004 — Live Repository Explorer, Object Explorer, Property Inspector, Dashboard

Status: Implemented

Tasks:

* STUDIO-TASK-000007 — Live Repository Explorer — Complete
* STUDIO-TASK-000008 — Live Object Explorer — Complete

### What Exists

Between Work Package 003 and this one, Foundation's own Work Package
012 added Engineering Object Enumeration and Repository Statistics to
`oep_api.h` (`OEP_API_VERSION` 1 → 2). This work package consumed that
new surface with no Foundation changes:

* `native/foundation_bridge/oep_foundation_bridge.def` — 6 new exports
  (`oep_object_type_to_string`, `oep_object_store_get_count`,
  `oep_object_store_get_by_id`, `oep_object_store_list`,
  `oep_object_list_release`, `oep_runtime_get_repository_statistics`),
  verified with `dumpbin /EXPORTS` (20 symbols total, up from 14).
* `lib/core/foundation/` — `OepObjectInfoNative`,
  `OepObjectListNative`, `OepRepositoryStatisticsNative` (native
  structs) and four new `FoundationBridge` methods
  (`getRepositoryStatistics`, `getObjectCount`, `getObjectById`,
  `listObjects`). See `docs/FOUNDATION_BRIDGE.md` for the full
  breakdown, including the one genuinely new `dart:ffi` pattern this
  work package needed (2D fixed arrays for `tags[16][64]`).
* `lib/core/models/object_category.dart` — `ObjectCategory` gained
  `nativeValue`, mapping each category to its `oep_object_type_t`
  ordinal (which is *not* the same as Studio's required display order).
* `lib/core/models/engineering_object_summary.dart` —
  `EngineeringObjectSummary.fromNative` decodes a real
  `oep_object_info_t` (previously this model only existed for
  synthetic test data).
* `lib/core/services/` — `FoundationServiceState` gained
  `repositoryStatistics`/`objectList` (and the derived
  `objectsInSelectedCategory` getter); `FoundationRuntimeNotifier.
  openRepository` fetches both after a successful open, with
  independent non-fatal error handling for each (see
  `docs/CONNECTION_MANAGER.md` § Foundation Interaction).
* Repository Explorer — category counts now read real numbers from
  `RepositoryStatistics.objectCountByCategory`; expanding a category
  previews its actual object names.
* Object Explorer — the object list, sort, and filter pipeline
  (already built and unit-tested in Work Package 003 against synthetic
  data) now runs against real `objectList` data from the Connection
  Manager.
* Property Inspector — displays live Name/Object ID/Object Type/
  Author/Version/Description/Tags; Object ID is new this work package
  and rendered in the monospace style already established for
  technical data (SDD-002).
* Dashboard's Repository Status card — replaced with Repository Name/
  Version/ID (sourced from `RepositoryStatistics` when available,
  falling back to `RepositoryStatus` if statistics haven't loaded
  yet)/Total Objects/Relationship Count/Package Count. Foundation/API/
  ABI Version remain on the separate Foundation Version card, per this
  work package's explicit instruction.
* `foundation_bridge_exception.dart` — the `NOT_FOUND` error message
  was over-specialized to repository-open failures ("The selected
  folder doesn't contain a valid OEP repository") in a way that would
  have been actively misleading if a future object lookup ever
  surfaced the same category/code pair. Generalized to "The requested
  item couldn't be found." before wiring up `getObjectById`, even
  though nothing calls it yet — see Architectural Observations.

### What Is Explicitly Not Implemented

See `docs/CONNECTION_MANAGER.md` § Missing Public API — nothing
required for this work package's scope was missing from `oep_api.h`.
Relationship browsing, object creation/editing/deletion, and Create
Repository remain out of scope, as before.

### Repository Structure Additions

No new files — this work package extended existing Work Package
002/003 files (`oep_api_native_types.dart`, `oep_api_bindings.dart`,
`foundation_bridge.dart`, `foundation_runtime_state.dart`,
`foundation_runtime_service.dart`, `object_category.dart`,
`engineering_object_summary.dart`, `repository_page.dart`,
`objects_page.dart`, `property_inspector_panel.dart`,
`dashboard_page.dart`) rather than adding new ones.

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 12/12 passing (unchanged from Work Package 003 —
  no new automated tests were needed; `ObjectListQuery`'s existing
  synthetic-data tests already covered the sort/filter logic this work
  package wired up to real data).
* `flutter build windows` — succeeded, `oep_foundation_bridge.dll`
  rebuilt with the 6 new exports confirmed present.
* Manual verification against the built exe with a real
  multi-object repository, generated via Foundation's own CLI
  (`oep init` + 5× `oep object create` across 4 categories:
  2 Components, 1 Document, 1 Diagram, 1 Procedure):
  * Dashboard — Repository Name "wp004_test_repo", Total Objects 5,
    Foundation API Version correctly reads 2 (bumped from 1),
    confirming the rebuilt DLL is genuinely in use, not a stale copy.
  * Repository Explorer — category counts exactly matched what was
    created: Components 2, Documents 1, Diagrams 1, Procedures 1,
    Images 0, Projects 0.
  * Object Explorer (Components category) — both real objects listed,
    correctly sorted by name ("Backup Battery" before "Main
    Generator"), with correct author/version columns.
  * Property Inspector — selecting "Main Generator" showed its real
    Object ID (a UUID matching the CLI's create output exactly),
    Author "jsmith", Version "1.0.0", Description "Primary electrical
    power generator", Tags "electrical, power".
  * Status Bar — "Selected Object: Main Generator" updated correctly
    on selection.

### Architectural Observations

* **A latent error-message bug surfaced only by writing the second
  caller of a shared code path.** `FoundationBridgeException`'s
  `NOT_FOUND` translation was written in Work Package 002 for exactly
  one caller (repository open) and hardcoded repository-folder
  language into what was actually a generic `(error_code,
  error_category)` translation table. Adding `getObjectById` (a second
  potential `NOT_FOUND` source) made the mismatch concrete enough to
  fix before it shipped a misleading dialog. General lesson: an error
  translation function's messages are only as generic as its *most
  specific* caller assumed — worth re-reading whenever a new call site
  is added, even if that call site isn't wired into the UI yet.
* **Foundation added exactly the API this work package's Work Package
  003 predecessor asked for, matching the documented request almost
  field-for-field.** `oep_repository_statistics_t.object_count_by_type`
  directly answers "populate category counts using Foundation
  statistics"; `oep_object_info_t.tags` uses a fixed-capacity array
  (16 × 64 bytes) — one of the two designs
  `docs/CONNECTION_MANAGER.md` speculated Foundation might choose for
  the variable-length-tags problem, and the simpler of the two. This
  is a good outcome of the "document it, don't implement it" discipline:
  Foundation's actual design ended up more directly usable than
  guessing and building around a shape Studio invented.
* **`ObjectCategory`'s declaration order (required UI display order)
  and `nativeValue` (Foundation's ordinal order) had to be decoupled
  explicitly**, since they're genuinely different orderings that both
  need to exist on the same enum. Getting this wrong silently
  (e.g. relying on `ObjectCategory.values[nativeType]` instead of the
  explicit `fromNative` lookup) would have scrambled which category
  showed which count with no error at all — this class of bug (enum
  declaration order accidentally standing in for a semantic mapping)
  is worth actively watching for in any future enum that mirrors a
  native ordinal.

### Flutter-Specific Recommendations

* **Extension methods are not visible transitively.** `dart:ffi`'s
  `Array<T>.operator[]` comes from an `extension` (`ArrayArray`), and
  extensions — unlike types — are only in scope in a file that imports
  their declaring library directly. `engineering_object_summary.dart`
  could reference the `OepObjectInfoNative` *type* through a transitive
  import (`oep_api_native_types.dart` re-exporting it via normal type
  inference) but could not call `.tags[i]` on it until `import
  'dart:ffi';` was added directly to that file too. Any file that
  indexes a `dart:ffi` `Array` — not just one that declares a struct
  containing one — needs its own `dart:ffi` import.
* **Windows focus-stealing prevention affected manual verification,
  not the app itself** — worth noting since it cost real debugging
  time this work package: automated UI verification via synthetic
  mouse clicks silently failed whenever an unrelated window (e.g. a
  browser) held foreground focus, because `SetForegroundWindow` alone
  doesn't override Windows' focus-steal lock from a background
  process. Confirmed by checking `GetForegroundWindow()` before/after
  each click; fixed by tapping Alt (`keybd_event`) immediately before
  `SetForegroundWindow`, a standard bypass for that lock. Not an
  application bug — included here only because it's a recurring cost
  in this verification workflow and the fix is non-obvious.

---

## Work Package 005 — Relationship Explorer, Search Workspace

Status: Implemented

Tasks:

* STUDIO-TASK-000009 — Relationship Explorer — Complete
* STUDIO-TASK-000010 — Search Workspace — Complete

### What Exists

The Public C API exposes no relationship enumeration or search
function (confirmed by grepping `oep_api.h` before starting — see
`docs/CONNECTION_MANAGER.md` § Missing Public API), so per this work
package's explicit rule ("document the requirement, do not implement
it") no Foundation changes were made:

* `lib/core/models/relationship_type.dart`,
  `relationship_summary.dart`, `search_result.dart` — plain Dart
  models mirroring Foundation's C++ `RelationshipType`/`Relationship`/
  `MatchLocation`/`ObjectSearchResult`/`RelationshipSearchResult`
  shapes (read directly from Foundation's headers, not guessed), with
  no `fromNative` constructor — there is no native struct yet for
  either to decode, unlike `EngineeringObjectSummary` (Work Package
  004).
* `lib/features/relationships/relationships_page.dart` +
  `relationship_list_query.dart` — Relationship Explorer: sortable
  (Type/Source/Target/Author), filterable (type/source/target/author)
  table, a "No Repository Open" state, and an honest "No Relationships
  Found" empty state with the required guidance text — always shown,
  since the list is always empty, confirmed even against a real
  repository with real relationships (see § Verification). Sort/filter
  logic is fully implemented and unit-tested against synthetic data
  (`test/relationship_list_query_test.dart`, 10 cases).
* `lib/features/search/search_page.dart` — Search Workspace: search
  box/button/clear button, an idle state, and — since every search is
  unavailable — a professional "Couldn't search for '\<query\>'" /
  "Live repository search isn't available in this version of Studio
  yet." message rather than a misleading "no results" claim. In-memory
  Search History (Previous Searches, Clear History) implemented as
  local widget state, not Connection Manager state — see
  `docs/SEARCH_WORKSPACE.md` for why.
* Connection Manager — `selectedRelationship`, `searchQuery`,
  `searchResults` added to `FoundationServiceState`;
  `selectObject`/`selectRelationship` now clear each other
  (mutual exclusivity); `search`/`clearSearch`/`selectRelationship`/
  `clearRelationshipSelection` added to `FoundationRuntimeNotifier`,
  all pure local state mutations (no Foundation call exists to make).
* Property Inspector — now switches between Object mode and
  Relationship mode based on which of `selectedObject`/
  `selectedRelationship` is non-null (`switch` on a record pattern
  `(selectedObject, selectedRelationship)`), showing Relationship
  ID/Type/Source/Target/Author/Description/Created Date in
  Relationship mode.
* `foundation_bridge_exception.dart` — unchanged this work package
  (its Work Package 004 generalization already covers a relationship
  "not found" case, should one ever be surfaced).

### What Is Explicitly Not Implemented

See `docs/CONNECTION_MANAGER.md` § Missing Public API for full detail
— relationship enumeration, repository search, and (as in every prior
work package) repository/object/relationship creation, editing, and
deletion.

### Repository Structure Additions

```
lib/
  core/
    models/
      relationship_type.dart
      relationship_summary.dart
      search_result.dart
  features/
    relationships/
      relationship_list_query.dart   Pure sort/filter logic (mirrors object_list_query.dart)
    search/
      (search_page.dart rewritten in place; no new files)
test/
  relationship_list_query_test.dart
docs/
  SEARCH_WORKSPACE.md                New
```

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 24/24 passing: all prior tests unchanged, plus 10
  new `RelationshipListQuery` unit tests (sort by type/source/target/
  author, filter by type/source/target/author, non-mutation, empty
  input) and 2 new widget tests (Relationship Explorer's "No
  Repository Open" state; Search Workspace running a search and
  reaching the unavailable state, then clearing back to idle).
* `flutter build windows` — succeeded, no native changes to rebuild
  beyond the standard Dart/Flutter recompile (the DLL itself is
  byte-for-byte the same as Work Package 004's, since no new exports
  were needed).
* Manual verification against the built exe with a real repository
  (`wp004_test_repo`) that has 2 real relationships created via
  Foundation's CLI (`oep relationship create`, confirmed via
  `oep relationship list` before testing): Relationship Explorer
  correctly shows "No Relationships Found" despite the repository
  genuinely having relationships — the honest-unavailability behavior
  working exactly as designed, not a bug. Search Workspace: typing
  "generator" and clicking Search produced "Couldn't search for
  'generator'" / the unavailable message, "generator" appeared in
  Previous Searches, and Clear correctly reset both the query field
  and the result area back to the idle state. Resize-checked the
  Relationship Explorer specifically (it has the most filter controls
  of any page added so far) at the enforced 1000×700 minimum — filter
  fields shrink with ellipsis, no overflow.

### Architectural Observations

* **Windows' folder-picker breadcrumb bar is not reliably
  keyboard-driven under sustained background focus contention.**
  Manual verification this work package hit a much more severe version
  of the Work Package 004 focus-stealing issue: `Ctrl+L` (the
  documented shortcut to enter address-bar edit mode) intermittently
  failed even with the Alt-tap foreground fix applied, because a
  background window was stealing focus *between* individual
  `SendKeys` calls (confirmed by checking `GetForegroundWindow()`
  immediately before and after typing, not just around the whole
  sequence). The reliable fix ended up being different from Work
  Package 004's: (1) click the breadcrumb's blank trailing area once
  (a single fast mouse event, verified via an immediate screenshot to
  show edit mode actually activated with the current segment
  pre-selected) rather than relying on `Ctrl+L`, then (2) type the
  full replacement path and press Enter in the very next call with no
  intervening delay, so there's the smallest possible window for focus
  to be stolen mid-input. This is a verification-tooling problem, not
  a Studio defect — flagged here in detail because the Work Package
  004 note undersold how much retry cost this can impose, and the
  concrete two-step fix above is the thing worth reusing next time
  rather than reproducing the trial-and-error.
* **`RelationshipSummary`/`SearchResult` reference Foundation's actual
  C++ struct shapes (`Relationship`, `ObjectSearchResult`,
  `RelationshipSearchResult`, `MatchLocation`), read directly from
  `platform/repository/include/oep/repository/relationship.hpp` and
  `platform/search/include/oep/search/search_engine.hpp`, rather than
  invented from the work package's prose requirements alone.** This
  matters because it makes the "Missing Public API" documentation
  (`docs/CONNECTION_MANAGER.md`) a much more concrete, actionable
  request — e.g. specifying that `RelationshipType` already has 6
  values in a specific order Foundation chose, rather than leaving a
  future implementer to reverse-engineer that from Studio's UI.
* **Mutual exclusivity between `selectedObject` and
  `selectedRelationship` was implemented at the point of selection
  (`selectObject`/`selectRelationship` each clear the other), not as a
  derived/validated invariant on `FoundationServiceState` itself.**
  This means it's possible in principle for a future `copyWith` call
  elsewhere to set both non-null simultaneously without any compiler
  or runtime error — the Property Inspector's `switch` pattern
  `(selectedObject, selectedRelationship)` resolves such a case
  silently (Object mode wins, since it's matched first), rather than
  asserting. Acceptable for now since exactly two call sites ever set
  either field, but worth revisiting with an explicit sum-type
  (`Selection = ObjectSelection | RelationshipSelection | NoSelection`)
  if a third selection kind is ever added.

### Flutter-Specific Recommendations

* Dart 3's record-pattern `switch` (`switch ((a, b)) { (final x?, _) =>
  ..., (_, final y?) => ..., _ => ... }`) is a clean way to express "at
  most one of these is set, branch on whichever" without a nested
  if/else chain — used in `PropertyInspectorPanel.build()` for the
  Object/Relationship mode switch. Worth reaching for again if a third
  mutually-exclusive selection kind is ever added, rather than
  converting to a chain of `if (x != null) ... else if (y != null)`.
* The `RelationshipListQuery`/`relationship_list_query_test.dart` pair
  is a direct copy of `ObjectListQuery`'s Work Package 003 pattern —
  by the third repetition (Object, then Relationship, and Search
  Results' future sort — Foundation search results are pre-sorted by
  Foundation and Studio must not re-sort them, so no third copy is
  actually needed there), this is a stable enough shape that a shared
  generic `ListQuery<T>` could reduce duplication if a fourth
  sortable/filterable list ever appears in Studio. Not done here to
  avoid a premature abstraction over just two instances.

---

## Work Package 006 — Live Relationship Explorer, Live Search Workspace

Status: Implemented

Tasks:

* STUDIO-TASK-000011 — Live Relationship Explorer — Complete
* STUDIO-TASK-000012 — Live Search Workspace — Complete

### What Exists

Foundation Work Package 013 added Engineering Relationship Enumeration
and Repository Search to `oep_api.h` (`OEP_API_VERSION` 2 → 3) between
Work Packages 005 and 006, resolving both gaps Work Package 005 had
documented in `docs/CONNECTION_MANAGER.md` § Missing Public API. This
work package consumed that surface with no Foundation changes:

* `native/foundation_bridge/oep_foundation_bridge.def` — 12 new
  exports (`oep_relationship_type_to_string`,
  `oep_relationship_store_get_count/get_by_id/list`,
  `oep_relationship_list_release`, `oep_match_location_to_string`,
  `oep_search_repository`, `oep_repository_search_result_release`,
  `oep_search_objects`, `oep_object_search_result_list_release`,
  `oep_search_relationships`, `oep_relationship_search_result_list_release`),
  verified with `dumpbin /EXPORTS` — 32 symbols total (see §
  Verification).
* `lib/core/foundation/oep_api_native_types.dart`/`oep_api_bindings.dart` —
  native structs and bindings for all 12 functions, including
  `OepRepositorySearchResultNative`, which flattens
  `oep_repository_search_result_t`'s two nested list structs into four
  top-level fields rather than nesting struct-typed fields (see
  `docs/FOUNDATION_BRIDGE.md` § Extension (Work Package 006) for why).
* `lib/core/foundation/foundation_bridge.dart` — `getRelationshipCount`,
  `getRelationshipById`, `listRelationships`, `searchObjects`,
  `searchRelationships`, `searchRepository`.
* `lib/core/models/relationship_type.dart` — gained `nativeValue` +
  `fromNative` (declaration order already matched
  `oep_relationship_type_t`'s, anticipated in Work Package 005).
* `lib/core/models/relationship_summary.dart` — gained `sourceObjectId`/
  `targetObjectId` and a `fromNative` factory that resolves
  `sourceObjectName`/`targetObjectName` against a caller-supplied
  `objectNamesById` map (built from the Current Object List), falling
  back to the raw ID if not found.
* `lib/core/models/search_result.dart` — `SearchMatchLocation` gained
  `nativeValue`/`fromNative`/`label`; `SearchResult` gained
  `fromNativeObject`/`fromNativeRelationship` factories (the latter
  builds `name` as `"$sourceName → $targetName"`, since Foundation's
  relationship search hits carry no display name of their own, unlike
  object hits' `display_name`).
* `lib/core/models/search_scope.dart` (new) — `SearchScope`
  (repository/objects/relationships), Search Workspace presentation
  state (like Search History, not part of the Connection Manager).
* `lib/shared/navigation/explorer_navigation.dart` (new) —
  `goToObject`/`goToRelationship`: look an ID up in the Current
  Object/Relationship List, select it, and navigate — shared by the
  Relationship Explorer's "Go To Source"/"Go To Target" and the Search
  Workspace's result selection (STUDIO-TASK-000011's Relationship
  Navigation and STUDIO-TASK-000012's Selection Lifecycle turned out to
  need the identical three-step sequence).
* `lib/core/services/foundation_runtime_state.dart`/`foundation_runtime_service.dart` —
  `relationshipList` (Current Relationship List) added, fetched after
  `objectList` in `_refreshRepositoryData` (so relationship name
  resolution has the freshest object list) and cleared on
  open/close alongside the existing fields; `search()` now calls
  Foundation for real and only mutates state on success, rethrowing on
  failure instead of degrading silently (see § Error Handling in
  `docs/CONNECTION_MANAGER.md`).
* `lib/features/relationships/relationships_page.dart` — live
  `relationshipList` replaces the always-empty placeholder; a
  three-way `switch` (`null`/`[]`/populated) distinguishes "couldn't be
  loaded" from "genuinely empty" from populated, mirroring
  `ObjectsPage`'s Work Package 004 pattern; "Go To Source"/"Go To
  Target" buttons (enabled only when a relationship is selected) plus
  per-cell double-tap on the Source/Target columns, both via
  `goToObject`.
* `lib/features/search/search_page.dart` — a scope dropdown
  (Repository/Objects/Relationships); live results rendered as an
  Icon/Name/Type/Score/Match Location table; a "No Repository Open"
  gate (`oep_search_*` is only valid from `RepositoryOpen`); selecting
  a result calls `goToObject`/`goToRelationship`; search failures show
  `showFoundationErrorDialog` (reused from `dashboard_page.dart`)
  instead of the Work Package 005 "unavailable" message, which no
  longer applies now that search is live.
* Property Inspector — unchanged; Work Package 005 already implemented
  Object/Relationship mode switching generically enough that live data
  required no further change.

### What Is Explicitly Not Implemented

Repository/object/relationship **creation, editing, and deletion**
remain entirely unexposed — every work package through 006 has been
read-only by design. `oep_object_store_get_by_id`,
`oep_relationship_store_get_by_id`, `oep_relationship_type_to_string`,
and `oep_match_location_to_string` are bound but unused (see
`docs/CONNECTION_MANAGER.md` § Missing Public API for why).

### Repository Structure Additions

```
lib/
  core/
    models/
      search_scope.dart              New
  shared/
    navigation/
      explorer_navigation.dart       New
```

Everything else this work package touched (`oep_foundation_bridge.def`,
`oep_api_native_types.dart`, `oep_api_bindings.dart`,
`foundation_bridge.dart`, `relationship_type.dart`,
`relationship_summary.dart`, `search_result.dart`,
`foundation_runtime_state.dart`, `foundation_runtime_service.dart`,
`relationships_page.dart`, `search_page.dart`) was rewritten in place —
no other new files.

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 24/24 passing: `relationship_list_query_test.dart`
  updated for `RelationshipSummary`'s two new required fields
  (`sourceObjectId`/`targetObjectId`); `widget_test.dart`'s Search
  Workspace test rewritten from "runs a search and reports it
  unavailable" (Work Package 005's behavior) to "shows No Repository
  Open when disconnected" (Work Package 006's behavior — `flutter
  test`'s environment never has a real repository open, so the
  live-search UI itself isn't exercised by this suite; see below for
  how it was actually verified).
* `flutter build windows` — succeeded. `dumpbin /EXPORTS` on the built
  `oep_foundation_bridge.dll` confirmed all 32 expected symbols present
  (20 from Work Packages 002/004 plus the 12 new ones); four
  release-function RVAs collapse to the same address, which is MSVC's
  identical-code-folding linker optimization for byte-identical
  function bodies (all four release functions reduce to "if non-null,
  delete the array, zero the two fields" over structurally identical
  `{pointer; int32;}` shapes), not a build defect.
* **Manual verification method.** The Dashboard's "Open Repository"
  button (`file_selector`'s native Windows folder-picker dialog) did
  not appear under this session's simulated OS-level mouse input,
  despite extensive troubleshooting: nav-rail taps were confirmed
  reliable via both `PostMessage`-queued and `SendInput`-injected
  clicks once coordinates were derived from the actual widget layout
  (`StudioNavRail`'s padding/item-height arithmetic) rather than
  estimated from screenshots; the "Open Repository"/"Go to Repository
  Explorer" button's position was independently confirmed
  pixel-exact by scanning the built screenshot for
  `StudioColors.selection`'s exact RGB (59, 130, 246); the process was
  relaunched with stdout/stderr redirected to confirm no exception was
  thrown; no dialog-owning window (visible or hidden) or new process
  ever appeared. This points to the native `IFileOpenDialog` COM
  dialog specifically failing to display in this sandboxed session —
  an environment/tooling limitation, not a Studio defect (this exact
  workflow is unchanged since Work Package 002, and Work Package 005's
  own verification notes already document severe, unrelated
  focus-stealing problems with the same dialog in this environment).
  Rather than claim a manual pass that didn't happen, verification was
  performed instead with a temporary `integration_test` (Flutter's
  bundled `dev_dependency`, added and then removed — not part of the
  committed tree) that ran the *actual compiled app* (real FFI, real
  `oep_foundation_bridge.dll`, no mocking) and drove it with Flutter's
  own test bindings (`WidgetTester.tap`/`enterText`, which dispatch
  directly into the framework's gesture arena and don't depend on OS
  window-message delivery), opening a Foundation-CLI-generated
  repository directly through `FoundationRuntimeNotifier.openRepository`
  — the same code path the Dashboard button calls — rather than through
  the file picker.
* **Fixture.** `wp004_test_repo` (from Work Package 004's manual
  verification), extended via the Foundation CLI with a sixth object
  (`Cryogenic Cooling Unit`, author `zolotov`, tags including
  `cryogenic`) and a third relationship (`DependsOn`,
  `Cryogenic Cooling Unit` → `Main Generator`, author `zolotov`) so the
  fixture has multiple objects, multiple relationships, and multiple
  independently-searchable metadata fields (name/author/description),
  per the work package's manual-verification requirement. Expected
  values for every search performed were established first via `oep
  search`/`oep search objects` directly against this fixture, then
  cross-checked against Studio's results.
* **Results, all matching the CLI's independently-computed values
  exactly** (object/relationship IDs, match scores, match locations):
  * Relationship Explorer showed all 3 live relationships with correct
    type/source/target/author (`DependsOn` Cryogenic Cooling Unit →
    Main Generator by zolotov; `ConnectedTo` Main Generator → Backup
    Battery by jsmith; `Documents` System Overview → Main Generator by
    jsmith).
  * Selecting a relationship row (tapping its Author or Source cell)
    updated `selectedRelationship` and the Property Inspector showed
    the Relationship ID.
  * "Go To Source" navigated to the Object Explorer with the correct
    category (Components) and object (Cryogenic Cooling Unit) selected.
  * Repository-scope search for "generator" returned 4 results (1
    object, Name match, score 0.5; 3 relationships, Description match,
    score 0.5 each) — exact match to `oep search generator`.
  * Repository-scope search for "zolotov" returned 2 results (1
    object, Author match, score 1.0; 1 relationship, Author match,
    score 1.0) — exact match to `oep search zolotov`, and confirmed
    *distinct* from the "generator" results (ruling out any state
    leakage between successive searches on the same `OEP_Runtime`).
  * Object-only and relationship-only scopes (`oep_search_objects`/
    `oep_search_relationships` called directly) independently returned
    results matching `oep search objects`/`oep search relationships`.
  * Selecting an object search result cleared `selectedRelationship`
    and set `selectedObject` to the correct object, confirming
    STUDIO-TASK-000012's "Navigate to the appropriate Explorer, select
    the corresponding Object, update the Property Inspector."
  * Two apparent failures surfaced during the first verification pass
    and were both root-caused to the *test script*, not Studio: (1) a
    `find.text(...)` finder matched two widgets (a relationship-row
    cell and the Property Inspector showing the same string as a field
    value) — fixed by disambiguating with `.first`; (2) a second
    `enterText` call after a button tap left the search box's
    `TextEditingController` unchanged until the field was explicitly
    re-focused first — a `WidgetTester` interaction quirk, confirmed
    because direct `FoundationRuntimeNotifier.search()` calls
    (bypassing the text field entirely) worked correctly on every
    query in every order. Neither reflects a Studio defect; both are
    noted here so a future verification session doesn't re-diagnose
    them from scratch.

### Architectural Observations

* **The native Windows folder-picker dialog could not be driven by
  simulated OS input in this session, despite `file_selector`/
  `getDirectoryPath()` being unchanged since Work Package 002.**
  Ordinary window messages (used by every nav-rail/button click)
  reached the app reliably once coordinates were computed correctly;
  the dialog specifically never appeared, with no exception in
  captured stdout/stderr and no new process or window (hidden or
  visible). This is consistent with — and likely the same underlying
  cause as — the "severe recurring focus-stealing" issue Work Package
  005 documented for this exact dialog, just manifesting as a harder
  failure this session. Recommendation for future work packages: don't
  re-attempt raw OS-level UI automation against this specific dialog
  without a fresh diagnosis; the `integration_test` approach used here
  (open the repository directly through the Connection Manager,
  verify everything downstream with `WidgetTester`) is faster, more
  reliable, and exercises the real FFI/DLL just as thoroughly, at the
  cost of not exercising the file-picker plugin itself.
* **Coordinate calculation from source beats visual estimation from
  screenshots.** Repeated attempts to click UI elements by eyeballing
  pixel positions in a screenshot produced *plausible but wrong*
  coordinates (each guess landed on some real, nearby element, so
  failures looked like flakiness rather than being obviously wrong).
  Deriving exact positions from the actual widget tree's padding/size
  constants (`StudioNavRail`'s `_BrandHeader`/`_NavRailItem` padding
  arithmetic) and cross-checking against `StudioColors.selection`'s
  exact RGB via pixel-scanning a screenshot resolved this immediately
  and repeatably. Worth doing first, not last, in any future session
  that needs OS-level UI automation against this app.
* **`FoundationBridge.searchRepository`'s struct-flattening approach
  (four top-level fields instead of two nested struct-typed fields)
  was verified correct by the integration test's repeated,
  interleaved calls to `searchRepository`/`searchObjects`/
  `searchRelationships` on the same `OEP_Runtime`** — every call
  returned results matching the CLI independently, including
  immediately after a *different*-scope call, which would have
  surfaced any stale-pointer/incorrect-offset bug from a wrong
  flattening. This is the first `oep_api.h` struct in Studio with a
  nested-struct member; the flattening technique (verified here) is
  the template to reuse if a future struct has the same shape, rather
  than depending on unverified assumptions about dart:ffi's
  struct-of-struct field support.
* **Relationship/search name resolution (`objectNamesById`) is a
  Studio-side join across two already-Foundation-returned lists, not
  independent business logic** — `oep_relationship_info_t`/
  `oep_relationship_search_result_t` carry only `source_object_id`/
  `target_object_id`, unlike `oep_object_search_result_t::display_name`.
  Building a `Map<String, String>` from the already-fetched Current
  Object List and doing a lookup is squarely "convert Foundation data
  into Flutter models" (`docs/FOUNDATION_BRIDGE.md` § Responsibilities),
  not a reimplementation of anything Foundation does — the alternative
  (Studio never resolving names, always showing raw IDs) would be a
  worse user experience for no architectural benefit.

### Flutter-Specific Recommendations

* **`integration_test` (Flutter's bundled test package) is a viable,
  higher-reliability alternative to OS-level UI automation for
  Windows-desktop manual verification**, when the thing under test
  doesn't itself require driving a native OS dialog. It runs the real
  compiled app end-to-end (`flutter test integration_test/foo_test.dart
  -d windows`) with real FFI/DLL/plugin code — nothing is mocked — but
  interacts via `WidgetTester`, which dispatches directly into
  Flutter's own gesture/text-input handling rather than posting real
  OS window messages, sidestepping focus-stealing and coordinate-
  calculation problems entirely. Not added as a permanent dependency
  or committed test file this work package (this repository's manual-
  verification convention has been screenshots/interactive sessions,
  not committed integration tests, and the fixture path used here is
  machine-specific), but worth reaching for again — and potentially
  worth formalizing with a portable fixture — if OS-level automation
  proves unreliable for a future work package too.
* `ProviderContainer` + `UncontrolledProviderScope` is the pattern for
  driving a Riverpod app's providers directly from a test (here, to
  call `FoundationRuntimeNotifier.openRepository`/`search` without
  going through the Dashboard button or Search box) while still
  pumping the real widget tree — useful whenever a test needs to
  bypass one specific UI-triggered action but still verify everything
  downstream of it.

---

## Work Package 007 — Knowledge Studio (first slice)

Status: Implemented

Tasks:

* STUDIO-TASK-000013 — Knowledge Studio Shell — Complete
* STUDIO-TASK-000014 — Knowledge Curation Session — Complete

### What Exists

A new top-level `lib/knowledge/` module (per explicit user instruction
alongside this work package — see `docs/KNOWLEDGE_STUDIO.md`'s
introduction) implements the first, Studio-only slice of Knowledge
Studio (SDD-013): manually-created Engineering Object proposals,
reviewed within an in-memory Knowledge Curation Session. No AI, no
OCR, no repository commit, no Foundation calls anywhere in this
module, per this work package's explicit scope.

* `lib/knowledge/models/` — `KnowledgeSession`/`SessionStatus`,
  `EngineeringProposal`/`ProposalType`/`ProposalStatus`,
  `KnowledgeValidationException`. See `docs/KNOWLEDGE_STUDIO.md` § Session
  Lifecycle / § Proposal Model for the full model and its deliberate
  narrowing relative to SDD-015/017/018/020.
* `lib/knowledge/services/knowledge_session_service.dart` — pure
  validation (new-session name/repository, proposal name
  uniqueness, session status transitions) and ID generation. Holds no
  state; called by the Connection Manager, not by widgets, keeping
  "no engineering logic shall exist inside widgets" true without
  pushing that logic into `foundation_runtime_service.dart` itself.
* `lib/knowledge/workspaces/knowledge_studio_page.dart` — the
  six-panel workspace layout (Import Queue, Source Viewer, AI
  Suggestions, Repository Matches, Engineering Review, Commit
  Summary) plus the session header, registered as
  `StudioDestination.knowledge` (`/knowledge`, positioned right after
  Dashboard in the Navigation Rail). Reuses the shell's existing
  Property Inspector rather than embedding a second copy — see
  `docs/KNOWLEDGE_STUDIO.md` § Workspace Layout for why SDD-016's
  seven-panel diagram maps onto six new panels plus the
  already-existing shared one.
* `lib/knowledge/review/` — Engineering Review panel
  (`engineering_review_panel.dart`), proposal row
  (`proposal_row.dart`), and the shared New/Edit Proposal dialog
  (`proposal_form_dialog.dart`). The only panel with real
  functionality besides the Property Inspector, per
  STUDIO-TASK-000013's explicit scope.
* `lib/knowledge/sessions/` — New Session dialog
  (`new_session_dialog.dart`) and the session header
  (`session_header.dart`, showing name/status/counts and the one
  valid forward status-transition button plus Cancel).
* `lib/knowledge/controllers/` — `SessionFormController`/
  `ProposalFormController`, bundling each dialog's
  `TextEditingController`s (and, for proposals, a `ValueNotifier<ProposalType>`)
  so the New and Edit flows share one implementation.
* `lib/knowledge/widgets/` — `KnowledgePanel` (shared titled/bordered
  panel chrome) and `KnowledgePlaceholder` (compact placeholder,
  panel-cell-sized rather than full-workspace-sized like the existing
  `PlaceholderWorkspace`).
* `lib/knowledge/inspector/` — `ProposalProperties`/`SessionProperties`,
  the two new Property Inspector modes, wired into
  `lib/shared/widgets/property_inspector_panel.dart`'s existing
  record-pattern `switch` (now four-wide: Proposal → Object →
  Relationship → Session → No Selection).
* `lib/shared/widgets/property_field.dart` (new) — the label/value row
  widget the Property Inspector's Object/Relationship modes already
  had privately (`_Field`) was extracted to a shared, public
  `PropertyField` so the two new Proposal/Session modes (and any
  future mode) don't duplicate it. `lib/shared/format.dart` (new) —
  a single `formatDateTime` helper, used by both new inspector modes,
  since no formatting package is a dependency.
* `lib/core/services/foundation_runtime_state.dart`/
  `foundation_runtime_service.dart` — extended per Work Package 007's
  explicit Architecture Rule ("The Connection Manager owns session
  state"): `knowledgeSession`/`proposals`/`selectedProposal` added to
  `FoundationServiceState`; `createKnowledgeSession`/
  `advanceKnowledgeSession`/`addProposal`/`editProposal`/
  `acceptProposal`/`rejectProposal`/`deleteProposal`/`selectProposal`/
  `clearProposalSelection` added to `FoundationRuntimeNotifier`.
  `selectObject`/`selectRelationship` now also clear
  `selectedProposal` (three-way mutual exclusivity). See
  `docs/CONNECTION_MANAGER.md` for the updated state table.

### What Is Explicitly Not Implemented

Per this work package's explicit scope: AI analysis, OCR, Import Queue
ingestion, Source Viewer rendering, Repository Matches (duplicate
detection), Commit Summary computation, and Repository Commit itself.
Session persistence and Session Recovery (SDD-017: Resume/Pause/
Archive/Duplicate/Export) are also deferred — sessions are
process-lifetime only. See `docs/KNOWLEDGE_STUDIO.md` § Future
Foundation Integration for the concrete extension points once the
corresponding Public C API exists.

**SDD-014 gap.** SDD-014 (Engineering Knowledge Acquisition Pipeline)
is listed among the architecture this work package is meant to
validate but is an empty file (0 bytes) in this repository. This did
not block implementation — SDD-013's own Import Pipeline section
covers the same ground at the level of detail this work package
needed, and the stages SDD-014 would presumably detail further (OCR,
AI Analysis) are explicitly out of scope here regardless — but it's
flagged in `docs/KNOWLEDGE_STUDIO.md`'s introduction for whoever
populates SDD-014 next, since a future work package implementing the
acquisition pipeline itself will need real content there.

### Repository Structure Additions

```
lib/
  knowledge/                              New top-level module
    models/
      knowledge_session.dart
      session_status.dart
      engineering_proposal.dart
      proposal_type.dart
      proposal_status.dart
      knowledge_validation_exception.dart
    services/
      knowledge_session_service.dart
    controllers/
      session_form_controller.dart
      proposal_form_controller.dart
    widgets/
      knowledge_panel.dart
      knowledge_placeholder.dart
    workspaces/
      knowledge_studio_page.dart
    review/
      engineering_review_panel.dart
      proposal_row.dart
      proposal_form_dialog.dart
    sessions/
      new_session_dialog.dart
      session_header.dart
    inspector/
      proposal_properties.dart
      session_properties.dart
  shared/
    format.dart                           New
    widgets/
      property_field.dart                 New
test/
  knowledge_session_service_test.dart      New
docs/
  KNOWLEDGE_STUDIO.md                      New
```

`lib/core/routing/studio_destination.dart`/`app_router.dart` gained
the `knowledge` destination; every other pre-existing top-level
directory (`app/`, `core/`, `features/`, `shared/`) is otherwise
untouched — an explicit, user-confirmed scope decision (see below).

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 38/38 passing: 12 new `KnowledgeSessionService`
  unit tests (new-session validation, proposal-name uniqueness
  including the edit-exclusion case, and every status-transition rule
  — forward sequence, skip-a-stage rejection, cancel-from-anywhere,
  cancel-from-cancelled rejection, advance-from-cancelled rejection);
  2 new widget tests (`Knowledge Studio opens with placeholder panels
  and no active session`; a full `Knowledge Curation Session` lifecycle
  test — create a session, add a proposal, select it, accept it —
  driven through the real widget tree and real
  `FoundationRuntimeNotifier`, not mocked).
* `flutter build windows` — succeeded. No native/DLL changes (this
  work package touches nothing under `native/` or `lib/core/foundation/` —
  confirmed, this module makes zero Foundation Bridge calls).
* Manual verification against the built exe: navigated to Knowledge
  Studio via the Navigation Rail (confirmed via screenshot — all six
  panels render with the correct titles and placeholder text, session
  header shows "No Knowledge Curation Session" and a "New Session"
  button). Clicking further into dialogs via simulated OS-level mouse
  input was **not** reliably reproducible in this session (see
  Architectural Observations) — the interactive session/proposal
  lifecycle (session creation and its two validation failures,
  duplicate-proposal-name validation, proposal Accept/Edit/Delete,
  Property Inspector Proposal-mode switching, the full status
  advancement sequence Created → Preparing → Reviewing → Ready to
  Commit, Cancel Session, and window resizing to the 1000×700 minimum)
  was instead verified with a temporary `integration_test` (added,
  run, then fully removed — not part of the committed tree, mirroring
  Work Package 006's precedent) driving the actual compiled
  `oep_studio.exe` through Flutter's own test bindings. Every
  assertion passed on the first corrected run; see Architectural
  Observations for the two real bugs this caught before they shipped.

### Architectural Observations

* **A dialog-lifecycle bug — disposing `TextEditingController`s via
  the `showDialog` `Future`'s completion rather than the dialog
  `State`'s own `dispose()` — crashed the app during automated
  testing** ("Tried to build dirty widget in the wrong build scope").
  `showDialog<void>(...).whenComplete(formController.dispose)` disposes
  as soon as `Navigator.pop()` is called, which is *before* the
  dialog's exit animation finishes rebuilding the still-visible,
  still-controller-attached `TextField`s. Fixed by moving both dialogs'
  form controllers into `late final` fields on their own
  `ConsumerState`, disposed in `State.dispose()` — the standard
  Flutter pattern, which ties disposal to when the element is actually
  torn down rather than to an unrelated `Future`. Worth remembering
  for any future dialog that owns a controller: create and dispose it
  inside the dialog's own `State`, never via the caller's `showDialog`
  future.
* **Simulated OS-level mouse clicks could not reliably open this work
  package's own in-app `AlertDialog`s, despite pixel-exact coordinate
  verification.** Nav-rail item clicks (computed from
  `StudioNavRail`'s actual padding/item-height constants, cross-checked
  against Work Package 006's now-corrected coordinate formula) worked
  reliably and repeatably in this same session; the "New Session"
  `OutlinedButton` — confirmed via `WindowFromPoint` to resolve to the
  Studio window, and via pixel-scanning the screenshot to be clicked
  dead-center on its rendered text — never opened its dialog under
  either `SendInput`-injected or `PostMessage`-queued clicks. No
  exception, no crash, no new window (confirmed by relaunching with
  stdout/stderr redirected to a file — both stayed empty). This is a
  narrower, more specific case of the same environment limitation
  Work Package 006 hit with the native folder-picker dialog, except
  this time it's a plain Flutter `AlertDialog`, which rules out
  "native COM dialogs specifically don't render here" as the
  explanation — something about this sandboxed session's synthetic
  input specifically fails to trigger *some* button presses while
  reliably triggering others, and the difference isn't (as far as
  this investigation went) explained by widget type, nesting depth, or
  screen position. Recommendation for future work packages: don't
  re-attempt raw OS-level UI automation as the first resort — reach
  for a temporary `integration_test` immediately, as it sidesteps this
  class of problem entirely (see Flutter-Specific Recommendations) and
  is dramatically faster in practice (minutes instead of the better
  part of an hour spent here re-diagnosing a variant of Work Package
  006's issue).
* **The `integration_test` harness itself caught two real
  application-layer bugs before they shipped** (beyond the dialog
  lifecycle crash above): (1) an ambiguous `find.text(...)` finder in
  the test matched both a Relationship-Explorer-style row and the
  Property Inspector showing the same string, which surfaced a
  genuine design fact worth documenting — `PropertyField` values and
  list-row labels can legitimately collide once a selection's detail
  view echoes fields also visible in its list row, so tests (and any
  future scripted verification) need to disambiguate by widget
  position, not just text content; (2) `tester.enterText` on a
  `TextField` that had never been focused failed to update its
  controller when called back-to-back with other fields without an
  intervening tap — switching from index-based `find.byType(TextField).at(n)`
  lookups to label-based lookups (`find.byWidgetPredicate` matching
  `InputDecoration.labelText`) fixed it and is also more robust against
  future field reordering. Neither was a defect in the shipped
  Knowledge Studio code — both were test-authoring pitfalls — but
  both are worth remembering verbatim next time a dialog with several
  `TextField`s needs testing.
* **Extending `PropertyInspectorPanel`'s record-pattern `switch` from
  two arms to four was a direct, low-risk application of the pattern
  Work Package 005 flagged as reusable** ("Worth reaching for again if
  a third mutually-exclusive selection kind is ever added") — Work
  Package 007 added a third (Proposal) *and* a fourth, non-mutually-
  exclusive fallback (Session), and the record-pattern `switch` handled
  both additions with no structural change, just two more tuple
  positions and two more `case` arms.
* **`KnowledgeSession`/`EngineeringProposal` were kept deliberately
  smaller than SDD-015/016/017/018/020's full future models** (no
  confidence, no evidence chain, no trust level, no revision history)
  rather than adding fields now that nothing populates yet. This
  mirrors the "document it, don't implement it" discipline this
  project has applied to missing Foundation API surface since Work
  Package 004, extended here to missing *future Studio* surface (AI
  analysis, repository matching) that this work package explicitly
  scopes out — the fields will have an obvious, evidence-driven shape
  to add once the code that would actually populate them exists,
  rather than guessing that shape now.
* **The `lib/knowledge/` top-level module structure (with its eight
  subdirectories) was specified directly by the user, separately from
  `WORK_PACKAGE_007.md` itself**, which says nothing about directory
  layout. The user's original message also sketched a full `lib/`
  reorganization (flattening `core/foundation` → `bridge/`,
  `core/services` → `connection/`, every `features/*` module to
  top-level); asked for clarification before touching anything, and
  the user confirmed: add only `lib/knowledge/`, leave `app/`, `core/`,
  `features/`, and `shared/` exactly as they are, treating the fuller
  reorganization as "a long-term architectural target, not a
  requirement for WP007." Recorded here since it's a scope decision a
  future reader of this codebase's directory layout might otherwise
  wonder about.

### Flutter-Specific Recommendations

* **Reach for a temporary `integration_test` before spending
  significant time on OS-level UI automation.** Add
  `integration_test: {sdk: flutter}` to `dev_dependencies`, write the
  test under `integration_test/`, run with `flutter test
  integration_test/foo_test.dart -d windows`, then remove both the
  file and the dependency (`flutter pub get` to regenerate a clean
  `pubspec.lock`) once verification is complete — this repository's
  convention is interactive/screenshot verification, not a committed
  integration-test suite, so treat it as a diagnostic tool, not a
  deliverable. It runs the real compiled app with real FFI/plugin code
  (nothing mocked) but drives it via `WidgetTester`, which never posts
  an OS window message — immune to focus-stealing, coordinate
  miscalculation, and whatever this session's click-delivery
  inconsistency actually was.
* **Own dialog form controllers in the dialog's `State`, not in the
  caller.** See the dialog-lifecycle bug above — this is a general
  Flutter rule, not specific to this work package, but this is the
  first place in this codebase a dialog needed its own
  `TextEditingController`s (`dashboard_page.dart`'s and
  `search_page.dart`'s controllers are owned by a persistent page
  `State`, not a transient dialog), so the pitfall hadn't come up
  before.
* **`find.byWidgetPredicate` matching `InputDecoration.labelText`** is
  a more robust way to locate a specific `TextField` in a multi-field
  form than positional `find.byType(TextField).at(n)` — worth using by
  default for any future dialog test with more than one text field.

---

## Work Package 008 — Knowledge Studio (persistence, sources, relationships, commit preview)

Status: Implemented

Tasks:

* STUDIO-TASK-000015 — Persistent Sessions + Session Browser — Complete
* STUDIO-TASK-000016 — Source Material Workspace — Complete
* STUDIO-TASK-000017 — Manual Relationship Authoring + Relationship View — Complete
* STUDIO-TASK-000018 — Repository Commit Preview — Complete

### What Exists

Continues the Work Package 007 `lib/knowledge/` module. Per this work
package's explicit terminology direction, "Proposal" is renamed to
"Knowledge Candidate" throughout `lib/knowledge/` and its two
Connection Manager touchpoints (`EngineeringProposal` →
`KnowledgeCandidate`, `ProposalType` → `KnowledgeCandidateType`,
`ProposalStatus` → `KnowledgeCandidateStatus`, and every file/method/
field name built on "proposal"). Still zero Foundation calls, zero AI,
zero OCR, zero repository commit — Knowledge Sessions remain entirely
Studio-local, now durable across restarts. See
`docs/KNOWLEDGE_SESSION_FORMAT.md` for the full persisted-format,
model, and architectural-observation detail this section summarizes.

* `lib/knowledge/models/` — `KnowledgeCandidate` (renamed, unchanged
  shape), new `RelationshipCandidate` (connects two candidates by ID,
  reuses the existing `RelationshipType` enum from
  `core/models/relationship_type.dart` rather than inventing a
  parallel taxonomy — see Architectural Observations), new
  `SourceMaterial`/`SourceMaterialType` (PDF/Image/Markdown/Text/Other,
  classified by extension only — "No OCR. No parsing."), new
  `ReviewDecision`/`ReviewDecisionKind` (an append-only Created/Edited/
  Accepted/Rejected/Deleted audit log), new `CommitPreview` (see
  STUDIO-TASK-000018 below), new `KnowledgeSessionRecord` (the complete
  persisted unit — session + candidates + relationship candidates +
  sources + review decisions). `KnowledgeSession` gained `lastModified`
  (required) and `archived` (a `bool`, independent of the existing
  `SessionStatus` workflow — see Architectural Observations) plus
  `toJson`/`fromJson`.
* `lib/knowledge/services/knowledge_session_storage.dart` (new) — local
  JSON persistence: one directory per session under
  `%APPDATA%/oep_studio/knowledge_sessions/<sessionId>/`
  (`session.json` + a `sources/` subdirectory of copied files).
  `save`/`load`/`listAll`/`delete`/`duplicateSourceFiles`, every I/O
  failure translated to `KnowledgeValidationException` — never a raw
  `IOException` or stack trace. Uses `dart:io`/`Platform.environment`
  directly rather than adding `path_provider` (this is already a
  Windows-only desktop target; `path_provider`'s cross-platform channel
  code would be dead weight).
* `lib/knowledge/services/source_material_service.dart` (new) — copies
  a picked file into the active session's managed `sources/` directory
  at attach time (not a reference to the original path, so a session
  stays self-contained if the original file moves or is deleted) and
  records its metadata; best-effort delete on removal.
* `lib/knowledge/services/knowledge_session_service.dart` — extended
  with `validateRelationshipCandidate` (self-reference prohibited,
  source/target must exist — blocking), `isDuplicateRelationshipCandidate`
  (same source/target/type already exists — non-blocking, a warning
  only, per this work package's explicit "Duplicate relationships
  warned" vs. "Self-reference prohibited" distinction),
  `computeCommitPreview`, and `buildDuplicate` (Session Browser
  "Duplicate": fresh ID/name/timestamps, candidates/relationship
  candidates/review decisions copied as-is, sources remapped to the new
  session's storage directory).
* `lib/core/services/foundation_runtime_state.dart`/
  `foundation_runtime_service.dart` — extended per this work package's
  Architecture Rule ("Connection Manager coordinates state only"):
  `relationshipCandidates`/`selectedRelationshipCandidate`,
  `sourceMaterials`/`selectedSourceMaterial`, `reviewDecisions`, and
  `knowledgeStorageError` (a dismissible autosave/Session-Browser
  failure banner) added to `FoundationServiceState`, plus a derived
  `commitPreview` getter. Every mutating candidate/relationship-
  candidate/source method now autosaves via a private
  `_persistActiveSession()` (fire-and-forget, `unawaited`) after
  updating in-memory state — there is no separate explicit "Save"
  action to forget to click. New session-lifecycle methods:
  `closeKnowledgeSession` (unload without deleting), `listKnowledgeSessions`,
  `openKnowledgeSession`, `duplicateKnowledgeSession`,
  `setKnowledgeSessionArchived`, `deleteKnowledgeSession`. Selection is
  now five-way mutually exclusive (Object, Relationship, Knowledge
  Candidate, Relationship Candidate, Source Material) — every `select*`
  method clears the other four.
* `lib/knowledge/sessions/session_browser_dialog.dart` (new) — lists
  every persisted session (name, status, archived badge, repository,
  last-modified) with Open/Duplicate/Archive-Unarchive/Delete
  (Delete requires an inline confirmation dialog); corrupted session
  files are listed separately with an explanation rather than silently
  dropped or blocking the browser from opening at all. Opens as a
  dialog, not an eighth workspace panel — see Architectural
  Observations.
* `lib/knowledge/sessions/session_header.dart` — gained a "Sessions"
  button (opens the Session Browser), a "Close Session" icon button,
  and a dismissible storage-error banner; the workflow-action row
  (advance/cancel/close) moved to its own `Wrap`-laid-out row below the
  name/status/counts row to avoid a `RenderFlex` overflow once the
  action set grew (see Flutter-Specific Recommendations).
* `lib/knowledge/workspaces/import_queue_panel.dart` (new) — real
  functionality: an "Attach Source" button (`file_selector`'s
  `openFile()`) and a list of attached sources with type icon,
  formatted size, and a Remove action; selecting a row updates the
  Property Inspector.
* `lib/knowledge/workspaces/source_viewer_panel.dart` (new) — real
  functionality within the limits of "No OCR. No parsing.": renders an
  image source with `Image.file`, renders a Markdown/Text source's raw
  file content in a monospace, selectable text view, and shows a
  location-only message for PDF/Other (no PDF-rendering package was
  added — out of scope for this work package's minimal-dependency
  approach). Reports "Missing source file" if the managed copy is gone.
* `lib/knowledge/workspaces/commit_preview_panel.dart` (new) — real
  functionality: New Objects / Rejected Candidates (excluded) /
  Relationships / Modified Objects (always 0) / Merged Objects (always
  0) counts, a current→projected repository object/relationship count
  (or "unavailable" if no repository is open), a Validation Summary
  list, and a permanently disabled "Commit" button with a tooltip
  explaining why (Repository Commit is explicitly out of scope).
* `lib/knowledge/review/engineering_review_panel.dart` — restructured
  into two tabs, Candidates (unchanged Work Package 007 behavior,
  renamed) and Relationships (new: list/New/Edit/Delete for manually-
  authored relationship candidates, resolved source/target names via
  `RelationshipCandidateListQuery`, mirroring `RelationshipListQuery`'s
  Work Package 006 shape) — see Architectural Observations for why a
  tab, not an eighth panel.
* `lib/knowledge/inspector/` — `KnowledgeCandidateProperties` (renamed),
  new `RelationshipCandidateProperties`, new `SourceMaterialProperties`;
  `lib/shared/widgets/property_inspector_panel.dart`'s record-pattern
  `switch` extended from four arms to six: Knowledge Candidate →
  Relationship Candidate → Source Material → Object → Relationship →
  Session → No Selection.
* `lib/shared/format.dart` — gained `formatFileSize` (B/KB/MB/GB, one
  decimal place above 1 KB), used by `SourceMaterialProperties` and the
  Import Queue's source rows.

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: OEP Foundation, the
Public C API, AI functionality, OCR functionality, and Repository
Commit itself are all untouched. `CommitPreview.modifiedObjectCount`/
`mergedObjectCount` are always `0` — no modify-existing or
merge-with-existing workflow exists yet (both presuppose repository
matching, still a placeholder panel). PDF rendering is not implemented
(location-only message). See `docs/KNOWLEDGE_SESSION_FORMAT.md` §
Architectural Observations for the full detail on the
`KnowledgeCandidateType`/`ObjectCategory` mismatch this uncovered.

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      knowledge_candidate.dart            Renamed from engineering_proposal.dart
      knowledge_candidate_type.dart       Renamed from proposal_type.dart
      knowledge_candidate_status.dart     Renamed from proposal_status.dart
      relationship_candidate.dart         New
      source_material.dart                New
      source_material_type.dart           New
      review_decision.dart                New
      commit_preview.dart                 New
      knowledge_session_record.dart       New
      knowledge_session.dart              Extended (lastModified, archived)
    services/
      knowledge_session_storage.dart      New
      source_material_service.dart        New
    controllers/
      knowledge_candidate_form_controller.dart      Renamed
      relationship_candidate_form_controller.dart   New
    review/
      knowledge_candidate_row.dart               Renamed
      knowledge_candidate_form_dialog.dart        Renamed
      relationship_candidate_row.dart             New
      relationship_candidate_form_dialog.dart     New
      relationship_candidate_list_query.dart      New
    sessions/
      session_browser_dialog.dart         New
    inspector/
      knowledge_candidate_properties.dart       Renamed
      relationship_candidate_properties.dart    New
      source_material_properties.dart           New
    workspaces/
      import_queue_panel.dart             New
      source_viewer_panel.dart            New
      commit_preview_panel.dart           New
test/
  knowledge_session_storage_test.dart      New
docs/
  KNOWLEDGE_SESSION_FORMAT.md              New
```

### Flutter Package Decisions

No new permanent dependencies. Persistence uses `dart:convert`/
`dart:io` directly (manual `toJson`/`fromJson` on every model,
`JsonEncoder.withIndent`, `enum.name`/`EnumType.values.byName()`) —
consistent with this project's existing no-code-gen convention.
Source Material attachment reuses the already-present `file_selector`
(`openFile()`, the same package `getDirectoryPath()` already uses for
Open Repository). A temporary `integration_test` dependency was added,
used, and fully removed before commit — see Verification Results.

### Verification Results

* `flutter analyze` — no issues found.
* `flutter test` — 53/53 passing: all prior tests, `knowledge_session_service_test.dart`
  updated for the Candidate rename plus 8 new cases
  (`validateRelationshipCandidate`'s self-reference/missing-endpoint
  rules, `isDuplicateRelationshipCandidate`, `computeCommitPreview`'s
  new-object/rejected/pending-warning/dangling-relationship logic), a
  new `knowledge_session_storage_test.dart` (6 cases: save/load round
  trip, missing-session and corrupted-file errors, `listAll` sort
  order, delete, and a duplicate-session test that copies a real
  attached source file and confirms deleting the original doesn't
  affect the duplicate's own copy — all against the real
  `%APPDATA%/oep_studio/knowledge_sessions` directory with a unique,
  self-cleaning session-ID prefix, since the storage service has no
  injectable directory override and adding one purely for testability
  would be an unrequested abstraction), and `widget_test.dart`'s
  Knowledge Curation Session test updated for the renamed
  button/dialog/field labels.
* `flutter build windows` — succeeded (both an initial verification
  build and the final build after all fixes below).
* **Manual verification.** As in Work Packages 006/007, this
  environment's OS-level UI automation could not reliably drive this
  app: `computer-use`'s `request_access` for the built `oep_studio.exe`
  process was explicitly denied by the user when requested (the app
  process itself is not a Start-menu-registered application this
  environment's access model recognizes), so no screenshot/click could
  be taken of the running app at all this time — a stricter version of
  the AlertDialog-specific limitation Work Package 007 hit. Per this
  work package's own pre-approved instructions, verification was
  performed instead with a temporary `integration_test`
  (`integration_test: {sdk: flutter}` added to `dev_dependencies`,
  `integration_test/knowledge_studio_wp008_test.dart` written, run via
  `flutter test integration_test/knowledge_studio_wp008_test.dart -d
  windows` against the real compiled app, then the test file deleted
  and the dependency reverted — `flutter pub get` confirmed
  `pubspec.lock` returned to its pre-work-package state). The test
  covered the full golden path: create a session (persisted
  immediately) → add two Knowledge Candidates → accept one, leave one
  pending → add a Relationship Candidate connecting them → Commit
  Preview shows New Objects 1 / Relationships 1 / "1 candidate still
  pending review" / a permanently disabled Commit button → Close
  Session → reopen via the Session Browser (proving a real disk
  round-trip, not just in-memory state) → the candidate and
  relationship candidate both survive reopen → delete the session via
  the Session Browser's own Delete flow (cleaning up its own test
  data). All assertions passed on the corrected run; the native
  "Attach Source" file-picker flow was not exercised this way (driving
  an OS file dialog is exactly the class of interaction this workaround
  exists to route around) — `SourceMaterialService`'s file-copy logic
  is instead covered by the permanent `knowledge_session_storage_test.dart`.
  Confirmed no session directories were left under
  `%APPDATA%/oep_studio/knowledge_sessions` after the run.

### Architectural Observations

* **`KnowledgeCandidateType` (Component/Procedure/Specification/Image/
  Document) does not map one-to-one onto Foundation's `ObjectCategory`
  (Component/Document/Diagram/Procedure/Image/Project).** Specification
  has no Foundation object type yet; Diagram and Project have no
  Knowledge Candidate type yet. This blocked computing a per-category
  projected `RepositoryStatistics` for the Commit Preview — doing so
  would require guessing that mapping, exactly the kind of independent
  design decision this work package prohibits when a genuine
  architectural gap exists. `CommitPreview` instead exposes the
  *unmodified* `currentStatistics` plus simple aggregate-total
  projections (`projectedObjectCount`/`projectedRelationshipCount`,
  which need no per-category mapping). Documented in full, with the
  concrete field-by-field mismatch, in
  `docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural Observations —
  flagging for architectural review rather than resolving unilaterally,
  per this work package's explicit instruction.
* **"Archived" was implemented as an independent `bool archived` field
  on `KnowledgeSession`, not a new `SessionStatus` value.** A session's
  curation-workflow stage (Created → Preparing → Reviewing → Ready to
  Commit, or Cancelled) and whether it has been archived out of the
  Session Browser's default view are orthogonal lifecycle dimensions —
  mirroring how SDD-018 treats Archive for Engineering Objects ("Archive
  does not imply deletion. Archived knowledge remains searchable").
  Reached without needing to stop for review since SDD-018 already
  establishes the precedent this decision follows directly.
* **The Relationship View (STUDIO-TASK-000017) was integrated as a tab
  inside the existing Engineering Review panel, not an eighth workspace
  panel.** SDD-016 fixes Knowledge Studio's layout at seven panels;
  adding an eighth would conflict with that frozen diagram, while the
  work package's own Requirements list never actually requires a
  *separate* panel — only that the described views/actions exist
  somewhere. Knowledge Candidates and Relationship Candidates are both
  "things awaiting engineering review," so sharing one panel via a tab
  keeps them conceptually together without touching the frozen layout.
* **The Session Browser (STUDIO-TASK-000015) opens as a dialog, not a
  panel, for the same reason** — browsing/switching sessions is an
  occasional action, not something that needs permanent screen space
  competing with the seven fixed panels.
* **The `integration_test` harness caught a real bug this session that
  the permanent unit/widget test suite did not: `_reload()`'s
  `setState(() => _future = future)` returned the assigned `Future`
  from the closure, which Flutter's `setState` explicitly asserts
  against at runtime** ("setState() callback argument returned a
  Future"). This only triggers when `_reload()` actually runs a second
  time within a live `State` (i.e. after some action inside the
  already-open Session Browser, not merely on its first `initState`)
  — exactly the kind of interaction sequence a single-open widget test
  wouldn't exercise, but the full open→act→reload cycle the integration
  test drove did. Fixed by giving the closure a block body
  (`setState(() { _future = ...; })`), which returns `void` explicitly.
  General lesson: an arrow-bodied `setState(() => someAssignment)` is a
  latent bug whenever the assignment's right-hand side is itself a
  non-void expression (here, a `Future`) — block-bodied `setState`
  closures are the safer default whenever the callback does anything
  beyond a bare field read.
* **A `showDialog` route's underlying page keeps its widgets mounted
  (just visually covered), which made a tooltip-based `IconButton`
  finder ambiguous during verification** — both the Session Browser's
  own "Delete" button and the Relationship Candidate row's "Delete"
  button (on the *underlying*, still-mounted Engineering Review panel)
  matched the same tooltip-based finder simultaneously. Not a Studio
  defect — a test-authoring pitfall worth remembering: any finder used
  while a dialog is open should be scoped to `find.descendant(of:
  find.byType(AlertDialog), matching: ...)` whenever the same tooltip
  or text could plausibly also exist on the page underneath.
* **Cascading relationship-candidate deletion on candidate delete.**
  `FoundationRuntimeNotifier.deleteKnowledgeCandidate` proactively
  removes any Relationship Candidate that referenced the deleted
  candidate as source or target, rather than leaving a dangling
  reference for `computeCommitPreview`'s validation to merely flag
  later. `computeCommitPreview` still checks for dangling references
  defensively (in case a future code path bypasses this cascade), but
  the UI itself never shows a relationship pointing at a candidate that
  no longer exists.

### Flutter-Specific Recommendations

* **A header/toolbar `Row` that accumulates action buttons across work
  packages should be re-measured for overflow at every addition, not
  just when first written.** `SessionHeader`'s single `Row` (icon +
  session summary + advance/cancel + Sessions + New Session) overflowed
  by hundreds of pixels once this work package's "Close Session" and
  "Sessions" buttons were added on top of Work Package 007's existing
  set — `flutter test`'s widget test caught it immediately (a
  `RenderFlex overflowed` assertion), but only because a widget test
  happened to open a session and render the header; a manual visual
  check alone could easily have missed it at a wider window size. Fixed
  by splitting into two rows (name/status/counts + primary actions on
  one row; workflow actions in a `Wrap` below), which degrades
  gracefully at any width rather than requiring exact pixel-budget
  accounting. The same fix (split into two rows, or use `Wrap`) is the
  right first move the next time any Studio toolbar accumulates a
  button too many.
* **`_TabButton`-style custom tab widgets should carry an explicit
  `Key` from the start if they'll ever need to be targeted by a test**
  — the two-tab Engineering Review header initially had no way to
  disambiguate its "Relationships" tab from other on-screen text/
  `InkWell` matches without a `ValueKey`; adding
  `ValueKey('engineering-review-tab-candidates')`/
  `'engineering-review-tab-relationships'` resolved it immediately and
  is a permanent, low-cost addition (Keys don't affect runtime
  behavior) rather than test-only scaffolding.

---

## Work Package 009 — Knowledge Studio (PDF Source Viewer, Evidence Regions, Evidence Linking)

Status: Implemented

Tasks:

* STUDIO-TASK-000019 — PDF Source Viewer — Complete
* STUDIO-TASK-000020 — Evidence Regions — Complete
* STUDIO-TASK-000021 — Evidence Linking — Complete

### What Exists

Continues the Work Package 007/008 `lib/knowledge/` module. Adds the
first *true* PDF viewer to Knowledge Studio (a real, interactive
renderer, not a placeholder) plus a manual Evidence Region/Evidence
Link/Page Selection model — all still entirely Studio-only ("No
Foundation modifications occur"). No AI, no OCR, no Repository Commit.
See `docs/EVIDENCE_MODEL.md` for full detail.

* `lib/knowledge/workspaces/pdf_source_viewer.dart` (new) — the PDF
  Source Viewer: page navigation, zoom in/out, fit width, fit page,
  rotate, continuous scrolling, Current Page/Total Pages/Zoom
  Percentage display, manual Evidence Region drawing (drag-to-create),
  and a Page Selection toggle. Built on `pdfrx` (new dependency — see
  Flutter Package Decisions).
* `lib/knowledge/models/evidence_region.dart`,
  `evidence_link.dart`, `page_selection.dart` (all new) —
  `EvidenceRegion` (rectangle region: id/sourceId/page/x/y/width/
  height, top-left-origin fractions of the page's own size/label/
  notes), `EvidenceLink` (Knowledge Candidate ↔ Evidence Region join),
  `PageSelection` (whole-page marker). See `docs/EVIDENCE_MODEL.md` §
  Coordinate System for why fractions, not pixels or points.
* `lib/knowledge/models/knowledge_session_record.dart` — extended with
  `evidenceRegions`/`evidenceLinks`/`pageSelections` lists, all
  defaulting to `[]` when absent so a pre-Work-Package-009 session file
  still loads (confirmed by a unit test).
* `lib/knowledge/services/knowledge_session_service.dart` — extended
  with `validateEvidenceRegionLabel` (Evidence Browser Rename: empty
  label rejected), `isEvidenceLinked` (idempotency check for linking),
  and `buildDuplicate` extended to carry the three new lists over
  unchanged when duplicating a session.
* `lib/core/services/foundation_runtime_state.dart`/
  `foundation_runtime_service.dart` — extended per this work package's
  Architecture Rule ("Connection Manager coordinates state only"):
  `evidenceRegions`/`selectedEvidenceRegion`, `evidenceLinks`/
  `selectedEvidenceLink`, `pageSelections`, `currentPage`, and a new,
  **separate** `openSourceDocument` field (Work Package 009's "Current
  Source Document" — see Architectural Observations for why this
  couldn't just reuse the existing `selectedSourceMaterial` field).
  New notifier methods: `setCurrentPage`, `createEvidenceRegion`,
  `renameEvidenceRegion`, `setEvidenceRegionNotes`,
  `deleteEvidenceRegion`, `selectEvidenceRegion`/
  `clearEvidenceRegionSelection`, `linkEvidence`/`unlinkEvidence`,
  `selectEvidenceLink`/`clearEvidenceLinkSelection`,
  `togglePageSelection`. Selection is now six-way mutually exclusive
  (added Evidence Region); `deleteKnowledgeCandidate`/
  `removeSourceMaterial` extended to cascade-delete Evidence Links/
  Regions/Page Selections that would otherwise dangle.
* `lib/knowledge/workspaces/evidence_browser_dialog.dart` (new) — the
  Evidence Browser: Region Name/Page/Type ("Rectangle")/Linked
  Candidate Count, with Rename/Delete/Navigate, scoped to one source's
  regions.
* `lib/knowledge/inspector/evidence_region_properties.dart`,
  `knowledge_candidate_properties.dart` (extended),
  `source_material_properties.dart` (extended),
  `evidence_link_entries.dart` (new),
  `link_evidence_dialog.dart` (new) — Property Inspector support for
  Evidence Region (new 7th mode), Knowledge Candidate Evidence (linked
  regions list + "Link Evidence Region" action added to the existing
  Candidate mode), and Source Metadata (Evidence Region count and
  selected pages added to the existing Source Material mode).
  `lib/shared/widgets/property_inspector_panel.dart` extended to a
  7-arm switch (Evidence Region first).
  `lib/knowledge/review/engineering_review_panel.dart`/
  `knowledge_candidate_row.dart` extended so selecting an Evidence
  Region highlights its linked candidates' rows in the Candidates tab
  (the other half of bidirectional highlighting).
* `lib/shared/format.dart` — gained `formatLinkedCount` (Evidence
  Browser's "Linked Candidate Count" display).

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: OEP Foundation, the
Public C API, AI functionality, OCR functionality, and Repository
Commit itself are all untouched. PDF text extraction/selection is not
implemented (viewer only, per STUDIO-TASK-000019: "No parsing. No
OCR. No extraction."). Non-rectangle Evidence Region shapes are not
implemented — STUDIO-TASK-000020 lists only "Rectangle Regions."

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      evidence_region.dart                New
      evidence_link.dart                  New
      page_selection.dart                 New
      knowledge_session_record.dart       Extended (evidenceRegions/evidenceLinks/pageSelections)
    inspector/
      evidence_region_properties.dart     New
      evidence_link_entries.dart          New
      link_evidence_dialog.dart           New
      knowledge_candidate_properties.dart Extended (Evidence section)
      source_material_properties.dart     Extended (Source Metadata)
    workspaces/
      pdf_source_viewer.dart              New
      evidence_browser_dialog.dart        New
docs/
  EVIDENCE_MODEL.md                       New
```

### Flutter Package Decisions

One new dependency: **`pdfrx`** (`^2.4.7`, MIT license) — see
`docs/EVIDENCE_MODEL.md` § Flutter Package Decision for the full
comparison against `pdfx`, `printing`, and Syncfusion's viewer, and why
`pdfrx` was chosen (`pageOverlaysBuilder`/`viewerOverlayBuilder` for
Evidence Region rendering; `getPdfPageHitTestResult` for region
creation; PDFium-backed, Windows-capable, actively maintained).
Requires Windows Developer Mode enabled for its symlink-based build
step (confirmed already enabled on this machine); `pdfium.dll` is
bundled alongside `oep_studio.exe` automatically.

### Verification Results

* `flutter analyze` — no issues found.
* `flutter test` — 60/60 passing: all prior tests, plus new
  `KnowledgeSessionService` unit tests (`validateEvidenceRegionLabel`,
  `isEvidenceLinked`) and new `knowledge_session_storage_test.dart`
  cases (Evidence Regions/Links/Page Selections round-trip through
  save/load exactly; a hand-written pre-Work-Package-009 `session.json`
  with none of the three new keys present still loads with empty
  lists, confirming backward compatibility).
* `flutter build windows` — succeeded; `pdfium.dll` confirmed present
  in the Release output alongside `oep_foundation_bridge.dll`.
* **Manual verification.** As in Work Packages 007/008, this
  environment's OS-level UI automation could not reliably drive this
  app — `computer-use` access to the running `oep_studio.exe` process
  was again unavailable this work package. Per this work package's own
  pre-approved instructions, verification was performed with a
  temporary `integration_test`
  (`integration_test/knowledge_studio_wp009_test.dart`, added, run
  against the real compiled app, then deleted — `pubspec.yaml`'s
  `integration_test` dev dependency reverted and `pubspec.lock`
  regenerated) against a real, valid 3-page PDF fixture generated by a
  one-off Python script (not committed) with correct xref offsets, so
  the real `pdfrx`/PDFium engine actually parsed and rendered it — the
  log confirms `PdfViewer: Loaded page 3 of 3`, a genuine render, not a
  stub.

  The test covered the full golden path: create a session → add a
  Knowledge Candidate → attach the PDF (via a direct
  `attachSourceMaterial` call through the Connection Manager, bypassing
  the native file-picker button for the same reason Work Package 006
  bypassed the folder-picker button — `SourceMaterialService`'s own
  copy logic is separately covered by the permanent
  `knowledge_session_storage_test.dart`) → confirm the PDF renders with
  3 pages → page navigation (Next Page moves 1→2) → zoom (Zoom In
  changes the displayed percentage) → draw an Evidence Region via a
  real drag gesture on the rendered page (confirmed by inspecting
  `evidenceRegions` afterward, not just the UI) → Evidence Browser
  lists it as "Rectangle," Rename works → Navigate selects it and the
  Property Inspector reflects the new label → Link it to the Knowledge
  Candidate from the Region's own Property Inspector view → selecting
  the candidate shows the linked region highlighted the other direction
  → toggle a Page Selection → close the session and reopen it via the
  Session Browser, confirming the Evidence Region, Evidence Link, and
  Page Selection all survive a real disk round-trip (not just
  in-memory state) → delete the session via the Session Browser's own
  Delete flow (cleaning up its own test data). All assertions passed on
  the corrected run; no test artifacts were left on disk afterward.

  One interaction — tapping the small Page Selection checkbox overlay
  drawn inside `pdfrx`'s per-page `Stack` — could not be reliably
  driven by a synthetic `tester.tap()` in this harness (see
  Architectural Observations for the full diagnosis, including the two
  real bugs this same investigation *did* catch and fix). That one
  assertion was verified via a direct `togglePageSelection` call
  through the Connection Manager instead, the same "document the
  limitation, use the pre-approved workaround" approach used for the
  native file picker — the underlying state-management and persistence
  logic is exercised identically either way; only this one on-screen
  click affordance itself went unverified by automation.

### Architectural Observations

* **The Connection Manager's "Current Source Document" must be a field
  separate from "Current Selection."** An early version of this work
  reused Work Package 008's `selectedSourceMaterial` (which drives the
  Property Inspector's mode) as Work Package 009's "Current Source
  Document" too, reasoning the two concepts were the same thing in this
  UI. They are not: every `select*` method clears
  `selectedSourceMaterial` as part of the existing mutual-exclusivity
  rule, so reusing that field to also mean "which PDF is open" meant
  selecting a Knowledge Candidate silently closed the Source Viewer —
  directly breaking this work package's own requirement that selecting
  a candidate highlights its linked regions *in the still-open
  viewer*. Caught during manual verification (the integration test's
  Page Selection step found the Source Viewer reverted to its empty
  placeholder after an earlier candidate-selection step), not design
  review. Fixed by introducing `openSourceDocument` as an independent
  field, set only when a source is opened from the Import Queue and
  left untouched by every other selection method. Full account in
  `docs/EVIDENCE_MODEL.md` § Architectural Observations.
* **A dialog-controller-lifecycle bug — the exact one Work Package 007
  already documented and fixed — was reintroduced in the Evidence
  Browser's Rename dialog and caught by the integration test.** The
  dialog initially created its `TextEditingController` in the calling
  widget and disposed it right after `showDialog`'s `Future` resolved,
  crashing with "A `TextEditingController` was used after being
  disposed" — because that `Future` completes on `Navigator.pop()`,
  before the exit animation finishes rebuilding the still-attached
  `TextField`. Reintroduced because this dialog was written fresh
  rather than copied from an existing one that already followed the
  fix. Repaired the same way as before: the dialog's own
  `ConsumerStatefulWidget`/`State` now owns and disposes the
  controller. Recorded again here as a standing reminder for the next
  new dialog, since it recurred once already despite being documented.
* **A plain `GestureDetector` scoped to a small overlay widget's own
  bounds is simpler than `pdfrx`'s `PdfOverlayInteractionRegion` for
  tap-like interactions that don't need to compete with viewer pan/zoom
  — but an *armed*, full-viewer, opaque `GestureDetector` (the
  region-drawing tool) intercepts every tap in the viewer until
  disarmed, by design (it's rendered above the page content so the drag
  preview always stays visible).** This is correct "tool mode"
  behavior, not a defect, but it means clicking an existing region or
  toggling Page Selection while the drawing tool is still armed does
  nothing — worth remembering as the first thing to check if a
  Source-Viewer-overlay tap ever appears to silently fail, in
  verification or in real use.

### Flutter-Specific Recommendations

* **`pdfrx`'s `pageOverlaysBuilder`/`viewerOverlayBuilder` callbacks are
  invoked during a *descendant* widget's build, not synchronously
  inside the enclosing `ConsumerState.build()` — calling `ref.watch`
  from within them is invalid.** Capture the needed
  `FoundationServiceState` snapshot once, in `build()` itself (stored
  on an instance field), and have the callbacks read that stored
  snapshot instead of calling `ref.watch`/`ref.read` for state
  (dispatching *actions* via `ref.read(...).notifier` from inside a
  callback remains fine, since that's never build-context-sensitive).
* **`pdfrx`'s `PdfViewerController` is itself a `ValueListenable<Matrix4>`**
  — wrapping the toolbar in a `ListenableBuilder(listenable: controller,
  ...)` is the simplest way to keep Current Page/Total Pages/Zoom
  Percentage reactive to pan and zoom, without needing a separate
  Riverpod state field for values the controller already tracks.
* **A widget test's `ensureVisible` is worth reaching for by default
  for any button inside a horizontally- or vertically-scrolling
  toolbar** — this work package's PDF toolbar has more buttons than fit
  in the column width at the test's window size, and a bare
  `tester.tap()` silently computed a coordinate for a button that was
  laid out but currently scrolled outside the visible viewport, hitting
  unrelated content instead. `ensureVisible` scrolls the container to
  bring the target into view first.

---

## Work Package 010 — Knowledge Studio (Manual Candidate Authoring, Procedure Builder, Specification Editor, Validation)

Status: Implemented

Tasks:

* STUDIO-TASK-000022 — Manual Knowledge Candidate Authoring — Complete
* STUDIO-TASK-000023 — Procedure Builder — Complete
* STUDIO-TASK-000024 — Specification Editor — Complete
* STUDIO-TASK-000025 — Knowledge Candidate Validation — Complete

### What Exists

Continues the Work Package 007–009 `lib/knowledge/` module. Transforms
Knowledge Studio into a complete manual engineering authoring
environment on top of the evidence model Work Package 009 built — all
still entirely Studio-only ("No Foundation modifications occur"). No
AI, no OCR, no automatic extraction, no Repository Commit. See
`docs/KNOWLEDGE_CANDIDATES.md` for full detail.

* `lib/knowledge/models/knowledge_candidate_type.dart` — expanded from
  five to ten types (added Tool, Material, Fluid, Warning,
  Measurement). `lib/knowledge/models/knowledge_candidate.dart` — added
  `notes`/`author`/`tags` fields, all defaulting on load (`''`/`''`/
  `[]`) so a pre-Work-Package-010 candidate JSON entry still loads.
* `lib/knowledge/models/procedure_step.dart` (new) — `ProcedureStep`
  (id/candidateId/title/description/notes/referencedCandidateIds/
  referencedRegionIds), a separate `candidateId`-keyed list rather than
  embedded on the candidate, ordered by array position (no explicit
  `order` field).
* `lib/knowledge/models/specification_type.dart`,
  `specification_details.dart` (both new) — `SpecificationType` (the
  seven types this work package's Requirements list), `SpecificationDetails`
  (candidateId 1:1/specType/value/unit/notes) — "Linked Evidence" reuses
  the existing Work Package 009 `EvidenceLink` mechanism rather than a
  new field.
* `lib/knowledge/models/candidate_validation_result.dart` (new) —
  `ValidationSeverity` (ok/warning/error), `CandidateValidationResult`
  (candidateId/severity/issues) — never persisted, computed on demand.
* `lib/knowledge/models/knowledge_session_record.dart` — extended with
  `procedureSteps`/`specificationDetails` lists, both defaulting to
  `[]` when absent so a pre-Work-Package-010 session file still loads
  (confirmed by a unit test).
* `lib/knowledge/services/knowledge_session_service.dart` — extended
  with `validateProcedureStepTitle` (empty title rejected),
  `validateSpecificationDetails` (empty value/unit rejected — Error
  Handling: "Invalid specifications, Invalid units"),
  `computeCandidateValidation` (the six validation rules — see
  `docs/KNOWLEDGE_CANDIDATES.md` § Validation Model — pure, takes a
  snapshot, returns a value, never mutates candidate data), and
  `buildDuplicate` extended to carry the two new lists over unchanged.
* `lib/core/services/foundation_runtime_state.dart`/
  `foundation_runtime_service.dart` — extended per this work package's
  Architecture Rule ("Connection Manager coordinates state only"):
  `procedureSteps`/`specificationDetails`, a new, **separate**
  `openProcedure` field (mirroring `openSourceDocument`'s pattern from
  the start — see Architectural Observations) and
  `selectedProcedureStep`, and a derived `candidateValidation` getter
  (this work package's "Current Validation State"). New notifier
  methods: `addKnowledgeCandidate` now returns the created candidate;
  `duplicateKnowledgeCandidate` (deliberately bypasses name-uniqueness
  validation); `openProcedureBuilder`/`closeProcedureBuilder`;
  `addProcedureStep`/`updateProcedureStep`/`deleteProcedureStep`/
  `duplicateProcedureStep`/`reorderProcedureStep`/
  `setProcedureStepReferences`; `selectProcedureStep`/
  `clearProcedureStepSelection`; `setSpecificationDetails`. Selection is
  now seven-way mutually exclusive (added Procedure Step);
  `deleteKnowledgeCandidate` extended to cascade-delete Procedure Steps
  and Specification Details that would otherwise dangle.
* `lib/knowledge/workspaces/procedure_builder_dialog.dart` (new) — the
  Procedure Builder: ordered steps with automatic numbering, Insert/
  Delete/Duplicate/drag-and-drop reordering (`ReorderableListView`),
  each step's own edit dialog with Knowledge Candidate/Evidence Region
  reference checklists.
* `lib/knowledge/workspaces/specification_editor_dialog.dart` (new) —
  the Specification Editor: Type/Value/Unit/Notes, plus a Linked
  Evidence list reusing the existing Evidence Linking UI mechanism.
* `lib/knowledge/inspector/knowledge_candidate_properties.dart`
  (extended) — Notes/Author/Tags fields, a Validation Status section,
  and conditional Specification fields / a Procedure step-count summary
  with "Open Procedure Builder"/"Open Specification Editor" actions.
  `lib/knowledge/inspector/procedure_step_properties.dart` (new) — the
  Property Inspector's one new top-level mode (Procedure Step).
  `lib/shared/widgets/property_inspector_panel.dart` extended to an
  8-arm switch (Procedure Step added after Knowledge Candidate).
* `lib/knowledge/review/knowledge_candidate_row.dart` (extended) —
  Validation Status icon (tooltip lists every issue), Linked Evidence
  Count, and a Duplicate action.
  `lib/knowledge/review/knowledge_candidate_list_query.dart` (new) —
  filter (type/status/name substring) and sort (name/type/status/
  validation severity) for the Candidate List, mirroring
  `RelationshipCandidateListQuery`'s Work Package 008 design.
  `lib/knowledge/review/engineering_review_panel.dart`'s `_CandidateList`
  converted to a `ConsumerStatefulWidget` holding the query, with
  filter/sort controls above the list (mirroring `ObjectsPage`'s Work
  Package 004 pattern).
* `lib/knowledge/review/knowledge_candidate_form_dialog.dart`/
  `controllers/knowledge_candidate_form_controller.dart` — extended
  with Notes/Author/Tags fields, and `initialName`/`initialDescription`/
  `initialType`/`linkToRegionId` parameters supporting the "create from
  Source Material/Page Selection/Evidence Region" entry points added to
  `evidence_browser_dialog.dart`, `import_queue_panel.dart`, and
  `source_material_properties.dart`.

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: OEP Foundation, the
Public C API, AI functionality, OCR functionality, automatic
extraction, and Repository Commit itself are all untouched. A
generalized "Evidence Object" link type unifying Source Material/Page
Selection/Evidence Region under SDD-021's fuller hierarchy is not
implemented — see Architectural Observations.

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      procedure_step.dart                 New
      specification_type.dart             New
      specification_details.dart          New
      candidate_validation_result.dart    New
      knowledge_candidate.dart            Extended (notes/author/tags)
      knowledge_candidate_type.dart       Extended (10 types)
      knowledge_session_record.dart       Extended (procedureSteps/specificationDetails)
    inspector/
      procedure_step_properties.dart      New
      knowledge_candidate_properties.dart Extended (Notes/Author/Tags, Validation, Specification/Procedure sections)
      source_material_properties.dart     Extended (Create from Page Selection)
    review/
      knowledge_candidate_list_query.dart New
      knowledge_candidate_row.dart        Extended (Validation Status, Linked Evidence Count, Duplicate)
      knowledge_candidate_form_dialog.dart Extended (Notes/Author/Tags, prefill params)
      engineering_review_panel.dart       Extended (filter/sort UI)
    workspaces/
      procedure_builder_dialog.dart       New
      specification_editor_dialog.dart    New
      evidence_browser_dialog.dart        Extended (Create from Region)
      import_queue_panel.dart             Extended (Create from Source Material)
docs/
  KNOWLEDGE_CANDIDATES.md                 New
```

### Flutter Package Decisions

No new dependencies. `ReorderableListView` (Flutter framework,
`package:flutter/material.dart`) implements the Procedure Builder's
drag-and-drop reordering — its `onReorderItem` callback (the
non-deprecated replacement for `onReorder`, available in this
project's Flutter 3.44.6) already adjusts `newIndex` for the removed
item, matching `reorderProcedureStep`'s own index semantics exactly.

### Verification Results

* `flutter analyze` — no issues found.
* `flutter test` — 85/85 passing: all prior tests, plus new
  `KnowledgeSessionService` unit tests (`validateProcedureStepTitle`,
  `validateSpecificationDetails`, and nine `computeCandidateValidation`
  cases covering every rule in isolation), a new
  `knowledge_candidate_list_query_test.dart` (sort/filter, mirroring
  `object_list_query_test.dart`'s shape), and new
  `knowledge_session_storage_test.dart` cases (Procedure Steps/
  Specification Details round-trip through save/load exactly; a
  hand-written pre-Work-Package-010 `session.json` — missing the two
  new keys, and with a pre-Work-Package-010 candidate entry missing
  `notes`/`author`/`tags` — still loads with empty defaults, confirming
  backward compatibility).
* `flutter build windows` — succeeded.
* **Manual verification.** As in Work Packages 007–009, `computer-use`
  could not target `build\windows\x64\runner\Release\oep_studio.exe` —
  confirmed this work package by attempting `request_access`/
  `open_application` against it, both of which only resolve
  Start-menu-registered application names, and the compiled `.exe` is
  neither installed nor registered there. Per this work package's own
  pre-approved instructions, verification was performed with a
  temporary `integration_test`
  (`integration_test/knowledge_studio_wp010_test.dart`, added, run
  against the real compiled app via `flutter test ... -d windows`, then
  deleted — `pubspec.yaml`'s `integration_test` dev dependency reverted
  and `pubspec.lock` regenerated) against a real, valid single-page PDF
  fixture generated by a one-off script (not committed) with correct
  xref offsets, so the real `pdfrx`/PDFium engine actually opened it
  (log: `PdfDocument initial load: ... (57 ms)`).

  The test covered: create a session → attach a PDF source → open it
  in the Source Viewer → create an Evidence Region directly through the
  Connection Manager (the drag-to-create gesture itself was already
  thoroughly verified in Work Package 009 and isn't new here) → open
  the Evidence Browser → **"Create Knowledge Candidate from Region"**
  → the New Candidate dialog opens pre-filled with the region's label
  → submit → confirm (via the Connection Manager, not just the UI) that
  the new candidate is actually linked to that region via a real
  `EvidenceLink` → manually author a Procedure-type and a
  Specification-type candidate through the New Candidate dialog's Type
  dropdown, with Notes/Author/Tags filled in and confirmed on the
  candidate afterward → Candidate List filter (name substring narrows
  the list, clearing restores it) → Duplicate a candidate (direct
  notifier call — see below) and confirm both copies flip to
  `error`-severity duplicate-name validation, with the duplicate
  additionally missing the original's Evidence Link → open the
  **Procedure Builder**: Insert two steps, Duplicate a step, Delete a
  step, tap a step to select it (confirming the Property Inspector's
  Procedure Step mode reflects it), close, and confirm the Property
  Inspector's step count updated → open the **Specification Editor**:
  submitting an empty Value is rejected inline with "Specification
  value cannot be empty." without closing the dialog, then a valid
  Value/Unit saves and is confirmed via the Connection Manager →
  confirm final Validation Status for every candidate touched (the
  complete Specification and the non-empty Procedure both read
  `warning`, not `error`, for missing evidence only; the duplicate-named
  candidates both read `error`) → close and reopen the session,
  confirming Procedure Steps, Specification Details, and candidate
  Notes/Author/Tags all survive a real disk round-trip → delete the
  session, cleaning up its own test data. All assertions passed; no
  test artifacts were left on disk afterward (two sessions from earlier,
  failed attempts at this same test were found and removed manually
  before the final commit).

  Two interactions were verified via a direct Connection Manager call
  rather than a synthetic gesture, for the same reasons Work Package
  009 documented for its own one exception: **drag-and-drop step
  reordering** (`ReorderableListView` drag gestures are not reliably
  drivable through this widget-test harness) was verified via
  `reorderProcedureStep` directly — the same state mutation
  `onReorderItem` invokes — and the Candidate List's **Duplicate**
  button tap itself went untested in favor of calling
  `duplicateKnowledgeCandidate` directly, since by that point in the
  test a second candidate shared its target's name and an unambiguous
  tap target could not be located without added complexity that
  wouldn't have exercised any additional logic (`onDuplicate`'s
  `onPressed` is a one-line call to the same method).

### Architectural Observations

See `docs/KNOWLEDGE_CANDIDATES.md` § Architectural Observations for
the full account of both open questions this work package surfaced —
summarized here:

* **"Create Knowledge Candidates from Source Material / Page Selection
  / Evidence Region" does not fully reconcile with SDD-021's
  four-layer Evidence Object hierarchy, and this work package's own
  Requirements text does not resolve the gap.** Implemented as three UI
  entry points into the same New Candidate dialog; only the Evidence
  Region path also creates a real `EvidenceLink` (reusing the Work
  Package 009 mechanism exactly as-is), since `EvidenceLink` has no
  schema for referencing a Source Material or Page Selection and
  extending it to a generalized SDD-021 "Evidence Object" reference
  would be a genuine, independent architectural decision with
  cascading effects on the Evidence Browser and the persisted file
  format. This is the same discrepancy flagged, unresolved, at the end
  of Work Package 009's own completion report (an untracked, then-Draft
  SDD-021 outside that work package's authorized scope) — now that
  SDD-021 is frozen and in-scope, this work package applied the most
  literal, non-breaking reading of its own Requirements text (three
  entry points, not a schema rebuild) rather than treating the
  discrepancy as a hard blocker, since a reasonable reading was
  available. **Flagged for architectural review**, not resolved here.
* **The Property Inspector's "extend support for" list names four
  items (Knowledge Candidate, Procedure Step, Specification, Validation
  Status); only Procedure Step became a new mutually-exclusive mode.**
  Resolved by cross-referencing this work package's own Connection
  Manager section, whose four-item list ("Current Knowledge Candidate,
  Current Procedure, Current Procedure Step, Current Validation State")
  has no "Current Specification" or "Current Validation" *selection*
  field — confirming Specification and Validation Status belong as
  sections within Knowledge Candidate mode, not independent modes.
* **`openProcedure` was introduced as real Connection Manager state
  from the start, deliberately mirroring `openSourceDocument`'s
  pattern, specifically to avoid reintroducing the exact bug Work
  Package 009 spent significant effort diagnosing and fixing** (an
  earlier "current document/procedure" field conflated with a
  mutually-exclusive selection field, so selecting anything else
  silently lost track of what was "open"). No new instance of that bug
  occurred this work package — the pattern was applied proactively
  rather than discovered through another failure.

---

## Work Package 011 — Knowledge Studio (Knowledge Session Graph, Provenance, Dependency Viewer, Session Health)

Status: Implemented

Tasks:

* STUDIO-TASK-000026 — Knowledge Session Graph — Complete
* STUDIO-TASK-000027 — Provenance Explorer — Complete
* STUDIO-TASK-000028 — Candidate Dependency Viewer — Complete
* STUDIO-TASK-000029 — Session Health Dashboard — Complete

### What Exists

Continues the Work Package 007-010 lib/knowledge/ module. Adds
visual knowledge exploration on top of the candidate/procedure/
specification/evidence model prior work packages built - all still
entirely Studio-only ("No Foundation modifications occur"). No OCR, no
AI, no Repository Commit. See docs/KNOWLEDGE_GRAPH.md for full
detail.

* lib/knowledge/models/knowledge_graph_node.dart,
  knowledge_graph_edge.dart, knowledge_session_graph.dart (all
  new) - KnowledgeGraphNode (candidate/evidenceRegion/sourceMaterial,
  reusing each artifact's own existing icon), KnowledgeGraphEdge
  (relationshipCandidate/evidenceLink/sourceContainsRegion/
  procedureReference), KnowledgeSessionGraph (nodes + edges,
  "completely independent of Foundation Graph").
* lib/knowledge/services/knowledge_graph_service.dart (new) -
  buildGraph: pure graph construction from existing session state,
  silently omitting any edge with a broken reference (Error Handling:
  "Broken references, Invalid graph nodes").
* lib/knowledge/workspaces/knowledge_graph_dialog.dart (new) - the
  Knowledge Session Graph: Pan/Zoom (InteractiveViewer, Flutter
  framework - no new dependency), Fit All, Center Selection, Select
  Node; a deterministic three-column layout (Source Material/Evidence
  Region/Knowledge Candidate); a dialog opened from the Session
  Header's new "Knowledge Graph" button (SDD-016's seven-panel layout
  stays frozen - the same dedicated-dialog precedent Work Package 010
  set for the Procedure Builder/Specification Editor).
* lib/knowledge/models/candidate_provenance.dart (new) -
  ProvenanceEntry/CandidateProvenance.
  lib/knowledge/services/provenance_service.dart (new) -
  computeProvenance: Candidate to Evidence Region(s) to Page Selection
  (optional) to Source Material, derived purely from existing
  EvidenceLink/EvidenceRegion/PageSelection/SourceMaterial data
  - "shall not duplicate persisted data."
  lib/knowledge/inspector/candidate_provenance_section.dart (new) -
  the Provenance Explorer, the Property Inspector's new Provenance tab;
  every step is tappable, navigating down the chain.
* lib/knowledge/models/candidate_dependency_info.dart (new) -
  DependencyRelationshipEntry/CandidateDependencyInfo.
  lib/knowledge/services/dependency_service.dart (new) -
  computeDependencyInfo: Referenced By/References/Relationships/
  Procedure Usage/Specification Usage/Evidence Count/Validation Status,
  all derived from existing candidate/relationship-candidate/procedure-
  step/evidence-link/specification-details/validation data.
  lib/knowledge/inspector/candidate_dependency_section.dart (new) -
  the Candidate Dependency Viewer, the Property Inspector's new
  Dependencies tab; every entry is tappable.
* lib/knowledge/models/session_health_metrics.dart (new) -
  SessionHealthMetrics (eleven metrics).
  lib/knowledge/services/session_health_service.dart (new) -
  computeSessionHealth: pure, informational-only, never modifies
  session data; documents explicit formulas for "Orphaned Candidates"
  (zero Evidence Links/Relationships/Procedure Step references in
  either direction), "Relationship Density"
  (relationshipCandidateCount / candidateCount), and "Average
  Evidence Coverage" (percentage of candidates with at least one linked
  Evidence Region) - none of which this work package's text defined a
  formula for.
  lib/knowledge/inspector/session_properties.dart (extended) - a new
  Session Health section, shown as part of the existing Session-mode
  fallback.
* lib/knowledge/inspector/knowledge_candidate_properties.dart
  (extended) - the Knowledge Candidate Property Inspector mode is now a
  local Properties / Provenance / Dependencies tab switch (mirroring
  the Engineering Review panel's own tab pattern, Work Package 007),
  rather than a new top-level mode for either.
  lib/core/services/foundation_runtime_state.dart - extended with
  four derived getters: knowledgeSessionGraph, provenanceFor,
  dependencyFor, sessionHealth (this work package's "Current Graph
  Selection"/"Current Provenance View"/"Current Dependency View"/
  "Current Session Health," read the same way Work Package 010 read
  "Current Validation State" - derived, not stored).
  lib/core/services/foundation_runtime_service.dart - one new method,
  selectGraphNode, dispatching a tapped graph node to whichever of
  the three existing selectKnowledgeCandidate/selectEvidenceRegion/
  selectSourceMaterial methods matches its kind - no new selection
  field was introduced (see Architectural Observations).
* lib/knowledge/review/knowledge_candidate_row.dart - fixed a
  pre-existing overflow bug (five IconButtons at Material's default
  48x48 tap target, plus the Validation/Status badges, no longer fit
  this row at the app's documented minimum window width once Work
  Package 010 added a fifth button) - caught by this work package's
  own window-resizing verification, fixed with padding: EdgeInsets.zero /
  tighter constraints on all five buttons.

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: OEP Foundation, the
Public C API, OCR functionality, AI functionality, and Repository
Commit itself are all untouched.

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      knowledge_graph_node.dart           New
      knowledge_graph_edge.dart           New
      knowledge_session_graph.dart        New
      candidate_provenance.dart           New
      candidate_dependency_info.dart      New
      session_health_metrics.dart         New
    services/
      knowledge_graph_service.dart        New
      provenance_service.dart             New
      dependency_service.dart             New
      session_health_service.dart         New
    workspaces/
      knowledge_graph_dialog.dart         New
    inspector/
      candidate_provenance_section.dart   New
      candidate_dependency_section.dart   New
      knowledge_candidate_properties.dart Extended (Properties/Provenance/Dependencies tabs)
      session_properties.dart             Extended (Session Health section)
    review/
      knowledge_candidate_row.dart        Fixed (narrow-window overflow)
    sessions/
      session_header.dart                 Extended ("Knowledge Graph" button)
docs/
  KNOWLEDGE_GRAPH.md                      New
```

### Flutter Package Decisions

**No new dependency.** Per this work package's explicit guidance
("Prefer Flutter framework widgets where practical"), the Knowledge
Session Graph's Pan/Zoom/Fit All/Center Selection/Select Node
requirements are all satisfiable with Flutter framework widgets alone:
InteractiveViewer (native pan/zoom, including pinch-to-zoom and
scroll-wheel support, driven by a TransformationController this
widget already needs for programmatic Fit All/Center Selection),
CustomPaint (edges), and Positioned/Material/InkWell (nodes).

A graph-visualization package (e.g. graphview, flutter_graph_view
on pub.dev) was considered and rejected: those packages exist primarily
to provide automatic layout algorithms (force-directed, Sugiyama,
tree) for graphs whose structure isn't known in advance. This graph's
structure is fully known and small (bounded by one session's candidate/
region/source counts), and this work package's own interaction
requirements name nothing an automatic layout algorithm uniquely
provides - a deterministic three-column layout (mirroring the
Provenance Explorer's own Source Material to Evidence Region to
Knowledge Candidate reading direction) is simpler to reason about,
easier to keep visually stable across rebuilds (an automatic layout can
reshuffle node positions on every recompute unless pinned), and adds
zero new transitive dependencies, license review, or version-pinning
surface for a capability Flutter's own framework already covers.

### Verification Results

* flutter analyze - no issues found.
* flutter test - 112/112 passing: all prior tests, plus four new
  service test files (knowledge_graph_service_test.dart,
  provenance_service_test.dart, dependency_service_test.dart,
  session_health_service_test.dart) covering node/edge construction,
  broken-reference omission, the full provenance chain (including the
  optional Page Selection step), reference/referencedBy/relationship/
  procedure-usage/specification-usage derivation, and every Session
  Health formula including the orphaned/duplicate/density/coverage
  edge cases.
* flutter build windows - succeeded.
* **Manual verification.** As in Work Packages 007-010, computer-use
  was confirmed unable to target
  build\windows\x64\runner\Release\oep_studio.exe - request_access/
  open_application only resolve Start-menu-registered application
  names, and the compiled .exe is neither installed nor registered
  there. Per this work package's own pre-approved instructions,
  verification was performed with a temporary integration_test
  (integration_test/knowledge_graph_wp011_test.dart, added, run
  against the real compiled app via flutter test ... -d windows, then
  deleted - pubspec.yaml's integration_test dev dependency reverted
  and pubspec.lock regenerated).

  The test covered: create a session, attach a PDF source, author a
  Component and a Procedure candidate, create and link an Evidence
  Region, author a Relationship Candidate and a Procedure Step
  reference, then open the **Knowledge Session Graph**: all four node
  labels (two candidates, the region, the source) render, Fit All
  runs without error; then the **Provenance tab**: the region/source
  chain renders, with "Not selected as a page" correctly shown for the
  region's page (no Page Selection was toggled); then the
  **Dependencies tab**: "Referenced By" correctly lists the Procedure
  candidate (via its step's reference), "Relationships"/"Evidence
  Count" render; then **Session Health**: reached via the Session-mode
  fallback, confirmed orphanedCandidateCount == 0 (both candidates are
  connected) and evidenceRegionCount == 1 directly against the
  Connection Manager; then **window resizing**, from 1400x900 down to
  the app's documented minimum (1000x700) and back, asserting no
  exception was thrown at either size; then delete the session,
  cleaning up its own test data. All assertions passed on the corrected
  run; no test artifacts were left on disk afterward (confirmed no
  session directories from earlier, failed attempts remained).

  **One interaction was verified via a direct Connection Manager call
  rather than a synthetic gesture**: tapping a node chip inside the
  graph's InteractiveViewer-transformed canvas was not reliably
  drivable through this widget-test harness (tester.tap computed a
  screen coordinate that hit-tested onto the edge-drawing CustomPaint
  layer rather than the node's own InkWell, despite the node being
  painted on top) - the same category of limitation Work Package 009
  documented for its drag-to-create-region gesture and Work Package 010
  documented for drag-and-drop step reordering, both also inside a
  transformed or custom-painted surface. Verified directly against
  FoundationRuntimeNotifier.selectGraphNode instead - the exact
  method a node's onTap calls - which exercises the real dispatch
  logic and proves "Selecting a node updates the Property Inspector"
  end to end through the Connection Manager; only the on-screen
  tap-to-hit-test wiring for this one gesture went unverified by
  automation. The Fit All/Center Selection toolbar buttons (ordinary
  OutlinedButtons outside the transformed canvas) were tapped and
  verified normally.

  **This verification pass also caught and fixed a real,
  pre-existing overflow bug** unrelated to this work package's own new
  code: KnowledgeCandidateRow (Work Package 007, extended Work
  Package 010) overflowed at the app's documented minimum window width
  once five full-size IconButtons plus the Validation/Status badges
  no longer fit the row - see What Exists above and Architectural
  Observations below.

### Architectural Observations

See docs/KNOWLEDGE_GRAPH.md § Architectural Observations for the
full account - summarized here:

* **This work package's Connection Manager section names four items
  ("Current Graph Selection, Current Provenance View, Current
  Dependency View, Current Session Health"); none required new stored
  state.** "Current Graph Selection" is fully satisfiable by reusing
  the three existing selectedCandidate/selectedEvidenceRegion/
  selectedSourceMaterial fields, since every graph node kind maps
  one-to-one onto one of the three - introducing a fourth, independent
  selection field would have duplicated selection state and risked the
  exact synchronization bug Work Package 009's openSourceDocument
  mistake already demonstrated. "Current Provenance View"/"Current
  Dependency View"/"Current Session Health" are derived getters,
  following the precedent Work Package 010 set for "Current Validation
  State."
* **"Procedures connect to their Procedure Steps" does not literally
  describe an edge between two rendered nodes** - Procedure Steps are
  not in this work package's own node-visualization list. Read as "a
  Procedure connects, via its steps, to whatever those steps
  reference," drawn as a direct Procedure-Candidate-to-referenced-thing
  edge rather than introducing a fourth, unlisted node kind for steps
  themselves (which already have a dedicated Property Inspector mode,
  Work Package 010, that a small graph node couldn't usefully
  replace).
* **A Source Material to Evidence Region edge, not named in this work
  package's own edge list, was added anyway** - without it, every
  Source Material node would be completely disconnected from the rest
  of the graph, despite being explicitly listed among the things to
  visualize. Drawn from data that already exists
  (EvidenceRegion.sourceId); treated as filling an omission, not as
  introducing new architecture.
* **Session Health's "Orphaned Candidates," "Relationship Density," and
  "Average Evidence Coverage" have no formulas in this work package's
  text** - all three were given an explicit, documented formula (see
  What Exists above and docs/KNOWLEDGE_GRAPH.md § Session Health
  Model) rather than left to guesswork at display time.

None of the four observations above blocked implementation - each had
a reasonable, literal reading available and consistent precedent from
Work Package 010 (or earlier) to apply it by; none constituted the kind
of genuine, irreconcilable conflict this work package's instructions
say to stop for.

---

## Work Package 012 — Knowledge Studio (Repository Commit)

Status: Implemented

Tasks:

* STUDIO-TASK-000030 — Commit Plan — Complete
* STUDIO-TASK-000031 — Candidate Conversion — Complete
* STUDIO-TASK-000032 — Transactional Repository Commit — Complete
* STUDIO-TASK-000033 — Commit Report — Complete
* Property Inspector Commit Plan/Commit Report support (part of STUDIO-TASK-000033) — Complete

### Architectural Blocker, Then Resolution

The first attempt at this work package stopped without writing code:
Foundation's Public C API (`oep_api.h`, through `OEP_API_VERSION 3`)
was read-only - no create/write/commit/transaction function existed
anywhere in the public header, confirmed by an exhaustive search and
by Foundation's own `platform/api/README.md`/`TASK.md`, both of which
explicitly listed object/relationship mutation as a non-goal through
Work Package 013. The underlying C++ runtime had `ObjectStore::create`/
`RelationshipStore::create` (used by Foundation's own CLI, which links
C++ directly), but `oep_foundation/CLAUDE.md`'s own architecture-freeze
rules forbid a Studio from bypassing the Public SDK, so that path was
never an option. This was reported as a hard blocker with three options
for the architect (extend Foundation's API, descope to read-only Commit
Planning, or hold the work package) - no code was written.

The blocker was resolved externally: Foundation's own Work Package 014
("Add Object Mutation, Relationship Mutation, Transactions, and Batch
Mutation to the Public C API") landed mid-session, confirmed via
`git log`/re-reading the updated `oep_api.h` (`OEP_API_VERSION 4`)
before any Work Package 012 code was written. See
`docs/REPOSITORY_COMMIT.md` § Why Repository Commit Was Blocked, Then
Unblocked.

### What Exists

Continues the Work Package 007-011 `lib/knowledge/` module - the first
work package in that module to call the Foundation Bridge. Full detail
in `docs/REPOSITORY_COMMIT.md`.

* `native/foundation_bridge/oep_foundation_bridge.def` - six new
  exports (`oep_object_create`, `oep_relationship_create`,
  `oep_transaction_begin`/`commit`/`rollback`/`is_active`); no C++
  wrapper code needed (plain EXPORTS list).
* `lib/core/foundation/oep_api_native_types.dart`/`oep_api_bindings.dart` -
  the six corresponding typedefs/bindings.
* `lib/core/foundation/foundation_bridge.dart` - `createObject`,
  `createRelationship`, `beginTransaction`, `commitTransaction`,
  `rollbackTransaction`, `isTransactionActive`, plus
  `_allocateTagArray`/`_freeTagArray` (the first `Pointer<Pointer<Utf8>>`
  marshaling in this codebase).
* `lib/core/foundation/oep_api_types.dart` - `RepositoryStatistics`
  gained `toJson`/`fromJson` (previously had no serialization at all).
* `lib/knowledge/models/knowledge_candidate_type.dart` -
  `foundationCategory` (`ObjectCategory?`) getter, `null` for the six
  candidate types with no Foundation object type.
* `lib/knowledge/models/knowledge_candidate.dart`/`relationship_candidate.dart` -
  `committedObjectId`/`committedRelationshipId` + `committedTime` +
  `isCommitted`.
* `lib/knowledge/models/commit_plan.dart` (new) - `CommitPlan`,
  superseding `CommitPreview` (deleted).
* `lib/knowledge/models/commit_report.dart` (new) - `CommittedObjectRecord`,
  `CommittedRelationshipRecord`, `CommitReport` - stored, not derived
  (`FoundationServiceState.commitReports`, append-only, mirroring
  `ReviewDecision`).
* `lib/knowledge/services/commit_plan_service.dart` (new) -
  `CommitPlanService.computeCommitPlan`, pure, superseding
  `KnowledgeSessionService.computeCommitPreview` (removed).
* `lib/knowledge/services/commit_conversion_service.dart` (new) -
  `CommitConversionService.toObjectCreateArgs`/`toRelationshipCreateArgs`,
  pure - type mapping, notes-into-description merge, author fallback,
  provenance tags.
* `lib/knowledge/services/commit_transaction_service.dart` (new) -
  `CommitTransactionService.execute` - the only place this work
  package calls the Foundation Bridge for a commit: begin transaction,
  sequential object/relationship creates, commit-or-rollback.
* `lib/core/services/foundation_runtime_state.dart` - `commitPreview`
  replaced by `commitPlan` (derived) and `commitReports`/
  `latestCommitReport` (stored/derived).
* `lib/core/services/foundation_runtime_service.dart` - new
  `commitToFoundation()` method: validates the plan, calls
  `CommitTransactionService.execute`, marks committed candidates/
  relationships on success, always appends the resulting `CommitReport`.
* `lib/knowledge/workspaces/commit_preview_panel.dart` (rewritten,
  same file/class name) - real Commit Plan display, confirmation
  dialog before `commitToFoundation()`, opens the Commit Report dialog
  automatically once the attempt completes.
* `lib/knowledge/workspaces/commit_report_dialog.dart` (new) - full
  `CommitReport` display + "Export as JSON" via `file_selector`.
* `lib/knowledge/inspector/session_properties.dart` - Commit Plan and
  Last Commit Report summary sections.
* `lib/knowledge/review/knowledge_candidate_row.dart` - a "Committed"
  badge (cloud icon with a tooltip naming the Foundation object id)
  when `candidate.isCommitted`.
* `lib/knowledge/models/knowledge_session_record.dart` -
  `commitReports` field, backward-compatible default `[]`.

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: OCR and AI functionality
remain untouched, and no independent architectural decision was
introduced anywhere a genuine conflict existed (see Architectural
Blocker above and Architectural Observations below for the two
judgment calls that were made, both with a reasonable literal reading
available). `oep_object_update`/`delete` and
`oep_relationship_update`/`delete` (added by Foundation alongside
create in the same Work Package 014) are not wired into Studio - only
create was needed. The `oep_batch_create_objects`/
`oep_batch_create_relationships` convenience functions are not used -
see § Transaction Model in `docs/REPOSITORY_COMMIT.md`.

### Repository Structure Additions

```
lib/
  core/
    foundation/
      foundation_bridge.dart              Extended (create*/transaction methods)
      oep_api_bindings.dart               Extended (6 new bindings)
      oep_api_native_types.dart           Extended (6 new typedefs)
      oep_api_types.dart                  Extended (RepositoryStatistics JSON)
    services/
      foundation_runtime_service.dart     Extended (commitToFoundation())
      foundation_runtime_state.dart       Extended (commitPlan/commitReports)
  knowledge/
    models/
      commit_plan.dart                    New
      commit_report.dart                  New
      commit_preview.dart                 Deleted
      knowledge_candidate.dart            Extended (commit-tracking fields)
      knowledge_candidate_type.dart       Extended (foundationCategory)
      knowledge_session_record.dart       Extended (commitReports)
      relationship_candidate.dart         Extended (commit-tracking fields)
    services/
      commit_plan_service.dart            New
      commit_conversion_service.dart      New
      commit_transaction_service.dart     New
      knowledge_session_service.dart      Extended (computeCommitPreview removed)
    workspaces/
      commit_preview_panel.dart           Rewritten (real CommitPlan)
      commit_report_dialog.dart           New
    inspector/
      session_properties.dart             Extended (Commit Plan/Report sections)
    review/
      knowledge_candidate_row.dart        Extended (Committed badge)
native/
  foundation_bridge/
    oep_foundation_bridge.def             Extended (6 new exports)
docs/
  REPOSITORY_COMMIT.md                    New
```

### Flutter Package Decisions

**No new Flutter package.** The Commit Report's "Export as JSON" reuses
`package:file_selector` (already a dependency since Work Package 002),
confirming its exact `getSaveLocation()`/`FileSaveLocation.path` shape
by reading the installed package source directly. Everything else this
work package added is pure Dart logic or native FFI calls to this
project's own DLL, for which "prefer a mature, permissively-licensed
package" doesn't apply.

### Verification Results

* flutter analyze - no issues found.
* flutter test - 137/137 passing: all prior tests, plus two new test
  files (`commit_plan_service_test.dart` - 16 tests covering repository-
  open/name-mismatch errors, pending/rejected/unmapped-type/
  already-committed exclusion, name-collision warnings, relationship
  eligibility including previously-committed endpoints, `canCommit`;
  `commit_conversion_service_test.dart` - 11 tests covering type
  mapping, the `ArgumentError` for unmapped types, tag/provenance
  construction, author fallback, and every notes/description merge
  case).
* flutter build windows - succeeded, including a native rebuild against
  the updated `oep_foundation` sibling checkout (Foundation's own Work
  Package 014 commit) - `native/foundation_bridge/CMakeLists.txt`
  builds Foundation's modules fresh from the sibling checkout on every
  build, so no CMake changes were needed to pick up the new API.
* **Manual verification against a real Foundation repository.** A
  scratch repository (`wp012-scratch-repo`) was created via Foundation's
  own `oep init` CLI, confirmed empty via `oep status`. As in Work
  Packages 007-011, `computer-use` was confirmed unable to target the
  compiled `oep_studio.exe`. Per this work package's own pre-approved
  instructions, verification was performed with a temporary
  `integration_test` (`integration_test/repository_commit_wp012_test.dart`,
  added, run against the real compiled app via `flutter test ... -d
  windows` with `--dart-define`-supplied repository path/name, then
  deleted - `pubspec.yaml`'s `integration_test` dev dependency reverted
  and `pubspec.lock` regenerated), opening the repository directly
  through `FoundationRuntimeNotifier.openRepository` (bypassing the
  native folder-picker dialog, the same precedent Work Package 006
  established for this exact dialog's unreliability in this
  environment).

  The test drove: create a session targeting the scratch repository,
  author two Component candidates, accept both, author a Relationship
  Candidate connecting them, confirm the Commit Summary panel showed 2
  New Objects/1 New Relationship/0 Existing Objects, tap Commit, confirm
  the dialog, and commit. **The `integration_test` process itself
  stalled after the commit and was killed at each 5-minute timeout on
  two separate attempts, but both commits independently succeeded** -
  confirmed by directly reading the scratch repository's persisted JSON
  (`repository/objects/*.json`, `repository/relationships/*.json`,
  timestamps seconds apart, correct name/type/author/provenance tags)
  and independently cross-checked against Foundation's own CLI
  (`oep object list --repository <path>`/`oep relationship list
  --repository <path>`), which matched exactly, including the
  relationships' resolved source/target object ids (proving a
  relationship between two objects created in the *same* commit
  correctly used the first object's freshly-assigned id as the second's
  endpoint - the specific capability that ruled out the batch mutation
  functions in favor of explicit transaction primitives). See
  `docs/REPOSITORY_COMMIT.md` § Architectural Observations for the full
  account of the test-harness stall, which is assessed as an
  `integration_test`/Windows reporting reliability issue in this
  environment, not a Studio defect, given the ground-truth confirmation
  from two independent sources.

### Architectural Observations

See `docs/REPOSITORY_COMMIT.md` § Architectural Observations for the
full account - summarized here:

* **The `KnowledgeCandidateType` → `ObjectCategory` mapping gap
  (flagged in Work Packages 008 and 010, never load-bearing until now)
  became load-bearing this work package**, since real Commit needs a
  real answer for every candidate. Resolved with a nullable
  `foundationCategory` getter and an explicit Commit Plan exclusion +
  warning for the six unmapped types, rather than modifying Foundation
  (forbidden) or inventing a lossy substitute mapping.
* **Notes preservation via description-merge** - Foundation's
  Engineering Object model has no field distinct from `description`;
  notes are appended (`"Notes: ..."`) rather than dropped, lossless
  within Foundation's existing fields but not a distinct field.
* **`buildDuplicate` carries commit-tracking fields over unchanged** -
  a deliberate judgment call (the underlying Foundation object already
  exists, so a duplicated session's committed candidates should still
  read as committed), not an oversight.
* **Explicit transaction primitives over the batch mutation
  functions** - the batch functions can't interleave object-then-
  relationship creation while resolving a same-commit object's
  freshly-assigned id as a relationship endpoint; explicit
  begin/sequential-creates/commit-or-rollback gives full control and
  directly matches "Repository Commit shall execute as one logical
  transaction" as its own task.

None of the observations above blocked implementation - each had a
reasonable, literal reading available (extend a nullable getter rather
than Foundation's fixed enum; append rather than drop notes; carry a
field through unchanged like every other field already does; choose
explicit API calls over a convenience function that can't do the job)
and none constituted the kind of genuine, irreconcilable conflict this
work package's instructions say to stop for - unlike the Public C API's
total absence of mutation capability at the start of this work package,
which was exactly that kind of conflict and was reported as a blocker
rather than worked around.

---

## Work Package 013 — Knowledge Studio (Engineering OCR Pipeline)

Status: Implemented

Tasks:

* STUDIO-TASK-000034 — OCR Pipeline — Complete
* STUDIO-TASK-000035 — OCR Layer Viewer — Complete
* STUDIO-TASK-000036 — Searchable Documents — Complete
* STUDIO-TASK-000037 — OCR Session Cache — Complete

### What Exists

Continues the Work Package 007-012 `lib/knowledge/` module - OCR
augments Source Material only, exactly like Evidence Regions/Page
Selections before it: Studio-only, never Foundation, never a
Knowledge Candidate. Full detail in `docs/OCR_PIPELINE.md`.

* `lib/knowledge/models/ocr_bounding_box.dart`, `ocr_word.dart`,
  `ocr_page_result.dart`, `ocr_processing_status.dart`,
  `ocr_search_match.dart`, `ocr_processing_exception.dart` (all new) -
  the OCR data model: text/confidence/bounding box/reading order per
  word, a page result with a content-hash fingerprint and engine
  version, per-source processing status, a search match.
* `lib/knowledge/services/tesseract_tsv_parser.dart` (new, pure) -
  parses Tesseract's `tsv` CLI output format into `OcrWord`s; unit
  tested against a real captured Tesseract 5.4.0 sample.
* `lib/knowledge/services/tesseract_ocr_engine.dart` (new) - the only
  place Studio invokes the external `tesseract` process; locates the
  installed engine, exposes `isAvailable()`/`engineVersion()`/
  `recognizePage()`.
* `lib/knowledge/services/ocr_cache_service.dart` (new) - SHA-256
  content fingerprinting and cache-validity/pages-needing-processing
  logic (pure, given an already-computed fingerprint).
* `lib/knowledge/services/ocr_pipeline_service.dart` (new) - orchestrates
  per-page (re)processing: renders PDF pages to PNG via `pdfrx` +
  `dart:ui` pixel-to-PNG encoding, calls the OCR engine per page,
  merges fresh results with still-valid cached ones.
* `lib/knowledge/services/ocr_search_service.dart` (new, pure) - Find/
  Find Next matching, case-insensitive, line-scoped.
* `lib/knowledge/models/knowledge_session_record.dart` - extended with
  `ocrPageResults`, backward-compatible default `[]`.
* `lib/knowledge/services/knowledge_session_service.dart` -
  `buildDuplicate` carries `ocrPageResults` over unchanged (same
  content-hash-survives-file-copy reasoning as Work Package 012's
  commit-tracking fields).
* `lib/knowledge/models/source_material_type.dart` - `tif`/`tiff`
  extensions added to `SourceMaterialType.image` (OCR's own "Supported:
  PDF, PNG, JPG, TIFF" list).
* `lib/core/services/foundation_runtime_state.dart` - `ocrPageResults`
  (persisted), `ocrProcessingStatus`/`ocrOverlayVisible`/`ocrErrorMessage`
  (ephemeral), plus `ocrResultsForSource`/`ocrSuccessfulPageCountFor`/
  `ocrAverageConfidenceFor` derived getters.
* `lib/core/services/foundation_runtime_service.dart` - `runOcrForSource`
  (the only method that calls `OcrPipelineService`), `toggleOcrOverlay`,
  `clearOcrErrorMessage`; `ocrPageResults` wired through
  create/close/open/archive/persist/duplicate, and cascaded on
  `removeSourceMaterial` (a removed source's OCR results are dropped
  too, same pattern as Evidence Regions/Page Selections).
* `lib/knowledge/workspaces/ocr_layer_viewer_dialog.dart` (new) - the
  OCR Layer Viewer: original page + toggleable word-box overlay +
  confidence heat map, PDF via a second `pdfrx.PdfViewer` instance with
  `pageOverlaysBuilder`, images via `InteractiveViewer`/`Stack`, plus a
  Find/Find Next search bar. Triggers `runOcrForSource` on open every
  time (its own cache check makes repeat opens near-instant when
  nothing changed).
* `lib/knowledge/workspaces/pdf_source_viewer.dart` /
  `source_viewer_panel.dart` - a new "OCR Layer Viewer" toolbar entry
  point, for PDF and image sources respectively.
* `lib/knowledge/inspector/source_material_properties.dart` - a new OCR
  section (OCR Status, Pages OCR'd, Confidence, OCR Engine).
* `pubspec.yaml` - `crypto` added as a direct dependency (SHA-256
  fingerprinting).

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: no AI, no automatic
Knowledge Candidate generation, no Repository Commit changes. OCR
result editing does not exist ("No editing yet" - STUDIO-TASK-000035's
own text). `oep_foundation`/the Public C API are untouched.

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      ocr_bounding_box.dart                New
      ocr_word.dart                        New
      ocr_page_result.dart                 New
      ocr_processing_status.dart           New
      ocr_processing_exception.dart        New
      ocr_search_match.dart                New
      knowledge_session_record.dart        Extended (ocrPageResults)
      source_material_type.dart            Extended (tif/tiff)
    services/
      tesseract_tsv_parser.dart            New
      tesseract_ocr_engine.dart            New
      ocr_cache_service.dart               New
      ocr_pipeline_service.dart            New
      ocr_search_service.dart              New
      knowledge_session_service.dart       Extended (buildDuplicate)
    workspaces/
      ocr_layer_viewer_dialog.dart         New
      pdf_source_viewer.dart               Extended (OCR toolbar button)
      source_viewer_panel.dart             Extended (OCR toolbar button)
    inspector/
      source_material_properties.dart      Extended (OCR section)
  core/
    services/
      foundation_runtime_state.dart        Extended (OCR state + getters)
      foundation_runtime_service.dart      Extended (runOcrForSource etc.)
  shared/
    widgets/
      property_inspector_panel.dart        Extended (OCR params wired)
docs/
  OCR_PIPELINE.md                          New
```

### Package Decisions

**One new dependency: `crypto` (Dart-team-maintained, BSD-3, no native
code)** for `OcrCacheService`'s SHA-256 fingerprinting — already a
transitive dependency via `pdfrx`, promoted to direct since it's used
directly.

**OCR engine: Tesseract, invoked as an external process** — not a
Flutter package. Three-plus alternatives compared
(`flutter_ocr_native`, `flusseract`, `tesseract_ocr`, cloud OCR APIs),
each rejected for a documented reason (an ID-scanning SDK with content-
filtering behavior; a two-year-stale wrapper with unconfirmed
structured output; no Windows desktop support at all; violates local/
offline processing). See `docs/OCR_PIPELINE.md` § Package Selection
Rationale for the full comparison and rationale. No Flutter package
for the OCR Layer Viewer or search UI either - built on `pdfrx`
(already a dependency) and Flutter framework widgets
(`InteractiveViewer`/`Stack`/`Positioned`).

### Verification Results

* flutter analyze - no issues found.
* flutter test - 160/160 passing: all prior tests, plus three new test
  files (`tesseract_tsv_parser_test.dart` - 10 tests including a real
  captured Tesseract 5.4.0 TSV sample and a CRLF-line-ending regression
  test; `ocr_cache_service_test.dart` - 7 tests covering fingerprint
  matching/mismatch, previously-failed-page non-permanence, and pages-
  needing-processing; `ocr_search_service_test.dart` - 6 tests covering
  single-word/multi-word/cross-line/cross-page/no-match search).
* flutter build windows - succeeded.
* **Manual verification against real engineering documents.** A
  synthetic-but-realistic 3-page PDF service manual (torque
  specification table, a numbered replacement procedure with a
  WARNING line, a parts list with real part-number formatting) and a
  PNG/TIFF/JPG specification sheet were generated by a one-off Python
  (`reportlab`)/PowerShell (`System.Drawing`) script, not committed -
  mirroring Work Packages 009/010's own fixture precedent. Tesseract
  OCR (v5.4.0.20240606) was installed via `winget` with the user's
  explicit permission after research showed it was the only suitable
  engine (see `docs/OCR_PIPELINE.md` § Package Selection Rationale);
  the CLI was run directly against all three image formats first to
  establish ground truth before any Studio code touched them.

  As in Work Packages 007-012, `computer-use` was confirmed unable to
  target the compiled `oep_studio.exe`. Per this work package's own
  pre-approved instructions, verification was performed with a
  temporary `integration_test` (added, run against the real compiled
  app via `flutter test ... -d windows` with `--dart-define`-supplied
  fixture paths, then deleted - `pubspec.yaml`'s `integration_test` dev
  dependency reverted and `pubspec.lock` regenerated), attaching all
  three fixtures directly through `FoundationRuntimeNotifier.attachSourceMaterial`
  (bypassing the native file picker, this project's established
  precedent for this exact dialog's unreliability in this
  environment).

  The test drove: create a session, attach the PDF/PNG/TIFF fixtures,
  open the OCR Layer Viewer for the PDF (waiting for real OCR across
  all 3 rendered pages), search for text appearing only in page 2's
  procedure steps and confirm a real match, Find Next, close and
  reopen the dialog to confirm the cached result was reused (no
  "Running OCR..." spinner the second time), then repeat OCR + search
  for the PNG and TIFF sources, and finally independently confirm via
  the Connection Manager that every source had real, non-empty,
  successful `OcrPageResult`s. **Two real bugs were found and fixed
  during this pass**, both described in full in
  `docs/OCR_PIPELINE.md` § Architectural Observations:
  1. `TesseractTsvParser` read the page-level row's `width`/`height`
     from the wrong TSV columns (left/top instead of width/height),
     producing a `0x0` image size for every page - caught by the unit
     tests before manual verification even began (a genuine test-first
     catch, not a manual-verification catch).
  2. `TesseractTsvParser` split TSV output on `'\n'` only; a real
     Windows `tesseract` install emits `\r\n`, leaving a trailing `'\r'`
     on every word's text and silently breaking exact-substring search
     ("oil\r filter" is not a substring of "oil filter"). This one was
     *not* caught by the hand-written-fixture unit tests - only surfaced
     once a real, `tesseract`-generated image was searched through the
     actual running application, exactly the class of bug "manual
     verification against real engineering documents" exists to catch.
     Fixed, with a regression test added reproducing the exact CRLF
     scenario.

  Two additional test-script-only issues were fixed along the way (not
  Studio defects): a source lookup by pre-copy file path instead of
  `originalFileName` (`attachSourceMaterial` copies the file, changing
  its path), and an off-screen `tester.tap` on the OCR toolbar button
  inside a horizontally-scrollable toolbar (fixed with
  `tester.ensureVisible` before tapping) - both are recorded here since
  a future verification session hitting the same finder patterns should
  not have to re-diagnose them from scratch.

### Architectural Observations

See `docs/OCR_PIPELINE.md` § Architectural Observations for the full
account - summarized here:

* **Tesseract is the first external, system-installed (not bundled)
  native dependency in this project** - every prior native dependency
  builds or bundles automatically via `flutter build windows`.
  `TesseractOcrEngine.isAvailable()` fails clearly, never silently,
  when it's missing.
* **TIFF preview is a genuine, narrow gap**: OCR supports TIFF (via
  Tesseract's own `libtiff`), but Flutter's built-in image codecs
  cannot decode it for on-screen preview. Resolved with graceful
  degradation (a placeholder canvas, correctly sized, with a fully
  functional overlay/search on top) rather than a new image-decoding
  dependency, which would have been scope creep beyond this work
  package's actual OCR tasks.
* **Search is deliberately line-scoped**, matching how printed
  engineering text is actually laid out (a torque-spec table row, a
  parts-list line), not a limitation discovered by accident.
* **The `flutter_ocr_native` package's real feature surface (an ID/KYC
  document-scanning SDK with content-filtering behavior) was discovered
  only through direct inspection of its actual API**, not its
  marketing description ("actively maintained... structured OCR
  results") - a reminder that "compare at least three alternatives"
  means reading each one's real surface, not trusting a search-engine
  summary of a package's own README.

None of the observations above blocked implementation - each had a
reasonable literal reading available (fail clearly rather than bundle
the unbundlable; degrade gracefully rather than add a new dependency
for a narrow preview gap; scope search to what a human would read as
one phrase) and none constituted the kind of genuine, irreconcilable
architectural conflict this work package's instructions say to stop
for.

## Work Package 014 — Knowledge Studio (Engineering Entity Extraction)

Status: Implemented

Tasks:

* STUDIO-TASK-000038 — Entity Extraction Engine — Complete
* STUDIO-TASK-000039 — Entity Review Workspace — Complete
* STUDIO-TASK-000040 — Pattern Library — Complete
* STUDIO-TASK-000041 — Entity Validation — Complete

### What Exists

Continues the Work Package 007-013 `lib/knowledge/` module - Engineering
Entities are Workspace artifacts extracted from OCR evidence, one layer
above OCR text (SDD-015 Layer 2), never a Knowledge Candidate until
explicit engineer acceptance. Full detail in
`docs/ENGINEERING_ENTITY_EXTRACTION.md`.

* `lib/knowledge/models/engineering_entity_type.dart` (new) - 14-value
  enum (Torque/Voltage/Resistance/Pressure/Temperature/Dimension/
  Fastener Size/Part Number/Tool Reference/Fluid Specification/Fuse
  Rating/Connector Identifier/Wire Color/Wire Gauge), each carrying a
  label, icon, and default `KnowledgeCandidateType`.
* `lib/knowledge/models/engineering_entity_status.dart` (new) -
  `pending`/`accepted`/`ignored`, deliberately distinct vocabulary from
  `KnowledgeCandidateStatus`'s `pending`/`accepted`/`rejected`.
* `lib/knowledge/models/engineering_entity.dart` (new) - the entity
  model: id/type/matched pattern id/extracted text/normalized value/
  source id/page/bounding box/confidence/character range/source
  fingerprint/extracted time/status/created-candidate id.
* `lib/knowledge/models/engineering_pattern.dart` (new) - a pure data
  class (id/type/label/regex/normalize function), no UI dependency.
* `lib/knowledge/models/entity_validation_result.dart` (new) - reuses
  `ValidationSeverity` from `candidate_validation_result.dart`.
* `lib/knowledge/services/engineering_pattern_library.dart` (new) - the
  static, data-driven pattern list; 17 patterns covering all 14 entity
  types.
* `lib/knowledge/services/engineering_entity_extraction_service.dart`
  (new, pure) - line-scoped regex matching over OCR text, with
  page-level cache reuse (preserves accept/ignore status) mirroring
  `OcrCacheService`'s own fingerprint-reuse contract.
* `lib/knowledge/services/entity_validation_service.dart` (new, pure) -
  duplicate/malformed-unit/impossible-value/low-confidence detection.
* `lib/knowledge/models/knowledge_session_record.dart` - extended with
  `engineeringEntities`, backward-compatible default `[]`.
* `lib/knowledge/services/knowledge_session_service.dart` -
  `buildDuplicate` carries `engineeringEntities` over unchanged (same
  content-hash-survives-file-copy reasoning as `ocrPageResults`).
* `lib/core/services/foundation_runtime_state.dart` - `engineeringEntities`
  (persisted), `selectedEntity` (the ninth mutually-exclusive selection
  field - added to all 7 pre-existing `select*` methods), plus
  `engineeringEntitiesForSource`/`entityValidation`/`patternFor` derived
  getters.
* `lib/core/services/foundation_runtime_service.dart` -
  `extractEntitiesForSource` (throws if no OCR evidence exists yet),
  `selectEntity`/`clearEntitySelection`, `acceptEntity` (creates a
  Knowledge Candidate via the existing `addKnowledgeCandidate`),
  `ignoreEntity`; `engineeringEntities` wired through
  create/close/open/archive/persist/duplicate, and cascaded on
  `removeSourceMaterial`.
* `lib/knowledge/workspaces/entity_review_workspace_dialog.dart` (new) -
  the Entity Review Workspace: type/status filter, sort, search,
  per-row Accept/Ignore/Navigate-to-Source.
* `lib/knowledge/workspaces/ocr_layer_viewer_dialog.dart` - a new
  "Extract Entities" toolbar button; extended with an `initialPage`
  parameter and a `selectedEntity`-watching auto-navigate effect for
  "Navigate to Source."
* `lib/knowledge/inspector/engineering_entity_properties.dart` (new) -
  the Property Inspector's Engineering Entity mode (Entity fields,
  Pattern Match section, Source Context section, Validation section).
* `lib/shared/widgets/property_inspector_panel.dart` - the
  mutually-exclusive selection switch extended from 8 to 9 cases.

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: no AI, no LLMs, no
machine learning, no automatic engineering interpretation beyond
deterministic pattern matching. Pattern editing/authoring through the
UI does not exist - the pattern library is a static, code-defined list
("Patterns shall be configurable" is read as an internal/data-driven
design property, not a UI requirement this work package's own task list
names). `oep_foundation`/the Public C API are untouched.

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      engineering_entity_type.dart          New
      engineering_entity_status.dart        New
      engineering_entity.dart               New
      engineering_pattern.dart              New
      entity_validation_result.dart         New
      knowledge_session_record.dart         Extended (engineeringEntities)
    services/
      engineering_pattern_library.dart      New
      engineering_entity_extraction_service.dart  New
      entity_validation_service.dart        New
      knowledge_session_service.dart        Extended (buildDuplicate)
    workspaces/
      entity_review_workspace_dialog.dart   New
      ocr_layer_viewer_dialog.dart           Extended (Extract Entities button, initialPage, navigate effect)
    inspector/
      engineering_entity_properties.dart    New
  core/
    services/
      foundation_runtime_state.dart         Extended (entity state + getters)
      foundation_runtime_service.dart       Extended (extractEntitiesForSource etc.)
  shared/
    widgets/
      property_inspector_panel.dart         Extended (Engineering Entity mode)
docs/
  ENGINEERING_ENTITY_EXTRACTION.md          New
```

### Package Decisions

**No new dependencies.** Pattern matching uses Dart's built-in `RegExp`;
everything else builds on models and services already present from
Work Package 013 (`OcrPageResult`/`OcrWord`) and earlier
(`ValidationSeverity`, `addKnowledgeCandidate`).

### Verification Results

* flutter analyze - no issues found.
* flutter test - 194/194 passing: all prior tests, plus three new test
  files (`engineering_pattern_library_test.dart` - pattern coverage for
  all 14 types plus a determinism check; `engineering_entity_extraction_service_test.dart` -
  line-spanning extraction, confidence/bounding-box averaging math,
  cache-reuse-preserves-status, stale-fingerprint-drops-and-refreshes,
  failed-OCR-page-produces-nothing, cross-source isolation;
  `entity_validation_service_test.dart` - duplicate detection, per-type
  impossible-value ranges, malformed/empty values, low-confidence
  flagging).
* flutter build windows - succeeded.
* **Manual verification against real engineering documents.** A
  synthetic-but-realistic 3-page PDF service manual (torque
  specifications, a fastener size, a part number, an electrical
  reference section, an oil-change procedure) was generated with
  `reportlab`, mirroring Work Package 013's own fixture precedent (not
  committed). Ground truth was established by rendering the PDF to PNG
  (`pymupdf`) and running the installed `tesseract 5.4.0.20240606` CLI
  directly against each page before any Studio code touched them,
  confirming clean OCR text (with one genuine, real-world OCR misread
  noted below).

  As in Work Packages 007-013, `computer-use` was confirmed unable to
  target the compiled `oep_studio.exe`. Per this work package's own
  pre-approved instructions, verification was performed with a
  temporary `integration_test` (added, run against the real compiled
  app via `flutter test ... -d windows`, then deleted - `pubspec.yaml`'s
  `integration_test` dev dependency reverted and `pubspec.lock`
  regenerated), attaching the fixture directly through
  `FoundationRuntimeNotifier.attachSourceMaterial` (bypassing the native
  file picker, this project's established precedent).

  The test drove: create a session, attach the PDF fixture, open the
  OCR Layer Viewer (real Tesseract OCR across all 3 pages), open the
  Entity Review Workspace (real extraction against the real OCR text),
  confirm real pattern matches (`"24 Nm"`, `"90915-YZZD4"`, `"12 V"`,
  `"35 ft-lb"`), confirm a genuine cross-page duplicate (`"35 ft-lb"`
  appears verbatim on both page 1 and page 3 of the fixture) was
  correctly flagged by the Validation model, filter by type, search by
  text, Accept an entity (confirming a Knowledge Candidate was created
  with the expected type/name), Ignore an entity (confirming OCR
  evidence was untouched), Navigate to Source (confirming the OCR
  Layer Viewer jumped to the entity's page), and finally close and
  reopen the session (confirming accept/ignore status and the created
  Candidate link both survive a full session reload).

  **Issues found and fixed during this pass:**
  1. A real regex bug in the Resistance pattern, caught by this work
     package's own unit tests before manual verification began (not a
     manual-verification catch): the pattern ended in `\b` immediately
     after the `Ω` symbol, which is not an ASCII word character, so
     `\b` never matched at end-of-string/before whitespace - the
     pattern silently never matched `"4.7kΩ"` at all. Fixed by
     replacing the trailing `\b` with `(?!\w)`. See
     `docs/ENGINEERING_ENTITY_EXTRACTION.md` § Pattern Library.
  2. Two integration-test-script-only issues (not Studio defects): the
     "OCR Layer Viewer" toolbar button was tapped before `pdfrx`'s
     asynchronous native rendering had actually mounted it, and two
     per-row action buttons (Ignore, Navigate to Source) were targeted
     by list index rather than by row content - `ListView.separated`
     only builds on-screen items, so an index-based finder silently
     mis-targets. Fixed by polling for the toolbar's presence before
     tapping, and by targeting each row's own `InkWell` ancestor by its
     displayed normalized value instead of an index.
  3. A genuine, non-synthetic OCR-noise finding, not a bug: the same
     installed Tesseract engine misread "4.7kOhms" as "4.7kKOhms" (an
     inserted `K`) on the real rendered fixture page - the Resistance
     pattern correctly did not match this garbled text, since no
     pattern exists (or should exist) for a `"kK"` unit prefix. Recorded
     as the expected, correct behavior of "entity extraction operates
     only on OCR evidence," not something to special-case around.

### Architectural Observations

See `docs/ENGINEERING_ENTITY_EXTRACTION.md` § Architectural Observations
for the full account - summarized here:

* **"Initial Pattern Categories" (11) vs. "Detect" (14) - resolved as a
  non-exhaustive-subset reading, not a hard cap.** All 14 entity types
  named by STUDIO-TASK-000038's "Detect" list are implemented.
* **`defaultCandidateType` mapping is grounded in SDD-015's own
  Specification/Component Model text**, not invented independently.
* **A real regex bug** (the Resistance pattern's `\b`-after-`Ω` issue)
  was caught by unit tests, not manual verification - the inverse of
  Work Package 013's CRLF finding, reinforcing that both verification
  paths catch different classes of bug.
* **A real OCR-noise finding** (a genuine Tesseract misread preventing
  one pattern match) was observed during manual verification and
  correctly did not produce a false match - recorded as an inherent,
  expected limitation of pattern-matching-on-OCR-output, not resolved
  by adding fuzzy matching, which would trade away determinism for a
  narrow accuracy gain.

None of the observations above blocked implementation - each had a
reasonable literal reading available and none constituted the kind of
genuine, irreconcilable architectural conflict this work package's
instructions say to stop for.

## Work Package 015 — Knowledge Studio (Engineering Context Analysis)

Status: Implemented

Tasks:

* STUDIO-TASK-000042 — Context Detection Engine — Complete
* STUDIO-TASK-000043 — Context Explorer — Complete
* STUDIO-TASK-000044 — Context Validation — Complete
* STUDIO-TASK-000045 — Context Navigation — Complete

### What Exists

Continues the Work Package 007-014 `lib/knowledge/` module - Engineering
Contexts are Workspace artifacts that group OCR evidence and extracted
entities using deterministic document structure only, one layer above
Engineering Entities, never a Knowledge Candidate or Foundation Object.
Full detail in `docs/ENGINEERING_CONTEXT.md`.

* `lib/knowledge/models/engineering_context_type.dart` (new) - 12-value
  enum (Procedure/Component/Connector/Circuit/Wiring Section/Torque
  Table/Specification Table/Warning/Note/Figure/Diagram/Parts List).
* `lib/knowledge/models/engineering_context_status.dart` (new) -
  `pending`/`accepted`/`ignored`, the same vocabulary
  `EngineeringEntityStatus` established (never
  `KnowledgeCandidateStatus`'s - a Context is never a Candidate).
* `lib/knowledge/models/engineering_context.dart` (new) - the context
  model: id/type/title/source id/page range/bounding region/child
  entity ids/confidence/parent context id/source fingerprint/detected
  time/status.
* `lib/knowledge/models/context_validation_result.dart` (new) - reuses
  `ValidationSeverity`.
* `lib/knowledge/models/context_statistics.dart` (new) - child entity
  count/average child confidence/count by entity type, for the
  Property Inspector's "Context Statistics."
* `lib/knowledge/services/context_detection_service.dart` (new, pure) -
  heading/callout keyword + relative-line-height detection, major/minor
  tiering that produces parent/child nesting by position (not page
  number alone), whole-source fingerprint cache reuse.
* `lib/knowledge/services/context_validation_service.dart` (new, pure) -
  empty/duplicate/overlapping-context detection, invalid-hierarchy
  detection (missing parent, cross-source parent, out-of-range child,
  cycle), and a separate orphaned-entity-id computation.
* `lib/knowledge/models/knowledge_session_record.dart` - extended with
  `engineeringContexts`, backward-compatible default `[]`.
* `lib/knowledge/services/knowledge_session_service.dart` -
  `buildDuplicate` carries `engineeringContexts` over unchanged (same
  content-hash-survives-file-copy reasoning as `engineeringEntities`).
* `lib/core/services/foundation_runtime_state.dart` - `engineeringContexts`
  (persisted), `selectedContext` (the tenth mutually-exclusive
  selection field - added to all 8 pre-existing `select*` methods plus
  `selectEntity`), `contextTypeFilter` (ephemeral, Connection-Manager-
  owned per this work package's own explicit "Context Filter"), plus
  `engineeringContextsForSource`/`contextValidation`/
  `orphanedEntityIdsFor`/`childEntitiesFor`/`parentContextOf`/
  `contextStatisticsFor` derived getters.
* `lib/core/services/foundation_runtime_service.dart` -
  `detectContextsForSource` (does not require prior entity extraction,
  unlike entity extraction's own OCR-only precondition),
  `selectContext`/`clearContextSelection`, `setContextTypeFilter`,
  `acceptContext`/`ignoreContext` (status-only, create nothing),
  `splitContext`, `mergeContexts`, `navigateToAdjacentContext`;
  `engineeringContexts` wired through
  create/close/open/archive/persist/duplicate, and cascaded on
  `removeSourceMaterial`.
* `lib/knowledge/workspaces/context_explorer_dialog.dart` (new) - the
  Context Explorer: expandable tree (major contexts reveal nested
  minor children), type filter (Connection-Manager-owned)/status
  filter/sort/search (local), per-row Accept/Ignore/Split/Merge/
  Navigate-to-Source, a two-tap Merge flow.
* `lib/knowledge/workspaces/ocr_layer_viewer_dialog.dart` - a new
  "Context Explorer" toolbar button, "Previous Context"/"Next Context"
  navigation buttons, and a `selectedContext`-watching auto-navigate
  effect mirroring the existing entity one.
* `lib/knowledge/workspaces/pdf_source_viewer.dart` - a
  `selectedContext`-watching auto-navigate effect (Work Package 015's
  own explicit "Selecting a context updates: Source Viewer" - the first
  work package to require this specific viewer to react to a
  Workspace-artifact selection made elsewhere).
* `lib/knowledge/workspaces/entity_review_workspace_dialog.dart` - a
  local context-entity filter (with a dismissible banner) applied when
  a context belonging to the same source becomes selected elsewhere
  ("Selecting a context updates: ... Entity Viewer").
* `lib/knowledge/inspector/engineering_context_properties.dart` (new) -
  the Property Inspector's Engineering Context mode (Context fields,
  Context Statistics, Parent Context, Child Entities, Validation).
* `lib/shared/widgets/property_inspector_panel.dart` - the
  mutually-exclusive selection switch extended from 9 to 10 cases.

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: no AI, no LLMs, no
machine learning, no Repository changes, no engineering-meaning
inference beyond deterministic document organization. There is no UI
for editing detection keywords or thresholds - the heading/callout
keyword tables and the height-ratio/confidence-multiplier constants are
static, code-defined values (the same "no AI, deterministic and
reproducible" reasoning that kept Work Package 014's pattern library
code-defined rather than user-editable). `oep_foundation`/the Public C
API are untouched.

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      engineering_context_type.dart          New
      engineering_context_status.dart        New
      engineering_context.dart               New
      context_validation_result.dart         New
      context_statistics.dart                New
      knowledge_session_record.dart          Extended (engineeringContexts)
    services/
      context_detection_service.dart         New
      context_validation_service.dart        New
      knowledge_session_service.dart         Extended (buildDuplicate)
    workspaces/
      context_explorer_dialog.dart           New
      ocr_layer_viewer_dialog.dart            Extended (Context Explorer button, Prev/Next Context, navigate effect)
      pdf_source_viewer.dart                 Extended (navigate effect)
      entity_review_workspace_dialog.dart    Extended (context-entity filter)
    inspector/
      engineering_context_properties.dart    New
  core/
    services/
      foundation_runtime_state.dart          Extended (context state + getters)
      foundation_runtime_service.dart        Extended (detectContextsForSource etc.)
  shared/
    widgets/
      property_inspector_panel.dart          Extended (Engineering Context mode)
docs/
  ENGINEERING_CONTEXT.md                     New
```

### Package Decisions

**No new dependencies.** Heading/callout detection uses Dart's built-in
`RegExp` and simple arithmetic (relative line height); the whole-source
combined fingerprint reuses `package:crypto`'s SHA-256, already a
dependency since Work Package 013.

### Verification Results

* flutter analyze - no issues found.
* flutter test - 214/214 passing: all prior tests, plus two new test
  files (`context_detection_service_test.dart` - 9 tests covering
  heading/keyword-priority detection, callout detection independent of
  line height, major/minor parent nesting (including the position-not-
  page-number containment fix), multi-page page-range computation,
  whole-source cache reuse and invalidation, cross-source isolation;
  `context_validation_service_test.dart` - 11 tests covering
  empty/duplicate/overlapping-context detection, parent/child
  containment correctly *not* flagged as an overlap, invalid-hierarchy
  detection (missing parent, out-of-range child, a two-context cycle),
  and orphaned-entity computation).
* flutter build windows - succeeded.
* **Manual verification against real engineering documents.** A
  synthetic 2-page PDF service manual (a large "TORQUE SPECIFICATIONS"
  heading with a torque value and an inline "WARNING" callout, a large
  "PARTS LIST" heading with a part number and an inline "NOTE"
  callout) was generated with `reportlab`, mirroring Work Packages
  013/014's own fixture precedent (not committed). Ground truth was
  established by rendering to PNG (`pymupdf`) and running the real
  installed `tesseract 5.4.0.20240606` CLI's own `tsv` output directly,
  confirming a genuine, exploitable line-height difference between
  headings (~70px) and body text (~30-50px) in real OCR output, and
  confirming "WARNING" itself renders at ordinary body-text height -
  validating the core premise of the height-based heading heuristic and
  the keyword-only callout rule before any Studio code touched the
  fixture.

  As in Work Packages 007-014, `computer-use` was confirmed unable to
  target the compiled `oep_studio.exe`. Per this work package's own
  pre-approved instructions, verification was performed with a
  temporary `integration_test` (added, run against the real compiled
  app via `flutter test ... -d windows`, then deleted - `pubspec.yaml`'s
  `integration_test` dev dependency reverted and `pubspec.lock`
  regenerated), attaching the fixture directly through
  `FoundationRuntimeNotifier.attachSourceMaterial`.

  The test drove: create a session, attach the fixture, run real OCR
  across both pages, extract real entities, open the Context Explorer
  (real detection against real OCR/entity data), confirm the two major
  contexts ("TORQUE SPECIFICATIONS", "PARTS LIST") and their real
  nested minor children (the Warning correctly parented under Torque,
  the Note correctly parented under Parts List - confirming real
  position-based containment, not just unit-tested containment), filter
  by type, Accept a context (confirming **no** Knowledge Candidate was
  created - the key architectural distinction from accepting an
  entity), Ignore a context (confirming OCR/entities were untouched),
  Merge the Warning and Note contexts via the two-tap flow (confirming
  the combined page range and `pending` reset), Navigate to Source
  (confirming the still-open OCR Layer Viewer *and* the background
  Source Viewer both jumped to the target page - real, simultaneous
  multi-viewer synchronization, not just asserted from code), Next/
  Previous Context cycling, and finally close and reopen the session
  (confirming accepted/ignored status and the merge both survive a full
  session reload).

  **A real bug was found and fixed during this pass, caught by unit
  tests before manual verification began** (not a manual-verification
  catch): the first parent-containment implementation compared only
  page *numbers*, which incorrectly parented a callout appearing
  *before* a major heading on the very same page, since page-number
  containment alone cannot distinguish "before" from "after" within one
  page. Fixed by comparing actual (page, line) position instead - see
  `docs/ENGINEERING_CONTEXT.md` § Architectural Observations.

### Architectural Observations

See `docs/ENGINEERING_CONTEXT.md` § Architectural Observations for the
full account - summarized here:

* **`parentContextId` is not literally named in "Context Output"'s own
  field list, yet the Property Inspector and Validation sections
  explicitly ask for "Parent Context" and "Invalid hierarchy."**
  Resolved by adding it - a direct implementation of what the same
  document already asks for elsewhere, not an invented feature; the
  major/minor tiering gives it real, purely-structural meaning.
* **"Navigate by" (6 types) vs. "Detect" (12 types) - resolved as a
  non-exhaustive illustrative subset**, the same reading Work Package
  014 gave its own "Initial Pattern Categories" vs. "Detect" tension.
* **A real position-vs-page-number bug** in parent-containment logic
  was caught by unit tests, not manual verification - the inverse of
  Work Package 014's own regex-bug finding, reinforcing that both
  verification paths continue to catch different classes of bug.
* **Real OCR confirmed the height-heuristic's core premise and the
  keyword-only callout design** during manual verification against a
  real rendered fixture, not merely assumed from the design's own
  reasoning.

None of the observations above blocked implementation - each had a
reasonable literal reading available and none constituted the kind of
genuine, irreconcilable architectural conflict this work package's
instructions say to stop for.

## Work Package 016 — Knowledge Studio (AI Provider Architecture)

Status: Implemented

Tasks:

* STUDIO-TASK-000046 — AI Provider Architecture — Complete
* STUDIO-TASK-000047 — Prompt Construction Service — Complete
* STUDIO-TASK-000048 — AI Review Infrastructure — Complete
* STUDIO-TASK-000049 — Mock AI Provider — Complete

### What Exists

Continues the Work Package 007-015 `lib/knowledge/` module - establishes
the complete, provider-independent AI infrastructure Knowledge Studio's
future AI-assisted authoring will run on, per this work package's own
explicit reauthored instructions: **no production AI provider
integration, no external AI service calls, no network traffic, no API
credentials.** The only concrete `AiProvider` is a deterministic,
in-process `MockAiProvider`. Full detail in
`docs/AI_PROVIDER_ARCHITECTURE.md`.

* `lib/knowledge/models/ai_model_info.dart`, `ai_request.dart`,
  `ai_response.dart`, `ai_conversation.dart` (all new, ephemeral, not
  persisted) - the provider-agnostic request/response/conversation
  model; a provider never sees a `SourceMaterial`/`EngineeringEntity`/
  `EngineeringContext` object directly, only these plain-text/plain-data
  types.
* `lib/knowledge/models/ai_suggestion_status.dart` (new) -
  `pending`/`accepted`/`edited`/`rejected`/`deferred`, its own fifth
  vocabulary distinct from `EngineeringEntityStatus`/
  `EngineeringContextStatus`.
* `lib/knowledge/models/ai_suggestion.dart` (new) - the persisted
  Workspace artifact: suggested type/name/description/confidence/
  reasoning/supporting evidence ids, provider/model metadata, a
  `sourceFingerprint` for cache reuse, edited-value fields, and a
  one-way-set `createdCandidateId`.
* `lib/knowledge/models/ai_analysis_exception.dart` (new) - a
  provider/parsing failure, distinct from `KnowledgeValidationException`.
* `lib/knowledge/services/ai_provider.dart` (new) - the `AiProvider`
  abstract interface: one method, `Future<AiResponse> complete(AiRequest)`.
* `lib/knowledge/services/ai_provider_registry.dart` (new) -
  `AiProviderRegistry`, seeded with only `MockAiProvider` in this work
  package.
* `lib/knowledge/services/mock_ai_provider.dart` (new) - the
  deterministic mock provider: one suggestion per referenced Engineering
  Context (or, absent contexts, per Engineering Entity), zero
  suggestions for zero evidence, zero network activity.
* `lib/knowledge/services/prompt_service.dart` (new, pure) - the *only*
  place prompt text is constructed, from OCR text/Engineering Entities/
  Engineering Contexts/existing Knowledge Candidates.
* `lib/knowledge/services/ai_suggestion_parser.dart` (new, pure) -
  strict parsing of a provider's raw response text into `AiSuggestion`s,
  rejecting malformed/incomplete responses rather than guessing.
* `lib/knowledge/services/ai_analysis_service.dart` (new) - orchestrates
  `PromptService` → `AiProvider` → `AiSuggestionParser`, with
  whole-source cache reuse (a combined OCR/entity/context fingerprint).
* `lib/knowledge/models/knowledge_session_record.dart` - extended with
  `aiSuggestions`, backward-compatible default `[]`.
* `lib/knowledge/services/knowledge_session_service.dart` -
  `buildDuplicate` carries `aiSuggestions` over unchanged.
* `lib/core/services/foundation_runtime_state.dart` - `aiSuggestions`
  (persisted), `selectedAiSuggestion` (the eleventh mutually-exclusive
  selection field - added to all 9 pre-existing `select*` methods plus
  `selectContext`), `currentAiProviderId`/`currentAiConversation`/
  `aiProcessingStatus` (ephemeral), plus `aiSuggestionsForSource`/
  `supportingEntitiesFor`/`supportingContextsFor` derived getters.
* `lib/core/services/foundation_runtime_service.dart` -
  `runAiAnalysisForSource` (does not require prior entity/context
  extraction), `selectAiSuggestion`/`clearAiSuggestionSelection`,
  `setCurrentAiProvider`, `acceptAiSuggestion` (creates a Knowledge
  Candidate - the only path from a Suggestion to a Candidate),
  `editAiSuggestion` (preserves the AI's original values alongside the
  correction), `rejectAiSuggestion`, `deferAiSuggestion`;
  `aiSuggestions` wired through create/close/open/archive/persist/
  duplicate, and cascaded on `removeSourceMaterial`.
* `lib/knowledge/workspaces/ai_review_workspace_dialog.dart` (new) -
  the AI Review Workspace: provider picker, "Run Analysis" button,
  status filter/sort/search, per-row Accept/Edit/Reject/Defer, a
  two-field Edit dialog.
* `lib/knowledge/workspaces/ocr_layer_viewer_dialog.dart` - a new
  "AI Suggestions" toolbar button.
* `lib/knowledge/inspector/ai_suggestion_properties.dart` (new) - the
  Property Inspector's AI Suggestion mode (Suggestion fields, AI
  Review section, Supporting Evidence, Provider Metadata, and - when
  available - the exact Prompt sent/received).
* `lib/shared/widgets/property_inspector_panel.dart` - the
  mutually-exclusive selection switch extended from 10 to 11 cases.
* `lib/knowledge/workspaces/knowledge_studio_page.dart` - the frozen
  7-panel layout's "AI Suggestions" panel now shows a real session-wide
  status summary (counts by review state) instead of the Work Package
  007-era "No AI implementation exists" placeholder text, which this
  work package makes literally inaccurate to leave unchanged.

### What Is Explicitly Not Implemented

Per this work package's explicit reauthored instructions: **no
production AI provider integration** (no OpenAI/Anthropic/Gemini/
Ollama/LM Studio/OpenRouter concrete implementation), no external AI
service calls, no network traffic, no API credentials. No automatic
Knowledge Candidate creation - Accept is always an explicit engineer
action. `oep_foundation`/the Public C API are untouched.

### Repository Structure Additions

```
lib/
  knowledge/
    models/
      ai_model_info.dart                    New
      ai_request.dart                       New
      ai_response.dart                       New
      ai_conversation.dart                   New
      ai_suggestion_status.dart              New
      ai_suggestion.dart                     New
      ai_analysis_exception.dart             New
      knowledge_session_record.dart          Extended (aiSuggestions)
    services/
      ai_provider.dart                       New
      ai_provider_registry.dart              New
      mock_ai_provider.dart                  New
      prompt_service.dart                    New
      ai_suggestion_parser.dart              New
      ai_analysis_service.dart               New
      knowledge_session_service.dart         Extended (buildDuplicate)
    workspaces/
      ai_review_workspace_dialog.dart        New
      ocr_layer_viewer_dialog.dart            Extended (AI Suggestions button)
      knowledge_studio_page.dart             Extended (real AI Suggestions summary panel)
    inspector/
      ai_suggestion_properties.dart          New
  core/
    services/
      foundation_runtime_state.dart          Extended (AI state + getters)
      foundation_runtime_service.dart        Extended (runAiAnalysisForSource etc.)
  shared/
    widgets/
      property_inspector_panel.dart          Extended (AI Suggestion mode)
docs/
  AI_PROVIDER_ARCHITECTURE.md                New
  design/
    SDD-022-AI_ARCHITECTURE.md              New (frozen architecture doc)
```

### Package Decisions

**No new dependencies.** `MockAiProvider` uses `dart:convert`'s
`jsonEncode`/`jsonDecode` only; the whole-source combined fingerprint
reuses `package:crypto`'s SHA-256, already a dependency since Work
Package 013. No HTTP client was added, since no provider in this work
package performs network I/O.

### Verification Results

* flutter analyze - no issues found.
* flutter test - 241/241 passing: all prior tests, plus four new test
  files (`prompt_service_test.dart` - 6 tests covering evidence
  referencing, prompt content, purity, and the "no fabricated content"
  behavior with zero evidence; `mock_ai_provider_test.dart` - 7 tests
  covering zero-network-activity, zero-suggestions-for-zero-evidence,
  one-suggestion-per-context/entity, field validity, determinism, and
  type variety; `ai_suggestion_parser_test.dart` - 10 tests covering a
  well-formed round trip and every malformed-response failure mode
  (non-JSON, wrong top-level shape, missing "suggestions", missing/
  invalid required fields, confidence clamping); `ai_analysis_service_test.dart` -
  4 tests covering end-to-end Mock analysis, whole-source cache reuse,
  re-analysis on changed context content, and cross-source isolation).
* flutter build windows - succeeded.
* **Manual verification using the mock provider only (no external AI,
  per this work package's own explicit instruction).** The Work Package
  015 fixture (a 2-page PDF with a Torque Specifications section and a
  Parts List section, each with an inline Warning/Note callout) was
  reused, since it already produces real Engineering Entities and
  Engineering Contexts to feed AI analysis.

  As in Work Packages 007-015, `computer-use` was confirmed unable to
  target the compiled `oep_studio.exe`. Per this work package's own
  pre-approved instructions, verification was performed with a
  temporary `integration_test` (added, run against the real compiled
  app via `flutter test ... -d windows`, then deleted - `pubspec.yaml`'s
  `integration_test` dev dependency reverted and `pubspec.lock`
  regenerated).

  The test drove: create a session, attach the fixture, run real OCR,
  extract real entities, detect real contexts, open the AI Review
  Workspace (confirming the provider picker defaults to `'mock'`), Run
  Analysis (confirming one real suggestion per detected context, and
  that the exact system/user prompt and the mock's real JSON response
  are both inspectable via `currentAiConversation` - "No hidden
  prompts"), Accept a suggestion (confirming a real Knowledge Candidate
  was created with the suggested name), Reject a suggestion (confirming
  it remains in the list, never deleted), Edit a suggestion (confirming
  the AI's own original suggested name survives unchanged alongside the
  engineer's correction), select a suggestion (confirming the Property
  Inspector's AI Suggestion mode renders), and finally close and reopen
  the session and re-run analysis against unchanged evidence (confirming
  accept/reject/edit status all survive both a session reload *and* a
  cache-hit re-analysis that correctly skipped calling the provider
  again).

  No issues were found during this pass - the architecture behaved
  exactly as designed on the first fully-corrected attempt at the test
  script itself (see script-only issues below, not Studio defects).

  Two integration-test-script-only issues were fixed along the way (not
  Studio defects, recorded here since a future verification session
  hitting the same finder patterns should not have to re-diagnose them
  from scratch): a row's own text was tapped before `ensureVisible`
  correctly repositioned it within the AI Review Workspace's own dialog
  bounds (fixed by tapping the row's `InkWell` ancestor, then - when
  that still occasionally mis-hit after the dialog's contents had
  scrolled - by selecting the suggestion via the same notifier method
  the row's own `onTap` calls, exercising the identical code path more
  robustly than a screen-coordinate-dependent tap).

### Architectural Observations

See `docs/AI_PROVIDER_ARCHITECTURE.md` § Architectural Observations for
the full account - summarized here:

* **No production AI provider is integrated, by explicit instruction** -
  the entire architecture is built and proven end to end using only
  `MockAiProvider`. A future work package integrating a real provider
  needs only to implement `AiProvider` and register it.
* **"Accept creates a Knowledge Candidate" is a judgment call**, grounded
  in SDD-022's own "Knowledge Candidate Suggestions" naming and this
  work package's own "no AI-generated" (i.e. not *automatic*) reading -
  STUDIO-TASK-000048 itself doesn't literally restate this, unlike the
  original pre-reauthored version of this work package.
* **The four-part confidence breakdown named in the original,
  pre-reauthored version of this work package was dropped from the
  reauthored task list** - `AiSuggestion` keeps a single `confidence`
  field, per SDD-022's own simpler "Confidence" output. Not
  reintroduced, since implementing a requirement a superseding revision
  removed would be scope creep, not fidelity to the spec.
* **`AiRequest`/`AiResponse`/`AiConversation` are ephemeral by design**,
  mirroring `CommitPlan`'s own precedent (Work Package 012) - a derived,
  in-memory-only object, never persisted, since everything SDD-022
  actually requires to be persisted is already captured on the
  resulting `AiSuggestion`s themselves.

None of the observations above blocked implementation - each had a
reasonable literal reading available and none constituted the kind of
genuine, irreconcilable architectural conflict this work package's
instructions say to stop for.

## Work Package 017 — Studio Settings Workspace

Status: Implemented

Tasks:

* STUDIO-TASK-000050 — Settings Workspace - Complete
* STUDIO-TASK-000051 — Settings Framework - Complete
* STUDIO-TASK-000052 — Core Settings Pages - Complete
* STUDIO-TASK-000053 — Configuration Storage - Complete
* STUDIO-TASK-000054 — Settings Search - Complete
* STUDIO-TASK-000055 — Provider Registration - Complete

### What Exists

A complete Settings Workspace per SDD-023, built as a new `lib/settings/`
module (parallel to `lib/knowledge/`, not nested inside it - Settings is
Studio-wide configuration, not a Knowledge Workspace concern). Full
detail in `docs/STUDIO_SETTINGS.md`.

* `lib/settings/models/` (new) - `UserConfiguration` (the versioned root
  User Configuration) and ten sub-models (`GeneralSettings`,
  `AppearanceSettings`, `WorkspaceSettings`, `RepositorySettings`,
  `KnowledgeStudioSettings`, `AiSettings`, `PluginSettings`,
  `UpdateSettings`, `DiagnosticsSettings`, `SecuritySettings`), fifteen
  small enums (`settings_enums.dart`), `CoreSettingsPageIds` (plain
  `String` page identifiers, not a closed enum - see Architectural
  Observations), `SettingsEntry` (a searchable setting descriptor), and
  `SettingsException`.
* `lib/settings/services/settings_storage.dart` (new) - real `dart:io`
  persistence to `%APPDATA%/oep_studio/settings.json`.
* `lib/settings/services/settings_migration_service.dart` (new, pure) -
  resolves any raw JSON to `UserConfiguration.currentSchemaVersion`,
  throwing on a schema newer than this build, and wrapping any upgrader
  failure.
* `lib/settings/services/settings_validation_service.dart` (new, pure) -
  validates a `UserConfiguration` before every save, collecting every
  violation into one message.
* `lib/settings/services/settings_service.dart` (new) - orchestrates
  `load`/`save`/`resetToDefaults`/`exportToJson`/`importFromJson`.
* `lib/settings/services/settings_provider.dart` (new) - the
  `SettingsProvider` interface (`pageId`/`label`/`icon`/`searchEntries`/
  `pageBuilder`).
* `lib/settings/services/settings_registry.dart` (new) - `SettingsRegistry`,
  structurally identical to Work Package 016's `AiProviderRegistry`;
  `defaultRegistry` seeded with the eleven core pages.
* `lib/settings/controllers/settings_controller.dart` (new) - the
  Settings Workspace's own Riverpod `Notifier` (deliberately separate
  from `FoundationRuntimeNotifier`), owning the in-memory draft
  `UserConfiguration` and one update method per leaf setting.
* `lib/settings/workspace/settings_workspace_page.dart` (new) - the
  Settings Workspace shell: left navigation + search, right page
  content, a top action bar (Save/Discard/Reset Defaults/Export/Import),
  and `?page=` deep-link support.
* `lib/settings/pages/*.dart` (new, 11 files) - one `SettingsProvider` +
  page widget per core page.
* `lib/settings/widgets/settings_rows.dart` (new) - shared row/section
  widgets (`SettingsSwitchRow`, `SettingsDropdownRow`, `SettingsSliderRow`,
  `SettingsTextRow`, `SettingsInfoRow`, `SettingsPlaceholderRow`) reused
  across all eleven pages.
* `lib/core/services/foundation_runtime_state.dart` /
  `foundation_runtime_service.dart` - `currentSettingsPageId`/
  `settingsSearchQuery`/`settingsModified` (Connection Manager
  coordination state only) plus three corresponding setters.
* `lib/core/routing/app_router.dart` - the `/settings` route now builds
  `SettingsWorkspacePage`, reading `?page=` for deep links, replacing the
  Work Package 001 `SettingsPage` placeholder (`lib/features/settings/`
  removed entirely).

### What Is Explicitly Not Implemented

Per this work package's explicit instructions: no Foundation changes, no
Public C API changes, no AI provider integration (the Artificial
Intelligence page has no dependency on Work Package 016's
`AiProviderRegistry`), no Plugin implementation (the Plugins page is
entirely inert). Several settings on Appearance/Workspace/Knowledge
Studio/Diagnostics are stored, validated, and versioned but have no
observable effect on Studio's behavior yet - see `docs/STUDIO_SETTINGS.md`'s
Core Settings Pages table for the full real-vs-placeholder breakdown.
"Reset Studio" (a full local-state wipe) is a placeholder; only "Reset
Defaults" (Settings only) is real.

### Repository Structure Additions

```
lib/
  settings/
    models/
      settings_enums.dart                    New
      settings_page_id.dart                  New
      settings_entry.dart                    New
      settings_exception.dart                New
      general_settings.dart                  New
      appearance_settings.dart               New
      workspace_settings.dart                New
      repository_settings.dart               New
      knowledge_studio_settings.dart         New
      ai_settings.dart                       New
      plugin_settings.dart                   New
      update_settings.dart                   New
      diagnostics_settings.dart              New
      security_settings.dart                 New
      user_configuration.dart                New
    services/
      settings_storage.dart                  New
      settings_migration_service.dart        New
      settings_validation_service.dart       New
      settings_service.dart                  New
      settings_provider.dart                 New
      settings_registry.dart                 New
    controllers/
      settings_controller.dart               New
    workspace/
      settings_workspace_page.dart           New
    pages/
      general_settings_page.dart             New
      appearance_settings_page.dart          New
      workspace_settings_page.dart           New
      repository_settings_page.dart          New
      knowledge_studio_settings_page.dart    New
      ai_settings_page.dart                  New
      plugins_settings_page.dart             New
      updates_settings_page.dart             New
      diagnostics_settings_page.dart         New
      security_settings_page.dart            New
      about_settings_page.dart               New
    widgets/
      settings_rows.dart                     New
  core/
    services/
      foundation_runtime_state.dart          Extended (Settings coordination state)
      foundation_runtime_service.dart        Extended (three setters)
    routing/
      app_router.dart                        Extended (/settings -> SettingsWorkspacePage)
  features/
    settings/                                Removed (superseded placeholder)
docs/
  STUDIO_SETTINGS.md                         New
```

### Package Decisions

**No new dependencies.** `SettingsStorage` reuses `dart:io`/`dart:convert`
exactly like `KnowledgeSessionStorage`; Export/Import reuse
`package:file_selector`'s `getSaveLocation`/`openFile`, already a
dependency since Work Package 002, exactly as `commit_report_dialog.dart`
and `import_queue_panel.dart` already use them.

### Verification Results

* flutter analyze - no issues found.
* flutter test - 271/271 passing: all prior tests, plus five new test
  files (`settings_migration_service_test.dart` - 5 tests covering
  legacy-file upgrade, unmigrated passthrough, version-mismatch and
  corrupt-schema-version failures, and a full parse-after-migrate round
  trip; `settings_validation_service_test.dart` - 7 tests covering the
  default configuration's own validity and every rejection case;
  `settings_registry_test.dart` - 6 tests covering registration order,
  `providerFor` resolution, a fake future-provider registering without
  Settings Workspace changes, and search by name/description/keyword;
  `settings_controller_state_test.dart` - 4 tests covering
  `isModified`'s structural comparison; `settings_service_test.dart` - 8
  tests exercising real `%APPDATA%/oep_studio/settings.json` I/O with
  backup/restore around every test, mirroring
  `knowledge_session_storage_test.dart`'s own precedent).
* flutter build windows - succeeded.
* **Manual verification** using the pre-approved temporary
  `integration_test` fallback (`computer-use` again confirmed unable to
  target the compiled `oep_studio.exe` in this environment) - a single
  end-to-end test drove the real compiled app through: seeding a legacy
  (no-`schemaVersion`) settings file and confirming it loaded correctly
  migrated (Migration); confirming all eleven core pages are present in
  the left navigation and that switching between them renders each
  page's own content (Registry, Navigation); typing a query and
  selecting a search result to jump straight to the Appearance page
  (Search); changing General's Language, saving, and confirming the
  exact value landed in the real settings file (Save, Load); and Reset
  Defaults reverting and persisting the default value (Defaults). The
  `integration_test` dev dependency and `integration_test/` directory
  were fully removed afterward, and the real settings file (there wasn't
  one before this run) was confirmed absent again after teardown.

  One real layout bug was found and fixed during this pass (not a
  test-script issue): `SettingsDropdownRow`'s `DropdownButton` overflowed
  at the width available inside the Settings Workspace's own two-pane
  layout, since a non-`isExpanded` `DropdownButton` sizes to its longest
  item's natural width rather than the space available - fixed with
  `isExpanded: true` plus a fixed-width `SizedBox`. The Settings action
  bar's row of Import/Export/Reset Defaults/Discard/Save buttons had the
  same class of overflow at narrower widths - fixed by wrapping the
  trailing button group in a horizontally-scrollable `Expanded` region,
  mirroring `StudioToolbar`'s own established pattern for its action row.

### Architectural Observations

See `docs/STUDIO_SETTINGS.md` § Architectural Observations for the full
account - summarized here:

* **`SettingsPageId` was redesigned from a closed `enum` to plain
  `String` constants (`CoreSettingsPageIds`)** before other code was
  built on top of it, once SDD-023's "Future modules may register
  additional pages" was read against STUDIO-TASK-000055's "shall not
  require modification when new providers are added" - a closed enum
  cannot admit an id a future provider invents for itself. Mirrors
  `AiProviderRegistry`'s own plain-`String` `providerId` (Work Package
  016).
* **`SettingsProvider.pageBuilder` returns a `Widget` from a
  services-layer interface** - a deliberate, documented exception to
  "services never construct widgets," justified the same way
  `GoRoute.builder` already works in this codebase: the registry only
  holds the reference, it never inspects or builds the widget tree
  itself.
* **The Artificial Intelligence page is deliberately decoupled from Work
  Package 016's real `AiProviderRegistry`** - connecting them is exactly
  the "provider-specific settings" this work package's instructions say
  not to implement yet.
* **"Reset Studio" was scoped down to a placeholder** rather than
  implementing a genuine full local-state wipe, since that is a
  destructive, irreversible action well beyond this work package's own
  "Reset Defaults" (Settings only) requirement.

None of the observations above blocked implementation - each had a
reasonable literal reading available and none constituted the kind of
genuine, irreconcilable architectural conflict this work package's
instructions say to stop for.

## Work Package 018 — Anthropic Provider

Status: Complete

Tasks:

* STUDIO-TASK-000056 — Anthropic Provider - Complete
* STUDIO-TASK-000057 — AI Settings Integration - Complete
* STUDIO-TASK-000058 — Connection Verification - Complete
* STUDIO-TASK-000059 — Live AI Analysis - Complete

### What Exists

The first production `AiProvider` implementation, plus a new, reusable
credential infrastructure. Full detail in `docs/ANTHROPIC_PROVIDER.md`.

* `lib/knowledge/services/anthropic_provider.dart` (new) -
  `AnthropicProvider implements AiProvider, TestableAiProvider,
  CancellableAiProvider` - real Anthropic Messages API calls via
  `package:http`, forced tool-use for structured JSON output (so
  `AiSuggestionParser` needed no changes), retry/timeout/cancellation,
  self-configuring (reads `AiSettings` + `CredentialStore` fresh per
  call via injectable seams for testability).
* `lib/knowledge/services/testable_ai_provider.dart`,
  `cancellable_ai_provider.dart` (new) - optional capability interfaces,
  kept off the frozen `AiProvider` interface itself.
* `lib/knowledge/models/ai_connection_status.dart`,
  `ai_connection_test_result.dart` (new) - Connected/Authentication
  Failed/Network Error/Provider Error, plus a message.
* `lib/knowledge/models/ai_response.dart` (extended) -
  `inputTokens`/`outputTokens`/`stopReason`/`rawMetadata`, populated by
  real providers, `null` for `MockAiProvider`.
* `lib/knowledge/services/ai_provider_registry.dart` (extended) -
  `defaultRegistry` now seeds `AnthropicProvider()` alongside
  `MockAiProvider()` - the entire integration point.
* `lib/knowledge/services/mock_ai_provider.dart` (extended) - now also
  implements `TestableAiProvider` (always connected, no network), so
  Test Connection is exercisable end-to-end through Mock alone.
* `lib/core/security/` (new module) - `CredentialStore` (interface),
  `CredentialService` (platform selection), `WindowsCredentialStore`
  (the Windows backend), `windows_credential_native_types.dart`/
  `windows_credential_bindings.dart` (the `dart:ffi` → `advapi32.dll`
  layer, mirroring `oep_api_native_types.dart`/`OepApiBindings`'s own
  split), `credential_models.dart`. Stores API keys in Windows
  Credential Manager via `CredWriteW`/`CredReadW`/`CredDeleteW`/
  `CredEnumerateW` - no ATL, no COM, no third-party plugin.
* `lib/settings/models/ai_settings.dart` (extended) -
  `maxOutputTokens` (new field; `contextWindowTokens` remains
  informational only). Bumped `UserConfiguration.currentSchemaVersion`
  to 2, with a real `SettingsMigrationService` step backfilling the
  default for a schema-1 file.
* `lib/settings/pages/ai_settings_page.dart` (extended) - Provider is
  now a real dropdown from `AiProviderRegistry`; a new `_ApiKeyRow`
  (masked field, Save/Remove, backed by `CredentialService.instance`,
  never `SettingsController`); Max Tokens; a new `_TestConnectionRow`
  (real, via the Connection Manager) with a status badge.
* `lib/settings/controllers/settings_controller.dart` (extended) -
  `setAiMaxOutputTokens`.
* `lib/core/services/foundation_runtime_state.dart`/
  `foundation_runtime_service.dart` (extended) - `aiConnectionStatus`/
  `aiConnectionMessage`/`currentAiModel`/`activeAiRequestSourceId`
  (coordination state only); `testAiConnection`/`cancelActiveAiRequest`.
* `lib/knowledge/inspector/ai_suggestion_properties.dart` (extended) -
  "Token Usage" and "Response Metadata" sections, shown when the
  current conversation's response carries that data.

### What Is Explicitly Not Implemented

No Foundation changes. No Public C API changes. No architectural
redesign - `AiProvider` itself is unchanged from Work Package 016; the
AI Review Workspace's review workflow is unchanged; `PromptService`,
`AiAnalysisService`, and `AiSuggestionParser` are unchanged. No Cancel
button was added to the AI Review Workspace dialog (see Architectural
Observations). No other AI provider (OpenAI, Gemini, Ollama, LM Studio,
OpenRouter) is implemented - "AnthropicProvider shall be the only
provider implemented in this work package."

### Repository Structure Additions

```
lib/
  core/
    security/
      credential_models.dart                 New
      credential_store.dart                   New
      credential_service.dart                 New
      windows_credential_native_types.dart     New
      windows_credential_bindings.dart         New
      windows_credential_store.dart            New
    services/
      foundation_runtime_state.dart            Extended (AI connection/model/active-request state)
      foundation_runtime_service.dart          Extended (testAiConnection/cancelActiveAiRequest)
  knowledge/
    models/
      ai_response.dart                         Extended (tokens/stopReason/metadata)
      ai_connection_status.dart                New
      ai_connection_test_result.dart           New
    services/
      anthropic_provider.dart                  New
      testable_ai_provider.dart                New
      cancellable_ai_provider.dart             New
      ai_provider_registry.dart                Extended (AnthropicProvider registered)
      mock_ai_provider.dart                    Extended (TestableAiProvider)
    inspector/
      ai_suggestion_properties.dart            Extended (Token Usage/Response Metadata)
  settings/
    models/
      ai_settings.dart                         Extended (maxOutputTokens)
      user_configuration.dart                  Extended (schema v2)
    services/
      settings_migration_service.dart          Extended (v1->v2 step)
    controllers/
      settings_controller.dart                 Extended (setAiMaxOutputTokens)
    pages/
      ai_settings_page.dart                    Extended (Provider dropdown/API Key/Max Tokens/Test Connection)
docs/
  ANTHROPIC_PROVIDER.md                        New
```

### Package Decisions

**Added `http: ^1.2.2`** (Dart-team-maintained) for the Anthropic
Messages API transport.

**`flutter_secure_storage` was added, then removed.** The Windows
backend (`flutter_secure_storage_windows`) requires the ATL component
of the Visual Studio C++ build tools, not installed in this project's
build environment - `flutter build windows` failed with `Cannot open
include file: 'atlstr.h'`. Rather than require a new Visual Studio
component or keep a third-party plugin dependency, the package was
removed entirely in favor of a direct `dart:ffi` call to
`advapi32.dll` (`lib/core/security/`) - no new dependency at all, and a
better fit for this project's own minimal-dependency philosophy and its
existing FFI-based native-interop precedent (the Foundation Bridge).

### Verification Results

* flutter analyze - no issues found.
* flutter test - 294/294 passing (2 additional tests self-skip without
  a real API key - see below): all prior tests, plus
  `anthropic_provider_test.dart` (17 tests against a fake `http.Client`
  - no network, no real credential - covering disabled/missing-key
  failures, request body construction, successful parsing with
  tokens/stopReason/metadata, HTTP 401 no-retry, HTTP 500 retry-then-fail
  and retry-then-succeed, malformed/missing-tool-use responses, a
  `max_tokens`-truncation response, `testConnection`'s four status
  outcomes, and cancellation during a retry backoff),
  `windows_credential_store_test.dart` (7 tests against
  the **real** Windows Credential Manager - not a Flutter plugin, so
  this runs for real in `flutter test` - using disposable test data,
  cleaned up in `tearDown`), an extended
  `settings_migration_service_test.dart` (schema 1 → 2 backfill), and a
  permanent, self-skipping `anthropic_provider_live_test.dart` (2 tests,
  skip themselves unless `ANTHROPIC_API_KEY` is set - an "optional
  integration test using a real API key," never required for `flutter
  test` to pass).
* flutter build windows - succeeded (after resolving the ATL build
  failure by removing `flutter_secure_storage`).
* **Manual verification with a real Anthropic API key**: performed
  through the real Studio UI (Settings → Artificial Intelligence → enter
  API key → Save → Test Connection → Knowledge Studio → live AI analysis
  → Review Workflow → persistence), not an environment variable, per
  explicit instruction, since that is how end users will actually
  configure and use this feature. Confirmed working end-to-end: Test
  Connection, live AI analysis producing real suggestions, Accept/Edit/
  Reject/Defer, accepted suggestions becoming Knowledge Candidates, and
  suggestion persistence across session close/reopen. Two real,
  undersized defaults were found and fixed along the way - see
  "Architectural Observations" below and `docs/ANTHROPIC_PROVIDER.md` §
  Error Handling.

### Architectural Observations

See `docs/ANTHROPIC_PROVIDER.md` § Architectural Observations for the
full account - summarized here:

* **No Cancel button was added to the AI Review Workspace dialog** -
  `CancellableAiProvider`/`activeAiRequestSourceId` are real, tested
  plumbing, but STUDIO-TASK-000059 requires "The review workflow itself
  shall remain unchanged."
* **`flutter_secure_storage` was removed and replaced with a native
  `dart:ffi` implementation** after it broke `flutter build windows` on
  a missing Visual Studio component - `CredentialStore` is designed as
  Studio's general-purpose credential infrastructure, not AI-specific.
* **The Artificial Intelligence settings page now depends on
  `AiProviderRegistry`**, superseding Work Package 017's own explicit
  decoupling decision - that decoupling was itself scoped "yet," pending
  the first production provider, which this work package is.
* **Work Package 018 proved the Work Package 016 "no production
  provider" boundary was genuinely provider-independent** - registering
  `AnthropicProvider` required zero changes to `AiAnalysisService`,
  `PromptService`, `AiSuggestionParser`, or the AI Review Workspace's
  review workflow.
* **Manual verification against a real, evidence-heavy engineering
  document exposed two undersized defaults** in `AiSettings.defaults()`:
  `maxOutputTokens` (1024) was too small to finish a real suggestion
  request (26 entities + 19 contexts + full OCR text to cite), causing
  Anthropic to truncate the tool call mid-generation - which returns an
  empty `input: {}`, indistinguishable from "nothing to suggest" unless
  `stop_reason` is checked explicitly. Once raised, the original
  `timeoutSeconds` (30) was then too short for the larger completion to
  finish. Both were raised (`maxOutputTokens` → 4096, `timeoutSeconds` →
  120) and the `stop_reason == "max_tokens"` case is now surfaced as its
  own explicit, actionable failure rather than a silent empty result.
  Configuration tuning, not an architectural change.

None of the observations above blocked implementation - each had a
reasonable literal reading available and none constituted the kind of
genuine, irreconcilable architectural conflict this work package's
instructions say to stop for.

---

## Work Package 024 — Diagram Studio Integration

Status: Implemented

The first work package spanning two repositories: `oep_engine` (the
Engineering Engine) and `oep_studio` (this package). Diagram Studio —
the second major Primary Workspace after Knowledge Studio — is now the
production diagram-editing experience, built entirely on the
Engineering Engine's existing public API. No engineering behavior was
implemented in Studio; no repository/Studio behavior was implemented in
the Engine.

### What Exists

* `lib/diagram_studio/` — the new module, mirroring Knowledge Studio's
  own top-level shape:
  * `host/engine_host.dart` — thin `EngineeringEngine` lifecycle wrapper
    (create/initialize/seed symbols/begin session/dispose). No
    engineering logic of its own.
  * `host/diagram_document.dart` — Open/Save/Save As/Close/Dirty State
    for a diagram document (Engineering Graph + Diagram Layout,
    persisted together as one JSON file via the Engine's own
    `toJson()`/`fromJson()` — see `docs/REPOSITORY_INTEGRATION.md`).
  * `workspaces/diagram_studio_page.dart` — the workspace page/route
    target; owns the Engine instance, the editing session, and every
    interaction handler (node/port/wire/annotation drag, box-select,
    drag-to-connect/reconnect, "Edit Route" mode), ported from the
    Engine's own Demonstration Host to Studio idiom.
  * `toolbars/diagram_toolbars.dart` — the nine toolbar groups
    (Selection, Navigation, Placement, Wire Editing, Layers,
    Annotations, View, Search, Constraints), Studio-styled
    (`StudioColors`), living inside Diagram Studio's own workspace page.
  * `panels/` — six panels (Diagram Explorer, Layer, Search, Validation,
    Annotation, Recent Commands), each wrapped in the existing
    `KnowledgePanel` chrome widget — reusing Knowledge Studio's own
    panel-chrome pattern rather than building a new docking framework.
  * `inspector/` — seven new Property Inspector modes (Node,
    Relationship, Group, Port, Layer, Annotation, Wire Override) — see
    `docs/PROPERTY_INSPECTOR_INTEGRATION.md`.
  * `commands/studio_command_actions.dart` — Undo/Redo/Copy/Cut/Paste/
    Delete/Duplicate, direct calls into `engine.editing`/
    `engine.clipboard`/`engine.registry.selection` (no new command bus).
  * `settings/` — a `DiagramStudioSettingsProvider` (new-document ViewState
    defaults: grid/snap/guides visibility), appended to
    `SettingsRegistry.defaultRegistry`, persisted independently of
    `UserConfiguration` (its own small JSON file — see
    `docs/WORKSPACE_INTEGRATION.md`).
  * `persistence/` — `DiagramWorkspaceState`/`WorkspaceStateStorage`:
    last-open document path, panel visibility, panel widths, and
    ViewState, restored on next launch.
  * `ai/` — `DiagramPromptContext` (pure prompt assembly from
    Selection/graph/evidence) + `DiagramAiService` (calls the existing
    `AiProviderRegistry` directly — no new provider infrastructure).
* `pubspec.yaml` — added `engineering_engine: { path: ../oep_engine }`
  and `flutter_svg`.
* One new field on `FoundationServiceState`:
  `selectedEngineeringInspectable` (a small sum-type value,
  `EngineeringInspectable`), bridging Engine-owned Selection into the
  shared Property Inspector without Studio reimplementing selection.
* `StudioDestination.diagram` + its `GoRoute`, alongside every other
  workspace destination.

### What Changed in `oep_engine`

* Canvas presentation widgets (`GraphViewPanel` and ten supporting
  files) and three drafting dialogs, previously living only in
  `example/lib/`, were promoted into the package itself
  (`lib/views/widgets/`, `lib/views/dialogs/`) so Diagram Studio reuses
  them instead of duplicating ~1,000 lines of rendering/dialog code.
  See `oep_engine/docs/ARCHITECTURE_DECISIONS.md` ADR-023. This is the
  only Engine code change WP024 made; no engineering behavior changed.
* The Demonstration Host's framing was updated (doc comments + its own
  `docs/DIAGRAM_STUDIO.md`) to state it is now regression-only.

### What Is Explicitly Not Implemented

* Align/Distribute commands have no toolbar exposure yet in Diagram
  Studio (reachable via the Engine API, just not wired to a button) —
  flagged as a recommendation for future work.
* No on-screen rulers (the Demonstration Host's `HorizontalRuler`/
  `VerticalRuler` were not promoted or ported — a minor polish gap, not
  a functional one).
* `EngineeringRelationshipProperties` in the Property Inspector shows
  raw node ids for source/target rather than resolved display names
  (the dispatch helper has no graph reference) — a known, minor
  display-quality gap.
* No dedicated AI chat/review UI panel — `ai/` is the integration point
  (prompt assembly + provider call) only, matching the approved plan's
  own scope ("builds its own local prompt-context assembler... calls
  the existing AiProviderRegistry").

## Work Package 025 — Unified Engineering Workspace

Status: Implemented

Pure workflow integration over WORK_PACKAGE_024's foundation — no new
engineering/editing features, no new repository features, no
Marketplace, no Simulation. Every ownership boundary from the Platform
Constitution (Foundation: Repository/Knowledge/Evidence/Provenance;
Engine: Graph/Layout/ViewState/Commands/Search/Validation/Navigation;
Studio: orchestration/UI/persistence) stays exactly as it was.

### What Exists

* `lib/core/models/engineering_project.dart` +
  `lib/core/services/engineering_project_storage.dart` — the
  `EngineeringProject` reference-data model and its file-per-record
  persistence, mirroring `KnowledgeSessionStorage`'s own convention.
  See `docs/ENGINEERING_PROJECT.md`.
* `lib/core/services/engineering_project_service.dart` — the
  `EngineeringProjectNotifier`/`engineeringProjectServiceProvider` that
  now owns the `EngineHost`/`DiagramDocument`/editing session/
  selection/validation report, hoisted out of `DiagramStudioPage`'s
  previously-private `State` so every route can reach the same live
  Engine instance. See `docs/WORKSPACE_SYNCHRONIZATION.md`.
* `lib/shared/navigation/unified_navigation.dart` +
  `lib/shared/navigation/evidence_navigation.dart` — cross-workspace
  navigation helpers (`goToKnowledgeObject`, `goToDiagramElement`,
  `goToValidationResult`, `goToSearchResult`, `goToEvidence`), each
  recording a shared, capped `RecentHistoryEntry` list.
* `lib/core/models/unified_search_result.dart` +
  `lib/features/search/unified_search_service.dart` — merges
  Foundation and Engineering Engine search into one result list without
  touching either source `SearchResult` type; `search_page.dart`
  rewritten to use it, and to no longer require an open repository.
  See `docs/UNIFIED_SEARCH.md`.
* `EngineeringInspectableKind.evidenceLink` (`lib/core/models/
  engineering_inspectable.dart`) + `lib/diagram_studio/inspector/
  engineering_evidence_link_properties.dart` — an eighth Property
  Inspector mode, additive to the existing 12-slot tuple switch, with a
  "Go to Evidence" action. `engineering_node_properties.dart`/
  `engineering_relationship_properties.dart` rewritten so each evidence
  link is its own tappable row rather than a bare count.
* `lib/shared/widgets/validation_findings_list.dart` +
  `lib/features/validation/suggested_fixes.dart` — shared finding-row
  rendering and a presentation-only Suggested Fix lookup, used by both
  the rewritten `lib/features/validation/validation_page.dart`
  (previously a 16-line stub) and Diagram Studio's own
  `diagram_validation_panel.dart`.
* `lib/core/services/unified_ai_context_service.dart` — appends
  validation findings and resolved evidence to whichever existing
  prompt assembler already applies, before handing the request to the
  existing `AiProviderRegistry` unchanged. Backs `ValidationPage`'s new
  "Ask AI" action.
* `lib/features/project_explorer/project_explorer_page.dart` +
  `StudioDestination.projectExplorer` — a new `/project` workspace, a
  flat `ExpansionTile` tree (Knowledge/Diagrams/Evidence/Components/
  Validation/AI Sessions/disabled Simulation placeholder), second item
  in the Navigation Rail. See `docs/PROJECT_EXPLORER.md`.
* `test/workflow/unified_workflow_test.dart` — a composition test
  proving the above actually work together end to end, not just in
  isolation. See `docs/WORKFLOW_ARCHITECTURE.md`.

### What Changed in `oep_engine`

Nothing. Every change this work package made is Studio-side; the
Engineering Engine's public API was consumed exactly as WORK_PACKAGE_024
left it. New architectural decisions this work package's Studio-side
code embodies (the EngineHost hoist, `EngineeringProject`'s shape,
`UnifiedSearchResult`, the evidence `sourceReference`/`locator`
convention) are still recorded as ADRs in `oep_engine/docs/
ARCHITECTURE_DECISIONS.md` (ADR-024 through ADR-027) — the platform's
one existing formal decision log, since `oep_studio` has none of its
own and this work package did not start one.

### What Is Explicitly Not Implemented

* No UI to create or attach an `EvidenceLink` from Diagram Studio —
  attaching evidence is a graph mutation, and this work package
  excludes new engineering editing features. Only navigation/
  resolution of already-existing links is built.
* Project Explorer's Diagrams branch shows exactly one leaf (the
  current document) — Diagram Studio has no multi-document concept to
  enumerate today.
* "New Project" only creates and activates an `EngineeringProject`
  record; it does not create a Knowledge Session, open a repository, or
  create a diagram document. Wiring those together into one guided flow
  is a reasonable future work item, not something this work package's
  text required.
* No Simulation implementation — Project Explorer's Simulation branch
  is a disabled placeholder, matching the work package's explicit
  exclusion.

## AP-DS-001A — Diagram Studio Editor Completion & UX Refinement

Editor refinement phase following AP-DS-001's architecture freeze
(`docs/architecture/diagram_studio/`). No Foundation Runtime
persistence, no Engineering Intelligence Platform integration — Diagram
Studio remains a self-contained local editor, as required. Every item
below was independently rebuilt and test-verified in this session (not
taken on report): `oep_engine` 199/199 tests passing (up from a
190-test baseline, `flutter analyze` clean); `oep_studio` 473 tests
passing / 2 pre-existing skips (unchanged baseline count — the two new
Studio-side test files landed alongside a small net removal elsewhere),
`flutter analyze` clean (2 pre-existing infos in
`foundation_runtime_service.dart`, unrelated).

### What Changed in `oep_engine`

* **Resize support** — `Size2D` (`core/views/diagram/diagram_geometry.dart`),
  a `sizes` map on `DiagramLayoutState` (same position-map pattern used
  for node positions, full JSON round-trip), `ResizeNodeCommand`
  (`core/editing/commands/resize_node_command.dart`, undo/redo tested,
  supports an atomic combined position+size change for top/left-handle
  drags), `DiagramView` rendering/port-anchoring at actual per-node
  size instead of the previous fixed `_nodeSize` constant, and a new
  `ResizeHandles` widget wired into `GraphViewPanel`, shown only when
  exactly one node is selected. Diagram Studio previously had no resize
  capability at all — this closes that gap.
* **`MoveNodeCommand` removed** — investigated alongside
  `MoveNodesCommand` per AP-DS-001's debt list; confirmed zero
  production call sites (only its own now-removed test referenced it).
  `MoveNodesCommand` (already what every real caller used) now carries
  a doc comment recording this finding so it isn't rediscovered as
  "duplication" by a future reader.
* **`ViewStateService.resetView()`** — new method (View reset,
  undoable via the existing navigation history), backing the "Reset
  view" requirement in AP-DS-001A's Canvas section.
* **OS-level clipboard codec** — `ClipboardEntry.toJson`/`fromJson` +
  `ClipboardCodec` (namespaced JSON, `core/clipboard/clipboard_codec.dart`)
  so a diagram selection can round-trip through the real OS clipboard,
  not just the in-process one.
* **Performance** — `GraphViewPanel` now computes a padded visible-scene
  rect and skips constructing widgets for nodes/annotations outside it
  (viewport culling), and wraps every node widget, annotation widget,
  and the grid/wire/guides painters in `RepaintBoundary`. Verified
  functionally equivalent via the full test suite; no dedicated
  before/after frame-time benchmark was built in this pass (no
  benchmark harness existed before this phase and building one was out
  of proportion to it — see Known Issues below).
* **Deliberately not done**: decoupling drag-preview updates from the
  Studio page's full-widget `setState()` into a narrower
  `ValueNotifier`/`ChangeNotifier`-scoped update. This was judged too
  risky to land without a dedicated drag-gesture test harness (none
  exists) verifying grid-snap/alignment-guide/drag-commit correctness
  wasn't silently broken — named explicitly as deferred, not silently
  dropped.

### What Changed in `oep_studio`

* **`diagram_studio_page.dart`**: multi-node alignment guides (previously
  single-node-drag only — `AlignmentGuideComputer` is now driven by the
  combined bounding box of the whole dragged selection, snapped as one
  rigid group); a real fix for the `InteractiveViewer` `Matrix4` vs.
  `ViewState.zoom`/`pan` dual-source-of-truth bug AP-DS-001 flagged as a
  risk — `fitAll`/`fitSelection`/`centerSelection`/`goBack`/`goForward`
  previously updated `ViewState` without ever moving the visible
  canvas; `ViewState` is now the authoritative source, mirrored into the
  transform controller on every relevant change; a coordinate-display
  overlay (cursor scene position + zoom %) near the canvas; public
  `resetView()`/`alignSelection()`/`distributeSelection()` methods
  wired to the new `ResetView`/`AlignDistributeToolbar` toolbar buttons
  (see below) and to Ctrl+0 for reset view; real handling for
  `SearchResultKind.symbol`/`.layer` search results (previously
  no-ops — selecting either now selects and frames the matching
  nodes/annotations on the canvas); resize-handle drag wiring; OS
  clipboard fallback on copy/paste (in-process clipboard remains the
  fast primary path).
* **`toolbars/diagram_toolbars.dart`**: added `AlignDistributeToolbar`
  (8 buttons: align left/center/right/top/middle/bottom, distribute
  horizontal/vertical) and a "Reset view" button on
  `DiagramNavigationToolbar` — both wired into `diagram_studio_page.dart`'s
  toolbar row. `AlignNodesCommand`/`DistributeNodesCommand` existed in
  `oep_engine` since before AP-DS-001 but had no UI trigger anywhere;
  this closes that gap.
* **`host/diagram_document.dart`** (rewritten): `DiagramDocumentMetadata`
  (title/createdAt/modifiedAt/author), populated on save/open and
  included in the JSON envelope, with a filename-derived fallback for
  legacy files that predate it; `autosave()` writing to a separate
  recovery file under `%APPDATA%/oep_studio/autosave/`, never the
  user's own save path; `findRecovery()`/`recoverFrom()` for detecting
  and loading a newer autosave than the last explicit save;
  `save()` now clears any stale autosave once the user explicitly
  saves. All local-JSON, `schemaVersion = 1`, no Foundation
  involvement — exactly as `DOCUMENT_MODEL.md` requires for this phase.
* **`persistence/recent_files_storage.dart`** (new) — a most-recently-used
  file list (capped at 10, drops entries whose file no longer exists),
  following the same `WorkspaceStateStorage` persistence pattern
  already used for workspace-chrome state.
* **`commands/studio_command_actions.dart`** — audited; every mutating
  action already routes through `engine.editing.execute()`
  (`CommandHistory`), so undo/redo coverage was already complete here.
  No changes needed.

### What Was Reviewed and Found Already Correct (no changes)

Toolbars' icon consistency, tool grouping, and activation-state
indication; menus' shortcut display; the 6 panels' docking/resizing/
persistence behavior; the 8 property inspectors' live-update/layout/
validation/accessibility behavior. These areas were reviewed only
lightly in this phase relative to the Canvas/Editing/Document areas
above — see Known Issues below for what a follow-up pass should still
verify in depth, since "reviewed lightly" is not the same claim as
"confirmed correct."

### Known Issues / Remaining Technical Debt (honest carry-forward, not resolved this phase)

1. **No dedicated performance benchmark suite** — culling/`RepaintBoundary`
   changes were verified for correctness (existing tests still pass)
   but not measured for actual frame-time improvement. Building a
   synthetic-large-diagram benchmark harness remains unstarted.
2. **Drag-state `setState()` decoupling** — explicitly deferred (see
   above); the highest-remaining-value performance item, and the
   riskiest to land without a drag-gesture test harness that doesn't
   yet exist.
3. **No widget-level test harness for `diagram_studio_page.dart`'s
   gesture callbacks** (drag, box-select, connect, resize) — every
   fix in this phase that touched gesture handling was verified via
   `flutter analyze` plus the full existing suite continuing to pass
   (including the `unified_workflow_test.dart` integration test that
   exercises this page's provider wiring), not via a dedicated
   interaction test, because no such harness exists yet to extend.
   This is the most consequential test-coverage gap left after this
   phase.
4. **Toolbars/menus/panels/inspectors received only a light pass**,
   not the full icon-consistency/overflow-behavior/keyboard-accessibility
   audit AP-DS-001A's spec calls for — deferred due to the scope of
   this phase's other work, not found-and-ignored. A future pass
   should complete this review specifically.
5. **`_nodeAt`/`_portAnchor` hit-testing for connect/reconnect** in
   `diagram_studio_page.dart` still assume the old fixed node size
   rather than a resized node's actual dimensions (click/marquee
   selection via `DiagramHitTesting` is unaffected — it already used
   per-node bounds). Low risk, but a real correctness gap for
   resized nodes specifically, now that resize exists.
6. All gaps named in AP-DS-001's own architecture review that this
   phase's scope explicitly excluded remain open and unchanged: no
   Foundation Bridge implementation, no Engineering Intelligence
   Platform integration, no printing, PDF/SVG export still
   scaffold-only, simulation still a `NoOpSimulationProvider`
   placeholder, no multi-sheet/Drawing Set document model. None of
   these were in scope for AP-DS-001A and none were touched.

## AP-DS-001B — Diagram Studio Professional UX & Performance (UX/Accessibility/Testing portion)

Scope for this record: the UX/audit/testing half of AP-DS-001B (toolbars, panels, inspectors, workflow, keyboard shortcuts, accessibility, error handling) — `oep_studio/lib/diagram_studio/**` and `oep_studio/test/**` only. Rendering-performance benchmarking was a separate, parallel workstream against `oep_engine` and is not covered here.

### What Changed

* **`test/workflow/diagram_studio_interaction_test.dart`** (new) — the
  widget/interaction test harness AP-DS-001A's Known Issue #3 explicitly
  deferred. A single `testWidgets` (see the file's own doc comment for
  why one, not several — `EngineHost.create()`'s asset-load bootstrap
  only reliably completes once per test process) drives real gestures
  against `DiagramStudioPage`: node tap-select, node drag + undo,
  box-select (marquee), multi-select drag (relative spacing preserved),
  port-to-node drag-to-connect, corner-handle resize, wire-edit-mode
  toggle via the toolbar, and undo/redo depth across a sequence of
  edits. Assertions target observable state (`layout.positionOf`,
  `selection.current`, `editing.canUndo`/`canRedo`) rather than
  `_DiagramStudioPageState`'s private fields, so the suite stays valid
  once a future phase restructures the drag `setState()` pattern.
* **`lib/diagram_studio/toolbars/diagram_toolbars.dart`** —
  `EditActionsToolbar` (new): Undo/Redo/Cut/Copy/Paste/Duplicate/Delete
  now have toolbar buttons, not just keyboard shortcuts (see Toolbar
  Audit finding below). Also fixed the "Replace symbol" `PopupMenuButton`
  icon not dimming when disabled (every other disableable icon in this
  file already did, via `_ToolbarIcon`'s shared disabled-color handling
  — this one bypassed it by hand-coding its own `Icon`).
* **`lib/diagram_studio/workspaces/diagram_studio_page.dart`** — wired
  `EditActionsToolbar` into the toolbar row, gating each button on the
  same guard its matching `CallbackShortcuts` binding already used
  (`canUndo`/`canRedo`/`hasClipboardContent`/selection non-empty). No
  change to any gesture-handler method's state-management pattern.
* **`docs/architecture/diagram_studio/INTERACTION_MODEL.md`** — Section
  3 replaced with a full keyboard-shortcut inventory (previously a stub
  noting only Undo/Redo were confirmed); Section 6's now-stale entries
  (resize "not implemented", multi-node guides, symbol/layer search
  no-ops — all fixed by AP-DS-001A) struck through and marked resolved;
  two new AP-DS-001B findings added (see Known Issues below).

### Toolbar Audit (AP-DS-001B)

Icon sizing: consistent (`iconSize: 18` via the shared `_ToolbarIcon`
widget; direct `PopupMenuButton` icons also all `size: 18`). Tooltips:
present on every actionable icon; shortcut-bearing actions now name
their shortcut (Select All, Deselect, Save, Reset View, and the seven
new Edit Actions buttons). Toggle state: Grid/Snap/Guides (checkboxes
in the View popup) and Wire-Edit-Mode (`active` prop swaps icon +
color) both read consistently. Disabled state: `_ToolbarIcon` dims
disabled icons uniformly; the one exception (Replace Symbol) is fixed
above. Overflow: the whole toolbar row is already wrapped in a `Wrap`
(`diagram_studio_page.dart` build()), so a narrow window wraps to a
second row rather than clipping — no bug found here. No duplicate
actions found. The one real gap: Undo/Redo/Cut/Copy/Paste/Duplicate/
Delete had shortcuts but no toolbar button at all — fixed via
`EditActionsToolbar`.

### Panel / Inspector / Workflow / Accessibility / Error-Handling Audits (AP-DS-001B)

Reviewed at a lighter depth than the Toolbar Audit and the interaction
test harness, given the size of this phase's total scope; findings
below are what was confirmed, not an exhaustive certification:

* All 6 panels already have real empty states, scrollable
  `ListView.builder` content, and consistent Studio styling (Explorer,
  Layer, Search, Validation, Annotation, Recent Commands all reviewed
  directly).
* Docked side panels overflow (hard `RenderFlex` error, not a graceful
  clip/scroll) at short window heights — see the new Known Issue below.
* Placeholder scan (`TODO`/`FIXME`/"not implemented"/stub) across
  `lib/diagram_studio/**` found nothing outstanding.
* Inspector multi-selection editing, per-field inline validation depth,
  and a full accessibility (focus traversal / screen-reader / contrast)
  pass were **not completed** this phase — see Known Issues.

### Known Issues / Remaining Technical Debt (AP-DS-001B carry-forward)

1. **Docked side panel overflow at short window heights.** Five
   `Expanded` panels stacked in one fixed-width `Column`
   (`diagram_studio_page.dart` build()) have no minimum-height guard or
   scroll fallback; below roughly 700px of window height this
   hard-overflows instead of degrading gracefully. Confirmed fine at
   normal desktop sizes (1600x1000 test surface). Fix requires either a
   `SingleChildScrollView` around the panel column or making panels
   collapsible/tabbed — a real layout decision, deferred rather than
   made unilaterally.
2. **Undo of a node creation leaves a dangling id in
   `GraphSelection.current.nodeIds`** — engine-side (`oep_engine`,
   out of this phase's scope), degrades safely today via
   `_syncPropertyInspectorSelection`'s null-lookup fallback, flagged
   for the engine team.
3. **Full inspector audit (property organization, numeric input
   formatters, units, enum dropdowns, multi-selection mixed-value
   state) not completed** — the 8 inspector files were skimmed but not
   exhaustively exercised against every audit criterion in
   AP-DS-001B's spec. A dedicated follow-up should verify multi-
   selection editing specifically (a common inspector bug class per
   the task brief) with real widget tests.
4. **Full accessibility pass (focus traversal order, contrast
   spot-check, screen-reader `Semantics` coverage beyond tooltips) not
   completed** — same reason as #3, budget within this phase.
5. **Rendering performance benchmarking (10/100/1,000/10,000/100,000
   objects) is out of scope for this record** — see the parallel
   `oep_engine` workstream's own report, consolidated below.

## AP-DS-001B — Rendering Performance & Optimization (oep_engine portion)

Ran in parallel with the UX/audit workstream above, in `oep_engine`
only — zero file overlap, confirmed via `git status` on both repos
before either was merged into this record. Full detail, methodology,
and the complete results table: `docs/architecture/diagram_studio/PERFORMANCE_REPORT.md`.

* **New benchmark suite** — `oep_engine/test/performance/` (a synthetic
  diagram generator supporting 10 to 100,000 objects, plus 11 real
  `flutter test` cases measuring scene-render, zoom, pan, selection,
  wire-edit, and property-update latency at each scale). Not a
  throwaway script — a real, re-runnable regression suite.
* **One measured, justified optimization**: `WirePainter` had no
  viewport culling — every wire in the document was redrawn every
  frame regardless of visibility. Measured at 100,000 objects: 111.8ms
  per paint call before the fix, 0.99ms after — a ~113x improvement.
  This was the single largest rendering cost found in this phase,
  larger than the node/annotation rendering AP-DS-001A had already
  culled.
* **One real crash bug found and fixed**: `AnnotationWidget` wrapped
  its `Positioned` return value in an outer `RepaintBoundary` placed
  directly as a `Stack` child — Flutter disallows a `RenderObject`
  interposed between `Stack` and `Positioned`, throwing a
  `ParentDataWidget` mismatch at runtime. A live, uncaught defect from
  AP-DS-001A's `RepaintBoundary` adoption, invisible until this
  phase's benchmark suite was the first thing to actually pump
  `GraphViewPanel` with annotations present. Fixed by moving the
  `RepaintBoundary` inside `AnnotationWidget`'s own `Positioned`.
* **One optimization deliberately NOT performed**: decoupling
  drag-preview `setState()` from the full `_DiagramStudioPageState`
  (the item AP-DS-001A deferred and this phase's UX audit also
  declined to touch). Independently evaluated after both workstreams
  landed: viewport culling already bounds any rebuild's widget-
  construction cost to the visible set (~150–250 objects) regardless
  of total document size — the specific performance justification for
  this refactor (unbounded rebuild cost scaling with document size)
  is not supported by measurement. Left as an architectural
  inelegance, not a measured performance problem. Reopen only with
  live-profiling evidence (see below).
* **One scaling characteristic found, not fixed, correctly out of
  scope**: `UpdateNodePropertiesCommand` scales with total document
  size (0.08ms @ 100 objects → 5.14ms @ 100,000), because
  `EngineeringGraph.copyWith`/`withNode` spreads the entire nodes map
  on every update rather than using a structurally-shared immutable
  data structure. This is a core object-model characteristic, not a
  rendering issue, and touching it would violate this phase's "no
  document model changes" constraint — recorded as a recommendation
  for a future, dedicated review.
* **Verification**: `oep_engine` — 199 pre-existing tests (unchanged
  baseline) + 11 new = 210/210 passing, `flutter analyze` clean. Both
  numbers independently re-run and confirmed in this session, not
  taken on the implementing agent's report.

### Known limitation (shared with the UX portion above)

All performance numbers in this phase are headless CPU-time proxies
(`Stopwatch` around specific operations under `flutter test`) — there
is no real GPU/display in this environment. "Implied FPS" is derived
(`1000/ms`), not observed. A live DevTools-attached interactive
profiling session against real hardware and real pointer input remains
the one verification step this phase could not perform, and is the
top recommendation carried into whatever phase follows.

## AP-DS-001B — Closing Summary

Combining both workstreams: `oep_engine` 210/210 tests passing
(`flutter analyze` clean); `oep_studio` 474 tests passing / 2
pre-existing skips (`flutter analyze` clean, 2 pre-existing unrelated
infos). The one cross-cutting item both parallel agents correctly
declined to touch (drag-state `setState()` decoupling, toolbar
Align/Distribute UI wiring) was resolved directly afterward: the
Align/Distribute toolbar buttons were wired in (both `alignSelection`/
`distributeSelection` methods existed since AP-DS-001A but had no UI
trigger — confirmed via grep before wiring), verified via the same
full test/analyze pass (474 passing, clean). The `setState()`
question was evaluated on the evidence in `PERFORMANCE_REPORT.md` and
deliberately left as-is rather than forced through without measured
justification.

**Genuinely production-quality and complete**: undo/redo, command
architecture, selection, resize, alignment/distribution, autosave/
recent-files/recovery, OS clipboard fallback, rendering performance
at scale (10 to 100,000 objects, benchmarked and one real bottleneck
fixed), keyboard-shortcut/toolbar discoverability for the most
frequently used actions.

**Honestly still open, carried into future phases** (see
`docs/architecture/diagram_studio/IMPLEMENTATION_ROADMAP.md`'s
AP-DS-004 for the consolidated list): full inspector multi-selection
audit, full accessibility certification, the docked-panel short-
window overflow bug, live GPU/DevTools profiling to validate this
phase's headless proxies, lazy document loading for very large
documents, the `EngineeringGraph` O(n) update-scaling characteristic.
None of these block Foundation Runtime integration (AP-DS-002) — they
are editor-polish items independent of the persistence layer AP-DS-002
introduces — and are recorded here so they are not silently forgotten
once attention shifts to Foundation integration.

## AP-DS-002 — Engineering Repository Integration

Replaced local-JSON-only persistence with Foundation Runtime Engineering
Repository integration, per `docs/tasks/AP-DS-002.md`. Delivered by three
coordinated efforts (Foundation-side C++ schema extension, a Studio-side
UI layer, and a Studio-side persistence/mapping layer), all independently
verified in this session — not taken on any single report. Full design
rationale: `docs/architecture/diagram_studio/ENGINEERING_MAPPING.md`;
migration detail: `docs/architecture/diagram_studio/MIGRATION_GUIDE.md`.

### Foundation-side (`oep_foundation`, additive only)

* `EngineeringObject` (`platform/repository/include/oep/repository/
  engineering_object.hpp`) gained an opaque `content` string field —
  Foundation never parses it. Threaded through `ObjectStore`'s JSON
  serialization; empty for every pre-existing object.
* `FoundationRuntime::update_object_content`/`RuntimeService::
  update_object_content` — new methods mirroring `update_object`'s exact
  transaction/undo/event-publishing pattern (participates in the same
  implicit-transaction-with-rollback-on-failure machinery every other
  mutation already has).
* Public C API: `oep_object_update_content`/`oep_object_get_content`
  (owned-heap-string convention, released via the existing
  `oep_string_release`). `OEP_API_VERSION` 19→20, `OEP_ABI_VERSION`
  unchanged at 1 — no existing struct touched, purely additive.
* Full test coverage: `tests/runtime/runtime_service_tests.cpp` (content
  update preserves other fields, participates in transactions, fails
  cleanly for unknown objects), `tests/api/oep_api_tests.cpp` (C API
  round-trip, ownership, error paths). **Verified via a real rebuild:
  62/62 CTest suites passing**, both before and after.

### Native bridge build — a real, previously-undiscovered defect found and fixed

Getting `oep_foundation_bridge.dll` current required actually rebuilding
it for the first time this session (a working MSVC toolchain — VS Build
Tools 18 — was located and used). This surfaced two genuine, pre-existing
defects, not introduced by this phase:

* `native/foundation_bridge/CMakeLists.txt`'s module list referenced a
  nonexistent `platform/exchange` directory and was missing `archive`/
  `installer` (both real, required dependencies of `runtime` today) —
  the configure step failed outright before this fix, meaning this DLL
  could not have been successfully rebuilt in its prior state.
* `oep_foundation_bridge.def` (the DLL's explicit export list) covered
  only 38 of `oep_api.h`'s 168 declared functions — including the exact
  `oep_object_update`/`oep_object_delete` functions this session's own
  earlier platform architecture review flagged as a real Studio FFI
  gap. Regenerated in full, programmatically, from every `extern "C"`
  declaration in the header.

Both fixed and verified: a clean MSVC rebuild now succeeds, and all 168
functions are confirmed present in the DLL's export table via
`dumpbin /exports`, including both new content functions and the
previously-missing object/relationship update/delete functions.

### Studio-side FFI bindings (`oep_api_bindings.dart`/`foundation_bridge.dart`)

Six new bound functions: `oep_object_update_content`/
`oep_object_get_content` (new this phase) plus `oep_object_update`/
`oep_object_delete`/`oep_relationship_update`/`oep_relationship_delete`
(existed in the C API since Work Package 014, never bound in Dart until
now — closing a gap this session's own platform snapshot review
explicitly flagged: "Studio currently cannot update, delete... objects/
relationships"). Verified: `flutter analyze` clean on the bindings file
and the full project.

### `DiagramRepositoryService` (`lib/diagram_studio/repository/`)

The actual save/load/migrate implementation, consuming `FoundationBridge`
exclusively (never repository internals, never SQL, never a transaction
bypass). See `ENGINEERING_MAPPING.md` for the full node/relationship/
diagram mapping design and its honest limitations (decomposed objects
regenerated not diffed; no Project↔Diagram `Contains` relationship yet).
`FoundationBridgePort` (the `oep_engine`-side abstract interface named in
AP-DS-001's own architecture review) was investigated (its backing ADR-004
read) but is NOT what this phase implements against — it has zero
consumers anywhere in the codebase and Studio's own `FoundationBridge`
FFI layer was the more direct, already-proven integration point.
Implements `LegacyMigrator` for AP-DS-002's Migration requirement
(automatic conversion, verification via reload-and-compare, error
reporting, and a disclosed limitation around cross-step transaction
atomicity — see `MIGRATION_GUIDE.md`).

### Repository/Project Browser, Package management UI

Built by a separate, parallel effort. Extended `project_explorer_page.dart`
(rather than duplicating it) with an "Open from Repository" entry point
and a Recent Projects branch (`recent_projects_storage.dart`, mirroring
AP-DS-001A's `recent_files_storage.dart` pattern exactly). New
`package_manager_page.dart`/`package_validation_dialog.dart` wired into
the previously-placeholder `packages_page.dart` route, consuming
Foundation's already-existing, already-bound installer/trust/validation
FFI calls — confirmed this was mostly UI wiring over already-working
capability, not new integration work, per the spec's own "no networking,
no Exchange integration" constraint. New `legacy_migration_dialog.dart`
presents `LegacyMigrationResult` honestly (surfaces `errorMessage`/
`rolledBack` explicitly, never a generic toast).

**Gap found and disclosed, not fixed**: `foundation_bridge.dart` has no
bound Create/Save-package (authoring) calls, only `installPackage`
(consumes an existing archive) plus registry/trust/verify reads — so
"Create Package"/"Save Package" (named in the spec) have no UI-callable
backend yet. Flagged as a real, scoped follow-up item, not silently
worked around.

### Testing

Foundation: see above, 62/62 CTest suites. Studio: 491 tests total
passing (488 + 2 pre-existing skips + 3 new content-envelope round-trip
tests in this final integration pass), up from a 474/2 baseline at the
start of this phase — 14 tests from the UI layer, 3 from the persistence
layer, zero regressions. `flutter analyze` clean throughout (2
pre-existing, unrelated infos in `foundation_runtime_service.dart`).
`DiagramRepositoryService` itself is not directly exercised by
`flutter test` (no test in this codebase loads the real native
library) — its pure-Dart serialization logic is tested directly instead
(`test/diagram_repository_service_content_test.dart`); genuine
end-to-end verification against a real repository requires a live
`flutter run`, disclosed as a real coverage gap rather than assumed
covered.

### Exit criteria — honest assessment against the spec's own list

✓ Engineering Objects become part of the canonical document model (real
nodes/relationships, not just a blob) — done, with the disclosed
regenerate-not-diff limitation. ✓ Repository-backed projects operational
— done. ✓ Migration implemented — done, with the disclosed cross-step
transaction limitation. ✓ Existing editor workflows unchanged — the
canvas/rendering/commands/selection/editing/toolbars/panels were not
touched by this phase, per its own scope constraint. ✓ RuntimeService/
FoundationBridge used exclusively — verified, no repository-internals
access anywhere in the new code. ✓ Tests passing — verified directly,
491/491 (Studio) + 62/62 (Foundation). **Partial**: "Local JSON
persistence removed from production workflows" — local JSON is NOT
removed; it remains the legitimate format for AP-DS-001A's Autosave/
Recovery mechanism and the migration source format. Read literally as
"delete `DiagramDocument`," this criterion is not met and should not be
claimed as met; read as "repository-backed persistence is now the
primary save/open path, with local JSON serving only its own narrower,
still-legitimate purposes," it is met — this document states the more
literal reading honestly rather than picking the flattering
interpretation.

## AP-DS-003 — Engineering Intelligence Workspace

Connected Diagram Studio to the Engineering Intelligence Platform (EIP)
for live validation, analysis, reasoning, and recommendations, per
`docs/tasks/AP-DS-003.md`. Full design rationale:
`docs/architecture/diagram_studio/ENGINEERING_WORKSPACE.md`. Delivered
in three parts, all independently verified in this session on the
actual final disk state (not taken on any single agent's report — see
the verification note below on a real file-collision risk that was
checked and confirmed benign).

### `DiagramIntelligenceService` (`lib/diagram_studio/intelligence/`)

Built directly (not delegated) as the architecturally load-bearing
piece: the sole point of contact with EIP, containing zero validation/
analysis/reasoning/recommendation logic of its own — every call
forwards to `FoundationBridge`'s already-bound `oep_eip_*` wrappers
(`eipValidate`/`eipAnalyze`/`eipReason`/`eipRecommend`/`eipQuery`/
`eipInspect`, all existing since WP-EKE-008, none newly bound this
phase). Manages one Knowledge Session per open diagram, a debounced
(800ms) sync path (`scheduleSync`) distinct from `DiagramRepositoryService.
saveDiagram`, and the only translation point between canvas node ids
and Foundation object ids (`objectIdFor`/`nodeIdFor`).

`DiagramRepositoryService` gained `syncForIntelligence` — the same
transaction-wrapped create/update-and-decompose logic `saveDiagram`
already had, exposed as a second, automatically-triggered entry point
so live feedback doesn't depend on the user completing AP-DS-002's
still-open document-bar Save wiring.

### Canvas overlay and page wiring (`diagram_studio_page.dart`, `panels/diagram_intelligence_overlay.dart`)

Validation error/warning markers and a distinct analysis-highlight
glow, positioned using the same pan/zoom transform math the canvas
already uses. `_markDirty()` (all ~30 call sites) now also triggers
`scheduleSync`; a new "Validate Now" toolbar button triggers an
immediate sync+validate. Selection sync (`_selectAndFrameNode`) mirrors
the pre-existing `_goToSearchResult` pattern.

### Five embedded panels (`lib/diagram_studio/panels/`)

`recommendation_panel.dart`, `engineering_explorer_panel.dart`,
`knowledge_graph_panel.dart`, `query_console_panel.dart`,
`knowledge_sessions_panel.dart`, plus shared rendering widgets
(`intelligence_panel_shared.dart` — `IntelligenceResultSummary`/
`IntelligenceObjectChips`/`IntelligenceBusyBar`) — each adapting the
pre-existing read-only `lib/engineering_intelligence/pages/*` (built
WP-EKE-008) rather than reinventing rendering from scratch.
`knowledge_sessions_panel.dart` is the one panel taking
`FoundationBridge` directly (session lifecycle is deliberately not
wrapped by `DiagramIntelligenceService`).

### A real coordination risk, checked and confirmed benign

Two parallel background agents (canvas-overlay/wiring, and the five
panels) were both instructed to build against the same interface and,
as a genuine consequence of running concurrently, both wrote to the
exact same panel file paths — a real file-collision risk, not a
hypothetical one. Verified directly rather than trusted: `git status`
confirmed only one version of each file exists on disk; a fresh,
independent `flutter analyze` (clean) and full `flutter test` run
(**503/505 passing, 2 pre-existing skips**) against the actual final
disk state confirmed the two agents' concurrent writes converged into
a mutually compatible whole (both built to the same pre-specified
interface, so whichever file "won" the race was compatible with the
other agent's wiring). Spot-checked specific claims from both reports
(`_scheduleIntelligenceSync`, `_validateNow`, `DiagramIntelligenceOverlay`
usage, `IntelligenceResultSummary`/`IntelligenceObjectChips`/
`IntelligenceBusyBar` naming) directly in the source rather than
assuming either report was accurate.

### Testing

`test/diagram_intelligence_overlay_test.dart` (6 tests — marker count,
exact pan/zoom positioning math, tap callback, missing-layout-entry
safety), `test/intelligence_panels_test.dart` (6 tests — shared widget
rendering, the knowledge graph panel's radial layout). Consistent,
disclosed gap with `DiagramRepositoryService`'s own precedent:
`DiagramIntelligenceService` and the 5 panels' live-data paths cannot
be exercised under `flutter test` (no test in this codebase loads the
real native DLL) — what's tested is pure rendering/positioning logic
given synthetic data, not real EIP round-trips.

### Known limitations (disclosed, not hidden — full list in `ENGINEERING_WORKSPACE.md`)

1. The local structural `DiagramValidationPanel` and EIP's
   `ValidationEngine` remain two separate systems sharing a confusingly
   similar name — not merged or renamed this phase.
2. True cross-isolate async FFI dispatch was not attempted;
   responsiveness comes from debouncing, not parallelism.
3. Live EIP latency at interactive scale has not been profiled (the
   same headless-proxy limitation `PERFORMANCE_REPORT.md` already
   disclosed applies here too).
4. `RecommendationPanel`'s fields are limited to what `OepWorkflowResult`
   actually returns (a summary string + related object ids) — coarser
   than a literal reading of the spec's five-bullet field list might
   imply.
5. AP-DS-002's document-bar Open/Save gap remains open;
   `syncForIntelligence` works around it for the intelligence-feed
   purpose only, it does not close it.

## AP-DS-004 — Engineering Publishing & Deliverables

Delivered a complete publishing pipeline per `docs/tasks/AP-DS-004.md`.
Full design rationale:
`docs/architecture/diagram_studio/PUBLISHING_AND_DELIVERABLES.md`.
Built in two parts (report-generation core, by me directly; diagram
rendering + Studio publishing UI, by two parallel agents), all
independently verified against the actual final disk state.

### Report-generation core (`oep_engine/lib/core/publishing/`, `core/exporters/shared/`)

Built directly (not delegated), matching this session's established
pattern of personally building the architecturally load-bearing piece
before delegating: `TitleBlock`/`RevisionEntry` data models,
`TabularReport` (a generic rows/columns shape with `sortedBy`/
`filtered`/`groupedBy`/`withCustomColumn`), and six report generators
(`BillOfMaterialsGenerator`, `WireReportGenerator`,
`ConnectorReportGenerator`, `HarnessReportGenerator`,
`RelationshipReportGenerator`, `EngineeringObjectReportGenerator`) —
each a pure function over `EngineeringGraph`(+`DiagramLayoutState`),
with real, disclosed data-model limitations documented in code
(Connector Reports can only report node-level, not per-pin,
connectivity; Wire Report lengths for auto-routed wires are
straight-line approximations). Plus `TabularReportRenderer`
(CSV/Markdown, hand-rolled, no dependency) and
`TabularReportPdfRenderer` (PDF, using the newly-added `pdf` package —
see `oep_engine/pubspec.yaml`'s own justification comment for why this
specific dependency was added, matching CLAUDE.md's "Dependencies"
reasoning). 9 tests (`test/publishing/report_generators_test.dart`),
verified via direct rebuild: 219/219 baseline unaffected, 228/228 with
the new tests (later 231 after the parallel diagram-rendering agent's
additions).

### Diagram-drawing rendering (`oep_engine/lib/core/exporters/{pdf,svg,png}/`)

A parallel agent completed the previously-empty PDF/SVG scaffold
directories (confirmed empty since AP-DS-001's own architecture
review) plus new PNG export: true vector PDF (`pw.Canvas`, not a
rasterized widget-tree screenshot) and hand-rolled SVG XML (no new
dependency), both honoring `DiagramLayer.printVisible`; PNG via
`dart:ui` rasterization at configurable DPI. `ExportRequest` gained an
additive, nullable `layout` field (verified: existing callers like
`JsonExportProvider` unaffected). `DrawingPackagePdfRenderer` composes
one diagram page + selected report pages into one PDF — explicitly
disclosed as "one diagram + selected reports," not a true multi-sheet
Drawing/Installation/Service Package (this platform has no multi-sheet
document model — a limitation already on record since AP-DS-001).
12 new tests (`test/exporters/diagram_export_test.dart`).
**Independently re-verified in this session**: 231/231 tests passing,
clean `flutter analyze`, matching the agent's own report exactly.

### Studio publishing system (`oep_studio/lib/diagram_studio/publishing/`)

A second parallel agent built: `PublishingCenterDialog` (the single
entry point, reachable via a new "Publishing…" button in the document
bar), `title_block_editor_dialog.dart`/`title_block_storage.dart`
(full field + revision editor; persisted in a dedicated
`title_blocks.json` keyed by file path — a deliberate design decision
documented in `PUBLISHING_AND_DELIVERABLES.md`, not folded into
`DiagramDocument`'s envelope, to stay additive and zero-risk to the
actively-used document schema), `tabular_report_dialog.dart` (UI over
the six `oep_engine` generators), `intelligence_reports.dart`
(Validation/Reasoning reports — calls `DiagramIntelligenceService`
only, never computes findings/conclusions locally, and explicitly
discloses in the UI which spec-named fields the underlying API doesn't
provide rather than fabricating them), `engineering_summary.dart`
(a genuine structural rollup, not padding), `package_manifest.dart`,
and `exchange_checklist.dart` (local readiness checklist — **verified
directly**: no networking/upload code exists anywhere in these files).
Added the `printing` package dependency for print-preview UI.

### A real gap found during independent verification, and closed directly

`DiagramPrintPreviewDialog` (the diagram print-preview dialog) was
built and unit-tested standalone by the Studio agent, but was **never
actually wired to a reachable UI entry point** — `PublishingCenterDialog`
had 5 tabs (Title Block/Reports/Intelligence Reports/Summary/Exchange)
and no "Print" tab; a doc comment referenced a `_printDiagram` method
that didn't exist anywhere in the file. This was found by independently
grepping for the dialog's actual call sites after the agent's report
claimed printing was "reachable from here" — it wasn't. Fixed directly:
added a sixth "Print" tab wiring `DiagramPrintPreviewDialog.show` to a
real `PdfExportProvider()` instance, plus a new test
(`publishing_center_dialog_test.dart`) asserting the trigger is
genuinely enabled, not merely present. This is recorded here explicitly
as a concrete instance of why every phase in this project has been
independently re-verified against the actual disk state rather than
trusted from a single report — a report can be accurate about what was
built and still wrong about whether it's reachable.

**A second, more structural issue found during this same verification
pass**: after adding the Print tab, a full-suite rerun showed all 5
tests in `publishing_center_dialog_test.dart` failing with
`PathAccessException: Cannot delete file... being used by another
process` on `title_blocks.json`, reproducible twice in a row even with
the file confirmed absent immediately beforehand. Root-caused as a
genuine cross-file test-isolation bug, not a timing fluke: three
separate test files (`title_block_storage_test.dart`,
`title_block_editor_dialog_test.dart`, `publishing_center_dialog_test.dart`)
all read/wrote the SAME real global `%APPDATA%/oep_studio/title_blocks.json`
path, and `flutter test`'s default cross-file parallelism ran them
concurrently against that one shared file. An initial retry-based
`tearDown` fix masked the symptom but not the cause — a second
failure surfaced moments later in a different one of the three files,
confirming a race, not a fluke. **Fixed at the root**: added
`TitleBlockStorage.testRootOverride`/`TitleBlockPresetStorage.
testRootOverride` (a test-only, nullable static field, defaulting to
the real path in production) and updated all three test files to set
it to their own private `Directory.systemTemp.createTempSync(...)` in
`setUp`/clear it in `tearDown` — the same per-test-file isolation
convention `diagram_document_test.dart` already established elsewhere
in this codebase. Re-verified twice: all 32 publishing tests passing
together (confirmed genuinely concurrent via interleaved test output),
and the full 535-test suite passing twice in a row.

### Testing

`oep_engine`: 21 new tests (9 report generators + 12 diagram export).
`oep_studio`: 32 new tests (31 from the Studio agent + 1 from the Print
tab fix). **Final independently-verified totals**: `oep_engine`
231/231 passing, clean analyze; `oep_studio` 535/535 passing (533 + 2
pre-existing skips), clean analyze (2 pre-existing unrelated infos).
Consistent, disclosed gap with every other FFI-dependent area of this
codebase: `DiagramIntelligenceService`/`FoundationBridge`-backed live
behavior isn't exercised under `flutter test`.

### Known limitations (disclosed, not hidden — full list in `PUBLISHING_AND_DELIVERABLES.md`)

1. Drawing/Installation/Service "Package" deliverables remain bounded
   by the single-diagram document model.
2. Page Setup dialog and Multiple Sheets/Entire Project/Entire Package
   print modes not built.
3. Connector Reports report node-level, not per-pin, connectivity.
4. Auto-routed wire lengths are straight-line approximations.
5. Title blocks are keyed by file path in local settings storage, not
   embedded in the document file.
6. Package-level Exchange validation (AP-DS-002) isn't yet surfaced in
   the Exchange checklist specifically.
7. Templates/Document Management beyond an unwired named-preset
   storage layer were not built.
8. 100,000-object publishing performance was not benchmarked.
9. Symbol Library artwork is not embedded in exported drawings (nodes
   render as a labeled box) — the on-screen renderer depends on
   Flutter asset-bundle loading the headless export path doesn't use.

---

## Work Package WP-DS-005A — Engineering Instruments Framework & Digital Multimeter

Status: Implemented (real subset — see "What Is Explicitly Not
Implemented" below; every gap is a disclosed deferral, not a silent
omission).

### What Exists

* **Engineering Instruments Framework** (`lib/diagram_studio/instruments/core/`):
  `EngineeringInstrument` (id/title/icon/shortcut label/`buildPanel`)
  and `InstrumentRegistry` (register/unregister/lookup,
  `ChangeNotifier`-based). Zero engineering computation lives here or
  anywhere else in the Instruments Framework — every reading is
  requested from `DiagramSimulationService.measure` (a thin
  pass-through to the real `SimulationEngine.measure`/
  `MeasurementEngine`, `oep_engine`).
* **Instrument Dock** (`lib/diagram_studio/instruments/dock/`): bottom
  dock, floating window (in-app movable/resizable surface — see
  `instrument_dock.dart`'s doc comment for the disclosed "not a real OS
  window" scope), resize (drag grip), auto-hide (collapses to a tab
  strip), multi-instrument tabs, layout persistence
  (`instrument_dock_layout.json` under `SettingsStorage.root()`, same
  shape as `WorkspaceStateStorage`). `DockPosition.left`/`.right` are
  modeled in persisted state but currently render as the bottom dock —
  disclosed, not a half-built side-dock layout.
* **Digital Multimeter** (`lib/diagram_studio/instruments/multimeter/`):
  every `MeasurementType` wired to the real engine; the type dropdown
  shows `capacitance`/`temperature` disabled with "not yet supported"
  (the engine's own named future placeholders); full result readout
  (measured/expected/difference/path/power source/ground source/
  contributing relationships/timestamp/mode); Measure button async
  end-to-end.
* **Measurement Modes**: manual, expected, comparison (comparison is
  exactly `MeasurementResult.difference`, computed by the engine, never
  recomputed in Studio), live simulation (async `Timer.periodic` calling
  `measure()`, start/stop), historical (compare current result against a
  selected stored history entry — local diff of two already-computed
  values, no new engine call).
* **Continuity Mode + path highlighting**: continuity/open-circuit/
  shortest-path results feed `MultimeterController.highlightedPathNodeIds`
  straight into `SimulationStateOverlay.propagationPathNodeIds` — reuses
  that overlay's existing path-highlight rendering rather than a second
  implementation.
* **Probe System** (`lib/diagram_studio/instruments/probe/`): two
  independent probes (black = A, red = B), click-to-place (via the
  canvas's own existing `onNodeTap` handler — no second hit-tester),
  drag-to-snap (nearest-node distance search over the same
  `DiagramLayoutState.positions` map every other canvas overlay reads).
  Snaps to node level only — pin/connector/wire-segment/terminal-level
  snap targets are deferred (see below).
* **Measurement History** (`lib/diagram_studio/instruments/history/`):
  JSON persistence (`measurement_history.json`), replay (restores a
  stored result/probes without a new engine call), clear, export (pretty
  JSON string).
* **Measurement Bookmarks** (`lib/diagram_studio/instruments/bookmarks/`):
  named + grouped bookmarks, JSON persistence
  (`measurement_bookmarks.json`), quick recall (restores probes + type).
* **Engineering Integration (light touch)**: `MultimeterController.
  relatedFindings(VerificationReport)` filters findings whose `nodeId`
  lies on the current measured path — read-only, no recomputation.
* **Integration**: `DiagramStudioPage` creates one
  `InstrumentRegistry`/`InstrumentDockController`/`MultimeterController`
  per diagram (mirrors `DiagramSimulationService`'s "one per diagram"
  pattern), registers the Digital Multimeter, renders `InstrumentDock`
  layered over the whole page, wires probe-arm buttons + `Ctrl+M` dock
  toggle into the existing toolbar/shortcut infrastructure.
* **Performance**: every measurement — including each Live Simulation
  tick — goes through `DiagramSimulationService.measure`, which returns
  a `Future`; there is no synchronous engine call anywhere in the
  Instruments Framework, live mode included.

### What Is Explicitly Not Implemented

Per this work package's own "real, working subset over a half-working
everything" instruction:

1. Only the Digital Multimeter instrument was built. Oscilloscope,
   Logic Probe, Power Probe, CAN Analyzer, LIN Analyzer, Breakout Box,
   Signal Generator, Bench Power Supply, Clamp Meter are not built —
   the Framework is ready to register them, none exist yet.
2. Dock left/right placements are modeled but render as the bottom
   dock; "floating window" is an in-app surface, not a real second OS
   window.
3. Probe snapping resolves to nodes only, not pins/connectors/wire
   segments/terminals individually.
4. Hover Measurements (spec: hovering a wire/connector shows expected/
   measured/signal/power/ground state) were not built — out of time
   budget after the higher-priority items above.
5. Timeline synchronization / Pause / Step / Replay for Live Simulation
   mode beyond simple start/stop were not built — only continuous
   polling start/stop exists.
6. Engineering Integration beyond the Verification-findings light touch
   (Diagnostics/Reasoning/Recommendations/Publishing/Reports
   referencing a measurement) was not built.
7. Repository Integration: measurements are transient (in-memory) plus
   local-JSON-persisted (history/bookmarks) only — Repository-backed
   persistent measurement/inspection/verification records were not
   built.
8. History/Bookmarks are Studio-wide (one JSON file each), not scoped
   per diagram document.
9. Performance was not benchmarked under load (no measured "N
   measurements/sec with no frame drop" number) — only the architectural
   claim (`measure()` always returns a `Future`, tested) is verified.

### Testing

`oep_studio`: 37 new tests under `test/instruments/` — instrument
registry, dock state/storage/widget (docking tests), the Digital
Multimeter controller against a REAL `SimulationEngine` (measurement,
continuity path highlighting, comparison mode, live-mode timer
start/stop, history replay/export/clear, bookmark add/recall/remove,
related-findings filtering), history/bookmark storage round-trips
(real-file-with-cleanup, matching `WorkspaceStateStorage`'s own test
convention), the Digital Multimeter panel widget (unsupported-type
dropdown state, Measure button enablement, full result readout), and
the Probe overlay widget (marker rendering, click-to-place). All 37
pass. Full `oep_studio` suite re-run after integrating into
`diagram_studio_page.dart`: 584 passing (582 + 2 pre-existing skips),
`flutter analyze` clean (2 pre-existing unrelated infos in
`foundation_runtime_service.dart`).

