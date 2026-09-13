/**
 * `packages/search`'s own copy of the search query shape — independent
 * of (though structurally similar to) `apps/exchange-api/src/persistence
 * /types.ts`'s `SearchQuery`, since this package cannot import from
 * `exchange-api` (DEPENDENCY_GRAPH.md §3) and the two represent
 * different concerns: this one is "what a client asked for, normalized
 * and validated," the persistence one is "what `SearchRepository` runs
 * against PostgreSQL."
 */

export type PackageStatusFilter = 'draft' | 'published' | 'deprecated' | 'suspended';
export type SearchSortBy = 'name' | 'createdAt' | 'updatedAt';
export type SearchSortDirection = 'asc' | 'desc';

/** The raw shape a REST query string decodes to — every field optional and untyped (as it arrives over HTTP). */
export interface RawSearchQuery {
  q?: string;
  publisherId?: string;
  categoryId?: string;
  status?: string;
  sortBy?: string;
  sortDirection?: string;
  page?: string;
  pageSize?: string;
}

/** A fully validated, defaulted search query (WP-EXC-006.md §5/§6/§7/§8). */
export interface NormalizedSearchQuery {
  keyword?: string;
  publisherId?: string;
  categoryId?: string;
  status?: PackageStatusFilter;
  sortBy: SearchSortBy;
  sortDirection: SearchSortDirection;
  page: number;
  pageSize: number;
}

/** WP-EXC-006.md §8 "Return: totalCount, totalPages, currentPage". */
export interface PaginationInfo {
  totalCount: number;
  totalPages: number;
  currentPage: number;
  pageSize: number;
}
