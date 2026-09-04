# @oep-exchange/exchange-admin

The Exchange Administration web UI — reviewing/approving submitted packages and managing publishers (WP-EXC-001 §6's "Administration" page).

**Status:** Scaffolded (TASK-EXC-0001). A Vite + React + TypeScript app proving the toolchain (build, dev server, Vitest + React Testing Library) is wired correctly. The real Administration page arrives in TASK-EXC-0009, once `@oep-exchange/exchange-client` has a real API to call.

## Running

```sh
npm run dev -w @oep-exchange/exchange-admin      # Vite dev server, http://localhost:5174
npm run build -w @oep-exchange/exchange-admin     # type-check + production build
npm test -w @oep-exchange/exchange-admin
```

## Dependency direction

Depends on `@oep-exchange/exchange-client` and `@oep-exchange/api-contracts` — same pattern as `@oep-exchange/publisher-portal`, kept as a separate app rather than a route within the Publisher Portal so Administration can be deployed/access-controlled independently later.

## Naming note

Renamed from `apps/admin_console` during TASK-EXC-0001's architectural review, to `exchange-admin` — consistent with the `exchange-api`/`exchange-client` naming family.
