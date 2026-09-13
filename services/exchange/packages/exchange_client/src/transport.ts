import type { ApiErrorResponse } from '@oep-exchange/api-contracts';
import { ExchangeApiError } from './errors.js';

/** Query parameter values `request()` accepts -- `undefined` entries are omitted, never sent as `"undefined"`. */
export type QueryParams = Record<string, string | number | boolean | undefined>;

function appendQuery(path: string, query?: QueryParams): string {
  if (!query) {
    return path;
  }
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined) {
      params.set(key, String(value));
    }
  }
  const search = params.toString();
  return search ? `${path}?${search}` : path;
}

/**
 * The one place every `ExchangeApiClient` namespace issues an HTTP
 * request -- deliberately small (WP-EXC-012 §5: "do not over-engineer
 * it"). Uses the platform's native `fetch` (never a second HTTP stack):
 * confirmed as the required transport by
 * `apps/publisher-portal/src/App.test.tsx`, which stubs `globalThis.fetch`
 * directly and asserts the real `ExchangeApiClient` calls it.
 */
export class HttpTransport {
  private readonly baseUrl: string;
  private readonly fetchImpl: typeof fetch;

  constructor(baseUrl: string, fetchImpl: typeof fetch = globalThis.fetch) {
    // A trailing slash on baseUrl would otherwise produce "//search" once
    // joined with a leading-slash path below.
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.fetchImpl = fetchImpl;
  }

  /** Builds the same URL `request()` would call, without performing the request -- used by `downloads.url()`, which is a synchronous href, not a fetch. */
  buildUrl(path: string, query?: QueryParams): string {
    return `${this.baseUrl}${appendQuery(path, query)}`;
  }

  async request<T>(
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
    path: string,
    options: { query?: QueryParams; body?: unknown } = {},
  ): Promise<T> {
    const url = this.buildUrl(path, options.query);
    const init: RequestInit = { method };
    if (options.body !== undefined) {
      init.headers = { 'Content-Type': 'application/json' };
      init.body = JSON.stringify(options.body);
    }

    const response = await this.fetchImpl(url, init);

    if (!response.ok) {
      throw await toExchangeApiError(response);
    }

    if (response.status === 204) {
      return undefined as T;
    }

    return (await response.json()) as T;
  }
}

/**
 * Maps a non-2xx response to `ExchangeApiError`. Every route in
 * `apps/exchange-api` already serializes failures as `ApiErrorResponse`
 * (`toApiErrorResponse`, `@oep-exchange/api-contracts`), so that shape is
 * read when present. A response that is not valid JSON, or does not
 * match that envelope (a proxy error page, a stale gateway, etc.), still
 * produces an `ExchangeApiError` -- with a generic message derived only
 * from the HTTP status, never a thrown/uncaught JSON-parse exception --
 * since the caller only needs to know the request failed, not that the
 * error body itself was unreadable.
 */
async function toExchangeApiError(response: Response): Promise<ExchangeApiError> {
  try {
    const body = (await response.json()) as Partial<ApiErrorResponse>;
    if (body?.error?.code && body.error.message) {
      return new ExchangeApiError(response.status, body.error.code, body.error.message);
    }
  } catch {
    // Not valid JSON -- fall through to the generic error below.
  }
  return new ExchangeApiError(
    response.status,
    'UNKNOWN_ERROR',
    `The Exchange API request failed with status ${response.status}.`,
  );
}
