import { describe, expect, it, vi } from 'vitest';
import { ExchangeApiClient } from './client.js';
import { ExchangeApiError } from './errors.js';

function jsonResponse(body: unknown, status = 200): Response {
  return { ok: status >= 200 && status < 300, status, json: async () => body } as Response;
}

function clientWithFetch(handler: (url: string, init?: RequestInit) => Response | Promise<Response>) {
  const fetchFn = vi.fn(async (input: string | URL, init?: RequestInit) => handler(String(input), init));
  const client = new ExchangeApiClient({ baseUrl: '/api/v1', fetch: fetchFn as unknown as typeof fetch });
  return { client, fetchFn };
}

describe('ExchangeApiClient construction', () => {
  it('exposes one resource per implemented Exchange API area', () => {
    const client = new ExchangeApiClient({ baseUrl: '/api/v1' });
    expect(client.search).toBeDefined();
    expect(client.packages).toBeDefined();
    expect(client.publishers).toBeDefined();
    expect(client.installations).toBeDefined();
    expect(client.downloads).toBeDefined();
  });
});

describe('client.search.run', () => {
  it('calls GET /search with the given params serialized as a query string', async () => {
    const { client, fetchFn } = clientWithFetch(() =>
      jsonResponse({ items: [], totalCount: 0, totalPages: 0, currentPage: 1, pageSize: 12 }),
    );

    const result = await client.search.run({ status: 'published', sortBy: 'updatedAt', pageSize: 12 });

    expect(fetchFn).toHaveBeenCalledWith(
      '/api/v1/search?status=published&sortBy=updatedAt&pageSize=12',
      { method: 'GET' },
    );
    expect(result.totalCount).toBe(0);
  });

  it('defaults to no params when called with none', async () => {
    const { client, fetchFn } = clientWithFetch(() =>
      jsonResponse({ items: [], totalCount: 0, totalPages: 0, currentPage: 1, pageSize: 20 }),
    );

    await client.search.run();

    expect(fetchFn).toHaveBeenCalledWith('/api/v1/search', { method: 'GET' });
  });
});

describe('client.packages.get', () => {
  it('calls GET /packages/{id} and returns the PackageDto', async () => {
    const { client, fetchFn } = clientWithFetch(() => jsonResponse({ id: 'pkg-1', displayName: 'Test' }));

    const pkg = await client.packages.get('pkg-1');

    expect(fetchFn).toHaveBeenCalledWith('/api/v1/packages/pkg-1', { method: 'GET' });
    expect(pkg).toEqual({ id: 'pkg-1', displayName: 'Test' });
  });

  it('throws ExchangeApiError for a 404', async () => {
    const { client } = clientWithFetch(() =>
      jsonResponse({ error: { code: 'NOT_FOUND', message: 'Package "pkg-1" was not found.' } }, 404),
    );

    await expect(client.packages.get('pkg-1')).rejects.toBeInstanceOf(ExchangeApiError);
  });
});

describe('client.publishers', () => {
  it('get() calls GET /publishers/{id} and returns the PublisherDto', async () => {
    const { client, fetchFn } = clientWithFetch(() =>
      jsonResponse({ id: 'pub-1', displayName: 'Divad Engineering' }),
    );

    const publisher = await client.publishers.get('pub-1');

    expect(fetchFn).toHaveBeenCalledWith('/api/v1/publishers/pub-1', { method: 'GET' });
    expect(publisher.displayName).toBe('Divad Engineering');
  });

  it('list() calls GET /publishers and unwraps the envelope to a flat array', async () => {
    const { client, fetchFn } = clientWithFetch(() =>
      jsonResponse({ publishers: [{ id: 'pub-1' }, { id: 'pub-2' }] }),
    );

    const publishers = await client.publishers.list();

    expect(fetchFn).toHaveBeenCalledWith('/api/v1/publishers', { method: 'GET' });
    expect(publishers).toEqual([{ id: 'pub-1' }, { id: 'pub-2' }]);
  });

  it('list() returns an empty array when the API has no publishers yet', async () => {
    const { client } = clientWithFetch(() => jsonResponse({ publishers: [] }));

    expect(await client.publishers.list()).toEqual([]);
  });
});

describe('client.installations', () => {
  it('install() calls POST /packages/{id}/install with no body when version is omitted', async () => {
    const { client, fetchFn } = clientWithFetch(() =>
      jsonResponse({ id: 'install-1', status: 'completed' }, 201),
    );

    const installation = await client.installations.install('pkg-1');

    expect(fetchFn).toHaveBeenCalledWith('/api/v1/packages/pkg-1/install', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    expect(installation.status).toBe('completed');
  });

  it('install() sends the requested version when supplied', async () => {
    const { client, fetchFn } = clientWithFetch(() => jsonResponse({ id: 'install-1' }, 201));

    await client.installations.install('pkg-1', '2.0.0');

    expect(fetchFn).toHaveBeenCalledWith('/api/v1/packages/pkg-1/install', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version: '2.0.0' }),
    });
  });

  it('get() calls GET /installations/{installationId}', async () => {
    const { client, fetchFn } = clientWithFetch(() =>
      jsonResponse({ id: 'install-1', status: 'pending' }),
    );

    const installation = await client.installations.get('install-1');

    expect(fetchFn).toHaveBeenCalledWith('/api/v1/installations/install-1', { method: 'GET' });
    expect(installation.status).toBe('pending');
  });
});

describe('client.downloads.url', () => {
  it('builds the download URL synchronously without calling fetch', () => {
    const { client, fetchFn } = clientWithFetch(() => jsonResponse({}));

    const url = client.downloads.url('pkg-1');

    expect(url).toBe('/api/v1/packages/pkg-1/download');
    expect(fetchFn).not.toHaveBeenCalled();
  });
});
