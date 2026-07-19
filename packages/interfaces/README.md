# @oep-exchange/interfaces

Future cross-repository integration contracts. **This package is not for implementations** — it exists only to define future contracts, and only once those cross-repository interactions are actually specified and needed.

**Status:** Scaffolded. Deliberately empty beyond this documentation and a package-identity smoke test — no interface has been defined yet, because none of the cross-repository interactions below have been specified yet. Adding a contract here ahead of the specification that defines it would be inventing behavior, which this repository's governing instructions explicitly prohibit.

## Anticipated future contracts (examples, not yet defined)

When `oep_exchange` needs to call into another OEP repository, the contract for that call belongs here first (as a type-only interface this repository consumes), before any concrete implementation exists on either side. Examples of the kind of contract expected to land here eventually:

- **`RepositoryService`** — installing a downloaded package into an OEP Repository (the `installer` package's eventual dependency; see `docs/architecture/DEPENDENCY_GRAPH.md`'s "Future Foundation Interfaces" layer).
- **`IdentityService`** — publisher/administrator authentication, once `oep_exchange` needs to verify identity against a platform-wide identity provider rather than its own Publisher Registry alone.
- **`AuditService`** — platform-wide audit logging, if audit records for Exchange transactions are ever required to flow into a shared audit trail rather than staying local to this repository's own database.
- **`GovernanceService`** — engineering governance/review-board integration (see `docs/specifications/governance/`), if package publication is ever required to pass through a cross-repository governance workflow.
- **`PackageTransactionService`** — the Package Transaction Engine (PKG-003) this repository's `installer` package invokes through public interfaces only (WP-EXC-001 §6 "Repository Integration").

None of these are implemented, specified in detail, or depended upon by any other package in this repository today. Each one, when actually needed, gets its own interface declaration in `src/`, added alongside the work package that first needs to call it — not speculatively ahead of time.

## Dependency direction

Depends on **nothing** in this workspace, and nothing in this workspace outside `installer` (once it needs a real contract) is expected to depend on this package either — it is the seam between repositories, not a shared utility library.
