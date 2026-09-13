import type { PaginationInfo } from './types.js';

/** Computes pagination metadata (WP-EXC-006.md §8) from a result count and the requested page/pageSize. */
export function computePagination(
  totalCount: number,
  page: number,
  pageSize: number,
): PaginationInfo {
  return {
    totalCount,
    totalPages: totalCount === 0 ? 0 : Math.ceil(totalCount / pageSize),
    currentPage: page,
    pageSize,
  };
}
