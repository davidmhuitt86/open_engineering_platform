import type { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test, vi } from 'vitest';
import { ExchangeApiClientContext } from '../api/ExchangeApiClientContext.js';
import { SearchResultsPage } from './SearchResultsPage.js';

function emptyResult(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    items: [],
    totalCount: 0,
    totalPages: 0,
    currentPage: 1,
    pageSize: 20,
    ...overrides,
  };
}

function renderPage(run: ReturnType<typeof vi.fn>, initialEntry = '/search') {
  const client: Partial<ExchangeApiClient> = {
    search: { run } as unknown as ExchangeApiClient['search'],
  };
  return render(
    <MemoryRouter initialEntries={[initialEntry]}>
      <ExchangeApiClientContext.Provider value={client as ExchangeApiClient}>
        <SearchResultsPage />
      </ExchangeApiClientContext.Provider>
    </MemoryRouter>,
  );
}

describe('SearchResultsPage', () => {
  test('runs an unfiltered search on first render and shows the result count', async () => {
    const run = vi.fn().mockResolvedValue(emptyResult({ totalCount: 0 }));
    renderPage(run);

    await waitFor(() => expect(run).toHaveBeenCalledOnce());
    expect(run).toHaveBeenCalledWith(
      expect.objectContaining({
        sortBy: 'createdAt',
        sortDirection: 'desc',
        page: 1,
        pageSize: 20,
      }),
    );
  });

  test('reads q/status/sortBy from the URL on load', async () => {
    const run = vi.fn().mockResolvedValue(emptyResult());
    renderPage(run, '/search?q=turbocharger&status=published&sortBy=name&sortDirection=asc&page=2');

    await waitFor(() => expect(run).toHaveBeenCalledOnce());
    expect(run).toHaveBeenCalledWith(
      expect.objectContaining({
        q: 'turbocharger',
        status: 'published',
        sortBy: 'name',
        sortDirection: 'asc',
        page: 2,
      }),
    );
  });

  test('submitting the search bar re-runs the search with the new keyword', async () => {
    const run = vi.fn().mockResolvedValue(emptyResult());
    renderPage(run);
    await waitFor(() => expect(run).toHaveBeenCalledOnce());

    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'turbocharger' } });
    fireEvent.click(screen.getByRole('button', { name: 'Search' }));

    await waitFor(() => expect(run).toHaveBeenCalledTimes(2));
    expect(run).toHaveBeenLastCalledWith(expect.objectContaining({ q: 'turbocharger', page: 1 }));
  });

  test('renders results and lets pagination request the next page', async () => {
    const run = vi.fn().mockResolvedValue(
      emptyResult({
        items: [
          {
            id: 'pkg-1',
            packageId: 'com.divad.honda',
            publisherId: 'pub-1',
            publisherName: 'Divad Engineering',
            displayName: 'Honda GL1200',
            description: '',
            categoryId: null,
            categoryName: null,
            currentVersion: '1.0.0',
            status: 'published',
            createdAt: '2026-01-01T00:00:00.000Z',
            updatedAt: '2026-01-01T00:00:00.000Z',
          },
        ],
        totalCount: 25,
        totalPages: 2,
        currentPage: 1,
      }),
    );
    renderPage(run);

    await waitFor(() => expect(screen.getByRole('link', { name: 'Honda GL1200' })).toBeDefined());
    expect(screen.getByText('25 result(s)')).toBeDefined();

    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    await waitFor(() => expect(run).toHaveBeenCalledTimes(2));
    expect(run).toHaveBeenLastCalledWith(expect.objectContaining({ page: 2 }));
  });

  test('shows an error view when the search fails', async () => {
    const run = vi.fn().mockRejectedValue(new Error('Search unavailable.'));
    renderPage(run);

    await waitFor(() => expect(screen.getByRole('alert')).toBeDefined());
    expect(screen.getByRole('alert').textContent).toContain('Search unavailable.');
  });
});
