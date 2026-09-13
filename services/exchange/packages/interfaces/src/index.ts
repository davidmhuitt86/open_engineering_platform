/**
 * `@oep-exchange/interfaces` — the designated future integration point
 * between `oep_exchange` and the rest of the OEP platform
 * (`oep_foundation`, `oep_repository`, `oep_engine`, and any future
 * governance/identity services).
 *
 * This package is NOT for implementations. It exists only to define
 * future contracts, once those cross-repository interactions are
 * actually specified and needed. Nothing in this package may depend on
 * any other workspace package, and this package must never contain a
 * working implementation of a service — only, eventually, type-only
 * contract declarations (interfaces, DTOs) describing a boundary this
 * repository consumes but does not own.
 *
 * See `docs/architecture/DEPENDENCY_GRAPH.md` for how this fits into
 * the platform's overall dependency direction, and this package's own
 * README for the roster of services anticipated (not yet defined) here.
 *
 * `RepositoryClient` (TASK-EXC-0008) is the first of these to actually
 * be defined — see `repository-client.ts`.
 */
export const PACKAGE_NAME = '@oep-exchange/interfaces' as const;

export type {
  RepositoryInstallRequest,
  RepositoryInstallResult,
  RepositoryClient,
} from './repository-client.js';
