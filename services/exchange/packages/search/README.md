# @oep-exchange/search

Validates, normalizes, and computes pagination for Package Catalog search queries.

**Status:** Real implementation (TASK-EXC-0006, Package Search).

## What this package owns

- `normalizeSearchQuery(raw: RawSearchQuery): NormalizedSearchQuery` — validates and defaults a raw REST search query (WP-EXC-006.md §5/§6/§7/§8): identifier format, `status`/`sortBy`/`sortDirection` enum membership (throwing `@oep-exchange/core`'s `ValidationError` when malformed), and `page`/`pageSize` clamping (never rejected — an out-of-range page is just an empty result, not a client error).
- `computePagination(totalCount, page, pageSize): PaginationInfo` — the `totalPages`/`currentPage` math WP-EXC-006.md §8 requires in every search response.

## What this package deliberately does not do

- **Query the search index itself.** This package cannot hold a PostgreSQL connection (`DEPENDENCY_GRAPH.md` §3) — `apps/exchange-api`'s `SearchRepository`/`SearchService` own the actual `search_index` query, the same "pure package, DB-owning application" split TASK-EXC-0005 established for `packages/manifest`/`packages/package-manager` (see `docs/architecture/REPOSITORY_STRUCTURE.md` §16.1).
- **Maintain the search index.** `search_index` is kept current by a PostgreSQL trigger on `packages` (`db/migrations/V5__search_index.sql`), not application code.

## Dependency direction

Depends on `@oep-exchange/core` and `@oep-exchange/api-contracts`. No dependency on PostgreSQL, Fastify, or any application.
