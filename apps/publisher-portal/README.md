# @oep-exchange/publisher-portal

The publisher- and engineer-facing Exchange web UI: Home, Search, Package Details, Publisher Profile, Upload, My Packages (WP-EXC-001 §6's "Exchange UI" deliverable, minus the Administration pages — see `@oep-exchange/exchange-admin`).

**Status:** Scaffolded (TASK-EXC-0001). A Vite + React + TypeScript app proving the toolchain (build, dev server, Vitest + React Testing Library) is wired correctly. Real pages arrive in TASK-EXC-0009, once `@oep-exchange/exchange-client` has a real API to call.

## Running

```sh
npm run dev -w @oep-exchange/publisher-portal      # Vite dev server, http://localhost:5173
npm run build -w @oep-exchange/publisher-portal     # type-check + production build
npm test -w @oep-exchange/publisher-portal
```

## Dependency direction

Depends on `@oep-exchange/exchange-client` (the typed HTTP client) and `@oep-exchange/api-contracts` (shared REST contracts) — never calls `exchange-api` directly or imports any other package's internals.

## Toolchain note

This app's `tsconfig.json` deliberately does **not** extend the repo's `tsconfig.base.json` — that base config targets Node (`module`/`moduleResolution: NodeNext`) for the library packages and server, whereas a Vite-bundled browser app needs `moduleResolution: "Bundler"` and a DOM lib/JSX setting. Documented here rather than silently diverging; see `docs/architecture/REPOSITORY_STRUCTURE.md`.
