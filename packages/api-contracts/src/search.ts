/**
 * Package Search wire contracts (TASK-EXC-0006, docs/tasks/WP-EXC-006.md
 * §4/§5/§7/§8). `SearchResultItemDto` mirrors
 * `apps/exchange-api/src/persistence/types.ts`'s `SearchResultItem` with
 * `Date` fields serialized to ISO strings, the same convention
 * `PackageDto`/`PublisherDto` already use.
 */
export type SearchSortBy = 'name' | 'createdAt' | 'updatedAt';
export type SearchSortDirection = 'asc' | 'desc';

export interface SearchResultItemDto {
  id: string;
  packageId: string;
  publisherId: string;
  publisherName: string;
  displayName: string;
  description: string;
  categoryId: string | null;
  categoryName: string | null;
  currentVersion: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
}

/** Pagination metadata WP-EXC-006.md §8 requires on every search response. */
export interface SearchResponse {
  items: SearchResultItemDto[];
  totalCount: number;
  totalPages: number;
  currentPage: number;
  pageSize: number;
}
