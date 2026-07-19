# @oep-exchange/installer

Invokes the Package Transaction Engine and Repository Merge Engine, through public Repository interfaces only, to install a downloaded package into an OEP Repository.

**Status:** Real implementation (TASK-EXC-0008, Repository Integration).

## What this package owns

- `RepositoryClient`, `RepositoryInstallRequest`, `RepositoryInstallResult` — re-exported from `@oep-exchange/interfaces` for convenience; this is the contract, defined there since this package is its only implementer/consumer.
- `HttpRepositoryClient` — the real implementation: POSTs the artifact (base64-encoded) to `{baseUrl}/api/v1/packages/install`, the Repository Public API shape `docs/architecture/DEPENDENCY_GRAPH.md` §5 anticipates. Network failures and non-2xx responses are caught and reported as `{ accepted: false, message }` rather than thrown.
- `StubRepositoryClient` — a deterministic, in-memory stand-in (configurable to simulate acceptance or rejection). No `oep_repository` codebase exists in the platform yet (WP-EXC-008.md §2 explicitly excludes "Repository implementation"), so `apps/exchange-api` wires this by default until a real Repository is reachable — swapping in `HttpRepositoryClient` requires no change to `InstallationService`, since both satisfy the same `RepositoryClient` contract.

## What this package deliberately does not do

- **Hold a database connection.** `apps/exchange-api`'s `InstallationService` owns Package/version/artifact resolution and the `installations` record; this package only ever sees the bytes and metadata it's handed.
- **Depend on any `oep_foundation`/`oep_repository` source.** `HttpRepositoryClient` reaches the Repository exclusively over HTTP against a configurable base URL — never a source-level import (`docs/architecture/DEPENDENCY_GRAPH.md` §3).

## Dependency direction

Depends on `@oep-exchange/core`, `@oep-exchange/exchange-client`, `@oep-exchange/interfaces`. The only package in this workspace that depends on `interfaces`.
