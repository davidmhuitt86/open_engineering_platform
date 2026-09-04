import type { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test, vi } from 'vitest';
import { ExchangeApiClientContext } from '../api/ExchangeApiClientContext.js';
import { MarketplaceHomePage } from './MarketplaceHomePage.js';

function renderWithClient(client: Partial<ExchangeApiClient>) {
  return render(
    <MemoryRouter>
      <ExchangeApiClientContext.Provider value={client as ExchangeApiClient}>
        <MarketplaceHomePage />
      </ExchangeApiClientContext.Provider>
    </MemoryRouter>,
  );
}

describe('MarketplaceHomePage', () => {
  test('shows a loading indicator, then categories and packages once the search resolves', async () => {
    const client: Partial<ExchangeApiClient> = {
      search: {
        run: vi.fn().mockResolvedValue({
          items: [
            {
              id: 'pkg-1',
              packageId: 'com.divad.honda',
              publisherId: 'pub-1',
              publisherName: 'Divad Engineering',
              displayName: 'Honda GL1200',
              description: 'Wiring diagrams.',
              categoryId: 'cat-1',
              categoryName: 'Automotive',
              currentVersion: '1.0.0',
              status: 'published',
              createdAt: '2026-01-01T00:00:00.000Z',
              updatedAt: '2026-01-01T00:00:00.000Z',
            },
          ],
          totalCount: 1,
          totalPages: 1,
          currentPage: 1,
          pageSize: 12,
        }),
      } as unknown as ExchangeApiClient['search'],
    };

    renderWithClient(client);

    expect(screen.getByRole('status').textContent).toContain('Loading the marketplace');

    await waitFor(() => expect(screen.getByRole('link', { name: 'Honda GL1200' })).toBeDefined());
    expect(screen.getByRole('link', { name: 'Automotive' })).toBeDefined();
  });

  test('shows an error view when the search call fails', async () => {
    const client: Partial<ExchangeApiClient> = {
      search: {
        run: vi.fn().mockRejectedValue(new Error('Network error.')),
      } as unknown as ExchangeApiClient['search'],
    };

    renderWithClient(client);

    await waitFor(() => expect(screen.getByRole('alert')).toBeDefined());
    expect(screen.getByRole('alert').textContent).toContain('Network error.');
  });

  test('shows empty states when there are no published packages', async () => {
    const client: Partial<ExchangeApiClient> = {
      search: {
        run: vi.fn().mockResolvedValue({
          items: [],
          totalCount: 0,
          totalPages: 0,
          currentPage: 1,
          pageSize: 12,
        }),
      } as unknown as ExchangeApiClient['search'],
    };

    renderWithClient(client);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'No categories yet' })).toBeDefined(),
    );
    expect(screen.getByRole('heading', { name: 'No packages published yet' })).toBeDefined();
  });
});
