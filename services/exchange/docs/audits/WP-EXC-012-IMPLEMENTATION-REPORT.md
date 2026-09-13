# WP-EXC-012 — Exchange Client API Foundation
## Implementation Report

STATUS:
COMPLETE

HISTORICAL IMPLEMENTATION:
NOT RECOVERABLE — confirmed via `git log --all --diff-filter=A --name-only` across both the upstream `oep_exchange` repository and this monorepo: no commit, at any point in either repository's history, ever added a real `ExchangeApiClient`/`ExchangeApiError` implementation. At the last known good commit (`18484e3`, WP-EXC-011's restoration baseline), `exchange_client` was still only its original `TASK-EXC-0001` scaffold.

NEW CLIENT IMPLEMENTATION:
`ExchangeApiClient` and `ExchangeApiError`, implemented in `packages/exchange_client/src/{client,errors,transport}.ts`, established entirely from `apps/exchange-api`'s existing routes, `apps/publisher-portal`'s existing (pre-existing, unmodified) consumer code and tests, and `packages/api-contracts`'s existing shared DTOs. Uses the platform's native `fetch` (no new HTTP dependency). No speculative endpoint or field was added.

CLIENT METHODS:
- `search.run(params?: SearchParams): Promise<SearchResponse>`
- `packages.get(packageId: string): Promise<PackageDto>`
- `publishers.get(publisherId: string): Promise<PublisherDto>`
- `publishers.list(): Promise<PublisherDto[]>`
- `installations.install(packageId: string, version?: string): Promise<InstallationDto>`
- `installations.get(installationId: string): Promise<InstallationDto>`
- `downloads.url(packageId: string): string` (synchronous, no fetch)

BACKEND ENDPOINTS:
- `GET /search`
- `GET /packages/{id}`
- `GET /publishers/{id}`
- `GET /publishers`
- `POST /packages/{id}/install`
- `GET /installations/{installationId}`
- `GET /packages/{id}/download` (URL construction only; the versioned-download route also exists on the backend but has no current consumer and is not exposed)

FILES CREATED:
- `services/exchange/packages/exchange_client/src/errors.ts`
- `services/exchange/packages/exchange_client/src/errors.test.ts`
- `services/exchange/packages/exchange_client/src/transport.ts`
- `services/exchange/packages/exchange_client/src/transport.test.ts`
- `services/exchange/packages/exchange_client/src/client.ts`
- `services/exchange/packages/exchange_client/src/client.test.ts`
- `services/exchange/docs/tasks/WP-EXC-012.md`
- `services/exchange/docs/audits/WP-EXC-012-IMPLEMENTATION-REPORT.md` (this file)

FILES MODIFIED:
- `services/exchange/packages/exchange_client/src/index.ts` (added real exports alongside the unchanged, pre-existing `PACKAGE_NAME` export)
- `OEP_PROJECT_STATUS.md` (Exchange section — see below)
- `docs/project/OEP_RELEASE_HISTORY.md` (new entry — see below)

No file under `apps/publisher-portal/` was modified — every existing consumer file's own contract was satisfied as-is (§4/§8 of WP-EXC-012.md), consistent with the WP's own preferred direction ("existing publisher-portal contract → ExchangeApiClient implementation," not the reverse).

PUBLISHER PORTAL:
```
$ npm run build -w @oep-exchange/publisher-portal
tsc --noEmit && vite build
✓ 67 modules transformed, built in 1.14s (exit 0)
```

EXCHANGE-CLIENT TESTS:
```
$ npx vitest run packages/exchange_client
 Test Files  4 passed (4)
      Tests  24 passed (24)
```

PUBLISHER-PORTAL TESTS:
Included in the full workspace run below (Vitest runs the whole workspace together); isolated confirmation via `grep -i FAIL` on the full run's output returned zero matches. All test files previously failing under `apps/publisher-portal` (7 files / 12 tests, per the WP-EXC-011 report) now pass.

EXCHANGE BUILD:
```
$ npm run build
tsc -b                                          -> exit 0 (all 14 packages + exchange-api)
@oep-exchange/publisher-portal build (tsc --noEmit && vite build) -> exit 0
@oep-exchange/exchange-admin build (tsc --noEmit && vite build)   -> exit 0
```
Full workspace build now succeeds end to end — the one failure WP-EXC-011 left open is closed.

TYPECHECK:
```
$ npx tsc -b   (root composite: all 14 packages + apps/exchange-api)
exit 0, zero errors
```
`publisher-portal` and `exchange-admin`'s own `tsc --noEmit` (run as part of their `build` script above): both exit 0.

FULL WORKSPACE TEST SUITE:
```
$ npm test
 Test Files  69 passed | 17 skipped (86)
      Tests  319 passed | 124 skipped (443)
```
Up from WP-EXC-011's 59 passed / 7 failed / 17 skipped (83 files), 284 passed / 12 failed / 124 skipped (420 tests). The 17 skipped files / 124 skipped tests are `apps/exchange-api`'s own pre-existing, Postgres-gated persistence/repository tests — unrelated to this WP, unchanged in count. **Zero failures anywhere in the workspace.**

LINT:
```
$ npm run lint
> eslint .
exit 0, zero errors/warnings
```

SECURITY:
No new authentication, credential handling, or cross-origin behavior introduced. `baseUrl` remains entirely caller-supplied (same-origin `/api/v1`, unchanged from the existing `ExchangeApiClientContext.tsx`). Error messages surface only the server's own already-public `ApiErrorResponse` fields — no header, cookie, or credential is ever captured. ADR-0003 (EAM/HttpConnector) untouched and unrelated.

ARCHITECTURAL IMPACT:
None. `@oep-exchange/exchange-client` remains its own package, at its own path, under its own name — not merged into `exchange-api`, not moved into any other OEP subsystem. Its dependencies remain exactly `@oep-exchange/core` and `@oep-exchange/api-contracts` (unchanged from the pre-existing `package.json`) — no dependency on Foundation, Engine, Diagram Studio, Knowledge Runtime, EAM, or Reference Vault was added or is needed.

REMAINING GAPS:
- The versioned-download backend route (`/packages/{id}/versions/{version}/download`) has no client method — no current consumer requires it; adding one would be speculative.
- No authentication exists anywhere in Exchange; this client has nothing to attach if/when one is introduced.
- No request timeout/retry/cancellation — not required by any existing consumer or test.

WP-EXC-010 READINESS:
READY WITH CONDITIONS unchanged from WP-EXC-011's own framing, now improved: the `publisher-portal` blocker WP-EXC-011 identified is fully closed. WP-EXC-010 (Exchange RC1 + Studio integration) itself remains not started and is not implied ready merely because its foundation now builds and tests cleanly — WP-EXC-010 has its own scope, entry criteria, and decisions still to be made independently.
