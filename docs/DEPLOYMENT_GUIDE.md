# Engineering Exchange RC1 — Deployment Guide

Deploying `exchange-api`, `apps/publisher-portal`, and (separately) OEP Studio with its Exchange workspace. Nothing here is new infrastructure for RC1 — this consolidates existing, already-established deployment facts from `docs/guides/DEVELOPER_GUIDE.md`, `db/README.md`, and `docs/guides/FRONTEND_GUIDE.md` into one place, plus the one new piece: how a Studio installation is pointed at a deployed `exchange-api`.

## 1. Database

A real PostgreSQL instance is required for production. Create the role/database and apply migrations with Flyway (`db/README.md` "Running migrations"):

```sql
CREATE ROLE oep_exchange LOGIN PASSWORD '<production-password>';
CREATE DATABASE oep_exchange OWNER oep_exchange;
```

```sh
cd db
flyway -configFiles=migrations/flyway.toml -password=<production-password> migrate
```

Apply migrations in order (`V1` through `V6` as of RC1); never edit a committed migration.

## 2. `exchange-api`

```sh
npm install
npm run build          # tsc -b across every package/app
node apps/exchange-api/dist/server.js
```

Environment variables (`apps/exchange-api/src/server.ts`, `src/storage/storage-config.ts`, `src/persistence/*`):

| Variable | Purpose | Default |
| --- | --- | --- |
| `PORT` | HTTP listen port | `3000` |
| `HOST` | HTTP listen host | `0.0.0.0` |
| `OEP_EXCHANGE_STORAGE_DIR` | Package artifact storage root | `./storage/packages` |
| Database connection vars (see `src/persistence/config.ts`) | PostgreSQL connection | — |

`GET /api/v1/health` (`registerHealthRoute`) is the readiness/liveness check every client (web app, Studio) also uses for "Test Connection."

No CORS headers are configured (`docs/guides/FRONTEND_GUIDE.md`) — a production deployment fronts `exchange-api` and `publisher-portal` behind one reverse proxy on the same origin, exactly as the dev server's own `/api/*` proxy already does locally.

## 3. `apps/publisher-portal` (web application)

```sh
npm run build -w @oep-exchange/publisher-portal   # tsc --noEmit && vite build
```

Serve the resulting `dist/` as static files behind the same reverse proxy as `exchange-api` (see above) — `ExchangeApiClient` is always constructed with the relative base URL `/api/v1`, never an absolute one.

## 4. OEP Studio's Exchange workspace (new in RC1)

OEP Studio is a separate desktop application binary (`oep_studio`); this release adds no new build or packaging step to it beyond the existing Flutter build. It reaches `exchange-api` directly (not through the reverse proxy `publisher-portal` uses), so it needs an absolute address:

- Set via Settings > Engineering Exchange > Service Address, or by editing `%APPDATA%/oep_studio/exchange_settings.json`'s `apiBaseUrl` directly.
- Default: `http://127.0.0.1:3000/api/v1` — correct only when Studio and `exchange-api` run on the same machine (the common desktop/single-engineer deployment shape this program has used throughout, matching Engineering Acquisition's own equivalent setting). Point it at the deployed `exchange-api`'s real host/port for any other topology.
- No restart is required after changing the address — it takes effect on the next request (`ExchangeRuntimeNotifier` rebuilds its client whenever the setting changes).
- Because `exchange-api` has no CORS headers, this only works when Studio talks to it directly (a native HTTP client, not a browser) — which is exactly what `ExchangeApiClient` (`package:http`) does; there is no CORS concern for a non-browser client.

## 5. Verifying a deployment

1. `curl <exchange-api-base>/health` returns `200`.
2. Open `publisher-portal` in a browser; Marketplace Home loads real packages.
3. Open OEP Studio, navigate to Engineering Exchange; the connection banner shows no error and Marketplace Home loads the same packages as (2).
4. Install a package from Studio; Installation Progress reports `completed` (or `failed`, if the configured `RepositoryClient` is still the default `StubRepositoryClient` reporting a deliberate rejection scenario — see `docs/guides/INSTALLATION_GUIDE.md`).
