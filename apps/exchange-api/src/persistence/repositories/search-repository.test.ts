import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresCategoryRepository } from './category-repository.js';
import { PostgresPackageRepository } from './package-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import { PostgresSearchRepository } from './search-repository.js';
import type { Publisher, PackageCategory } from '../types.js';
import type { SearchQuery } from '../types.js';

/**
 * `search_index`/`packages` integration tests (WP-EXC-006.md §3/§9) — the
 * trigger's search-document maintenance is already covered by
 * `../schema.test.ts`; these tests exercise `SearchRepository.search()`
 * itself: keyword matching, filtering, sorting, and pagination.
 */
const databaseAvailable = await isTestDatabaseAvailable();

function baseQuery(overrides: Partial<SearchQuery> = {}): SearchQuery {
  return { sortBy: 'name', sortDirection: 'asc', page: 1, pageSize: 20, ...overrides };
}

describe.skipIf(!databaseAvailable)('PostgresSearchRepository (integration)', () => {
  let pool: Pool;
  let search: PostgresSearchRepository;
  let packages: PostgresPackageRepository;
  let publisherA: Publisher;
  let publisherB: Publisher;
  let category: PackageCategory;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    search = new PostgresSearchRepository(pool);
    packages = new PostgresPackageRepository(pool);
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    const publishers = new PostgresPublisherRepository(pool);
    publisherA = await publishers.create({
      name: 'Alpha Engineering',
      displayName: 'Alpha',
      namespace: `com.alpha.${randomUUID()}`,
      publisherType: 'company',
    });
    publisherB = await publishers.create({
      name: 'Beta Engineering',
      displayName: 'Beta',
      namespace: `com.beta.${randomUUID()}`,
      publisherType: 'company',
    });
    category = (await new PostgresCategoryRepository(pool).list()).find(
      (c) => c.slug === 'automotive',
    )!;
  });

  afterAll(async () => {
    await pool.end();
  });

  test('keyword search matches title, description, and packageId via search_index', async () => {
    await packages.create({
      packageId: `com.alpha.turbocharger.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Turbocharger Manual',
      description: 'Diagrams for turbocharger assemblies.',
    });
    await packages.create({
      packageId: `com.alpha.brakes.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Brake System',
      description: 'Hydraulic brake schematics.',
    });

    const results = await search.search(baseQuery({ keyword: 'turbocharger' }));
    expect(results.items).toHaveLength(1);
    expect(results.items[0]!.displayName).toBe('Turbocharger Manual');
    expect(results.totalCount).toBe(1);
  });

  test('filters by publisherId', async () => {
    await packages.create({
      packageId: `com.alpha.one.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Alpha One',
    });
    await packages.create({
      packageId: `com.beta.one.${randomUUID()}`,
      publisherId: publisherB.id,
      title: 'Beta One',
    });

    const results = await search.search(baseQuery({ publisherId: publisherA.id }));
    expect(results.items).toHaveLength(1);
    expect(results.items[0]!.publisherId).toBe(publisherA.id);
  });

  test('filters by categoryId', async () => {
    await packages.create({
      packageId: `com.alpha.categorized.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Categorized',
      categoryId: category.id,
    });
    await packages.create({
      packageId: `com.alpha.uncategorized.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Uncategorized',
    });

    const results = await search.search(baseQuery({ categoryId: category.id }));
    expect(results.items).toHaveLength(1);
    expect(results.items[0]!.displayName).toBe('Categorized');
  });

  test('filters by status', async () => {
    await packages.create({
      packageId: `com.alpha.draft.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Draft Package',
      status: 'draft',
    });
    await packages.create({
      packageId: `com.alpha.published.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Published Package',
      status: 'published',
    });

    const results = await search.search(baseQuery({ status: 'published' }));
    expect(results.items).toHaveLength(1);
    expect(results.items[0]!.displayName).toBe('Published Package');
  });

  test('sorts by name ascending and descending', async () => {
    await packages.create({
      packageId: `com.alpha.zebra.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Zebra',
    });
    await packages.create({
      packageId: `com.alpha.apple.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Apple',
    });

    const ascending = await search.search(baseQuery({ sortBy: 'name', sortDirection: 'asc' }));
    expect(ascending.items.map((i) => i.displayName)).toEqual(['Apple', 'Zebra']);

    const descending = await search.search(baseQuery({ sortBy: 'name', sortDirection: 'desc' }));
    expect(descending.items.map((i) => i.displayName)).toEqual(['Zebra', 'Apple']);
  });

  test('paginates results and reports totalCount across pages', async () => {
    for (let i = 0; i < 5; i += 1) {
      await packages.create({
        packageId: `com.alpha.page-${i}.${randomUUID()}`,
        publisherId: publisherA.id,
        title: `Package ${i}`,
      });
    }

    const page1 = await search.search(
      baseQuery({ sortBy: 'name', sortDirection: 'asc', page: 1, pageSize: 2 }),
    );
    expect(page1.items).toHaveLength(2);
    expect(page1.totalCount).toBe(5);

    const page3 = await search.search(
      baseQuery({ sortBy: 'name', sortDirection: 'asc', page: 3, pageSize: 2 }),
    );
    expect(page3.items).toHaveLength(1);
    expect(page3.totalCount).toBe(5);
  });

  test('excludes soft-deleted packages', async () => {
    const created = await packages.create({
      packageId: `com.alpha.deleteme.${randomUUID()}`,
      publisherId: publisherA.id,
      title: 'Delete Me',
    });
    await packages.softDelete(created.id);

    const results = await search.search(baseQuery());
    expect(results.items).toHaveLength(0);
  });

  test('returns an empty result set when nothing matches', async () => {
    const results = await search.search(baseQuery({ keyword: 'nonexistent-keyword-xyz' }));
    expect(results.items).toHaveLength(0);
    expect(results.totalCount).toBe(0);
  });
});
