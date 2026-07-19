import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { buildApp } from '../app.js';
import {
  isTestDatabaseAvailable,
  setupTestDatabase,
  truncateAllTables,
} from '../persistence/test-support.js';

/**
 * REST API tests (docs/tasks/WP-EXC-003.md §8) exercising the full
 * `/api/v1/publishers` lifecycle end to end via Fastify's `.inject()`
 * against a real database — skip (never fail) if none is reachable, per
 * `db/README.md` "Testing without a live database".
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('/api/v1/publishers (REST API)', () => {
  let pool: Pool;
  let app: FastifyInstance;

  const validBody = {
    namespace: 'com.test.divad',
    publisherType: 'individual',
    displayName: 'Divad',
    legalName: 'Divad Engineering LLC',
    contactEmail: 'contact@example.com',
  };

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    app = await buildApp({ db: pool });
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  test('the full create -> get -> list -> update -> delete lifecycle', async () => {
    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/publishers',
      payload: {
        ...validBody,
        description: 'Honda GL1200 knowledge.',
        website: 'https://divad.example.com',
      },
    });
    expect(created.statusCode).toBe(201);
    const publisher = created.json();
    expect(publisher.namespace).toBe('com.test.divad');
    expect(publisher.legalName).toBe('Divad Engineering LLC');
    expect(publisher.description).toBe('Honda GL1200 knowledge.');
    expect(publisher.status).toBe('active');

    const fetched = await app.inject({ method: 'GET', url: `/api/v1/publishers/${publisher.id}` });
    expect(fetched.statusCode).toBe(200);
    expect(fetched.json()).toEqual(publisher);

    const listed = await app.inject({ method: 'GET', url: '/api/v1/publishers' });
    expect(listed.statusCode).toBe(200);
    expect(listed.json().publishers).toHaveLength(1);

    const updated = await app.inject({
      method: 'PUT',
      url: `/api/v1/publishers/${publisher.id}`,
      payload: { displayName: 'Divad Updated', status: 'suspended' },
    });
    expect(updated.statusCode).toBe(200);
    expect(updated.json().displayName).toBe('Divad Updated');
    expect(updated.json().status).toBe('suspended');

    const deleted = await app.inject({
      method: 'DELETE',
      url: `/api/v1/publishers/${publisher.id}`,
    });
    expect(deleted.statusCode).toBe(204);

    const afterDelete = await app.inject({
      method: 'GET',
      url: `/api/v1/publishers/${publisher.id}`,
    });
    expect(afterDelete.statusCode).toBe(404);
  });

  test('POST with a missing required field returns 400 with the shared error envelope', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/publishers',
      payload: { ...validBody, contactEmail: undefined },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });

  test('POST with an unrecognized publisherType returns 400 (Fastify schema validation)', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/publishers',
      payload: { ...validBody, publisherType: 'not_a_real_type' },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });

  test('POST with a duplicate namespace returns 409', async () => {
    await app.inject({ method: 'POST', url: '/api/v1/publishers', payload: validBody });
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/publishers',
      payload: { ...validBody, legalName: 'Someone Else LLC', contactEmail: 'other@example.com' },
    });
    expect(response.statusCode).toBe(409);
    expect(response.json().error.code).toBe('CONFLICT');
  });

  test('GET an unknown id returns 404', async () => {
    const response = await app.inject({ method: 'GET', url: `/api/v1/publishers/${randomUUID()}` });
    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe('NOT_FOUND');
  });

  test('GET a malformed id returns 400', async () => {
    const response = await app.inject({ method: 'GET', url: '/api/v1/publishers/not-a-uuid' });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });

  test('PUT with an invalid status returns 400', async () => {
    const created = await app.inject({
      method: 'POST',
      url: '/api/v1/publishers',
      payload: validBody,
    });
    const publisher = created.json();

    const response = await app.inject({
      method: 'PUT',
      url: `/api/v1/publishers/${publisher.id}`,
      payload: { status: 'archived' },
    });
    expect(response.statusCode).toBe(400);
  });

  test('DELETE an unknown id returns 404', async () => {
    const response = await app.inject({
      method: 'DELETE',
      url: `/api/v1/publishers/${randomUUID()}`,
    });
    expect(response.statusCode).toBe(404);
  });

  test('the new publisher routes appear in the generated OpenAPI document', async () => {
    const response = await app.inject({ method: 'GET', url: '/documentation/json' });
    expect(response.statusCode).toBe(200);
    const spec = response.json();
    expect(spec.paths['/api/v1/publishers']).toBeDefined();
    expect(spec.paths['/api/v1/publishers/{id}']).toBeDefined();
  });
});
