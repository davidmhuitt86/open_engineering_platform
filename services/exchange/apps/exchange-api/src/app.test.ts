import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildApp } from './app.js';

describe('exchange_server app', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await buildApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/health reports ok with the current API version', async () => {
    const response = await app.inject({ method: 'GET', url: '/api/v1/health' });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ok', version: 'v1' });
  });

  it('GET /documentation/json serves a generated OpenAPI document', async () => {
    const response = await app.inject({ method: 'GET', url: '/documentation/json' });
    expect(response.statusCode).toBe(200);
    const spec = response.json();
    expect(spec.info.title).toBe('OEP Engineering Exchange API');
    expect(spec.paths['/api/v1/health']).toBeDefined();
  });

  it('an unknown route returns a 404', async () => {
    const response = await app.inject({ method: 'GET', url: '/api/v1/does-not-exist' });
    expect(response.statusCode).toBe(404);
  });
});
