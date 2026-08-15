# Frontend Guide

How `apps/publisher-portal` — the Engineering Exchange Web Application (TASK-EXC-0009, `docs/tasks/WP-EXC-009.md`) — is built, run, and structured. This is the first production UI for the Exchange; it consumes the REST APIs built in TASK-EXC-0001 through TASK-EXC-0008 and adds no new backend behavior of its own.

## Architecture

```
Browser
  ↓
React Application (apps/publisher-portal)
  ↓
Exchange API Client (packages/exchange-client)
  ↓
Exchange REST API (apps/exchange-api)
```

No component calls `fetch` (or any backend service) directly — every data access goes through an `ExchangeApiClient` instance, obtained via `useExchangeApiClient()` (WP-EXC-009.md §3). This is enforced by construction, not lint rule: `ExchangeApiClientContext` is the only place an `ExchangeApiClient` is created, and pages/components only ever receive one through that context.

## Running locally

```sh
npm run dev -w @oep-exchange/publisher-portal    # Vite dev server, http://localhost:5173
npm run build -w @oep-exchange/publisher-portal   # type-check + production build
npm test -w @oep-exchange/publisher-portal
```

`exchange-api` has no CORS headers (authentication/CORS are out of scope for every task so far), so the dev server proxies `/api/*` to `http://localhost:3000` (`vite.config.ts`'s `server.proxy`) — the browser only ever talks to its own origin. Override the proxy target with `OEP_EXCHANGE_API_PROXY_TARGET` if `exchange-api` runs somewhere else. A production deployment is expected to front both behind one reverse proxy the same way; `ExchangeApiClient` itself is always constructed with the relative base URL `/api/v1` (`ExchangeApiClientContext.tsx`), never an absolute one.

## Routes

| Path              | Page                   | Notes                                                                                       |
| ----------------- | ---------------------- | ------------------------------------------------------------------------------------------- |
| `/`               | `MarketplaceHomePage`  | Recently updated packages + a category-cards sample.                                        |
| `/search`         | `SearchResultsPage`    | `?q=&publisherId=&categoryId=&status=&sortBy=&sortDirection=&page=`, all synced to the URL. |
| `/categories`     | `CategoriesPage`       | See "Where category data comes from" below.                                                 |
| `/publishers`     | `PublishersPage`       | `GET /publishers`.                                                                          |
| `/publishers/:id` | `PublisherProfilePage` | Publisher + their packages (`GET /search?publisherId=`).                                    |
| `/packages/:id`   | `PackageDetailPage`    | Download + Install actions, Installation Progress.                                          |
| `/library`        | `MyLibraryPage`        | Locally tracked installation history.                                                       |
| `/downloads`      | `DownloadsPage`        | Locally tracked download history.                                                           |
| `*`               | `NotFoundPage`         | 404.                                                                                        |

All routes render inside `AppShell` (header, responsive sidebar nav, footer) via a layout route in `App.tsx`.

## Where category data comes from

No `GET /categories` endpoint exists (only `GET /search` accepts a `categoryId` filter) — Marketplace Home's "Browse by category" section and the `/categories` page both derive their category list from a `GET /search` sample (`src/lib/derive-categories.ts`), grouping and counting by `categoryId`/`categoryName`. This means only categories with at least one matching package appear, which is the correct behavior for a discovery surface anyway, and keeps the frontend from inventing a category list that doesn't exist server-side (WP-EXC-009.md §7 "no mock data").

## API client

`packages/exchange-client`'s `ExchangeApiClient` groups endpoints by resource:

```ts
client.publishers.list() / .get(id)
client.packages.list() / .get(id)
client.search.run({ q, publisherId, categoryId, status, sortBy, sortDirection, page, pageSize })
client.installations.install(packageId, version?) / .get(installationId)
client.downloads.url(packageId, version?)   // builds the download URL — does not fetch it
```

`downloads.url()` only builds a URL: downloads are triggered by navigating the browser to it directly (an `<a href>` in `PackageDetailPage`) so the browser's native download handling (and `Content-Disposition` filename) takes over, rather than fetching the binary into JS and re-serving it as a Blob.

Every call throws `ExchangeApiError` (status/code/message/details, mirroring the shared `ApiErrorResponse` envelope) on a non-2xx response — pages catch this via `useAsync()`, never a raw `fetch` rejection.

## State management

Two deliberately small, hand-rolled mechanisms — no Redux/Zustand/TanStack Query, consistent with this repository's preference for the smallest tool that does the job (the same reasoning behind choosing npm workspaces over Turborepo):

- **`useAsync()`** (`src/hooks/use-async.ts`) — a generic `{status: 'loading'|'success'|'error', ...}` hook every page uses for its own API call(s). Discards a stale response if the caller's dependencies change before the previous call resolves.
- **`LibraryContext`** (`src/state/LibraryContext.tsx`) — a `useReducer` + `localStorage`-backed store for the Downloads and My Library history. Authentication is out of scope for this task (and TASK-EXC-0008's Installation API), so there is no server-side "current user" to own this data; it is scoped to the browser instead. Every field stored is either a real id (`packageId`, `installationId`) or a value a real API response already returned (`displayName`, `version`, timestamps) — never fabricated data.

## Downloads and My Library, precisely

- **Download** (`PackageDetailPage`'s Download button) — a plain `<a href={client.downloads.url(...)}>`; clicking it lets the browser download the real artifact (TASK-EXC-0007) natively, and an `onClick` handler (that does not call `preventDefault`) records the event into `LibraryContext`.
- **Install** (`PackageDetailPage`'s Install button) — calls `client.installations.install(packageId)` (TASK-EXC-0008), which resolves synchronously to a `completed` or `failed` `InstallationDto`; the result is shown inline as "Installation progress" and recorded into `LibraryContext`. `MyLibraryPage`'s "Refresh status" re-fetches the real `Installation` by id rather than trusting the cached status forever.

## Error handling and loading states

Every page follows the same three-branch render: `state.status === 'loading'` → `LoadingIndicator`; `'error'` → `ErrorView` (with the `ExchangeApiError`'s own message); `'success'` → the real content, itself falling back to `EmptyState` when a list is empty. No skeleton/placeholder content is shown with fabricated data — "loading" is the only state permitted to omit real data (WP-EXC-009.md §7).

## Testing

- **Component tests** — one file per component in `src/components/`, React Testing Library + jsdom, no network.
- **Page (integration) tests** — one file per page in `src/pages/`, rendering the real page against a fake `ExchangeApiClient` (a `Partial<ExchangeApiClient>` cast, mirroring the fakes used throughout `apps/exchange-api`'s own service tests) supplied via `ExchangeApiClientContext.Provider` — exercises real loading/error/success rendering without a live `exchange-api`.
- **Navigation/API-integration tests** (`src/App.test.tsx`) — render the whole `<App/>` tree (real router, real pages, real `ExchangeApiClient`) against a stubbed global `fetch` that dispatches by URL, then click through the sidebar nav and assert both the rendered page and the actual request URLs `fetch` was called with.
- **Cleanup gotcha**: this project does not enable Vitest's `globals` option, so `@testing-library/react`'s automatic per-test DOM cleanup never registers itself on its own. `src/test-setup.ts` (wired into both this app's own `vite.config.ts` and the root `vitest.config.ts`) calls `cleanup()` in an `afterEach`, guarded on `document` existing so it's a no-op for every other (Node-environment) package's tests.

Run everything with `npm test -w @oep-exchange/publisher-portal`, or as part of the whole workspace's `npm test`.

## Relationship to the OEP Studio Exchange workspace

This web application remains the reference implementation of the Exchange's UI, but it is no longer the only front end: WP-EXC-010 adds a native Exchange workspace to OEP Studio (a separate, Flutter/Dart desktop repository) that consumes the same `exchange-api` REST surface through its own client, not this one and not by embedding this app. The two front ends are independent and this app required no changes to support the Studio integration. See `docs/guides/STUDIO_INTEGRATION_GUIDE.md`.
