# Dependency Graph

The intended dependency graph for `oep_exchange`, at two levels: within this repository (packages/apps), and between this repository and the rest of the OEP platform. See `docs/architecture/REPOSITORY_STRUCTURE.md` §2 for the current, as-built package-level graph with every concrete package named; this document states the _rule_ the current graph already follows and the platform's future integration points.

## 1. The layered model

```
                    Applications
        (exchange-api, publisher-portal, exchange-admin)
                          |
                          v
                  Exchange Packages
   (api-contracts, exchange-client, manifest, signing,
    search, package-manager, dependency-resolver,
    installer, update-service, licensing, payments, reviews)
                          |
                          v
                     Core Package
                       (core)
                          |
                          v
              Future Foundation Interfaces
                    (interfaces)
                          |
                          v
         oep_foundation / oep_repository / oep_engine
              (separate repositories — never imported
               directly; see §4)
```

This mirrors the platform-wide layering already established for `oep_studio` and `oep_acquisition`: a shared primitives layer at the bottom, domain/service packages built on it, applications built on those, and a narrow, explicit seam (never a direct code dependency) to anything outside the repository.

## 2. Allowed dependency directions

- **Applications may depend on Exchange Packages, the Core Package, and (once real contracts exist) `interfaces`.** An application (`exchange-api`, `publisher-portal`, `exchange-admin`) may never be depended upon by a package — dependencies point strictly downward.
- **Exchange Packages may depend on the Core Package and on each other**, as long as the resulting graph is acyclic (see §3). Today's real inter-package edges: `package-manager` → `manifest` + `signing`; `exchange-client` → `api-contracts`; `installer`/`update-service` → `exchange-client`; `dependency-resolver` → `manifest`; `reviews`/`search` → `api-contracts`. See `docs/architecture/REPOSITORY_STRUCTURE.md` §2 for the full current graph.
- **Every package may depend on the Core Package (`core`).** Nothing may depend on a package that itself depends on the thing doing the depending (see §3).
- **The Core Package depends on nothing else in this workspace.** It is the floor of the graph.
- **`interfaces` depends on nothing**, and (until a package genuinely needs a defined contract from it) nothing depends on it either. It is not part of the "normal" build-order dependency chain — it is a deliberately inert placeholder for a future edge.
- **Only `installer` is expected to ever depend on `interfaces`** once a real `RepositoryService`-shaped contract is defined there — no other package has a legitimate reason to reach toward a cross-repository contract.

## 3. Forbidden dependency directions

- **No package may depend on an application.** `manifest`, `signing`, `core`, etc. must remain usable (and testable) with no knowledge that `exchange-api`/`publisher-portal`/`exchange-admin` exist.
- **No circular dependencies, anywhere in the graph.** TypeScript project references make a cycle a build failure, not just a lint warning — see `ADR-0001-Repository-Structure.md`'s "Why TypeScript Project References." If implementing a feature seems to require package A to depend on package B and package B to depend on package A, that is a signal the responsibility boundary between A and B is drawn in the wrong place, not a signal to introduce a cycle — extract the shared concern into a package both A and B can depend on downward (usually `core`), or reconsider which package should own the responsibility at all.
- **No package may import another package's `src/` directory or any path not exposed through its declared `exports`.** Only the compiled public surface (`dist/*.d.ts`, per `package.json`) is a legitimate import target — see `CONTRIBUTING_ARCHITECTURE.md`.
- **No package or application may open a direct connection to PostgreSQL except `exchange-api`.** Database access is `exchange-api`'s exclusive responsibility (see `OWNERSHIP.md`); a package needing data reads/writes gets them through a function `exchange-api` (or, if the boundary genuinely calls for it, a dedicated persistence-owning package) exposes, never by importing a database client of its own.
- **No direct import of another OEP repository's source.** `oep_foundation`, `oep_repository`, and `oep_engine` are never `import`ed, `require`d, or referenced via a relative/workspace path from anything in this repository — see §4.

## 4. Circular dependency policy

Zero tolerance, enforced structurally rather than by review alone: TypeScript's project-reference build graph (`tsc -b`) cannot produce a working build if two packages reference each other, so a cycle is caught at `npm run build` time, not discovered later at runtime or in production. If a cycle is ever proposed as the "quickest" way to share code between two packages, the correct fix is always one of:

1. Move the shared concern into `core` (if it's genuinely a domain primitive, not Exchange-specific), or
2. Move the shared concern into a new package both existing packages can depend on downward, or
3. Recognize that one of the two packages actually owns the responsibility the other was trying to borrow, and have the dependency point only one way.

Never: add the back-reference and suppress the resulting build error.

## 5. Future integration points with the rest of the platform

`oep_exchange` is developed independently and today has **zero code dependency** on `oep_foundation`, `oep_repository`, or `oep_engine` — consistent with WP-EXC-001 §2's explicit exclusion list (Repository Engine, Foundation Runtime, Knowledge Engine, Governance Engine, Package Runtime, Identity Provider all belong to those repositories, not this one). When a genuine integration need arises, the platform's own established pattern (`oep_studio` → `oep_acquisition`, documented in the platform snapshot's `DEPENDENCY_GRAPH.md`) is: **a network call (REST/HTTP) against a published API, never a source-level import** — the same rule this repository's own governing instructions state for cross-repository interaction ("Use published interfaces... Do NOT duplicate functionality... Do NOT copy code").

Anticipated future integration points, none implemented today (see `packages/interfaces`'s own README for the full list and why each is not yet defined):

- **`oep_foundation` / `oep_repository`** — via a future `RepositoryService` contract, invoked by `installer` to perform the Package Transaction Engine → Repository Merge Engine → Repository Validation sequence (WP-EXC-001 §6 "Repository Integration") through Foundation's public interfaces only.
- **`oep_engine`** — no anticipated integration point identified at this time; `oep_exchange` distributes packages, it does not execute or render engineering diagrams, so no current work package gives cause for this repository to call into the Engine.
- **A future platform Identity Provider** — via a future `IdentityService` contract, if publisher/administrator authentication is ever required to verify against a platform-wide identity service rather than this repository's own Publisher Registry credentials alone.

Each of these, when actually specified and needed, gets a real contract added to `packages/interfaces` first — describing what this repository consumes — before any implementation is written on either side.
