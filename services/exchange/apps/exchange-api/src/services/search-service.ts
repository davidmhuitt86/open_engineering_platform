import type { RawSearchQuery } from '@oep-exchange/search';
import { computePagination, normalizeSearchQuery } from '@oep-exchange/search';
import type { SearchResponse, SearchResultItemDto } from '@oep-exchange/api-contracts';
import type { SearchRepository, SearchResultItem } from '../persistence/index.js';

/**
 * The Package Search service (WP-EXC-006.md §3: "REST API -> Search
 * Service -> Search Repository -> PostgreSQL. Business logic shall
 * remain within the Search Service."). Query validation/normalization
 * and pagination math are delegated to `@oep-exchange/search`'s pure,
 * DB-free functions — this class supplies the one thing that package
 * cannot: the actual `search_index`/`packages` query, via
 * `SearchRepository` (see `packages/search/README.md`).
 */
export class SearchService {
  constructor(private readonly searchRepository: SearchRepository) {}

  async search(raw: RawSearchQuery): Promise<SearchResponse> {
    const query = normalizeSearchQuery(raw);

    const results = await this.searchRepository.search(query);
    const pagination = computePagination(results.totalCount, query.page, query.pageSize);

    return {
      items: results.items.map(toDto),
      totalCount: pagination.totalCount,
      totalPages: pagination.totalPages,
      currentPage: pagination.currentPage,
      pageSize: pagination.pageSize,
    };
  }
}

function toDto(item: SearchResultItem): SearchResultItemDto {
  return {
    id: item.id,
    packageId: item.packageId,
    publisherId: item.publisherId,
    publisherName: item.publisherName,
    displayName: item.displayName,
    description: item.description,
    categoryId: item.categoryId,
    categoryName: item.categoryName,
    currentVersion: item.currentVersion,
    status: item.status,
    createdAt: item.createdAt.toISOString(),
    updatedAt: item.updatedAt.toISOString(),
  };
}
