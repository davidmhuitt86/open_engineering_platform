import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { buildApp } from '../app.js';
import { PostgresPackageRepository } from '../persistence/repositories/package-repository.js';
import { PostgresPublisherRepository } from '../persistence/repositories/publisher-repository.js';
import {
  isTestDatabaseAvailable,
  setupTestDatabase,
  truncateAllTables,
} from '../persistence/test-support.js';
import type { Publisher } from '../persistence/types.js';

/**
 * REST API tests (docs/tasks/WP-EXC-006.md §4) exercising
 * `GET /api/v1/search` end to end via Fastify's `.inject()` against a
 * real database — skip (never fail) if none is reachable, per
 * `db/README.md` "Testing without a live database".
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('/api/v1/search (REST API)', () => {
  let pool: Pool;
  let app: FastifyInstance;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    app = await buildApp({ db: pool });
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    publisher = await new PostgresPublisherRepository(pool).create({
      name: 'Divad Engineering LLC',
      displayName: 'Divad',
      namespace: `com.test.${randomUUID()}`,
      publisherType: 'individual',
    });
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  test('finds a package by keyword and reports pagination metadata', async () => {
    const packages = new PostgresPackageRepository(pool);
    await packages.create({
      packageId: `com.divad.turbocharger.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Turbocharger Manual',
      description: 'Diagrams for turbocharger assemblies.',
    });

    const response = await app.inject({ method: 'GET', url: '/api/v1/search?q=turbocharger' });
    expect(response.statusCode).toBe(200);
    const body = response.json();
    expect(body.items).toHaveLength(1);
    expect(body.items[0].displayName).toBe('Turbocharger Manual');
    expect(body.items[0].publisherName).toBe('Divad Engineering LLC');
    expect(body.totalCount).toBe(1);
    expect(body.totalPages).toBe(1);
    expect(body.currentPage).toBe(1);
    expect(body.pageSize).toBe(20);
  });

  test('an empty search returns every non-deleted package, paginated', async () => {
    const packages = new PostgresPackageRepository(pool);
    await packages.create({
      packageId: `com.divad.a.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'A',
    });
    await packages.create({
      packageId: `com.divad.b.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'B',
    });

    const response = await app.inject({ method: 'GET', url: '/api/v1/search' });
    expect(response.statusCode).toBe(200);
    expect(response.json().items).toHaveLength(2);
    expect(response.json().totalCount).toBe(2);
  });

  test('filters by publisherId', async () => {
    const packages = new PostgresPackageRepository(pool);
    const otherPublisher = await new PostgresPublisherRepository(pool).create({
      name: 'Other Publisher',
      displayName: 'Other',
      namespace: `com.other.${randomUUID()}`,
      publisherType: 'company',
    });
    await packages.create({
      packageId: `com.divad.mine.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Mine',
    });
    await packages.create({
      packageId: `com.other.theirs.${randomUUID()}`,
      publisherId: otherPublisher.id,
      title: 'Theirs',
    });

    const response = await app.inject({
      method: 'GET',
      url: `/api/v1/search?publisherId=${publisher.id}`,
    });
    expect(response.statusCode).toBe(200);
    const body = response.json();
    expect(body.items).toHaveLength(1);
    expect(body.items[0].displayName).toBe('Mine');
  });

  test('sorts by name descending', async () => {
    const packages = new PostgresPackageRepository(pool);
    await packages.create({
      packageId: `com.divad.apple.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Apple',
    });
    await packages.create({
      packageId: `com.divad.zebra.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Zebra',
    });

    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/search?sortBy=name&sortDirection=desc',
    });
    const body = response.json();
    expect(body.items.map((i: { displayName: string }) => i.displayName)).toEqual([
      'Zebra',
      'Apple',
    ]);
  });

  test('paginates via page/pageSize', async () => {
    const packages = new PostgresPackageRepository(pool);
    for (let i = 0; i < 3; i += 1) {
      await packages.create({
        packageId: `com.divad.page-${i}.${randomUUID()}`,
        publisherId: publisher.id,
        title: `Package ${i}`,
      });
    }

    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/search?sortBy=name&pageSize=2&page=2',
    });
    const body = response.json();
    expect(body.items).toHaveLength(1);
    expect(body.currentPage).toBe(2);
    expect(body.pageSize).toBe(2);
    expect(body.totalPages).toBe(2);
  });

  test('a malformed publisherId returns 400', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/search?publisherId=not-a-uuid',
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });

  test('an unrecognized status returns 400', async () => {
    const response = await app.inject({ method: 'GET', url: '/api/v1/search?status=archived' });
    expect(response.statusCode).toBe(400);
  });

  test('the search route appears in the generated OpenAPI document', async () => {
    const response = await app.inject({ method: 'GET', url: '/documentation/json' });
    expect(response.statusCode).toBe(200);
    expect(response.json().paths['/api/v1/search']).toBeDefined();
  });
});
