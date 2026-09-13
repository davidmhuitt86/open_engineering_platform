# @oep-exchange/api-contracts

Shared REST contracts, DTOs, schemas, and API types for Exchange clients and the server — used by `exchange-api`, `exchange-client`, `publisher-portal`, and `exchange-admin`. Types and constants only — no route handlers, no persistence, no business logic.

**Status:** Scaffolded (TASK-EXC-0001). Currently holds only the API version constant and the shared error envelope; the Publisher/Package/Search/Download DTOs arrive alongside their owning tasks (TASK-EXC-0003 through TASK-EXC-0007) so the contract types are added together with the code that actually needs them, rather than speculatively upfront.

## Exports

- `EXCHANGE_API_VERSION` — the current API version segment (`v1`); every route is mounted under `/api/${EXCHANGE_API_VERSION}`.
- `ApiErrorResponse`, `toApiErrorResponse()` — the stable JSON error envelope every failed request returns, built from an `@oep-exchange/core` `DomainError`.
- `HealthCheckResponse` — the `GET /health` response shape.

## Dependency direction

Depends on `@oep-exchange/core` only. Depended on by `exchange-api` (the Fastify app), `exchange-client`, and (transitively, via `exchange-client`) the UI apps.
