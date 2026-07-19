# Architecture Contribution Rules

Mandatory architectural rules for all contributors to `oep_exchange`. These are not suggestions — a change that violates one of these rules is not ready to merge, regardless of whether it otherwise works. See `docs/architecture/adr/` for the reasoning behind the foundational choices these rules protect, `docs/architecture/DEPENDENCY_GRAPH.md` for the full dependency-direction reference, and `OWNERSHIP.md` for which package/app owns which responsibility.

## The rules

### 1. No circular dependencies

Enforced structurally by TypeScript project references (`tsc -b` fails to build a cycle), not just by review. If two packages seem to need each other, one of them is drawing its boundary in the wrong place — see `docs/architecture/DEPENDENCY_GRAPH.md` §4 for the correct fix (extract the shared concern downward, usually into `core`; never add the back-reference).

### 2. Import only through public package APIs

Every package's importable surface is exactly what its `package.json` `exports` field and `dist/*.d.ts` declare — nothing else, no matter how convenient. If something you need isn't exported, that's a signal to add it to the package's real public API deliberately, not to reach around it.

### 3. Never import another package's `src` directory

A build-time import must resolve to a package's compiled `dist/` output (its declared `main`/`types`/`exports`), never a relative path into `../other-package/src/...`. This is what makes "public API only" (rule 2) actually true rather than aspirational — a `src`-directory import bypasses every boundary the package's own `exports` field was meant to draw.

### 4. Domain code cannot depend on UI

Nothing in `packages/` may import from `react`, `react-dom`, or either web app (`publisher-portal`, `exchange-admin`). Domain/service logic (`manifest`, `signing`, `search`, `package-manager`, etc.) must be usable — and tested — with no UI framework present at all.

### 5. Domain code cannot depend on Fastify

Nothing in `packages/` other than what `exchange-api` itself owns may import `fastify` or any `@fastify/*` plugin. A package that needs to expose something over HTTP does so by being _called from_ a route `exchange-api` defines — it does not become a web framework consumer itself. This keeps every service package testable and reusable independent of which web framework (or none at all) ends up fronting it.

### 6. UI cannot access persistence directly

Neither web app may hold a PostgreSQL client, connection string, or any direct database dependency. Every data access from the UI goes through `exchange-client` → `exchange-api`'s REST surface — no exceptions for "just this one read."

### 7. Database access belongs only to persistence modules

Within `exchange-api`, PostgreSQL access is confined to the modules that own it (its persistence layer, once built in TASK-EXC-0002) — route handlers call into that layer; they do not issue SQL themselves. No package outside `exchange-api` opens a database connection at all (see `OWNERSHIP.md`).

### 8. Business logic remains outside controllers

Route handlers in `exchange-api` are thin: parse/validate the request, call the owning service package or persistence layer, shape the response. The upload pipeline, manifest parsing, signature verification, search indexing, and every other piece of actual business logic live in their owning `packages/*` package (see `OWNERSHIP.md`), callable — and testable — with no Fastify request/reply object anywhere in the call.

### 9. Repository boundaries are mandatory

`oep_exchange` shall not implement Repository Engine, Foundation Runtime, Knowledge Engine, Governance Engine, Package Runtime, or Identity Provider logic (per WP-EXC-001 §2) — those responsibilities belong to their own repositories. A feature that seems to require this repository to reimplement one of them is a signal to define a contract in `packages/interfaces` and consume the real thing through a published interface, not to build a local substitute.

### 10. Foundation logic shall never be duplicated

If a capability already exists in `oep_foundation`/`oep_repository`/`oep_engine`, this repository consumes it — it does not re-derive, re-validate, or maintain a parallel copy of it. Duplicated logic between repositories is a maintenance liability from the moment it's written: the two copies will eventually disagree, and nothing will tell you which one is right.

### 11. Future integrations occur through published interfaces

Any future dependency on another OEP repository is a REST/HTTP call against that repository's published API (the pattern `oep_studio` → `oep_acquisition` already established platform-wide), or a contract declared in `packages/interfaces` first — never a direct source import of another repository's code, and never a workaround that requires modifying the other repository to accommodate this one.

## Enforcement

- Rules 1–3 are checked by `npm run build` (`tsc -b`'s project-reference graph) and `npm run lint`.
- Rules 4–8 are architectural review items today (no automated check yet) — a reviewer should reject a change that violates them regardless of whether it happens to build and pass tests.
- Rules 9–11 apply to any change that reaches toward another repository; `packages/interfaces` existing with nothing implemented in it is itself evidence rule 9 is being followed, not a gap to be filled in early.
