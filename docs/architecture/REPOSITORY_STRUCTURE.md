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

`db/migrations/` holds the Exchange's real initial schema (TASK-EXC-0002): `V1__initial_schema.sql` (the 8 tables — `publishers`, `publisher_profiles`, `package_categories`, `packages`, `package_versions`, `package_files`, `downloads`, `search_index`) and `V2__seed_package_categories.sql`, following the same Flyway convention `oep_acquisition` already established elsewhere in the platform (see `db/README.md`).

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

## 11. `apps/exchange-api/src/persistence` (TASK-EXC-0002)

TASK-EXC-0002's own task specification, `docs/tasks/WP-EXC-002.md`, differs from this document's earlier §6/§8 draft and from a few assumptions this task started with; §11.1 records the conflicts found and how each was resolved (with the user, before implementation proceeded) before §11.2 describes the resulting design.

### 11.1 Conflicts identified and resolved

Reading `docs/tasks/WP-EXC-002.md` (found only partway through this task — see the task's own final report for the full account) surfaced four conflicts with either this repository's already-approved architecture or this task's own initial draft:

- **Table set.** This document's earlier draft (§6, since corrected) and `db/README.md`'s original TASK-EXC-0001 note both said the eighth table would be `search_index`. WP-EXC-002.md §4 names `audit_log` instead and §2 explicitly excludes search indexing from this task. **Resolved: `audit_log`** — `search_index` is deferred to the Search task (TASK-EXC-0006).
- **Primary keys.** `oep_acquisition`'s platform-wide convention (surrogate `BIGSERIAL` + external `UUID`) was this task's initial draft. WP-EXC-002.md §8 requires UUID as the true primary key plus an optimistic-concurrency `row_version` column. **Resolved: UUID primary keys + `row_version`**, establishing this as the Exchange's own persistence convention (distinct from `oep_acquisition`'s) going forward.
- **Persistence package location.** WP-EXC-002.md §7 says to create a top-level `packages/persistence`. `docs/architecture/DEPENDENCY_GRAPH.md` §3 already restricts direct PostgreSQL access to `exchange-api` alone. **Resolved: kept inside `exchange-api`** (`src/persistence/`), preserving the already-approved rule rather than carving out an exception for a new package.
- **Repository interface location.** WP-EXC-002.md §6 says interfaces belong in `packages/interfaces`. That package's own already-approved charter (its README, `OWNERSHIP.md`) defines it as cross-repository-contracts-only, never an implementation, and never for in-repository domain repositories. **Resolved: kept interfaces alongside their implementations** in `exchange-api/src/persistence/repositories/`; `packages/interfaces` keeps its existing charter unchanged.

### 11.2 Resulting design

The Exchange's persistence layer is an internal module of `apps/exchange-api`, not a new top-level workspace package (per the resolution above).

Layout:

- `config.ts` / `pool.ts` — environment-sourced `DatabaseConfig` and a `pg.Pool` factory, built against a minimal `Queryable` interface (`{ query(...) }`, satisfied by both `Pool` and `PoolClient`) so repositories never depend on connection-pool lifecycle directly.
- `types.ts` — one domain type (plus a `New*` input type) per table in `db/migrations/V1__initial_exchange_schema.sql`. `id` is the table's true UUID primary key (WP-EXC-002.md §8); every mutable entity carries `rowVersion`, incremented on every UPDATE — append-only event logs (`Download`, `AuditLogEntry`) have none.
- `repositories/*.ts` — one repository interface + `Postgres*Repository` implementation pair per table (`Publisher`, `PublisherProfile`, `Category`, `Package`, `PackageVersion`, `PackageFile`, `Download`, `Audit` — naming follows WP-EXC-002.md §6 where it names one explicitly), each the sole owner of its table's SQL, consistent with `OWNERSHIP.md`.
- `test-support.ts` — shared test-database bootstrap (env-overridable connection settings, migration application, `TRUNCATE ... CASCADE`, and reachability detection), mirroring `oep_acquisition`'s own established testing precedent so the suite stays runnable without a live database, just less exercised. See `db/README.md` "Testing without a live database".
- `schema.test.ts` — migration/constraint/rollback tests (WP-EXC-002.md §10) distinct from each repository's own CRUD tests: asserts the applied schema's shape (all 8 tables present, UUID primary keys, `row_version` on mutable tables only) and behavioral guarantees (a rejected duplicate leaves no partial row; a CHECK constraint rejects an invalid enum value at the database level).

No routes were wired to these repositories in this task — `GET /api/v1/health` remains the only real route (TASK-EXC-0001). Routing Publisher/Package/Download/Audit HTTP endpoints through this persistence layer is later tasks' own deliverable, per WP-EXC-001's suggested task sequence.

## 12. Validation performed for TASK-EXC-0002

- `npm run build` — full composite `tsc -b` graph plus both UI apps' `vite build` succeed with the new `persistence` module and its `pg`/`@types/pg` dependency.
- `npm test` — every persistence repository has an integration test suite (`describe.skipIf` against `test-support.ts`'s reachability check); all skip cleanly in this environment (no reachable PostgreSQL instance was set up, and per this task's own standing decision, no attempt was made to discover or brute-force a database credential — see `db/README.md` "Running migrations" for the documented developer/operator setup path instead). `config.test.ts` (a pure unit test, no database) passes unconditionally.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.

## 13. Publisher Registry (TASK-EXC-0003)

Implements `docs/tasks/WP-EXC-003.md`'s "REST API -> Publisher Service -> Publisher Repository -> PostgreSQL" architecture (§3), reusing the `PublisherRepository`/`PublisherProfileRepository`/`AuditRepository` built in TASK-EXC-0002 — no persistence-layer redesign, only additive schema changes described below.

### 13.1 Gaps filled (not conflicts — see §11.1 for what a real conflict against this repository's approved architecture looks like)

WP-EXC-003.md's Publisher Model (§5) and this repository's already-approved schema (TASK-EXC-0002, grounded in EXC-002) don't fully overlap in field names. Each gap below was resolved by extending additively, consistent with "propose missing details, do not redesign":

- **"Legal Name"** (§5) is not a new column — it is the persistence layer's existing `name` column (EXC-002 §4's "Publisher Name"), surfaced as `legalName` in `PublisherDto`. `displayName` maps directly to `display_name`.
- **"Contact Email"** (§5) did not exist on `publishers`. Added via `V3__publisher_registration_fields.sql`, with a case-insensitive partial unique index (active rows) enforcing WP-EXC-003.md §6's "Duplicate contact email" rule the same way `namespace` already enforces uniqueness.
- **"Duplicate publisher names"** (§6) — `publishers.name` had no uniqueness constraint before this task (only `namespace` did). `V3` replaces the plain index from V1 with a unique partial one.
- **`namespace` and `publisherType`** are required by `POST /publishers` even though WP-EXC-003.md §5's field list doesn't name them — both are `NOT NULL` columns on the already-approved `publishers` table (EXC-002 §5/§6) with no sensible default, so removing them was not an option; WP-EXC-003.md's list is treated as the task's own illustrative subset, not an instruction to relax already-approved schema requirements (the same treatment TASK-EXC-0002 gave "Example:"-prefixed lists elsewhere).
- **`description`/`website`** (§5) already have an approved home: `publisher_profiles` (EXC-002 §7's separate, public-facing Profile). `PublisherService` transparently upserts/reads that table for these two fields rather than duplicating the columns onto `publishers` — the API-facing `PublisherDto` still exposes them as top-level fields; only the storage location is split, exactly as TASK-EXC-0002 already established.

### 13.2 Design

- **`packages/api-contracts/src/publisher.ts`** — `PublisherDto`, `CreatePublisherRequest`, `UpdatePublisherRequest`, `PublisherListResponse`, `PublisherType`, `PublisherStatus`. Pure types (no runtime logic), consistent with `health.ts`'s existing pattern — no dedicated test file, matching that precedent.
- **`apps/exchange-api/src/services/publisher-validation.ts`** — pure, DB-free validation (required fields, email/identifier format, status-transition rules). Duplicate name/namespace/email detection is data-dependent and is left to `PostgresPublisherRepository`, which already throws `ConflictError` for each (built in TASK-EXC-0002); the service relies on that rather than re-querying.
- **`apps/exchange-api/src/services/publisher-service.ts`** — the actual business logic (WP-EXC-003.md §3 "Business logic shall remain inside the Publisher Service"). Lives inside `exchange-api`, not a new `packages/*` service package: `DEPENDENCY_GRAPH.md` §3 forbids a package from depending on an application, and the persistence layer this service calls is itself an `exchange-api`-internal module (§11.1) — a package outside `exchange-api` structurally cannot reach it. Records an `audit_log` entry for every mutation via `AuditRepository` (WP-EXC-001 §4 "All transactions are audited"), giving that table its first real writer.
- **`apps/exchange-api/src/routes/publishers.ts`** — thin Fastify handlers (`GET /publishers`, `GET /publishers/:id`, `POST /publishers`, `PUT /publishers/:id`, `DELETE /publishers/:id`, per WP-EXC-003.md §4) with JSON Schema request/response definitions, matching `health.ts`'s existing schema-first pattern (ADR-0001 "Why Fastify") so these routes are automatically documented at `/documentation`.
- **`apps/exchange-api/src/app.ts`** — `BuildAppOptions` gained an injectable `db?: Queryable`, defaulting to `createPool()`, so tests can point the app at a test database (or, for routes that don't touch it, simply never exercise the connection — `pg.Pool` is lazy and opens no socket until a query runs).
- **`apps/exchange-api/src/error-handler.ts`** — extended to map Fastify's own request-schema validation failures (`error.validation`, e.g. a malformed `POST /publishers` body) to the same `ApiErrorResponse` envelope at 400. This gap existed since TASK-EXC-0001 but was unexercised until this task's routes had real request bodies to validate — without it, a schema-validation failure would have fallen through to the generic 500 branch instead of a 400.

### 13.3 Validation performed for TASK-EXC-0003

- `npm run build` — clean across the full composite graph.
- `npm test` — `publisher-validation.test.ts` (pure unit, 18 tests) and `publisher-service.test.ts` (in-memory fake repositories, 14 tests, mirroring `oep_acquisition`'s own "Service-layer tests against an in-memory fake repository" precedent) pass unconditionally. `publisher-repository.test.ts`'s new cases (contact email, name uniqueness, update, soft delete) and `routes/publishers.test.ts` (full REST lifecycle + validation/conflict/not-found status codes + OpenAPI presence) skip cleanly without a reachable database, same as every other integration suite.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.

## 14. Package Catalog (TASK-EXC-0004)

Implements `docs/tasks/WP-EXC-004.md`'s "REST API -> Package Service -> Package Repository -> PostgreSQL" architecture (§3), reusing the `PackageRepository`/`CategoryRepository`/`PackageVersionRepository`/`AuditRepository` built in TASK-EXC-0002 — same pattern as §13, no persistence-layer redesign, no new migration beyond one additive uniqueness index.

### 14.1 Gaps filled

WP-EXC-004.md's Package Model (§5) doesn't map 1:1 onto the already-approved `packages` table (TASK-EXC-0002, grounded in PKG-002) any more cleanly than WP-EXC-003.md's did for Publisher — the same treatment applies (extend additively, do not redesign):

- **"Package ID"** -> `id`, the persistence layer's UUID primary key (same pattern as Publisher's "Publisher ID" -> `id`).
- **"Package Name"** -> `packageId`, the persistence layer's existing `package_id` column (PKG-001/PKG-002's reverse-domain package identifier, e.g. `com.divad.honda.gl1200.electrical`) — required at creation and immutable afterward, the same role `namespace` played for Publisher.
- **"Display Name"** -> `displayName`, the persistence layer's existing `title` column (PKG-002's manifest "title" field) — no new column needed; "Package Name" and "Display Name" map to two fields that already existed for two different reasons (identity vs. presentation), the same shape as Publisher's `legalName`/`displayName` split.
- **"Current Version"** -> `currentVersion`, a semver string looked up from `package_versions` via `latestVersionId` and merged in (never stored redundantly) — `null` until a version is registered. `PackageService` does not register versions itself: `package_versions.manifest` is `NOT NULL`, and manifest parsing is explicitly excluded from this task (§2) and belongs to the Upload task, so "Current Version" here is read-only.
- **"Category"** -> `categoryId`, the existing FK to `package_categories`; "Invalid category references" (§6) is enforced by `PackageService` looking the category up before writing, not by letting the FK constraint raise.
- Manifest-derived columns already on `packages` (`engineeringDomains`, `keywords`, `capabilities`, `license`) are not part of this task's model, for the same reason `currentVersion`'s write path isn't: they come from a manifest, and manifest parsing is excluded here (§2). They remain at their column defaults until the Upload task populates them.
- **"Package version registration"** is listed as Included (§2) but no versions endpoint appears in §4's endpoint list, and building one would require manifest data this task explicitly excludes from scope. Resolved as: this task surfaces the already-built version-registration _capability_ (`PackageVersionRepository`, from TASK-EXC-0002) only as a read (`currentVersion`); no new write path or endpoint is added here — see Remaining Work in this task's completion report.

### 14.2 Design

Mirrors §13.2's Publisher Registry structure exactly, one file per concern:

- **`db/migrations/V4__package_name_uniqueness.sql`** — a unique partial index on `packages (publisher_id, title)` (active rows), enforcing WP-EXC-004.md §6 "Duplicate package names within a publisher" (packages titled the same across _different_ Publishers remain allowed — only `package_id`, PKG-001's global identifier, was already globally unique).
- **`apps/exchange-api/src/persistence/repositories/package-repository.ts`** — gained `findByPublisherAndTitle`, `list`, `update`, `softDelete`, matching the shape TASK-EXC-0003 added to `PublisherRepository`.
- **`packages/api-contracts/src/package.ts`** — `PackageDto`, `CreatePackageRequest`, `UpdatePackageRequest`, `PackageListResponse`, `PackageStatus`. Pure types, no dedicated test file (same precedent as `publisher.ts`).
- **`apps/exchange-api/src/services/package-validation.ts`** — pure, DB-free validation (required fields, packageId/UUID format, status-transition rules for `draft`/`published`/`deprecated`/`suspended` — see the module's own comment for the transition table's reasoning). Duplicate name/id detection stays in `PostgresPackageRepository` (`ConflictError`); publisher/category _reference_ validity is data-dependent and lives in the service instead (a lookup, not a repository-level duplicate check).
- **`apps/exchange-api/src/services/package-service.ts`** — the business logic. Lives inside `exchange-api` for the same structural reason `publisher-service.ts` does (§13.2): it depends on the `exchange-api`-internal persistence layer, which no `packages/*` package may reach. Records an `audit_log` entry per mutation (`PackageCreated`/`PackageUpdated`/`PackagePublished`/`PackageDeprecated`/`PackageSuspended`/`PackageDeleted`).
- **`apps/exchange-api/src/routes/packages.ts`** — thin Fastify handlers (`GET /packages`, `GET /packages/:id`, `POST /packages`, `PUT /packages/:id`, `DELETE /packages/:id`, per WP-EXC-004.md §4), same schema-first pattern as `routes/publishers.ts`.
- **`apps/exchange-api/src/app.ts`** — wires `PackageService` alongside `PublisherService`, sharing the same injectable `db`.

### 14.3 Validation performed for TASK-EXC-0004

- `npm run build` — clean across the full composite graph.
- `npm test` — `package-validation.test.ts` (pure unit, 21 tests) and `package-service.test.ts` (in-memory fake repositories, 18 tests) pass unconditionally. `package-repository.test.ts`'s new cases (title uniqueness per publisher, cross-publisher title reuse, list, update, soft delete) and `routes/packages.test.ts` (full REST lifecycle + validation/conflict/not-found status codes + OpenAPI presence) skip cleanly without a reachable database, same as every other integration suite.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.
