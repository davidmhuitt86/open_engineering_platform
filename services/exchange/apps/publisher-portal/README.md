# @oep-exchange/publisher-portal

The Engineering Exchange Web Application: Marketplace Home, Search Results, Package Detail, Publisher Profile, Downloads, My Library, and a 404 page, plus the application shell and responsive navigation (TASK-EXC-0009, `docs/tasks/WP-EXC-009.md`). Publisher self-service (package upload, publisher account management) and Administration are out of this task's scope — see `docs/tasks/WP-EXC-009.md` §2 and `@oep-exchange/exchange-admin`.

**Status:** Real implementation (TASK-EXC-0009). See `docs/guides/FRONTEND_GUIDE.md` and `docs/guides/COMPONENT_GUIDE.md`.

## Running

```sh
npm run dev -w @oep-exchange/publisher-portal      # Vite dev server, http://localhost:5173
npm run build -w @oep-exchange/publisher-portal     # type-check + production build
npm test -w @oep-exchange/publisher-portal
```

The dev server proxies `/api` to `exchange-api` on `http://localhost:3000` by default (override with `OEP_EXCHANGE_API_PROXY_TARGET`) — `exchange-api` has no CORS headers, so every request needs to be same-origin in the browser.

## Dependency direction

Depends on `@oep-exchange/exchange-client` (the typed HTTP client — the only path to `exchange-api`) and `@oep-exchange/api-contracts` (shared REST contracts) and `react-router-dom` — never calls `exchange-api` directly or imports any other package's internals.

## Toolchain note

This app's `tsconfig.json` deliberately does **not** extend the repo's `tsconfig.base.json` — that base config targets Node (`module`/`moduleResolution: NodeNext`) for the library packages and server, whereas a Vite-bundled browser app needs `moduleResolution: "Bundler"` and a DOM lib/JSX setting. Documented here rather than silently diverging; see `docs/architecture/REPOSITORY_STRUCTURE.md`.
