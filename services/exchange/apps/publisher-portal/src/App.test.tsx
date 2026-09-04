import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import { App } from './App.js';

function jsonResponse(body: unknown, status = 200): Response {
  return { ok: status < 400, status, json: async () => body } as Response;
}

/**
 * A minimal router over `fetch` so the whole `<App/>` tree (shell + real
 * pages + the real `ExchangeApiClient`) can be exercised end to end
 * without a live `exchange-api` server — the API integration/navigation
 * tests this task requires (WP-EXC-009.md §9).
 */
function installFakeFetch(): ReturnType<typeof vi.fn> {
  const fetchFn = vi.fn(async (input: string | URL) => {
    const url = String(input);
    if (url.startsWith('/api/v1/search')) {
      return jsonResponse({
        items: [],
        totalCount: 0,
        totalPages: 0,
        currentPage: 1,
        pageSize: 12,
      });
    }
    if (url === '/api/v1/publishers') {
      return jsonResponse({ publishers: [] });
    }
    return jsonResponse({ error: { code: 'NOT_FOUND', message: 'Not found.' } }, 404);
  });
  vi.stubGlobal('fetch', fetchFn);
  return fetchFn;
}

describe('App', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/');
    window.localStorage.clear();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    window.localStorage.clear();
  });

  test('renders the application shell and the Marketplace Home page at /', async () => {
    installFakeFetch();
    render(<App />);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'OEP Engineering Exchange' })).toBeDefined(),
    );
    expect(screen.getByRole('link', { name: 'Home' })).toBeDefined();
    expect(screen.getByRole('link', { name: 'Search' })).toBeDefined();
    expect(screen.getByRole('link', { name: 'My Library' })).toBeDefined();
    expect(screen.getByRole('link', { name: 'Downloads' })).toBeDefined();
  });

  test('navigating to Search calls the real search endpoint through the API client', async () => {
    const fetchFn = installFakeFetch();
    render(<App />);
    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'OEP Engineering Exchange' })).toBeDefined(),
    );

    fireEvent.click(screen.getByRole('link', { name: 'Search' }));

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'Search packages' })).toBeDefined(),
    );
    expect(fetchFn.mock.calls.some(([url]) => String(url).startsWith('/api/v1/search'))).toBe(true);
  });

  test('navigating to Publishers renders the Publishers page', async () => {
    installFakeFetch();
    render(<App />);
    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'OEP Engineering Exchange' })).toBeDefined(),
    );

    fireEvent.click(screen.getByRole('link', { name: 'Publishers' }));

    await waitFor(() => expect(screen.getByRole('heading', { name: 'Publishers' })).toBeDefined());
    expect(screen.getByRole('heading', { name: 'No publishers yet' })).toBeDefined();
  });

  test('navigating to My Library and Downloads renders their empty states', async () => {
    installFakeFetch();
    render(<App />);
    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'OEP Engineering Exchange' })).toBeDefined(),
    );

    fireEvent.click(screen.getByRole('link', { name: 'My Library' }));
    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'Your library is empty' })).toBeDefined(),
    );

    fireEvent.click(screen.getByRole('link', { name: 'Downloads' }));
    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'No downloads yet' })).toBeDefined(),
    );
  });

  test('an unknown route renders the 404 page', async () => {
    installFakeFetch();
    window.history.pushState({}, '', '/this-page-does-not-exist');
    render(<App />);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'Page not found' })).toBeDefined(),
    );
  });
});
