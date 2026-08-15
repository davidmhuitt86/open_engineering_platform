# Studio Settings

Work Package 017 (STUDIO-TASK-000050 through STUDIO-TASK-000055) implements
the Studio Settings Workspace defined by SDD-023 (Studio Configuration
Architecture): a dedicated Studio Workspace, a provider registration
framework, versioned/migrated persistence, and full-text search — with
eleven core pages, most containing real, validated, persisted settings,
and a few containing honest placeholder controls where the underlying
functionality (docking, plugins, multi-monitor awareness, and so on)
doesn't exist yet.

No Foundation changes. No Public C API changes. No AI provider
integration. No Plugin implementation. This work package builds only the
framework future subsystems register into.

## Settings Architecture

Four layers, mirroring the Widgets/Services/Controllers/Connection
Manager separation this work package's own instructions require:

```
Settings Workspace (widgets)
        |
SettingsController (Riverpod Notifier — the draft UserConfiguration)
        |
SettingsService (orchestration: load / save / reset / export / import)
        |
SettingsStorage (I/O) + SettingsMigrationService (pure) + SettingsValidationService (pure)
```

- **Widgets** (`lib/settings/workspace/`, `lib/settings/pages/`,
  `lib/settings/widgets/`) never touch `SettingsService` or
  `SettingsStorage` directly. They read `SettingsControllerState` and
  call one of `SettingsController`'s per-field update methods.
- **`SettingsController`** (`lib/settings/controllers/settings_controller.dart`)
  is a *separate* Riverpod `Notifier` from `FoundationRuntimeNotifier`
  (the Connection Manager). It owns the in-memory *draft*
  `UserConfiguration` being edited, alongside the last-persisted
  `savedConfiguration` it loaded (or last saved) from —
  `SettingsControllerState.isModified` is a structural comparison of the
  two (`jsonEncode(configuration.toJson()) != jsonEncode(savedConfiguration.toJson())`),
  not a separately-tracked mutable flag.
- **`SettingsService`** (`lib/settings/services/settings_service.dart`)
  orchestrates `load`/`save`/`resetToDefaults`/`exportToJson`/`importFromJson`,
  tying storage, migration, and validation together — mirroring the same
  storage/pure-service/orchestrator split Work Package 013's OCR pipeline
  established (`TesseractOcrEngine`/`OcrCacheService`/`OcrPipelineService`).
- **`SettingsStorage`** (`lib/settings/services/settings_storage.dart`)
  is the only place that touches `dart:io`, reading and writing one file:
  `%APPDATA%/oep_studio/settings.json`. Unlike Knowledge Sessions (one
  directory per session), there is exactly one User Configuration per
  Studio installation.

### Connection Manager's role

Per this work package's own explicit instruction ("Connection Manager
coordinates application state only"), `FoundationServiceState` gained
exactly three fields — pure navigation/UI coordination state, not the
settings content itself:

| Field | Purpose |
|---|---|
| `currentSettingsPageId` | Which Settings page is visible (a `CoreSettingsPageIds` constant, or a future provider's own id) |
| `settingsSearchQuery` | The Settings Workspace's current search text |
| `settingsModified` | Mirrors `SettingsControllerState.isModified`, synced by the Settings Workspace widget via `ref.listen`, so other parts of the shell can read "there are unsaved settings changes" without importing `lib/settings` |

`FoundationRuntimeNotifier` gained three corresponding setters:
`setCurrentSettingsPage`, `setSettingsSearchQuery`, `setSettingsModified`.
None of the eleven pre-existing `select*` mutual-exclusion methods needed
changes — these three fields are independent UI state, not part of the
Property Inspector's one-selection-at-a-time group (Property Inspector
itself needed **no changes** for this work package, per its own explicit
instruction).

### Configuration scope

SDD-023 defines four configuration scopes. This work package implements
persistence for exactly one of them:

| Scope | Persisted by | Status |
|---|---|---|
| **User Configuration** | `SettingsService` → `%APPDATA%/oep_studio/settings.json` | Implemented (this work package) |
| Repository Configuration | Would be stored with the repository | Out of scope — Foundation has no such API yet |
| Knowledge Session Configuration | `KnowledgeSessionRecord` | Already exists (Work Packages 008-016); untouched here |
| Runtime Configuration | `FoundationServiceState`'s own ephemeral fields | Already exists; the three new Settings-coordination fields above are additions to it |

## Registry

`SettingsRegistry` (`lib/settings/services/settings_registry.dart`) holds
every registered `SettingsProvider`, structurally identical to
`AiProviderRegistry` (Work Package 016): an ordered `List<SettingsProvider>`
wrapped once at construction, keyed by each provider's own `pageId`.
`SettingsRegistry.defaultRegistry` is seeded with the eleven core pages
in SDD-023's own listed order (General, Appearance, Workspace, Repository,
Knowledge Studio, Artificial Intelligence, Plugins, Updates, Diagnostics,
Security, About).

`SettingsProvider` (`lib/settings/services/settings_provider.dart`) is the
interface every page — core or future — implements:

```dart
abstract class SettingsProvider {
  String get pageId;
  String get label;
  IconData get icon;
  List<SettingsEntry> get searchEntries;
  WidgetBuilder get pageBuilder;
}
```

`pageId` is a plain `String`, not a closed `enum` — SDD-023 Navigation
explicitly allows "Future modules may register additional pages," and
STUDIO-TASK-000055 requires "The Settings Workspace shall not require
modification when new providers are added." A closed enum could never
admit a page id a future AI Provider or Plugin invents for itself, so
`CoreSettingsPageIds` (`lib/settings/models/settings_page_id.dart`) is
just a set of `static const String` constants for the eleven core pages,
exactly mirroring `AiProviderRegistry`'s own plain-`String` `providerId`
convention.

A future AI Provider or Plugin registers by constructing a
`SettingsRegistry` that includes its own `SettingsProvider` alongside the
core ones — the Settings Workspace widget itself never changes; it only
ever iterates whatever `SettingsRegistry.providers` it's given. See
`test/settings_registry_test.dart`'s `_FakeFuturePlugin` for a
demonstration.

## Search

`SettingsEntry` (`lib/settings/models/settings_entry.dart`) is one
searchable setting: `pageId`, `name`, `description`, `keywords`. Each
`SettingsProvider` builds its own list of entries; `SettingsRegistry.search(query)`
matches case-insensitively across all three fields (SDD-023 Settings
Search: "Search shall include: Setting Name, Description, Keywords").
Selecting a search result in the Settings Workspace calls
`setCurrentSettingsPage(entry.pageId)` and clears the search box —
"Selecting a search result navigates directly to the setting."

## Storage

`SettingsStorage.root()` resolves to `%APPDATA%/oep_studio/` (falling
back to `%LOCALAPPDATA%`, then the system temp directory), the same
resolution `KnowledgeSessionStorage` already uses, via `dart:io`/
`Platform.environment` directly rather than adding the `path_provider`
package — this is already a Windows-only desktop target, so a
cross-platform channel dependency would be dead weight (this project's
own minimal-dependency philosophy).

All I/O and parse failures are translated to a single `SettingsException`
with a professional message — never a raw `IOException`/`FormatException`
reaching the UI, mirroring `KnowledgeValidationException`'s own
one-type-many-messages precedent rather than introducing a separate
exception class per failure kind (Work Package 017 Error Handling:
"Invalid configuration / Corrupt configuration / Version mismatch /
Migration failure").

## Versioning & Migration

`UserConfiguration.schemaVersion` is written on every save.
`SettingsMigrationService.migrate(json)` (pure) resolves a raw JSON map
to `UserConfiguration.currentSchemaVersion` before `SettingsService.load`
ever calls `UserConfiguration.fromJson`:

- A file with `schemaVersion` already at the current version passes
  through unmigrated.
- A file with **no `schemaVersion` key at all** (hand-edited, produced by
  tooling that predates versioning, or otherwise foreign) is treated as
  schema `0` and upgraded by a registered step that backfills every
  missing top-level section as an empty map, letting
  `UserConfiguration.fromJson`'s own per-field defaulting take over from
  there.
- A `schemaVersion` **newer** than this build's
  `UserConfiguration.currentSchemaVersion` throws a version-mismatch
  `SettingsException` rather than guessing at a downgrade.
- Any unexpected failure inside a migration step is caught and rethrown
  as a `SettingsException` naming the failure explicitly.

If migration actually changed anything, `SettingsService.load` writes
the migrated file straight back to disk, so migration only ever runs
once per file.

This is the very first shipped schema
(`UserConfiguration.currentSchemaVersion == 1`), so there is no real
prior release to migrate *from* — the one registered step (0 → 1) exists
to prove the mechanism generically, not to model invented history. A
future work package that changes the schema adds a new
`1: (json) => ...` step to `SettingsMigrationService`'s `_upgraders` map;
the engine itself (`migrate`) does not change. See
`test/settings_migration_service_test.dart`.

## Persistence

`SettingsValidationService.validate(UserConfiguration)` (pure) runs
before every `SettingsService.save` — collecting every violation rather
than stopping at the first, so a caller can report the complete list in
one message. Nothing invalid is ever written (SDD-023 Validation:
"Invalid values shall never be written").

`SettingsService.exportToJson`/`importFromJson` implement SDD-023 Import
/ Export. No sub-model of `UserConfiguration` has a credential field —
export is secret-free by construction, and there is nothing to strip.
Import parses, migrates, and validates but does **not** save on its own;
the caller (the Settings Workspace's "Import" button) decides whether to
follow up with an explicit Save.

## Core Settings Pages

All eleven pages exist and are reachable (STUDIO-TASK-000052: "The page
architecture shall be complete"). Most bind real, validated, persisted
fields; a few contain `SettingsPlaceholderRow` controls (disabled, with a
"Not yet implemented" helper) where the underlying subsystem doesn't
exist yet:

| Page | Real, persisted | Placeholder |
|---|---|---|
| General | Language, Region, Units, Date/Time Format, Autosave, Startup Behavior, Logging | — |
| Appearance | Theme, Accent Color, Density, Font/Icon Size, Animations, Workspace Scaling | Values don't yet re-theme the app — `StudioTheme` remains Studio's single ratified dark theme |
| Workspace | Default Workspace path, Window Behavior, Restore Layout | Recent Workspaces (nothing tracks visit history yet), Docking, Multi-monitor |
| Repository | Default Repository path, Auto-open, Cache, Validation Defaults | Backup, Snapshots |
| Knowledge Studio | Autosave preference, OCR Overlay default, Evidence Colors, Default Zoom, Context/Entity Display, Review Preferences | These are stored preferences not yet consumed by the actual Knowledge Studio workspace (Work Packages 007-016) |
| Artificial Intelligence | Enable AI, Provider (real dropdown from `AiProviderRegistry`), Model id, API Key (real, via `CredentialStore` — Work Package 018), Temperature, Timeout, Max Tokens (Work Package 018), Test Connection (real, via the Connection Manager — Work Package 018), Reasoning Depth, Privacy Controls | Context Window (informational only — not a configurable request parameter), Local Server Configuration (future Ollama/LM Studio) |
| Plugins | Enable Plugins toggle | Installed Plugins (always empty — no install mechanism), Permissions, Updates, Marketplace |
| Updates | Automatic Updates, Update Channel | No updater component exists yet — values are stored for a future release |
| Diagnostics | Foundation Runtime / Studio Runtime (live, read-only, from the Connection Manager) | Performance/Memory/GPU Monitoring, Reset Studio (a full reset is a destructive action out of this work package's scope — use "Reset Defaults" for Settings only) |
| Security | Credential Storage backend (descriptive), Privacy Mode | Certificate Management, Encryption at Rest — the page also states, truthfully, that no secret exists anywhere in Studio today |
| About | Studio Version, Foundation/API/ABI Version (live), License, Third-party Notices | — |

## Architectural Observations

- **`SettingsPageId` was redesigned mid-implementation from a closed
  `enum` to plain `String` constants (`CoreSettingsPageIds`).** SDD-023
  Navigation says "Future modules may register additional pages," which
  a closed enum cannot satisfy — a future AI Provider or Plugin needs to
  be able to introduce a page id Studio's own code was never written to
  enumerate. This mirrors `AiProviderRegistry`'s own plain-`String`
  `providerId` design (Work Package 016) for the identical reason. Not a
  blocking conflict — corrected before any other code was built on top of
  the wrong abstraction.
- **`SettingsProvider.pageBuilder` returns a `Widget`, on an interface
  that lives in `lib/settings/services/`.** This could look like a
  service constructing UI, which this project's layering otherwise
  avoids. It isn't: the registry never calls `pageBuilder` itself or
  inspects what it returns — it only holds the reference for the
  Settings Workspace shell (a widget) to invoke, the same pattern
  `GoRoute.builder` already uses in `lib/core/routing/app_router.dart`.
  "Core Studio shall not contain subsystem-specific code" (SDD-023 still
  holds: the Settings Workspace shell has zero knowledge of what's
  inside any page's widget tree.
- **Most settings are "real" (validated, persisted, versioned,
  migrated) but several have no observable effect on Studio's behavior
  yet** — Appearance's Theme/Density/Font Size, Knowledge Studio's
  display preferences, all of Artificial Intelligence and Plugins, and
  more. This is the literal shape of STUDIO-TASK-000052's own
  instruction ("Pages may initially contain placeholder controls where
  functionality is not yet implemented. The page architecture shall be
  complete.") — the *framework* (storage/validation/versioning/search/
  registry) had to be genuinely complete and provably correct now, while
  wiring each individual preference into the subsystem it describes is
  each subsystem's own future work, done through the registry rather
  than by modifying the Settings Workspace.
- **Artificial Intelligence's page was deliberately decoupled from
  `AiProviderRegistry` in Work Package 017** — scoped "yet," pending the
  first production provider. **Work Package 018 supersedes that
  decoupling on purpose**: its own instructions explicitly require
  "Provider Selection" integration, and `AnthropicProvider` is that
  first production provider. The Provider field is now a real dropdown
  sourced from `AiProviderRegistry.defaultRegistry.availableModels`; the
  API Key field is real, backed by `CredentialStore` (`lib/core/security/`);
  Test Connection is real, via the Connection Manager. See
  `docs/ANTHROPIC_PROVIDER.md`.
- **"Reset Studio" (Diagnostics) is a placeholder, not a real
  reset-everything action.** Wiping all local Studio state (every
  Knowledge Session, the settings file, caches) is destructive and
  irreversible, well beyond "Reset Defaults" (which only ever resets the
  User Configuration this work package owns) — implementing it was not
  requested and would be a unilateral, hard-to-reverse addition.

None of the observations above blocked implementation — each had a
reasonable literal reading available and none constituted the kind of
genuine, irreconcilable architectural conflict this work package's
instructions say to stop for.
