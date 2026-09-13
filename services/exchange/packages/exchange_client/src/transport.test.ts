import { describe, expect, it, vi } from 'vitest';
import { ExchangeApiError } from './errors.js';
import { HttpTransport } from './transport.js';

function fakeFetch(handler: (url: string, init?: RequestInit) => Response | Promise<Response>) {
  return vi.fn(async (input: string | URL | Request, init?: RequestInit) =>
    handler(String(input), init),
  );
}

function jsonResponse(body: unknown, status = 200): Response {
  return { ok: status >= 200 && status < 300, status, json: async () => body } as Response;
}

describe('HttpTransport', () => {
  describe('buildUrl', () => {
    it('joins baseUrl and path without a double slash', () => {
      const transport = new HttpTransport('/api/v1/', vi.fn());
      expect(transport.buildUrl('/packages/pkg-1/download')).toBe(
        '/api/v1/packages/pkg-1/download',
      );
    });

    it('omits undefined query params entirely, never sending "undefined"', () => {
      const transport = new HttpTransport('/api/v1', vi.fn());
      const url = transport.buildUrl('/search', { q: undefined, pageSize: 12, status: 'published' });
      expect(url).toBe('/api/v1/search?pageSize=12&status=published');
    });

    it('appends no "?" at all when every query param is undefined', () => {
      const transport = new HttpTransport('/api/v1', vi.fn());
      expect(transport.buildUrl('/search', { q: undefined })).toBe('/api/v1/search');
    });
  });

  describe('request', () => {
    it('performs a GET and returns the parsed JSON body', async () => {
      const fetchFn = fakeFetch(() => jsonResponse({ hello: 'world' }));
      const transport = new HttpTransport('/api/v1', fetchFn);

      const result = await transport.request('GET', '/publishers');

      expect(result).toEqual({ hello: 'world' });
      expect(fetchFn).toHaveBeenCalledWith('/api/v1/publishers', { method: 'GET' });
    });

    it('sends a JSON-encoded body on POST with a Content-Type header', async () => {
      const fetchFn = fakeFetch(() => jsonResponse({ id: 'install-1' }, 201));
      const transport = new HttpTransport('/api/v1', fetchFn);

      await transport.request('POST', '/packages/pkg-1/install', { body: { version: '1.0.0' } });

      expect(fetchFn).toHaveBeenCalledWith('/api/v1/packages/pkg-1/install', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ version: '1.0.0' }),
      });
    });

    it('returns undefined for a 204 No Content response without calling .json()', async () => {
      const json = vi.fn();
      const fetchFn = fakeFetch(() => ({ ok: true, status: 204, json }) as unknown as Response);
      const transport = new HttpTransport('/api/v1', fetchFn);

      const result = await transport.request('DELETE', '/packages/pkg-1');

      expect(result).toBeUndefined();
      expect(json).not.toHaveBeenCalled();
    });

    it('throws ExchangeApiError built from the ApiErrorResponse envelope on a non-2xx response', async () => {
      const fetchFn = fakeFetch(() =>
        jsonResponse({ error: { code: 'NOT_FOUND', message: 'Package "pkg-1" was not found.' } }, 404),
      );
      const transport = new HttpTransport('/api/v1', fetchFn);

      await expect(transport.request('GET', '/packages/pkg-1')).rejects.toMatchObject({
        status: 404,
        code: 'NOT_FOUND',
        message: 'Package "pkg-1" was not found.',
      });
      await expect(transport.request('GET', '/packages/pkg-1')).rejects.toBeInstanceOf(
        ExchangeApiError,
      );
    });

    it('falls back to a generic ExchangeApiError when the error body is not valid JSON', async () => {
      const fetchFn = fakeFetch(
        () =>
          ({
            ok: false,
            status: 502,
            json: async () => {
              throw new SyntaxError('Unexpected token < in JSON');
            },
          }) as unknown as Response,
      );
      const transport = new HttpTransport('/api/v1', fetchFn);

      await expect(transport.request('GET', '/search')).rejects.toMatchObject({
        status: 502,
        code: 'UNKNOWN_ERROR',
      });
    });

    it('falls back to a generic ExchangeApiError when the error body does not match the envelope', async () => {
      const fetchFn = fakeFetch(() => jsonResponse({ unexpected: 'shape' }, 500));
      const transport = new HttpTransport('/api/v1', fetchFn);

      await expect(transport.request('GET', '/search')).rejects.toMatchObject({
        status: 500,
        code: 'UNKNOWN_ERROR',
      });
    });

    it('propagates a transport/network failure as a plain error, not an ExchangeApiError', async () => {
      const fetchFn = vi.fn(async () => {
        throw new TypeError('Failed to fetch');
      });
      const transport = new HttpTransport('/api/v1', fetchFn);

      await expect(transport.request('GET', '/search')).rejects.toBeInstanceOf(TypeError);
      await expect(transport.request('GET', '/search')).rejects.not.toBeInstanceOf(ExchangeApiError);
    });
  });
});
