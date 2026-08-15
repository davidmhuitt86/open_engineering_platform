# Studio Integration Guide

How the Engineering Exchange is integrated into OEP Studio as a native workspace (WP-EXC-010, `docs/tasks/WP-EXC-010.md`), for engineers working in either `oep_exchange` or `oep_studio`. This is Studio-side wiring only — no `exchange-api` route, service, or persistence behavior changed for this work package.

## Architecture

```
OEP Studio (Flutter/Dart desktop)
  Exchange Studio workspace (lib/exchange/)
    ExchangeApiClient (lib/exchange/services/exchange_api_client.dart)
  ↓
Exchange REST API (apps/exchange-api, unchanged)
```

Studio never embeds `apps/publisher-portal`'s React UI (no WebView infrastructure exists anywhere in `oep_studio`, and no other Studio integration in this codebase works that way). Instead, `lib/exchange/services/exchange_api_client.dart` is a hand-rolled Dart REST client mirroring `packages/exchange_client`'s own TypeScript SDK one-for-one — same five resources (`publishers`, `packages`, `search`, `installations`, `downloads`), same endpoints, same DTO field names (`camelCase`, read directly from JSON). This is the same "reuse the API, not the UI" pattern `oep_studio`'s existing Engineering Acquisition Studio already established against `oep_acquisition`.

## Where things live (`oep_studio`)

- `lib/exchange/models/` — Dart mirrors of `packages/api-contracts`' DTOs (`Publisher`, `ExchangePackage`, `SearchResultItem`/`ExchangeSearchResponse`, `Installation`), plus two Studio-only local-tracking models (`LibraryEntry`, `DownloadEntry` — see "Local state" below).
- `lib/exchange/services/exchange_api_client.dart` — the REST client. `exchange_api_exception.dart` translates non-2xx responses (parsing the Exchange's own `{"error": {"code","message","details"}}` envelope) and connection failures into a curated, professional message, mirroring `AcquisitionApiException`.
- `lib/exchange/services/exchange_runtime_service.dart` — `ExchangeRuntimeNotifier`, the Exchange Studio's Connection Manager (mirrors `AcquisitionRuntimeNotifier`): owns the one `ExchangeApiClient` instance, rebuilt whenever the settings address changes; every widget reads/calls through `exchangeRuntimeServiceProvider` — no widget constructs an `ExchangeApiClient` or calls `dart:http` itself.
- `lib/exchange/services/exchange_library_storage.dart` — persists My Library/Downloads history to `exchange_library.json` (see "Local state" below).
- `lib/exchange/settings/` — `ExchangeSettings`/`ExchangeSettingsStorage`/`ExchangeSettingsProvider` (the REST API address, default `http://127.0.0.1:3000/api/v1`), registered with the Settings Workspace exactly like Engineering Acquisition's settings page.
- `lib/exchange/workspaces/exchange_studio_page.dart` — the workspace shell: a connection banner (mirrors `AcquisitionStudioPage`'s), a left section rail (Marketplace Home / Search / My Library / Downloads), and a drill-down area that shows Package Detail or Publisher Profile when one is selected.
- `lib/exchange/panels/` — one widget per WP-EXC-010 §5 view: `exchange_marketplace_home_panel.dart`, `exchange_search_panel.dart`, `exchange_package_detail_panel.dart` (with inline Installation Progress), `exchange_publisher_profile_panel.dart`, `exchange_my_library_panel.dart`, `exchange_downloads_panel.dart`.

## Navigation, Settings, Search, Commands

Exchange is registered exactly the way every other Studio is (WP-STUDIO-021/022/023), through the same three central registries — no new registration mechanism was introduced:

- `lib/core/routing/studio_destination.dart` — a new `exchange` destination (`/exchange`, storefront icon).
- `lib/core/routing/studio_registry.dart` — a new `StudioDescriptor` with `settingsProvider: ExchangeSettingsProvider()`, `searchProvider: _searchExchange` (a best-effort, client-side filter over already-cached Marketplace data, mirroring `_searchAcquisition`'s own documented limitation — Exchange's real full-text index is server-side `GET /search`, which Search Studio's synchronous, cache-only Unified Search contract can't call directly), and three `CapabilityDescriptor`s (`exchange.browse`, `exchange.install`, `exchange.library`).
- `lib/core/commands/command_registry.dart` — three commands (`exchange.search`, `exchange.refreshMarketplace`, `exchange.refreshRepository`), reachable from the Command Palette (Ctrl+K). `installPackage` is **not** registered as a command: `CommandArgs` only carries a single optional `String`, but installing needs both a package id and a display name, and stretching that contract is out of scope here — the same reasoning WP-STUDIO-023 already applied to Knowledge Studio's session-lifecycle methods.
- `lib/core/models/unified_search_result.dart` — two new categories (`exchangePackage`, `exchangePublisher`) and a new `UnifiedSearchOrigin.exchange` / `UnifiedSearchResult.fromExchange` factory, alongside the existing Foundation/Engine/Acquisition ones.
- `lib/shared/navigation/unified_navigation.dart` — `goToExchangeResult` switches to the Exchange destination and selects the matched package/publisher, mirroring `goToAcquisitionResult`.

## Repository Integration (WP-EXC-010 §6)

| Requirement | Implementation |
| --- | --- |
| Install Package | `ExchangeRuntimeNotifier.installPackage` calls the already-built `POST /packages/{id}/install` (TASK-EXC-0008) and publishes an `OperationEvent` (started/completed/failed) on the `PlatformEventBus`, so `OperationManager`/`StudioStatusBar` show install progress the same way an Acquisition download does. |
| Show Installation Status | The `InstallationDto`'s `status`/`errorMessage`/`repositoryPackageId` are shown inline in Package Detail ("Installation Progress"); "Refresh Status" re-fetches `GET /installations/{id}` rather than trusting the cached value, mirroring `MyLibraryPage`'s own web behavior. |
| Refresh Repository | `FoundationRuntimeNotifier` gained one new **public** method, `refreshRepository()` (`lib/core/services/foundation_runtime_service.dart`) — it re-runs the same statistics/object-list/relationship-list refresh `openRepository`/`commitToFoundation` already perform internally (previously only reachable through the private `_refreshRepositoryData`). This is the "approved public interface" the Exchange communicates through, per WP-EXC-010 §6 — no Foundation-side redesign, just a minimal, additive method. |
| Open Installed Package | Best-effort: calls `refreshRepository()` then navigates to the existing Repository destination (`/repository`). See "Known limitation" below. |

## Workspace Integration (WP-EXC-010 §7) — known limitation

"Open in Engineering Workspace" navigates to the existing Project Explorer destination (`/project`) once an installation completes. This is a deliberate, documented simplification, not an oversight: Studio has no generic "installed-package-asset-type → Studio destination" dispatch mechanism today, and building one would mean either

1. teaching `EngineeringObjectRuntime` (explicitly read-only, WP-STUDIO-031) or `WorkspaceManager` (explicitly Diagram-only, WP-STUDIO-029) a new "open by asset type" responsibility neither was designed for, or
2. inventing a new Foundation-side or Platform-side dispatch abstraction from scratch,

either of which is architectural work outside WP-EXC-010's "No architectural redesign shall occur" mandate. `PackageDto`/`InstallationDto` also don't currently carry an asset-type field Studio could dispatch on — the manifest-derived fields that might (`engineeringDomains`, `capabilities`) exist on `exchange-api`'s persistence layer but were deliberately excluded from the wire DTOs by TASK-EXC-0004 (see `packages/api-contracts/src/package.ts`'s own doc comment). A real "launch this specific installed asset directly" experience is future work — see the Recommendations in `docs/VALIDATION_REPORT.md`.

## Studio Navigation (WP-EXC-010 §4) — reconciliation

WP-EXC-010 §4 lists seven Studio Navigation destinations: Dashboard, Repository, Engineering Workspace, Engineering Exchange, Documentation, Administration, Settings. Only three of those names (Dashboard, Repository, Settings) match an existing `oep_studio` destination one-for-one; "Engineering Workspace," "Documentation," and "Administration" are not existing navigation entries anywhere in this codebase. Reconciliation (mirroring this program's own precedent for reconciling a task doc against an already-approved codebase, e.g. TASK-EXC-0002's WP-EXC-002.md reconciliation):

- **Engineering Exchange** — added, per this work package's core mandate.
- **Engineering Workspace** — not a literal new destination. The existing Project Explorer / Objects / Relationships / Diagram Studio destinations together already are Studio's "engineering workspace" concept; renaming or consolidating them into one new destination would be an unrequested navigation redesign. "Open in Engineering Workspace" (§7) therefore targets Project Explorer specifically (see above).
- **Documentation** and **Administration** — these navigation destinations do not exist in `oep_studio` today and inventing them from nothing is out of this work package's scope twice over: WP-EXC-010 §2 excludes "Publisher administration" outright, and fabricating two new, unrelated Studio sections with no content of their own would itself be a redesign / new Studio features, which §1 and §2 both forbid. Flagged here as a gap between the task document and the current, approved Studio architecture, not silently implemented or silently ignored.

## Local state (My Library / Downloads)

`apps/publisher-portal`'s own `LibraryContext` is `localStorage`-backed because it has no server-side "current user" (authentication is out of scope everywhere in this program so far). Studio has no browser storage, so `ExchangeLibraryStorage` persists the same kind of history — installed packages and downloaded artifacts — to `%APPDATA%/oep_studio/exchange_library.json`, mirroring `AcquisitionSettingsStorage`'s own file-based persistence pattern. Every field stored is either a real id (`packageId`, `installationId`) or a value a real API response already returned — never fabricated, the same rule `LibraryContext` follows.

## Settings

Settings > Engineering Exchange (`ExchangeSettingsProvider`, `pageId: 'engineering_exchange'`) holds one field, the REST API address, defaulting to `http://127.0.0.1:3000/api/v1` (`exchange-api`'s own default port, `apps/exchange-api/src/server.ts`, plus its versioned route prefix, `packages/api-contracts/src/version.ts`). A "Test Connection" button calls `GET /health`.

## Testing

Plain Dart tests only (this codebase's standing convention — see `test/studio_registry_test.dart`/`test/command_registry_test.dart`), added under `oep_studio/test/`:

- `exchange_api_client_test.dart` — request/response/error-mapping against a fake `http.Client` (`package:http/testing.dart`), mirroring `anthropic_provider_test.dart`.
- `exchange_models_test.dart` — every DTO's `fromJson` reads the exact `camelCase` field names `packages/api-contracts` serializes.
- `exchange_settings_test.dart` — defaults/JSON round-trip/file persistence, mirroring `diagram_studio_settings_test.dart`.
- `foundation_refresh_repository_test.dart` — the new `refreshRepository()` public method is a safe no-op when no repository is open.
- Extended `studio_registry_test.dart`/`command_registry_test.dart`/`command_palette_dialog_test.dart`/`settings_registry_test.dart` assertions to cover Exchange's registration alongside the existing Studios.

Run with `flutter test` (whole suite) from `oep_studio/`.
