# Repository Structure

**Task:** TASK-EXC-0001 (Repository Structure), part of WP-EXC-001 (OEP Exchange Repository MVP). Approved with architectural amendments — see §9.

This document records the tooling and layout decisions made to turn the pre-existing `oep_exchange` directory scaffold (empty `apps/`/`packages/` folders with one-line placeholder READMEs, plus the full EXC-/PKG-/GOV- specification set) into an independently buildable, testable monorepo. Per the governing instructions for this work package, specifications are the source of truth and this work implements them rather than redesigning them; where a specification didn't dictate an implementation detail (test runner, web UI framework, etc.), a choice was made and is justified below rather than left undecided.

## 1. Monorepo tooling

**npm workspaces** (`workspaces: ["packages/*", "apps/*"]` in the root `package.json`) — no additional package manager (pnpm, Yarn) or build orchestrator (Turborepo, Nx) was introduced. npm ships with Node itself, so this keeps the repository's tooling surface to exactly what the WP-EXC-001 technology mandate already requires (Node/TypeScript) plus nothing else. If the workspace grows enough that plain `npm run build`/`npm test` become too slow (no caching, no task graph parallelism), Turborepo or Nx are the natural next step — deliberately not adopted now, per "avoid unnecessary abstractions."

**TypeScript project references** (`tsconfig.base.json` + one `tsconfig.json` per library package/server app + a root `tsconfig.json` listing every composite project) drive `npm run build` (`tsc -b`) — this gives incremental, dependency-ordered builds and means a package can only import another package's declared public exports (via its `dist/*.d.ts`), not reach into another package's internals, enforcing the "clean dependency inversion" requirement mechanically rather than by convention alone.

**Vitest** was chosen as the test runner (not explicitly mandated by the technology list, which only specifies PostgreSQL/Flyway/Fastify/TypeScript/OpenAPI). Rationale: native ESM/TypeScript support with zero transpile configuration, fast (esbuild-based), and integrates with Vite for the two React apps without needing a second, differently-configured test runner for them. Each package/app has its own `vitest.config.ts` (so `npm test -w <package>` works standalone, satisfying "the repository must remain independently buildable, testable, deployable") plus a root `vitest.config.ts` that aggregates every package's tests for one `npm test` at the repository root.

**ESLint (flat config) + Prettier** — `typescript-eslint`'s recommended rules, plus the `globals` package for Node/browser global recognition (Node globals repo-wide, browser globals scoped to the two React apps only, via a per-path override).

**Node 20 LTS** (`.nvmrc`, `engines.node: ">=20"` in `package.json`) — the oldest currently-supported Node LTS at time of writing, giving the widest compatible deployment target while still supporting native ESM, `node:test`-adjacent APIs, and modern V8 features Fastify 5/Vite 5 expect.

See `docs/architecture/adr/ADR-0001-Repository-Structure.md` for the architectural (as opposed to implementation-detail) reasoning behind these choices.

## 2. Package layout and dependency direction

Every workspace package/app already existed as an empty scaffold directory before this task; this task gave each one a real `package.json`, `tsconfig.json`, `vitest.config.ts`, at least one real source file, at least one real test, and an accurate README. Dependency direction (enforced by `package.json` dependencies + `tsconfig.json` project references, never a bare relative import crossing a package boundary):

```
                     @oep-exchange/core
                    (no workspace deps)
                     /        |        \
                    /         |         \
        api-contracts    manifest     signing
             |               \          /
             |                \        /
    exchange-client       package-manager
        /   |   \
       /    |    \
installer update  (publisher-portal, exchange-admin
        service    depend on exchange-client + api-contracts)

  dependency-resolver → core, manifest      (scaffold only, deferred)
  licensing, payments  → core               (scaffold only, excluded from WP-EXC-001)
  reviews              → core, api-contracts (scaffold only, excluded from WP-EXC-001)
  search               → core, api-contracts

  exchange-api (Fastify app) → core, api-contracts
    (→ manifest, signing, search, package-manager once their owning tasks land)

  interfaces           → nothing (future cross-repository contracts only; see §9)
```

`@oep-exchange/core` depends on nothing else in the workspace and is the only package every other package/app may assume is available — it holds `Result<T,E>`, the `DomainError` family, `newId()`, and an injectable `Clock`, all genuinely used (not speculative) by at least one other package or test written in this task.

`@oep-exchange/api-contracts` holds the versioned wire-contract types (`EXCHANGE_API_VERSION`, the `ApiErrorResponse` envelope, `HealthCheckResponse`) shared by the server and every client. It deliberately does **not** yet contain Publisher/Package/Search/Download DTOs — those arrive alongside the tasks that own them (TASK-EXC-0003 through TASK-EXC-0007), so a contract type is never added speculatively ahead of the code that needs it.

## 3. Packages scaffolded but intentionally empty

Three categories of package received only the minimal "proves the workspace wiring works" scaffold (a `PACKAGE_NAME` export and one test asserting it), not real logic, because their directories already existed in the pre-existing scaffold but their content falls outside this task or this work package:

- **Owned by a later task within WP-EXC-001**: `manifest`, `signing`, `search`, `package-manager`, `exchange-client`, `installer` — each README states which TASK-EXC-00NN owns its real implementation.
- **Deferred, not explicitly required by WP-EXC-001's MVP scope**: `dependency-resolver` (a single-package install has no dependency graph to resolve yet), `update-service`.
- **Explicitly excluded by WP-EXC-001 §5**: `licensing`, `payments`, `reviews` — the task doc's own Scope section lists "Commerce," "Revenue Distribution," "Reviews," "Ratings," and "Licensing beyond Free Packages" as excluded; these packages exist as directories only so the eventual WP-EXC-002/003/004 work has a home to land in, per each package's own README.
- **Contracts-only, no implementation ever**: `interfaces` (added in the post-review amendments — see §9) — defines forward-looking cross-repository contracts, never a working implementation.

## 4. `apps/exchange-api`

A Fastify 5 app, built with a factory/entry-point split (`src/app.ts` exports `buildApp()`; `src/server.ts` calls it and only `.listen()`s when run directly, guarded by an ESM-safe "is this the main module" check using `pathToFileURL`). This split exists specifically so tests exercise routes via Fastify's `.inject()` — in-process, no real socket — rather than needing a live port, which would make tests slower and occasionally flaky (port collisions) for no benefit.

Two structural pieces were built now, ahead of their owning task, because they are infrastructure every future route needs rather than a route themselves:

- **A shared error handler** (`src/error-handler.ts`) mapping any thrown `DomainError` subclass to the `ApiErrorResponse` envelope with an appropriate HTTP status. Every future route (TASK-EXC-0003 onward) can `throw new NotFoundError(...)` / `throw new ValidationError(...)` and get a consistent response without re-plumbing error handling per route.
- **OpenAPI generation** (`@fastify/swagger` + `@fastify/swagger-ui`, mounted at `/documentation`) — satisfies EXC-001 §4's "every capability provided by the web interface shall also be available through a documented API" and the technology mandate's "OpenAPI" from the very first route, rather than being bolted on once there are many routes to retroactively document.

The one real route today, `GET /api/v1/health`, is a liveness check with no database dependency — proving the server starts, versions its API surface (`/api/${EXCHANGE_API_VERSION}`), and is documented, before any persistence exists (TASK-EXC-0002).

## 5. The two web apps (`publisher-portal`, `exchange-admin`)

**React 18 + Vite + TypeScript**, chosen because the technology mandate specifies Fastify (a backend framework) but is silent on the web UI framework, and because Vite + Vitest share the same underlying toolchain (esbuild/Rollup) already in use for testing, avoiding a second, differently-configured bundler. React Testing Library is used for the one placeholder-render test each app has today.

Both apps' `tsconfig.json` deliberately does **not** extend the repository's `tsconfig.base.json`: that base config targets Node (`module`/`moduleResolution: NodeNext`, no DOM lib, no JSX) for the library packages and the server, whereas a Vite-bundled browser app needs `moduleResolution: "Bundler"`, a DOM lib, and `jsx: "react-jsx"`. Documented here as a deliberate divergence rather than left as an unexplained inconsistency. Consequently, these two apps are also **not** part of the root `tsc -b` composite project graph (`tsconfig.json`'s `references`) — Vite performs their actual build (`vite build`), with `tsc --noEmit` run first purely for type-checking; the root `npm run build` script runs `tsc -b` for the composite graph and then explicitly builds these two apps afterward.

Kept as **two separate apps**, matching the pre-existing scaffold, rather than one app with an admin route: WP-EXC-001 §6 lists "Administration" alongside but distinct from the engineer/publisher-facing pages (Home, Search, Package Details, Publisher Profile, Upload, My Packages), and keeping them separate leaves room to deploy or access-control Administration independently later without a later restructuring.

## 6. Database (`db/`)

`db/migrations/` exists as an empty, version-controlled directory (`.gitkeep`) — the Flyway configuration and the first migration are TASK-EXC-0002's own deliverable, following the same convention `oep_acquisition` already established for Flyway usage elsewhere in the platform (see `db/README.md`).

## 7. Known, disclosed limitations

- `npm audit` reports 5 vulnerabilities (3 moderate, 1 high, 1 critical), all transitive dev-only dependencies of Vitest 2.x's bundled esbuild/Vite version (a dev-server-only advisory, not exploitable in production or CI test runs). Upgrading to Vitest 4 would resolve it but is a breaking change out of scope for this task; noted here rather than silently ignored.
- No CI pipeline configuration (e.g. GitHub Actions) was added — not an explicit WP-EXC-001 deliverable for this task, and adding one prematurely risked scope creep; `npm run build`, `npm test`, `npm run lint`, and `npm run format:check` are all real, working commands a future CI config can call directly.

## 8. Validation performed for the initial submission

- `npm run build` — full composite `tsc -b` graph (13 packages + the server) plus both UI apps' `vite build`, all succeed.
- `npm test` — 19 test files, 28 tests, all passing, run from a single root command across every package and app.
- `npm run lint` — zero errors/warnings across the workspace.
- `npm run format:check` — zero issues in every file this task created or modified (pre-existing specification documents under `docs/specifications/` were not reformatted, since they predate this task and reformatting them wasn't requested).

## 9. Post-review amendments

TASK-EXC-0001 was reviewed and approved with the following architectural amendments, applied after the initial submission described in §1–8 above (no functionality changed; renames and new governance documents only):

- **`packages/common` → `packages/core`** (`@oep-exchange/core`) — "common" tends to become an unscoped dumping ground over time; "core" names what the package actually is.
- **`apps/exchange_server` → `apps/exchange-api`** (`@oep-exchange/exchange-api`) — the executable API service now owns the "exchange-api" identity, since that's what engineers and publishers actually mean by "the Exchange API."
- **`packages/exchange_api` → `packages/api-contracts`** (`@oep-exchange/api-contracts`) — freed the `exchange-api` name for the application above, and more accurately describes the package's actual contents (shared REST contracts/DTOs/schemas, not an application).
- **`apps/publisher_portal` → `apps/publisher-portal`** and **`apps/admin_console` → `apps/exchange-admin`** (`@oep-exchange/exchange-admin`) — hyphenated, consistent naming across the app family.
- **New governance documents**: `docs/architecture/adr/ADR-0001-Repository-Structure.md`, `OWNERSHIP.md`, `docs/architecture/DEPENDENCY_GRAPH.md`, `CONTRIBUTING_ARCHITECTURE.md` (all at repository root except the ADR).
- **New package**: `packages/interfaces` — contracts-only (no implementation, no dependencies), the designated future integration point with `oep_foundation`/`oep_repository`/`oep_engine`.

Every dependency graph, package.json, tsconfig.json project reference, source import, and README in this repository was updated to the new names; nothing above changed any public API, runtime behavior, or test outcome — re-validated in full after the rename (§10 below covers this pass).

## 10. Validation performed after the amendments

- `npm install`, `npm run build`, `npm run lint`, `npm test` — all re-run after every rename; see the amendment's own completion report for the actual pass/fail counts (unchanged from §8: 28/28 tests, 0 lint errors, clean build).
