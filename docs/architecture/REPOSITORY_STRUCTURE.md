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

## 15. Package Upload Pipeline (TASK-EXC-0005)

Implements `docs/tasks/WP-EXC-005.md`'s "REST API -> Upload Service -> Manifest Parser -> Metadata Extraction -> Package Repository -> File Storage" architecture (§3). This is the first task to give `packages/manifest` and `packages/package-manager` real implementations (both were scaffold-only since TASK-EXC-0001), and the first to write to the filesystem as well as PostgreSQL.

### 15.1 Splitting the pipeline across the package/application boundary

WP-EXC-001's own `OWNERSHIP.md` already specified, before this task began, that `manifest` owns manifest parsing and `package-manager` "orchestrates the upload pipeline end to end... sequences `manifest`, `signing`, and catalog writes." Taken completely literally, that would mean `package-manager` performs catalog registration itself — but `docs/architecture/DEPENDENCY_GRAPH.md` §3 already forbids a package from depending on an application, and the persistence layer lives inside `exchange-api` (§11.1), so no package can reach PostgreSQL directly. This is resolved the way `DEPENDENCY_GRAPH.md` §3 itself already anticipates: "a package needing data reads/writes gets them through a function `exchange-api`... exposes, never by importing a database client of its own." Concretely:

- **`packages/manifest`** (real implementation) — `extractManifestFromArchive`/`extractManifestJson` (opens the `.oep` ZIP container, PKG-001 §5, and reads `manifest/package.json`) and `parseManifest` (validates against PKG-002 §5/§20). Pure, DB-free, no Fastify.
- **`packages/package-manager`** (real implementation) — `processUpload(archive: Buffer)` sequences archive extraction, manifest parsing, and metadata/file-hash extraction, returning a plain `ProcessedUpload` result. Still pure and DB-free — it is hooked up to `manifest`, never to `exchange-api`.
- **`apps/exchange-api/src/services/upload-service.ts`** — calls `processUpload()` first, then performs the actual `Package`/`PackageVersion`/`PackageFile` registration and file storage using its own (already-approved, `exchange-api`-internal) persistence layer. This is `package-manager`'s "sequences... catalog writes" satisfied at the point where the sequenced data determines what gets written, without `package-manager` ever holding a database connection.

Signature verification (`manifest.signatures`, PKG-002 §17) is read but never verified — explicitly excluded from WP-EXC-005.md §2. `@oep-exchange/signing` remains scaffold-only; `package-manager`'s dependency on it (declared since TASK-EXC-0001) is unused until a future task implements real verification and `UploadService` calls it before registration.

### 15.2 Design

- **`packages/manifest/src/*`** — `types.ts` (the manifest's own `PackageManifest` shape — independent of, though structurally similar to, `persistence/types.ts`'s `PackageVersion`, since the two represent different concerns and `manifest` cannot import from `exchange-api` regardless), `parse-manifest.ts`, `extract-manifest-from-archive.ts` (uses `adm-zip`, pinned to `^0.6.0` specifically to avoid a disclosed high-severity advisory in `<0.6.0` — "crafted ZIP file triggers 4GB memory allocation" — directly relevant since this package's whole job is reading untrusted uploaded archives).
- **`packages/package-manager/src/*`** — `types.ts` (`ExtractedPackageMetadata`, `UploadedFileMetadata`, `ProcessedUpload`), `extract-metadata.ts` (projects a `PackageManifest` into Package Catalog fields), `compute-file-metadata.ts` (SHA-256 + size of the raw upload), `process-upload.ts` (the orchestrator).
- **`apps/exchange-api/src/storage/package-file-storage.ts`** — `PackageFileStorage` interface + `LocalPackageFileStorage`, content-addressable and SHA-256-sharded (`{root}/{first-two-hex}/{hash}.oep`) — the same sharding convention `oep_acquisition`'s Reference Vault (`compute_vault_path`) already established platform-wide, adapted with a `.oep` extension for on-disk clarity. `storage-config.ts` reads the root directory from `OEP_EXCHANGE_STORAGE_DIR` (default `./storage/packages`).
- **`apps/exchange-api/src/services/upload-validation.ts`** — pure format checks (publisher/category id shape, file presence). Manifest/archive validity is `@oep-exchange/manifest`'s own thrown `ValidationError`s; publisher/category _existence_, namespace ownership, and duplicate-version detection are data-dependent and live in `UploadService`.
- **`apps/exchange-api/src/services/upload-service.ts`** — the pipeline's business logic (WP-EXC-005.md §3 "Business logic shall remain within the Upload Service"). Validates the uploading Publisher and (optional) Category exist, that the manifest's `packageId` falls under the uploading Publisher's namespace (EXC-002 §5: "Package IDs shall reside within Publisher namespaces"), that a differently-owned `packageId` isn't hijacked (`ForbiddenError`), and that the version isn't a duplicate — then stores the file, registers the `Package` (first upload) and `PackageVersion`/`PackageFile` (every upload), and points the Package's `latestVersionId` at the new version. Records an `audit_log` entry (`PackageVersionUploaded`) per upload.
- **`apps/exchange-api/src/routes/upload.ts`** — `POST /packages/upload`, a `multipart/form-data` request (`@fastify/multipart`, `attachFieldsToBody: true`) carrying the `.oep` file plus `publisherId`/`categoryId` form fields. No `body` JSON Schema is declared (the multipart field-envelope shape doesn't fit Fastify's schema validator); validation happens in the handler and `UploadService` instead, same as it would either way.
- **`apps/exchange-api/src/app.ts`** — registers `@fastify/multipart` (100 MiB upload limit) and wires `UploadService`; `BuildAppOptions` gained an injectable `storage?: PackageFileStorage` alongside the existing `db?`, so tests can point storage at a temp directory.
- **`packages/api-contracts/src/upload.ts`** — `UploadResultDto`.

### 15.3 Validation performed for TASK-EXC-0005

- `npm run build` — clean across the full composite graph, including the two newly-real packages and their new `adm-zip` dependency.
- `npm test` — pure unit tests (`packages/manifest`: 30 tests; `packages/package-manager`: 8 tests; `upload-validation.test.ts`: 8 tests) and service tests against in-memory fakes plus real in-memory ZIP archives built with `adm-zip` (`upload-service.test.ts`: 9 tests) pass unconditionally. `package-file-storage.test.ts` (3 tests) and `storage-config.test.ts` (2 tests) exercise a real temp directory and pass unconditionally — no database involved. `routes/upload.test.ts` (5 tests, full REST lifecycle against a real database and a real temp-directory `LocalPackageFileStorage`) skips cleanly without a reachable database, same as every other integration suite.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.
- `npm audit` — introducing `adm-zip` briefly raised the vulnerability count by one (a high-severity advisory in `<0.6.0`, directly relevant to this task's untrusted-upload attack surface); pinning to `^0.6.0` (which fixes it) returned the count to the pre-existing baseline (5, all pre-existing dev-only Vitest/esbuild advisories disclosed since TASK-EXC-0001).

## 16. Package Search (TASK-EXC-0006)

Implements `docs/tasks/WP-EXC-006.md`'s "REST API -> Search Service -> Search Repository -> PostgreSQL" architecture (§3), and builds the `search_index` table deferred from TASK-EXC-0002 (§11.1: TASK-EXC-0002 registered `audit_log` instead, noting search indexing was out of scope and belonged to this task).

### 16.1 Splitting search across the package/application boundary

`OWNERSHIP.md` describes `packages/search` as owning "the search index itself." Taken literally that would mean the package queries PostgreSQL directly, which `DEPENDENCY_GRAPH.md` §3 forbids (no package may hold a database connection or depend on an application). This is resolved with the exact same split TASK-EXC-0005 established for `packages/manifest`/`packages/package-manager` versus `UploadService` (§15.1):

- **`packages/search`** (real implementation) — `normalizeSearchQuery()` (validates/defaults a raw REST query: identifier format, `status`/`sortBy`/`sortDirection` enum membership, `page`/`pageSize` clamping) and `computePagination()` (the `totalPages`/`currentPage` math). Pure, DB-free, no Fastify.
- **`apps/exchange-api/src/persistence/repositories/search-repository.ts`** — `PostgresSearchRepository`, the only place `search_index` is queried, joining `packages`/`publishers`/`package_categories`/`package_versions` for the fields WP-EXC-006.md §5 wants displayed.
- **`apps/exchange-api/src/services/search-service.ts`** — `SearchService`, which calls `packages/search`'s two pure functions and `SearchRepository.search()`, then assembles the `SearchResponse` DTO. No business logic beyond that orchestration lives here (WP-EXC-006.md §9: "business logic shall remain within the Search Service").

### 16.2 Keeping `search_index` current without touching prior tasks' approved code

Rather than modifying `PackageService`, `UploadService`, or any other already-tested, already-approved service to also write to `search_index`, `db/migrations/V5__search_index.sql` adds a PostgreSQL trigger (`refresh_package_search_index()`) fired `AFTER INSERT OR UPDATE ON packages FOR EACH ROW`. It recomputes a `search_text` document (package id, title, summary, description, publisher name/display name, category name, keywords, current version) and upserts it into `search_index`, whose `search_vector` is a generated, stored `tsvector` column (`GENERATED ALWAYS AS (to_tsvector('english', search_text)) STORED`) backed by a GIN index. Every task that already writes to `packages` needs zero changes to keep the index current.

A soft-deleted Package's search document is left in place but unreachable — every read query joins back through `packages` and filters `deleted_at IS NULL`, the same soft-delete convention used everywhere else in this schema.

### 16.3 Design

- **`db/migrations/V5__search_index.sql`** — `search_index` table, GIN index on `search_vector`, `refresh_package_search_index()` trigger function and its trigger on `packages`.
- **`apps/exchange-api/src/persistence/types.ts`** — `SearchSortBy`, `SearchSortDirection`, `SearchQuery`, `SearchResultItem`, `SearchResults`, appended alongside the existing persistence types.
- **`apps/exchange-api/src/persistence/repositories/search-repository.ts`** — `SearchRepository` interface + `PostgresSearchRepository`. Keyword matching uses `search_index.search_vector @@ websearch_to_tsquery('english', ...)`; filtering/sorting/pagination operate on `packages` and its joined fields directly. `COUNT(*) OVER()` returns the total matching row count in the same query rather than a second round trip. Sorting never uses `ts_rank`/relevance — WP-EXC-006.md §7 lists only Name/CreatedDate/UpdatedDate, so the keyword join is used for filtering only.
- **`packages/search/src/*`** — `types.ts` (this package's own independent copy of the query/pagination shapes, since it cannot import from `exchange-api`), `normalize-query.ts`, `pagination.ts`.
- **`packages/api-contracts/src/search.ts`** — `SearchResultItemDto`, `SearchResponse`.
- **`apps/exchange-api/src/services/search-service.ts`** — `SearchService`.
- **`apps/exchange-api/src/routes/search.ts`** — `GET /search`, registered under the existing `/api/v1` prefix. The query string is passed through to `SearchService` untouched; all validation happens in `packages/search`.
- **`apps/exchange-api/src/app.ts`** — wires `PostgresSearchRepository` + `SearchService` + `registerSearchRoute`, alongside the existing Publisher/Package/Upload wiring.

### 16.4 Validation performed for TASK-EXC-0006

- `npm run build` — clean across the full composite graph, including `packages/search`'s first real implementation and its new project reference from `apps/exchange-api`.
- `npm test` — `packages/search` unit tests (`normalize-query.test.ts`: 13 tests, `pagination.test.ts`: 4 tests) pass unconditionally. `search-service.test.ts` (4 tests, in-memory fake repository) passes unconditionally. `search-repository.test.ts` (8 tests), `routes/search.test.ts` (8 tests), and `schema.test.ts`'s new `search_index`/trigger assertions (3 tests) skip cleanly without a reachable database, same as every other integration suite.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.

## 17. Package Download Service (TASK-EXC-0007)

Implements `docs/tasks/WP-EXC-007.md`'s "REST API -> Download Service -> Download Repository -> Package Storage -> Package Artifact" architecture (§3). Unlike every prior task, this one needed no new migration and no new package: the `downloads` table and `DownloadRepository` were already built in TASK-EXC-0002 (in anticipation of this task), and the artifact-retrieval need is met by extending `apps/exchange-api/src/storage/package-file-storage.ts` — the same storage TASK-EXC-0005 built for writing uploaded archives — with a `retrieve()` method, rather than introducing a second storage abstraction.

### 17.1 Design

- **`apps/exchange-api/src/storage/package-file-storage.ts`** — `PackageFileStorage` gained `retrieve(storagePath): Promise<Buffer>`; `LocalPackageFileStorage.retrieve()` is a plain `readFile`, symmetric with `store()`.
- **`apps/exchange-api/src/services/download-validation.ts`** — pure, DB-free identifier/parameter format checks (package id UUID shape, a non-blank version string), mirroring `package-validation.ts`'s split between format validation and data-dependent existence checks.
- **`apps/exchange-api/src/services/download-service.ts`** — `DownloadService`, following WP-EXC-007.md §5's flow exactly: validate the Package exists and its status permits download (§6 — only `suspended` blocks; `draft`/`published`/`deprecated` may still be downloaded), resolve the target `PackageVersion` (the Package's `latestVersionId` for the "current version" endpoint, or an exact `findByPackageAndVersion` lookup for the versioned endpoint), locate its `PackageFile`, read the bytes back via `PackageFileStorage.retrieve()`, record a `downloads` row, and return the artifact plus its metadata (file name, mime type, size, SHA-256, resolved version) for the route to shape into an HTTP response.
- **`apps/exchange-api/src/routes/download.ts`** — `GET /packages/{id}/download` and `GET /packages/{id}/versions/{version}/download` (WP-EXC-007.md §4), registered under the existing `/api/v1` prefix. The response body is the raw artifact; "download metadata" (WP-EXC-007.md §2/§8) is carried as headers (`Content-Disposition`, `Content-Length`, `X-Checksum-Sha256`, `X-Package-Id`, `X-Package-Version`) alongside it rather than as a separate JSON envelope, since the endpoint's job is delivering bytes, not describing them.
- **`apps/exchange-api/src/app.ts`** — wires `DownloadService` (reusing the same `PackageRepository`/`PackageVersionRepository`/`PackageFileRepository`/storage instances already constructed for `PackageService`/`UploadService`) and `registerDownloadRoutes`.

### 17.2 Validation performed for TASK-EXC-0007

- `npm run build` — clean across the full composite graph.
- `npm test` — `download-validation.test.ts` (5 tests) and `download-service.test.ts` (10 tests, in-memory fakes) pass unconditionally. `package-file-storage.test.ts` gained 2 `retrieve()` tests, passing unconditionally (real temp directory, no database). The pre-existing `download-repository.test.ts` (3 tests) needed no changes. `routes/download.test.ts` (8 tests, full REST lifecycle — upload then download — against a real database and a real temp-directory `LocalPackageFileStorage`) skips cleanly without a reachable database, same as every other integration suite.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.
- `npm audit` — unchanged from the pre-existing baseline; no new dependency was introduced.

## 18. Repository Installation Integration (TASK-EXC-0008)

Implements `docs/tasks/WP-EXC-008.md`'s "REST API -> Installation Service -> Repository Client -> Exchange Services -> Repository Public API" architecture (§3): §5's flow reads as "Repository Client" and "Exchange Services" both being dependencies `InstallationService` orchestrates (the latter — `PackageRepository`/`PackageVersionRepository`/`PackageFileRepository`/`PackageFileStorage` — resolves the Package/version/artifact, exactly as `DownloadService` already does; the former reaches the Repository), rather than a strict linear pipeline where the Repository Client itself calls into Exchange Services. This is the first task where the "other side" of an integration (the OEP Repository) doesn't exist anywhere in this monorepo or the wider platform yet — see §18.1.

### 18.1 What "the Repository's approved public interface" means when no Repository exists yet

`docs/architecture/DEPENDENCY_GRAPH.md` §5 already anticipated this integration before this task began: "a network call (REST/HTTP) against a published API, never a source-level import," landing in `packages/installer` via a future `RepositoryService`-shaped contract in `packages/interfaces`. `packages/interfaces`'s own README named that contract `RepositoryService`, but WP-EXC-008.md itself names the abstraction `RepositoryClient` — the task specification is authoritative, so that is the name actually defined (§18.2). No `oep_repository` directory exists anywhere in the platform; `oep_foundation`'s own Repository is documented as exposing a **Public C API**, not a REST endpoint, and "Repository implementation" is explicitly excluded from this task's scope (WP-EXC-008.md §2). Given that, this task:

- Defines `RepositoryClient` (and its request/result types) as a pure, type-only contract in `packages/interfaces` — satisfying "communicate with the Repository only through its approved public interface" architecturally, regardless of what that interface eventually turns out to be.
- Implements `HttpRepositoryClient` in `packages/installer` (the only package `DEPENDENCY_GRAPH.md` §5 ever expected to depend on `interfaces`) — a real, working HTTP client against a configurable base URL, matching the platform's own already-documented anticipation of how this integration will work, but not a dependency on any actual Repository codebase.
- Implements `StubRepositoryClient` alongside it — a deterministic, in-memory stand-in, the same "the real other side doesn't exist yet, build a Stub" pattern `oep_acquisition`'s own Connector framework already established platform-wide (`StubConnector`, WP-0005). This is what `apps/exchange-api` wires by default today, so the entire Installation flow is real, tested, and end-to-end functional without waiting on a Repository to exist. Swapping in `HttpRepositoryClient` once a real Repository is reachable requires no change to `InstallationService` — both satisfy the same `RepositoryClient` contract.

### 18.2 Design

- **`packages/interfaces/src/repository-client.ts`** — `RepositoryClient`, `RepositoryInstallRequest`, `RepositoryInstallResult`. Type-only, per this package's charter; the first contract this package has ever actually defined (previously "deliberately empty," per §3/§9).
- **`packages/installer/src/*`** — `HttpRepositoryClient` (POSTs the artifact base64-encoded to `{baseUrl}/api/v1/packages/install`; network/non-2xx failures are caught and reported as `{ accepted: false, message }` rather than thrown, so a Repository being unreachable is a recorded Installation outcome, not an unhandled exception) and `StubRepositoryClient` (configurable to simulate acceptance or rejection, for exercising both outcomes in tests).
- **`db/migrations/V6__installations.sql`** — `installations`: one row per install attempt, created `pending` and updated exactly once more to `completed`/`failed`. Unlike `downloads`/`audit_log` (append-only, no `row_version`), this table carries `row_version` despite being a historical record, the same way `package_versions` does for its own pending -> published lifecycle.
- **`apps/exchange-api/src/persistence/repositories/installation-repository.ts`** — `InstallationRepository` + `PostgresInstallationRepository` (`create`/`findById`/`getByIdOrThrow`/`complete`/`fail`).
- **`packages/api-contracts/src/installation.ts`** — `InstallationDto`, `InstallRequest`.
- **`apps/exchange-api/src/services/installation-validation.ts`** — pure, DB-free identifier/parameter format checks, mirroring `download-validation.ts`.
- **`apps/exchange-api/src/services/installation-service.ts`** — `InstallationService` (WP-EXC-008.md §8: "Business logic shall remain inside InstallationService"). Follows §5's flow: validate the Package exists and its status permits installation (§6 — only `suspended` blocks, the same rule `DownloadService` uses) -> resolve the requested (or current) `PackageVersion` -> locate its `PackageFile` -> create a `pending` Installation row -> read the artifact bytes -> call `RepositoryClient.install()` -> record the terminal `completed`/`failed` state and an `audit_log` entry -> return the Installation. A Repository rejection is a valid, recorded outcome (`status: 'failed'`, `errorMessage` populated) rather than a thrown error — mirroring `oep_acquisition`'s own Job Execution History precedent, where an execution can complete with `status: 'failed'` without the API call itself being an error.
- **`apps/exchange-api/src/routes/installation.ts`** — `POST /packages/{id}/install` (body `{ version?: string }`; installs the Package's current version when omitted) and `GET /installations/{installationId}` (WP-EXC-008.md §4). Both return `201`/`200` respectively even when `status` is `failed` — the HTTP request itself succeeded; the Repository's own decision is data in the response body, not an HTTP error.
- **`apps/exchange-api/src/app.ts`** — `BuildAppOptions` gained an injectable `repositoryClient?: RepositoryClient`, defaulting to `StubRepositoryClient`; wires `InstallationService` reusing the same `PackageRepository`/`PackageVersionRepository`/`PackageFileRepository`/storage instances already constructed for `PackageService`/`DownloadService`.

### 18.3 Validation performed for TASK-EXC-0008

- `npm run build` — clean across the full composite graph, including `packages/interfaces`'s first real contract and `packages/installer`'s first real implementation.
- `npm test` — `packages/installer`: `stub-repository-client.test.ts` (3 tests) and `http-repository-client.test.ts` (5 tests, injected fake `fetch`) pass unconditionally. `installation-validation.test.ts` (7 tests) and `installation-service.test.ts` (13 tests, in-memory fakes including a fake `RepositoryClient` exercising both acceptance and rejection) pass unconditionally. `installation-repository.test.ts` (6 tests), `routes/installation.test.ts` (10 tests, full REST lifecycle — upload then install, including a simulated Repository rejection via an injected `StubRepositoryClient` — against a real database), and `schema.test.ts`'s new `installations` assertions (2 tests) skip cleanly without a reachable database, same as every other integration suite.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.
- `npm audit` — unchanged from the pre-existing baseline; no new dependency was introduced (`HttpRepositoryClient` uses the platform-global `fetch`).

## 19. Engineering Exchange Web Application (TASK-EXC-0009)

Implements `docs/tasks/WP-EXC-009.md`'s "Browser -> React Application -> Exchange API Client -> Exchange REST API" architecture (§3): the first production UI, giving `apps/publisher-portal` (scaffold-only since TASK-EXC-0001) and `packages/exchange-client` (scaffold-only since TASK-EXC-0001, despite its README claiming TASK-EXC-0007 — that never materialized; this task is where it actually happens) their real implementations.

### 19.1 Scope boundary: "Publisher Portal" the capability vs. `publisher-portal` the app

WP-EXC-009.md §2 excludes "Publisher Portal" from scope, which reads as a contradiction against building out the app literally named `publisher-portal` — resolved the same way `OWNERSHIP.md` already describes the app: it serves _both_ "the publisher's point of view" (package management, upload — excluded here) _and_ "the engineer's point of view" (discovery, download — this task's actual seven views). §4's view list (Marketplace Home, Search Results, Package Detail, Publisher Profile, Downloads, My Library, 404) confirms this reading — none of them are publisher self-service screens (no Upload page, no "create/edit Publisher" form). This task builds only the discovery/marketplace side; the publisher self-service side remains unbuilt, for a future task.

### 19.2 Technology choices where WP-EXC-009.md is silent

Consistent with this repository's pattern of choosing the smallest tool that satisfies an unspecified requirement (the same reasoning already used for React+Vite itself, per ADR-0001):

- **Routing**: `react-router-dom` (v6) — the only new runtime dependency this task adds. No lighter alternative exists for a multi-view SPA with URL-synced search params (`SearchResultsPage`'s filters).
- **State management** (§2 "State management"): no Redux/Zustand/TanStack Query. `useAsync()` (`apps/publisher-portal/src/hooks/use-async.ts`) is a ~40-line generic loading/success/error hook every page uses for its own API call(s); `LibraryContext` (`src/state/LibraryContext.tsx`) is a `useReducer` + `localStorage`-backed store for the two features that need client-side state at all (Downloads/My Library history — see §19.4). A full state library would manage server data this app never needs to cache or share across unrelated views.
- **Styling** (§8 "consistent visual language"): one global stylesheet (`src/styles/global.css`) with CSS custom properties for tokens and semantic component classes — no CSS-in-JS, no utility-class framework.
- **Dev-server proxy**: `exchange-api` has no CORS middleware (out of scope for every task so far); rather than add any, `vite.config.ts`'s `server.proxy` maps `/api` to `exchange-api`'s port, so the browser only ever calls its own origin and `ExchangeApiClient` can be constructed with the plain relative base URL `/api/v1`.

### 19.3 No dedicated categories endpoint

Only `GET /search` accepts a `categoryId` filter — no `GET /categories` was ever built (no task specified one). `src/lib/derive-categories.ts` derives the categories shown on Marketplace Home and `/categories` from a `GET /search` sample, grouping/counting by `categoryId`/`categoryName` rather than inventing a mock category list (WP-EXC-009.md §7 "no mock data") — a category with zero matching packages simply doesn't appear, which is correct for a discovery surface regardless.

### 19.4 Downloads and My Library without authentication

Authentication is excluded from this task's scope (as it has been for every task so far), so there is no server-side "current user" to own a downloads/library history against. `LibraryContext` tracks "packages this browser downloaded/installed" instead: `PackageDetailPage`'s Download button (a plain `<a href={client.downloads.url(...)}>` — the browser handles the actual file download natively) and Install button (`client.installations.install()`, TASK-EXC-0008) each record an entry locally, and `DownloadsPage`/`MyLibraryPage` render that history. Every field stored is a real id or a value a real API response already returned — this is a browser-local _view_ over real data, not fabricated data.

### 19.5 Design

- **`packages/exchange-client/src/*`** — `HttpClient` (the one place a `fetch` call is made; maps a non-2xx `ApiErrorResponse` to a thrown `ExchangeApiError`), `PublishersResource`/`PackagesResource`/`SearchResource`/`InstallationsResource`/`DownloadsResource` (thin per-resource wrappers), and `ExchangeApiClient` (bundles all five, constructed once via `ExchangeApiClientContext`).
- **`apps/publisher-portal/src/api/ExchangeApiClientContext.tsx`** — the only place an `ExchangeApiClient` is constructed; `useExchangeApiClient()` is how every page reaches it.
- **`apps/publisher-portal/src/hooks/use-async.ts`** — the shared loading/success/error hook (§19.2).
- **`apps/publisher-portal/src/state/LibraryContext.tsx`** — the Downloads/My Library store (§19.4).
- **`apps/publisher-portal/src/components/*`** — `AppShell`, `Header`, `Sidebar`, `Footer` (the shell + responsive nav, §5/§6) and ten reusable components (`SearchBar`, `PackageCard`, `PublisherCard`, `CategoryCard`, `PackageList`, `Breadcrumbs`, `LoadingIndicator`, `EmptyState`, `ErrorView`, `Pagination`) — see `docs/guides/COMPONENT_GUIDE.md` for the full catalog.
- **`apps/publisher-portal/src/pages/*`** — the seven views (`MarketplaceHomePage`, `SearchResultsPage`, `CategoriesPage`, `PublishersPage`, `PublisherProfilePage`, `PackageDetailPage`, `DownloadsPage`, `MyLibraryPage`, `NotFoundPage` — `CategoriesPage`/`PublishersPage` are extra pages this task's navigation (§5 "Categories", "Publishers") needs beyond WP-EXC-009.md §4's headline list). `PackageDetailPage` also implements "Installation Progress" (§2) inline: idle -> installing -> completed/failed, backed by `client.installations.install()`'s synchronous result.
- **`apps/publisher-portal/src/App.tsx`** — wires `ExchangeApiClientProvider` + `LibraryProvider` + the full `react-router-dom` route tree under `AppShell`.

### 19.6 A real bug found only by running the app in a browser

`HttpClient`'s (and `HttpRepositoryClient`'s, TASK-EXC-0008) default `fetchFn` was `options.fetchFn ?? fetch` — a bare reference to the global `fetch`. Every unit/integration test passed, because every test injects its own `fetchFn`. Actually running `apps/publisher-portal` against a live `exchange-api` in a browser surfaced `TypeError: Failed to execute 'fetch' on 'Window': Illegal invocation` — calling an extracted, unbound `fetch` reference as `this.fetchFn(...)` loses the `this` binding browsers require. Fixed by binding it at construction time: `fetch.bind(globalThis)`. This is why WP-EXC-009.md §9's manual smoke test matters beyond the automated suite — no unit test using an injected fake would ever have caught this class of bug.

### 19.7 Validation performed for TASK-EXC-0009

- `npm run build` — clean across the full composite graph, including `packages/exchange-client`'s first real implementation and `apps/publisher-portal`'s full page/component/routing bundle (72 modules, up from the 30-module placeholder).
- `npm test` — 30 new tests in `packages/exchange-client`/`packages/installer` (the `HttpClient`/resource classes, and the `fetch`-binding fix) pass unconditionally. 72 new tests in `apps/publisher-portal` (component tests, page-level integration tests against a fake `ExchangeApiClient`, `App.test.tsx`'s navigation/API-integration tests against a stubbed global `fetch`) pass unconditionally — none require a live database or a live `exchange-api`.
- **Manual verification**: started `exchange-api` and `apps/publisher-portal`'s real dev servers and drove the app in a real browser (no live PostgreSQL in this environment, so every API call reaches `exchange-api` and fails at the database layer — the same limitation every prior task in this session has had). This is what surfaced §19.6's bug; after the fix, confirmed the shell, responsive sidebar nav, breadcrumbs, and `ErrorView` all render correctly end to end, and that client-side navigation (Home -> Publishers) works via the real router.
- `npm run lint` / `npm run format:check` — zero issues across every file this task created or modified.
- `npm audit` — unchanged from the pre-existing baseline aside from `react-router-dom` itself, which introduced none.
