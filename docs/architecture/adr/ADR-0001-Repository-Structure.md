# ADR-0001: Repository Structure

**Status:** Accepted
**Date:** TASK-EXC-0001 (WP-EXC-001, OEP Exchange Repository MVP), amended after architectural review.
**Context:** `oep_exchange` — the Open Engineering Exchange.

## Context

`oep_exchange` had to go from an empty directory scaffold to a real, independently buildable/testable/deployable repository, consuming the rest of the OEP platform only through published interfaces (per this repository's own governing instructions), while implementing — not redesigning — the EXC-/PKG-/GOV- specifications that already existed. This ADR records the architectural reasoning behind the foundational technology and structural choices, as distinct from `docs/architecture/REPOSITORY_STRUCTURE.md`, which records the resulting implementation detail (exact config files, naming, file layout). Read this ADR for _why_; read that document for _how_.

## Decisions

### Why npm workspaces

The alternative was a heavier orchestrator — pnpm's workspace protocol, Yarn workspaces, or a build-graph tool like Turborepo/Nx layered on top of any of them. npm workspaces was chosen because it ships with Node itself: adopting it introduces zero new tooling dependency beyond what "TypeScript" in the technology mandate already implies. The architectural principle at stake is **minimal necessary tooling surface** — a reference implementation repository should be approachable by any Node/TypeScript engineer without first learning a bespoke build system. A task-graph orchestrator becomes justified once the workspace is large enough that uncached, unparallelized `npm run build`/`npm test` are genuinely too slow; that threshold has not been reached, and adopting one pre-emptively would be optimizing for a problem that does not yet exist.

### Why TypeScript Project References

The architectural requirement this serves is **enforced dependency direction** — Change 6's "Import only through public package APIs" and "Never import another package's `src` directory" are not just conventions engineers are asked to follow; TypeScript project references make them structurally true. A package can only see another package's compiled, declared public surface (its `dist/*.d.ts`, driven by its `package.json` `exports` field), never its internals, and the build graph itself fails if a cyclic or undeclared dependency is introduced. This is a compiler-enforced version of the same boundary Change 6 states in prose — belt and suspenders, not redundant, because a rule that can be silently violated at runtime (a bare relative import reaching across a package boundary) is a much weaker guarantee than one the build cannot produce a working artifact without satisfying.

### Why Fastify

Fastify is the technology mandate's own explicit choice, not a decision made independently in this task. The architectural fit is worth stating anyway: Fastify's schema-first route definition (JSON Schema per route) is what lets OpenAPI generation (`@fastify/swagger`) be derived automatically from the routes themselves rather than hand-maintained as a separate artifact — directly serving EXC-001 §4's "every capability provided by the web interface shall also be available through a documented API" and the platform-wide "API-first" principle, without a second source of truth for the API surface to drift out of sync with the implementation.

### Why React + Vite

The technology mandate specifies Fastify for the backend but is silent on the web UI framework — this was a genuine implementation-detail gap this task had to fill (per this repository's standing instruction to propose missing details while remaining consistent with the specifications, rather than leave them undecided). The architectural reasoning: EXC-001 §4 mandates "every capability provided by the web interface shall also be available through a documented API," which means the web UI must be a pure client of the REST API with no privileged server-side access of its own — a client-rendered SPA (React) naturally enforces this, since it has no code path to the database or any Exchange-internal state except through the same REST API a third-party integrator would use. Vite was chosen alongside React specifically because it shares its underlying toolchain (esbuild/Rollup) with Vitest, avoiding a second, independently-configured bundler/test-runner pairing for the two web apps versus the Node packages.

### Why Vitest

Not mandated by the technology list. The architectural reasoning is **one test-running mental model across the whole repository** — native ESM/TypeScript execution with no separate transpile step, usable identically for the Node library packages, the Fastify server, and (via its Vite integration) the two React apps, rather than pairing Node packages with one test runner (e.g. `node:test` or Jest) and the React apps with another. A single, consistent testing story is what makes "the repository must remain independently buildable, testable, deployable" (this repository's own standing rule) something every package can satisfy identically, not something each package re-derives its own answer to.

### Why PostgreSQL

Mandated by the technology list, and architecturally consistent with the rest of the OEP platform: `oep_acquisition` (the platform's other REST-API-fronted, PostgreSQL-backed repository) already establishes PostgreSQL + Flyway as the platform's convention for a service that owns its own relational persistence independently of Foundation's Repository Engine. `oep_exchange`'s data (publishers, package metadata, download records, search index) is Exchange-owned business data, not Engineering Object/Relationship data belonging to Foundation's domain model — it has no architectural reason to live anywhere but a database this repository owns outright, and PostgreSQL is the platform's already-proven choice for exactly that shape of ownership.

### Why Flyway

Serves the same architectural goal EXC-001 §4/WP-EXC-001 §4 state directly: "No manual database changes are required" — every schema change must be a versioned, forward-only, repeatable migration, never a hand-run `ALTER TABLE` against a live database. Flyway is, again, the platform's own already-established convention (`oep_acquisition`) for this — adopting the same tool rather than an alternative (e.g. Prisma Migrate, node-pg-migrate) keeps migration tooling consistent for anyone who works across both PostgreSQL-backed OEP repositories, rather than requiring them to learn a second migration DSL for no architectural benefit.

### Why independent repositories

This repository's own governing instructions are explicit: `oep_exchange` shall not implement Repository Engine, Foundation Runtime, Knowledge Engine, Governance Engine, Package Runtime, or Identity Provider logic, and no dependency on another OEP repository shall require modifying that repository. The architectural principle is **ownership follows responsibility**: the Exchange owns Publisher Registry/Package Catalog/Upload/Publication/Search/Distribution/Administration (WP-EXC-001 §2) because those are genuinely Exchange concerns, and nothing else — it does not own Repository merge semantics, package trust verification, or dependency resolution _of the platform's Engineering Objects_, because those are Foundation's concerns regardless of which product surfaces them. Two independently-owned, independently-deployable repositories with a narrow, published-interface seam between them is what makes it possible to evolve either one (rewrite Exchange's storage layer, or change Foundation's Repository internals) without the other needing to change in lockstep.

### Why repository boundaries are enforced

Stated as a mandatory rule (`CONTRIBUTING_ARCHITECTURE.md`) rather than left as a convention because the cost of a violated boundary compounds silently: one bare import reaching into another repository's internals, or one bypass of the published interface "for now, just this once," becomes very expensive to unwind once other code depends on the shortcut. Enforcing the boundary structurally where possible (TypeScript project references within this repository; REST/HTTP only across repository lines, per `docs/architecture/DEPENDENCY_GRAPH.md`) and stating it as a hard rule where it can't be structurally enforced (the `packages/interfaces` package, which exists specifically to keep the eventual cross-repository contract from becoming an unstated assumption baked into whichever package first needed it) is how this repository keeps that promise verifiable rather than aspirational.

## Consequences

- Every package/app in this repository is independently buildable and testable (`npm run build`/`npm test` scoped with `-w <package>`), and the whole repository builds/tests from one root command.
- Adding a genuinely new cross-repository dependency requires either a REST/HTTP call (the pattern `oep_studio` → `oep_acquisition` already established platform-wide) or a new contract in `packages/interfaces` — never a direct import of another repository's source.
- The cost of these choices is upfront structure (project references, a contracts-only package with nothing in it yet) for problems (boundary violations, undocumented cross-repository coupling) that are cheap to prevent now and expensive to unwind later.
