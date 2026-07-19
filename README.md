# OEP Exchange

The Open Engineering Exchange (OEX) — the official distribution platform for Open Engineering Platform (OEP) Engineering Packages: publisher registration, package publication, discovery, and distribution.

This repository is developed independently and integrates with the rest of the OEP platform (`oep_foundation`, `oep_repository`, `oep_engine`) exclusively through published interfaces — see `docs/architecture/REPOSITORY_STRUCTURE.md`, `docs/architecture/DEPENDENCY_GRAPH.md`, and `CONTRIBUTING_ARCHITECTURE.md`.

## Status

**WP-EXC-001 (OEP Exchange Repository MVP) — TASK-EXC-0001 (Repository Structure) complete, approved with architectural amendments.** The monorepo tooling, every package/app skeleton, and the Exchange REST API's first real endpoint (`/health`) are in place and validated. See `docs/tasks/WP-EXC-001.md` for the full work package, `docs/architecture/REPOSITORY_STRUCTURE.md` for this task's own architecture rationale, and `OWNERSHIP.md` for who/what owns each package and app.

## Repository layout

```
apps/
  exchange-api/          Fastify REST API — Publishers, Packages, Search, Downloads, Administration
  publisher-portal/      Publisher/engineer-facing web UI (React + Vite)
  exchange-admin/        Exchange Administration web UI (React + Vite)
packages/
  core/                  Domain primitives, errors, utilities (no workspace deps)
  api-contracts/         Shared REST contracts/DTOs/schemas for clients and the server
  exchange_client/       Typed HTTP client SDK for the Exchange API
  manifest/              PKG-002 package manifest parsing
  signing/               PKG-005 signature verification
  search/                Package Catalog search indexing/querying
  package_manager/       Upload pipeline orchestration
  dependency_resolver/   PKG-004 dependency graph resolution (deferred)
  installer/             Repository installation via public Repository interfaces
  update_service/        Installed-package update checks (deferred)
  licensing/             License issuance/entitlements (excluded from WP-EXC-001)
  payments/              Commerce (excluded from WP-EXC-001)
  reviews/               Ratings/reviews (excluded from WP-EXC-001)
  interfaces/            Future cross-repository contracts only — no implementation, no dependencies
db/
  migrations/            Flyway SQL migrations (empty — TASK-EXC-0002)
docs/
  architecture/          Architecture decisions made during implementation, ADRs, dependency graph
  specifications/        The governing EXC-/PKG-/GOV- specifications
  tasks/                 Work package definitions
```

## Development

```sh
npm install
npm run build     # tsc -b across every library/server package, then both web apps
npm test          # every package's tests, from one root command
npm run lint
npm run format:check
```

Requires Node 20+ (see `.nvmrc`).

## Architecture governance

- [`OWNERSHIP.md`](./OWNERSHIP.md) — what each app/package owns.
- [`CONTRIBUTING_ARCHITECTURE.md`](./CONTRIBUTING_ARCHITECTURE.md) — mandatory architectural rules for all contributors.
- [`docs/architecture/DEPENDENCY_GRAPH.md`](./docs/architecture/DEPENDENCY_GRAPH.md) — the intended dependency graph, allowed/forbidden directions, and future integration points.
- [`docs/architecture/adr/`](./docs/architecture/adr/) — Architecture Decision Records.

## Governing specifications

See `docs/specifications/` — in particular `EXC-001` (Exchange Architecture), `PKG-001` through `PKG-008` (Package format/manifest/transaction/dependency/trust/registry), and `docs/tasks/WP-EXC-001.md` (this work package's own objective, scope, and success criteria).
