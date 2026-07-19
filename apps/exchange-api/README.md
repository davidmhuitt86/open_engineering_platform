# @oep-exchange/exchange-api

The Exchange REST API server (Fastify) — Publishers, Packages, Search, Downloads, Administration.

**Status:** Scaffolded (TASK-EXC-0001). Real routes (Publisher Registry, Package Catalog, Upload, Search, Download, Administration) arrive in TASK-EXC-0003 through TASK-EXC-0008. Today the app has:

- `GET /api/v1/health` — a real liveness check (no database dependency).
- `GET /documentation` (Swagger UI) / `GET /documentation/json` (raw OpenAPI document) — generated from route schemas via `@fastify/swagger`, satisfying EXC-001 §4's "every capability... shall also be available through a documented API" from day one, even while there's only one route to document.
- A shared error handler (`src/error-handler.ts`) mapping any thrown `DomainError` (from `@oep-exchange/core`) to the stable `ApiErrorResponse` envelope (from `@oep-exchange/api-contracts`) with the right HTTP status — every future route can `throw new NotFoundError(...)` etc. without re-plumbing error responses.

## Running

```sh
npm run dev -w @oep-exchange/exchange-api    # tsx watch mode
npm run build -w @oep-exchange/exchange-api
npm start -w @oep-exchange/exchange-api      # runs the built dist/server.js
```

`PORT` (default `3000`) and `HOST` (default `0.0.0.0`) are read from the environment.

## Testing

`src/app.ts` exports `buildApp()` separately from `src/server.ts`'s `start()` specifically so tests exercise routes via Fastify's `.inject()` (in-process, no real socket) rather than needing a live port — see `src/app.test.ts`.

## Dependency direction

Depends on `@oep-exchange/core` and `@oep-exchange/api-contracts`. Will additionally depend on `manifest`, `signing`, `search`, and `package-manager` once their owning tasks land.

## Naming note

Renamed from `apps/exchange_server` during TASK-EXC-0001's architectural review — the executable API service now owns the "exchange-api" identity, since it's the thing engineers and publishers actually mean by "the Exchange API." The shared contract-types library it depends on was renamed to `@oep-exchange/api-contracts` to free up the name and to describe what that library actually is: REST contracts, not an application.
