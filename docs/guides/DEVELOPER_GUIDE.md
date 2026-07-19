# Developer Guide

Orientation for engineers working on `oep_exchange`. For the architectural reasoning behind the repository's structure and technology choices, see `docs/architecture/adr/ADR-0001-Repository-Structure.md`; for the current, as-built layout, see `docs/architecture/REPOSITORY_STRUCTURE.md`; for the mandatory contribution rules, see `CONTRIBUTING_ARCHITECTURE.md`.

## Getting started

```sh
npm install
npm run build   # tsc -b across every package/app, then both web apps' vite build
npm test        # vitest run, aggregated across the whole workspace
npm run lint
npm run format:check
```

A real PostgreSQL database is only needed to exercise the repository/service/REST integration tests that touch it — everything else (unit tests, `tsc`, `eslint`, `prettier`) runs with no database at all. See `db/README.md` for setting one up and for exactly which environment variables point the test suite at it.

## Where things live

- `apps/exchange-api` — the Fastify REST API. `src/app.ts` builds the app (`buildApp()`); `src/server.ts` starts it listening. Routes are thin (`src/routes/*.ts`); business logic and validation live in `src/services/*.ts`; all PostgreSQL access lives in `src/persistence/*` (the only place in this repository allowed to hold a database connection — see `docs/architecture/DEPENDENCY_GRAPH.md` §3).
- `apps/publisher-portal` / `apps/exchange-admin` — the two React + Vite web apps. Neither holds any server-side state; both talk to `exchange-api` exclusively through `packages/exchange-client`.
- `packages/core` — shared, Exchange-agnostic primitives (`Result`, the `DomainError` family, `newId()`, `Clock`). Everything else may depend on it; it depends on nothing.
- `packages/api-contracts` — the versioned REST wire contract (request/response DTOs). Both `exchange-api` and every client compile against these types, so a contract change is one edit here, not several kept in sync by hand.
- Every other `packages/*` directory: see `OWNERSHIP.md` for what each one owns (and which are still scaffold-only, pending a later task).

## Adding a REST endpoint

Following the Publisher Registry (TASK-EXC-0003) and Package Catalog (TASK-EXC-0004) as reference examples — both follow this exact sequence, and the Package Catalog additionally shows how to validate a request field that references another entity (`publisherId`/`categoryId`) by looking it up in the service rather than letting a foreign-key violation surface as a raw database error:

1. Add the request/response DTOs to `packages/api-contracts/src/<domain>.ts` and export them from its `index.ts`.
2. If new persistence is needed, add a repository interface + `Postgres*Repository` implementation under `apps/exchange-api/src/persistence/repositories/`, following the pattern in any existing one there (a `Queryable`-typed constructor argument, never a bare `pg.Pool`, so it stays testable against fakes).
3. Add a validation module (`apps/exchange-api/src/services/<domain>-validation.ts`) for pure, DB-free checks (required fields, format, state-transition rules) and a service (`apps/exchange-api/src/services/<domain>-service.ts`) that calls the repository, applies validation, and is the only place business logic lives (`CONTRIBUTING_ARCHITECTURE.md` rule 8).
4. Add thin routes (`apps/exchange-api/src/routes/<domain>.ts`) with a Fastify JSON Schema per route (this both validates requests and feeds the auto-generated OpenAPI document at `/documentation` — see ADR-0001 "Why Fastify"). Register them in `app.ts`.
5. Any thrown `DomainError` subclass (`NotFoundError`, `ValidationError`, `ConflictError`, `ForbiddenError`) is mapped to the shared `ApiErrorResponse` envelope automatically by `error-handler.ts` — routes never need to build their own error JSON.

## Testing conventions

Four layers, following the pattern the Publisher Registry established:

- **Pure unit tests** (validation modules) — no database, no Fastify, run unconditionally.
- **Service tests** — the service under test against in-memory fake repositories (implementing the same interface a `Postgres*Repository` does), so business logic is exercised without a live database. See `apps/exchange-api/src/services/publisher-service.test.ts` for the pattern.
- **Repository tests** and **REST API tests** — exercise real SQL / the real HTTP surface against an actual PostgreSQL database via `apps/exchange-api/src/persistence/test-support.ts`, and **skip (never fail)** when no database is reachable. See `db/README.md` "Testing without a live database" for the exact environment variables and setup SQL.
- **Migration/schema tests** (`apps/exchange-api/src/persistence/schema.test.ts`) — assert the applied schema's shape and constraint/rollback behavior, distinct from any single repository's own CRUD tests.

## Database changes

Every schema change is a new Flyway migration under `db/migrations/`, named `V{n}__{snake_case_description}.sql` — never edit a committed migration. See `db/README.md` for the full convention (UUID primary keys, `row_version` optimistic concurrency, soft delete, partial unique indexes) and for how to run migrations against a real database.
