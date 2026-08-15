# WP-STUDIO-021 — Studio Registry Framework

Repository: `projects/platform/oep_studio`

## 1. Objective

Create the Platform Studio Registry: a single authoritative source for Navigation, Routing, Search Providers, Settings Providers, and Studio Metadata. Refactor the existing implementation so that Knowledge Studio, Diagram Studio, and Engineering Acquisition Studio register through this framework, with all existing behavior preserved exactly. No Platform redesign, no Studio redesign, no plugin system or dynamic loading.

## 2. Architectural Review — Dependency Map

Before this Work Package, a Studio's presence in the Platform was assembled by hand, once per concern, in four separate files that had to be kept in sync manually:

| Concern | File | Mechanism |
|---|---|---|
| Studio Metadata (label/path/icon) | `lib/core/routing/studio_destination.dart` | `StudioDestination` enum, 13 values |
| Routing | `lib/core/routing/app_router.dart` | One hand-written `GoRoute` per `StudioDestination`, inside a single `ShellRoute` |
| Navigation (rail rendering) | `lib/app/widgets/studio_nav_rail.dart` | `for (final destination in StudioDestination.values)` |
| Settings Providers | `lib/settings/services/settings_registry.dart` | `SettingsRegistry.defaultRegistry`, a hand-written list of 13 `SettingsProvider` constructors (10 core + 3 Studio-owned) |
| Search Providers | `lib/features/search/unified_search_service.dart` | `UnifiedSearchService.search()`, three hand-written blocks (Foundation/Knowledge, Engine/Diagram, EAM/Acquisition), hardcoded in that order |

**Consumers, not registration sites** (verified by a repo-wide grep of `StudioDestination.`, 13 files): `unified_navigation.dart`, `explorer_navigation.dart`, `evidence_navigation.dart`, `project_explorer_page.dart`, `repository_page.dart`, `objects_page.dart`, `relationships_page.dart`, `search_page.dart`, `recent_history_entry.dart`, `workspace_settings.dart`. Each of these only reads `StudioDestination.xxx.path`/`.label` to navigate or label a history entry — none of them assemble a Studio's registration, so none needed to change.

**Key finding informing the design**: only 3 of the 13 `StudioDestination` values (`knowledge`, `diagram`, `acquisition`) are "Studios" in the PAIS-001 sense and carry both a `SettingsProvider` and a search contribution; the other 10 are core Platform pages with a route and a rail entry but no settings/search hook of their own (e.g. "Settings" itself has no `SettingsProvider` — it's the page that renders `SettingsRegistry`). The registry design keeps that distinction as optional fields rather than forcing every destination into a full "Studio" shape.

## 3. Studio Registry Architecture

New file: [lib/core/routing/studio_registry.dart](lib/core/routing/studio_registry.dart).

- **`StudioDescriptor`** — one per navigation destination: `{ destination: StudioDestination, pageBuilder, settingsProvider?, searchProvider? }`. Wraps the existing `StudioDestination` (still the single source of label/path/icon — unchanged) rather than duplicating its metadata.
- **`StudioSearchProvider`** typedef — `List<UnifiedSearchResult> Function(WidgetRef ref, String query, SearchScope scope)`.
- **`StudioRegistry`** — an ordered, immutable list of descriptors (`List.unmodifiable`, identical shape to the pre-existing `SettingsRegistry`), exposing:
  - `destinations` → consumed by `StudioNavRail`
  - `buildRoutes()` → consumed by `app_router.dart`
  - `settingsProviders` → consumed by `SettingsRegistry.defaultRegistry`
  - `searchProviders` → consumed by `UnifiedSearchService`
  - `descriptorFor(StudioDestination)` → lookup, available for future use (command palette, etc.)
- **`StudioRegistry.defaultRegistry`** — seeded with the same 13 destinations, in the same order, pointing at the same widgets/providers/search logic that were already hand-wired. A plain static compile-time list — no plugin loading, no reflection, no dynamic registration.

This is a composition-root pattern: one file now owns what four files used to own piecemeal. `StudioDestination` itself was not touched — it remains the identity/metadata primitive referenced everywhere else in the app.

## 4. Refactored Files

| File | Change |
|---|---|
| `lib/core/routing/studio_registry.dart` | **New.** `StudioDescriptor`/`StudioRegistry`, all 13 route builders, and the 3 search-provider functions moved verbatim from `UnifiedSearchService`. |
| `lib/core/routing/app_router.dart` | Route list replaced with `StudioRegistry.defaultRegistry.buildRoutes()`. All 13 page imports removed (moved to `studio_registry.dart`). `ShellRoute` wrapper unchanged. |
| `lib/app/widgets/studio_nav_rail.dart` | `StudioDestination.values` → `StudioRegistry.defaultRegistry.destinations`. |
| `lib/settings/services/settings_registry.dart` | The 3 Studio-owned provider constructions replaced with `...StudioRegistry.defaultRegistry.settingsProviders` spliced into the same position in the list. Direct imports of the 3 Studio settings pages removed. |
| `lib/features/search/unified_search_service.dart` | `search()` reduced to iterating `StudioRegistry.defaultRegistry.searchProviders`; all Foundation/Engine/Acquisition-specific logic and imports removed (moved to `studio_registry.dart`). |

No changes to `StudioDestination`, `StudioShell`, any Studio's own workspace/settings/panel code, Foundation, or `oep_acquisition`.

## 5. Test Results

- `flutter analyze`: 2 pre-existing informational lints in `foundation_runtime_service.dart` (unrelated to this Work Package, not touched). **0 issues in any changed file.**
- `flutter test`: **317/317 passed** (2 pre-existing, unrelated skips) — identical pass count to before this refactor, confirming zero behavior change, including `settings_registry_test.dart`'s exact-order assertion and `widget_test.dart`'s nav-rail walk.
- `flutter build windows`: succeeded (`build\windows\x64\runner\Release\oep_studio.exe`).

## 6. Recommendations for WP-STUDIO-022

- **Command Palette metadata source**: `StudioDescriptor.descriptorFor` and `.destinations` are now the natural place for a future Command Palette to enumerate "go to Studio X" commands, once one exists (still Category C from WP-PLAT-020 — not built here).
- **Settings ordering coupling**: `SettingsRegistry.defaultRegistry` still hand-places `...StudioRegistry.defaultRegistry.settingsProviders` between Repository and AI Settings by textual position — this is correct today (Knowledge/Diagram/Acquisition are contiguous in the registry) but would silently break if a future non-contiguous Studio ordering were introduced. Consider whether `SettingsRegistry` should instead read positions from a per-descriptor "settings group" field once a second such gap appears.
- **Search-provider placement**: the three search-provider functions currently live in `studio_registry.dart` itself rather than inside each Studio's own folder, to avoid a two-way import between `studio_registry.dart` and each Studio module. If a future Studio's search logic grows substantially, consider relocating its function to that Studio's own folder and having `studio_registry.dart` import only the function reference — `acquisition_runtime_service.dart`-style Notifier logic should stay Studio-owned; only the thin match/filter glue belongs at the registry.
- **`StudioDestination` consolidation**: not recommended. It is referenced by 13 files as a stable, cheap identity; folding it into `StudioDescriptor` would touch all of them for no behavioral gain and was explicitly out of scope here.
