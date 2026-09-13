# @oep-exchange/interfaces

Cross-repository integration contracts. **This package is not for implementations** — it exists only to define contracts, and only once the cross-repository interaction they describe is actually specified and needed.

**Status:** `RepositoryClient` (TASK-EXC-0008, Repository Installation Integration) is the first real contract defined here — see `src/repository-client.ts`. Everything else below remains anticipated, not yet defined.

## Defined contracts

- **`RepositoryClient`** (`src/repository-client.ts`) — installing a downloaded package into an OEP Repository. `packages/installer` is the only implementer (`HttpRepositoryClient`, `StubRepositoryClient`) and the only consumer of this file; `apps/exchange-api`'s `InstallationService` depends on the `RepositoryClient` type only, never on a concrete implementation directly.

## Anticipated future contracts (examples, not yet defined)

When `oep_exchange` needs to call into another OEP repository, the contract for that call belongs here first (as a type-only interface this repository consumes), before any concrete implementation exists on either side. Examples of the kind of contract expected to land here eventually:

- **`IdentityService`** — publisher/administrator authentication, once `oep_exchange` needs to verify identity against a platform-wide identity provider rather than its own Publisher Registry alone.
- **`AuditService`** — platform-wide audit logging, if audit records for Exchange transactions are ever required to flow into a shared audit trail rather than staying local to this repository's own database.
- **`GovernanceService`** — engineering governance/review-board integration (see `docs/specifications/governance/`), if package publication is ever required to pass through a cross-repository governance workflow.

None of these are implemented, specified in detail, or depended upon by any other package in this repository today. Each one, when actually needed, gets its own interface declaration in `src/`, added alongside the work package that first needs to call it — not speculatively ahead of time.

## Dependency direction

Depends on **nothing** in this workspace. `packages/installer` is the only package expected to ever depend on this one (`docs/architecture/DEPENDENCY_GRAPH.md` §2) — it is the seam between repositories, not a shared utility library.
