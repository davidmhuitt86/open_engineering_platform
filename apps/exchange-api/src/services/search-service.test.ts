import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';
import type {
  SearchQuery,
  SearchRepository,
  SearchResultItem,
  SearchResults,
} from '../persistence/index.js';
import { SearchService } from './search-service.js';

/** In-memory fake (no database), mirroring `package-service.test.ts`'s own precedent. */
class FakeSearchRepository implements SearchRepository {
  constructor(private readonly items: SearchResultItem[]) {}

  lastQuery: SearchQuery | undefined;

  async search(query: SearchQuery): Promise<SearchResults> {
    this.lastQuery = query;
    return { items: this.items, totalCount: this.items.length };
  }
}

function fakeItem(overrides: Partial<SearchResultItem> = {}): SearchResultItem {
  const now = new Date();
  return {
    id: randomUUID(),
    packageId: 'com.divad.honda.gl1200',
    publisherId: randomUUID(),
    publisherName: 'Divad',
    displayName: 'Honda GL1200 Electrical',
    description: 'Wiring diagrams.',
    categoryId: null,
    categoryName: null,
    currentVersion: '1.0.0',
    status: 'published',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

describe('SearchService', () => {
  test('normalizes the raw query, delegates to the repository, and shapes a SearchResponse', async () => {
    const repository = new FakeSearchRepository([fakeItem()]);
    const service = new SearchService(repository);

    const response = await service.search({ q: 'honda', page: '2', pageSize: '10' });

    expect(repository.lastQuery).toEqual({
      keyword: 'honda',
      sortBy: 'createdAt',
      sortDirection: 'desc',
      page: 2,
      pageSize: 10,
    });
    expect(response.items).toHaveLength(1);
    expect(response.items[0]!.displayName).toBe('Honda GL1200 Electrical');
    expect(response.totalCount).toBe(1);
    expect(response.totalPages).toBe(1);
    expect(response.currentPage).toBe(2);
    expect(response.pageSize).toBe(10);
  });

  test('serializes Date fields to ISO strings on the DTO', async () => {
    const item = fakeItem();
    const repository = new FakeSearchRepository([item]);
    const service = new SearchService(repository);

    const response = await service.search({});
    expect(response.items[0]!.createdAt).toBe(item.createdAt.toISOString());
    expect(response.items[0]!.updatedAt).toBe(item.updatedAt.toISOString());
  });

  test('propagates a ValidationError for a malformed publisherId without querying the repository', async () => {
    const repository = new FakeSearchRepository([]);
    const service = new SearchService(repository);

    await expect(service.search({ publisherId: 'not-a-uuid' })).rejects.toThrow(
      /not a valid Publisher identifier/,
    );
    expect(repository.lastQuery).toBeUndefined();
  });

  test('defaults page/pageSize/sortBy/sortDirection when omitted', async () => {
    const repository = new FakeSearchRepository([]);
    const service = new SearchService(repository);

    const response = await service.search({});
    expect(response.currentPage).toBe(1);
    expect(response.pageSize).toBe(20);
    expect(response.totalPages).toBe(0);
  });
});
