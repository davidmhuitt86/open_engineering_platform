import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { buildApp } from '../app.js';
import { PostgresCategoryRepository } from '../persistence/repositories/category-repository.js';
import { PostgresPublisherRepository } from '../persistence/repositories/publisher-repository.js';
import {
  isTestDatabaseAvailable,
  setupTestDatabase,
  truncateAllTables,
} from '../persistence/test-support.js';
import type { PackageCategory, Publisher } from '../persistence/types.js';

/**
 * REST API tests (docs/tasks/WP-EXC-004.md §8) exercising the full
 * `/api/v1/packages` lifecycle end to end via Fastify's `.inject()`
 * against a real database — skip (never fail) if none is reachable, per
 * `db/README.md` "Testing without a live database".
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('/api/v1/packages (REST API)', () => {
  let pool: Pool;
  let app: FastifyInstance;
  let publisher: Publisher;
  let category: PackageCategory;

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
    category = (await new PostgresCategoryRepository(pool).list()).find(
      (c) => c.slug === 'automotive',
    )!;
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  const validBody = () => ({
    packageId: `com.divad.honda.${randomUUID()}`,
    publisherId: publisher.id,
    displayName: 'Honda GL1200 Electrical',
  });

  test('the full create -> get -> list -> update -> delete lifecycle', async () => {
    const body = { ...validBody(), description: 'Honda GL1200 wiring.', categoryId: category.id };
    const created = await app.inject({ method: 'POST', url: '/api/v1/packages', payload: body });
    expect(created.statusCode).toBe(201);
    const pkg = created.json();
    expect(pkg.packageId).toBe(body.packageId);
    expect(pkg.publisherId).toBe(publisher.id);
    expect(pkg.description).toBe('Honda GL1200 wiring.');
    expect(pkg.categoryId).toBe(category.id);
    expect(pkg.status).toBe('draft');
    expect(pkg.currentVersion).toBeNull();

    const fetched = await app.inject({ method: 'GET', url: `/api/v1/packages/${pkg.id}` });
    expect(fetched.statusCode).toBe(200);
    expect(fetched.json()).toEqual(pkg);

    const listed = await app.inject({ method: 'GET', url: '/api/v1/packages' });
    expect(listed.statusCode).toBe(200);
    expect(listed.json().packages).toHaveLength(1);

    const updated = await app.inject({
      method: 'PUT',
      url: `/api/v1/packages/${pkg.id}`,
      payload: { displayName: 'Honda GL1200 Electrical Updated', status: 'published' },
    });
    expect(updated.statusCode).toBe(200);
    expect(updated.json().displayName).toBe('Honda GL1200 Electrical Updated');
    expect(updated.json().status).toBe('published');

    const deleted = await app.inject({ method: 'DELETE', url: `/api/v1/packages/${pkg.id}` });
    expect(deleted.statusCode).toBe(204);

    const afterDelete = await app.inject({ method: 'GET', url: `/api/v1/packages/${pkg.id}` });
    expect(afterDelete.statusCode).toBe(404);
  });

  test('POST with a missing required field returns 400', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages',
      payload: { ...validBody(), displayName: undefined },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });

  test('POST with a nonexistent publisherId returns 400', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages',
      payload: { ...validBody(), publisherId: randomUUID() },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });

  test('POST with a nonexistent categoryId returns 400', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages',
      payload: { ...validBody(), categoryId: randomUUID() },
    });
    expect(response.statusCode).toBe(400);
  });

  test('POST with a duplicate packageId returns 409', async () => {
    const body = validBody();
    await app.inject({ method: 'POST', url: '/api/v1/packages', payload: body });
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages',
      payload: { ...body, displayName: 'Different Display Name' },
    });
    expect(response.statusCode).toBe(409);
    expect(response.json().error.code).toBe('CONFLICT');
  });

  test('POST with a duplicate title for the same publisher returns 409', async () => {
    const body = validBody();
    await app.inject({ method: 'POST', url: '/api/v1/packages', payload: body });
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages',
      payload: { ...body, packageId: `com.divad.other.${randomUUID()}` },
    });
    expect(response.statusCode).toBe(409);
  });

  test('GET an unknown id returns 404', async () => {
    const response = await app.inject({ method: 'GET', url: `/api/v1/packages/${randomUUID()}` });
    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe('NOT_FOUND');
  });

  test('GET a malformed id returns 400', async () => {
    const response = await app.inject({ method: 'GET', url: '/api/v1/packages/not-a-uuid' });
    expect(response.statusCode).toBe(400);
  });

  test('PUT with an invalid status transition returns 400', async () => {
    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/packages',
      payload: validBody(),
    });
    const pkg = created.json();

    await app.inject({
      method: 'PUT',
      url: `/api/v1/packages/${pkg.id}`,
      payload: { status: 'published' },
    });
    await app.inject({
      method: 'PUT',
      url: `/api/v1/packages/${pkg.id}`,
      payload: { status: 'deprecated' },
    });

    const response = await app.inject({
      method: 'PUT',
      url: `/api/v1/packages/${pkg.id}`,
      payload: { status: 'published' },
    });
    expect(response.statusCode).toBe(400);
  });

  test('DELETE an unknown id returns 404', async () => {
    const response = await app.inject({
      method: 'DELETE',
      url: `/api/v1/packages/${randomUUID()}`,
    });
    expect(response.statusCode).toBe(404);
  });

  test('the new package routes appear in the generated OpenAPI document', async () => {
    const response = await app.inject({ method: 'GET', url: '/documentation/json' });
    expect(response.statusCode).toBe(200);
    const spec = response.json();
    expect(spec.paths['/api/v1/packages']).toBeDefined();
    expect(spec.paths['/api/v1/packages/{id}']).toBeDefined();
  });
});
