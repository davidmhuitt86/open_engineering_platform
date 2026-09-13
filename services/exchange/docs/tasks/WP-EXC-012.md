# WP-EXC-012

Title:
Exchange Client API Foundation

Status:
Complete

Milestone:
Prerequisite to WP-EXC-010 (Exchange RC1 + Studio Integration), specifically the `apps/publisher-portal` portion of it.

Dependencies:

- WP-EXC-011 (Exchange Workspace Reconstruction — restored `packages/*`, identified this exact gap)
- `docs/tasks/WP-EXC-009.md` (Engineering Exchange Web Application Phase 1 — the consumer whose contract this WP satisfies)
- `apps/exchange-api` (the existing backend this client is built against)
- `packages/api-contracts` (the shared wire-contract types this client reuses)

---

# 1. Objective

Implement the minimum real `@oep-exchange/exchange-client` API client (`ExchangeApiClient`, `ExchangeApiError`) required to unblock `apps/publisher-portal`'s already-existing build/typecheck/test infrastructure — not to build Exchange RC1, not to develop new publisher-portal features, not to integrate with Studio.

# 2. Historical context

WP-EXC-011 restored 14 packages byte-for-byte from the upstream `oep_exchange` repository's last known good commit (`18484e3`). `exchange_client` was one of them — but at `18484e3` it was still its original `TASK-EXC-0001` scaffold (`export const PACKAGE_NAME = ...`), with its own doc comment stating "Real implementation arrives in TASK-EXC-0007 (Download API)." The upstream repository's own final commit (`c6dbb75`, "v2") added new `publisher-portal` consumer code that assumes a real `ExchangeApiClient`/`ExchangeApiError` — but never committed the client implementation itself, in either repository, at any commit.

# 3. Why restoration was impossible

`git log --all --diff-filter=A --name-only` across both the upstream `oep_exchange` repository and this monorepo, filtered for any file under `packages/exchange_client/src/` beyond `index.ts`/`index.test.ts`, returns nothing. There is no commit, in either repository's history, that ever added a real `ExchangeApiClient` or `ExchangeApiError` implementation. This is not a case of "the file was deleted and needs restoring" (WP-EXC-011's situation for the other 13 packages) — it is a case of "the file was never written." This WP is therefore **new code**, not a restoration, established entirely from:

1. `apps/exchange-api`'s existing, real backend routes (the actual HTTP contract).
2. `apps/publisher-portal`'s existing consumer code and tests (the actual required client surface — every method, its parameters, and its return shape are pinned by tests that already existed before this WP, e.g. `use-async.test.ts`'s `new ExchangeApiError(404, 'NOT_FOUND', 'not found')` and `PublishersPage.test.tsx`'s `client.publishers.list()` resolving to a flat array).
3. `packages/api-contracts`'s existing shared DTOs (`PublisherDto`, `PackageDto`, `SearchResponse`, `InstallationDto`, `ApiErrorResponse`, etc.) — reused, not duplicated.
4. `apps/publisher-portal/src/App.test.tsx`'s existing fake-fetch harness, which independently confirms the required transport is the platform's native `fetch` (it stubs `globalThis.fetch` directly and asserts the real client calls it).

No architectural decision was invented; every piece of the contract below was already pinned by pre-existing code this WP did not write.

# 4. Current consumer contract (established from actual usage, not assumption)

| Symbol | Usage site | Required behavior |
|---|---|---|
| `new ExchangeApiClient({ baseUrl })` | `ExchangeApiClientContext.tsx` | Constructs with a configurable `baseUrl` (`/api/v1`, same-origin) |
| `client.search.run(params)` | `CategoriesPage`, `MarketplaceHomePage`, `SearchResultsPage`, `PublisherProfilePage` | Returns a `Promise<SearchResponse>` (`.items`, `.totalCount`, `.totalPages`, `.currentPage`, `.pageSize`) |
| `client.packages.get(id)` | `PackageDetailPage` | Returns `Promise<PackageDto>` |
| `client.publishers.get(id)` | `PackageDetailPage`, `PublisherProfilePage` | Returns `Promise<PublisherDto>` |
| `client.publishers.list()` | `PublishersPage` | Returns `Promise<PublisherDto[]>` — a **flat array**, pinned by `PublishersPage.test.tsx`'s `state.data.length`/`state.data.map(...)` |
| `client.installations.install(packageId)` | `PackageDetailPage` | Returns `Promise<InstallationDto>` |
| `client.installations.get(installationId)` | `MyLibraryPage` | Returns `Promise<InstallationDto>` |
| `client.downloads.url(packageId)` | `PackageDetailPage` | Returns a plain `string` **synchronously** — used directly as an `<a href>`, never `await`ed |
| `new ExchangeApiError(status, code, message)` | `use-async.test.ts` | Exact 3-argument constructor order, `.message` readable |
| `error instanceof ExchangeApiError` | `use-async.ts`, `PackageDetailPage.tsx` | Must be a real `Error` subclass distinguishable via `instanceof` |

# 5. Backend API contract

| Client Method | HTTP Method | Endpoint | Existing Backend Route | Request | Response | Consumer |
|---|---|---|---|---|---|---|
| `search.run(params)` | GET | `/search` | `apps/exchange-api/src/routes/search.ts` | query string: `q, publisherId, categoryId, status, sortBy, sortDirection, page, pageSize` | `SearchResponse` | Categories/MarketplaceHome/SearchResults/PublisherProfile pages |
| `packages.get(id)` | GET | `/packages/{id}` | `apps/exchange-api/src/routes/packages.ts` | — | `PackageDto` | PackageDetailPage |
| `publishers.get(id)` | GET | `/publishers/{id}` | `apps/exchange-api/src/routes/publishers.ts` | — | `PublisherDto` | PackageDetailPage, PublisherProfilePage |
| `publishers.list()` | GET | `/publishers` | `apps/exchange-api/src/routes/publishers.ts` | — | `PublisherListResponse` (`{publishers}`), unwrapped to `PublisherDto[]` by the client | PublishersPage |
| `installations.install(id, version?)` | POST | `/packages/{id}/install` | `apps/exchange-api/src/routes/installation.ts` | `{ version? }` | `InstallationDto` (201) | PackageDetailPage |
| `installations.get(installationId)` | GET | `/installations/{installationId}` | `apps/exchange-api/src/routes/installation.ts` | — | `InstallationDto` | MyLibraryPage |
| `downloads.url(id)` | — (URL only, no fetch) | `/packages/{id}/download` | `apps/exchange-api/src/routes/download.ts` | — | binary (browser-navigated) | PackageDetailPage |

Every implemented client method maps to an existing, already-implemented backend route. **No speculative endpoint was created.** Both download routes (`/packages/{id}/download` and `/packages/{id}/versions/{version}/download`) exist on the backend; only the first is currently used by any consumer, so only it is exposed by `downloads.url()` — the versioned variant is not implemented here, since no current consumer requires it (adding it would be speculative surface, out of this WP's scope).

# 6. Implemented client surface

`packages/exchange_client/src/`:
- `errors.ts` — `ExchangeApiError extends Error`, constructor `(status: number, code: string, message: string)`.
- `transport.ts` — `HttpTransport`: the one place any HTTP request is issued. Wraps the platform's native `fetch` (no second HTTP stack introduced — none existed to reuse, and none was needed beyond this). `buildUrl()` (synchronous, used by `downloads.url()`) and `request()` (async, used by every other method).
- `client.ts` — `ExchangeApiClient` and its five resource namespaces (`search`, `packages`, `publishers`, `installations`, `downloads`), matching §4/§5 exactly.
- `index.ts` — exports `PACKAGE_NAME` (unchanged, pre-existing), `ExchangeApiClient`, `ExchangeApiError`, and the public option/param types.

# 7. Error model

`ExchangeApiError` carries `status` (HTTP status code), `code` (the same machine-readable identifier `apps/exchange-api` already emits via `toApiErrorResponse(DomainError)`), and `message` (human-readable, read directly by existing consumers). A non-2xx response whose body matches the existing `ApiErrorResponse` envelope (`{ error: { code, message } }`) is mapped exactly; a non-2xx response that is not valid JSON, or does not match that envelope, still produces an `ExchangeApiError` (status + a generic `UNKNOWN_ERROR` code and message) rather than throwing an unrelated JSON-parse exception. A transport-level failure (the network request itself failing) is **not** wrapped — it propagates as whatever `fetch` itself threw (typically a `TypeError`) — because existing consumers (`use-async.ts`'s `messageFor`) already have their own `instanceof Error` fallback for exactly this case, and wrapping it would misrepresent a network failure as an API-modeled one.

# 8. Transport model

The platform's native `fetch` (`globalThis.fetch`), confirmed as the required transport by `App.test.tsx`'s existing fake-fetch harness (it stubs `globalThis.fetch` and asserts the real client calls it — no other transport would satisfy that test). No axios, no `node-fetch`, no second stack. `baseUrl` is entirely caller-supplied (`ExchangeApiClientContext.tsx` passes `/api/v1`, same-origin) — never hardcoded to any hostname. `fetch` itself is also overridable per client instance (`ExchangeApiClientOptions.fetch`), purely so tests can inject a fake without global stubbing where a test prefers that style — this WP's own new tests use it; existing consumer tests continue to stub `globalThis.fetch` or construct `Partial<ExchangeApiClient>` fakes directly, both of which still work unchanged.

# 9. Security considerations

No authentication mechanism exists anywhere in this repository (WP-EXC-009.md §2 explicitly excludes it), so none was invented here. No credential, API key, or authorization header is read, sent, or logged by this client. No TLS validation is disabled. No cross-origin behavior was added — `baseUrl` defaults to a same-origin relative path exactly as the existing consumer already configures it, and nothing in this client permits an arbitrary caller-supplied remote origin beyond what `baseUrl` itself, supplied by the same code that already existed, already specifies. Error messages surface only `status`/`code`/`message` already present in the server's own `ApiErrorResponse` envelope — no response header, cookie, or credential is ever included in a thrown error. ADR-0003 (EAM/HttpConnector network-boundary) is unrelated to Exchange and was not touched.

# 10. Tests

`packages/exchange_client/src/{errors,transport,client}.test.ts` — 23 new focused unit tests (plus the 1 pre-existing scaffold test in `index.test.ts`, unchanged): client construction, base URL joining, query-parameter omission of `undefined`, successful GET/POST requests, 204 handling, `ApiErrorResponse`-shaped error mapping, malformed/non-JSON error body fallback, unexpected-shape error body fallback, network/transport failure propagation (not wrapped), and one test per implemented client method. See the Implementation Report for exact pass counts.

# 11. Remaining limitations

- `downloads.url()` only covers "download current version" (`/packages/{id}/download`) — the versioned download route exists on the backend but has no current consumer, so it is not exposed by this client (adding it now would be speculative).
- No authentication/authorization is implemented anywhere in Exchange yet; this client has nothing to attach even if it existed.
- No request timeout/retry/cancellation logic was added — no existing consumer or test requires it, and adding it would be speculative infrastructure ahead of a demonstrated need.
- `packages/exchange_client`'s own `dependency_resolver`/`update_service`/`installer` consumers described in its own package description ("used by the installer, update service, and both web apps") were not audited for their own usage in this pass beyond confirming `installer` depends on `interfaces`, not `exchange_client`'s newly-implemented surface directly — no other package's source imports `@oep-exchange/exchange-client` today (confirmed by repository-wide search), so no further consumer contract exists to satisfy.

# 12. Out of scope

Exchange RC1, new publisher-portal features/workflows, Studio/Engineering-Workspace integration, licensing/payments/reviews, update-service/dependency-resolver redesign, new authentication architecture, any backend route not already implemented, any new Exchange architecture.

# 13. Exit criteria

- [x] Current `exchange-client` consumers audited (every `publisher-portal` file referencing it, read in full).
- [x] Backend API contracts audited (every route file the consumer surface touches, read in full).
- [x] `ExchangeApiClient` contract explicitly documented (§4-§6).
- [x] `ExchangeApiError` contract explicitly documented (§7).
- [x] Required client functionality implemented (§6) — nothing more.
- [x] No speculative API endpoints created (§5).
- [x] `publisher-portal` typecheck passes.
- [x] `publisher-portal` build passes.
- [x] `publisher-portal` tests pass (0 failed; the same 124 skipped, pre-existing, Postgres-gated `exchange-api` tests are unrelated to this app or this WP).
- [x] `exchange-client` tests pass (24/24).
- [x] Exchange root typecheck/build remains passing.
- [x] No unrelated OEP subsystem modified.
- [x] Security behavior documented (§9).
- [x] ADR-0003 untouched.
- [x] WP-EXC-010 remains separate (not implemented).
- [x] Documentation complete (this file + the Implementation Report).
- [x] Dedicated WP-EXC-012 commit created.
- [x] Nothing pushed.

# 14. Final disposition

**COMPLETE.** The Exchange client foundation `apps/publisher-portal` depends on now exists, is fully tested, and unblocks its entire build/typecheck/test pipeline with zero remaining failures. This is new code closing a genuine, previously-unrecoverable historical gap — not a restoration, and not an expansion into Exchange RC1's own scope. WP-EXC-010 may now proceed against a fully green Exchange workspace (`exchange-api`, `exchange-admin`, and `publisher-portal` all build/typecheck/test cleanly), subject to whatever WP-EXC-010 itself separately decides to scope.
