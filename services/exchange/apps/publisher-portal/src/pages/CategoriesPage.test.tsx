import type { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test, vi } from 'vitest';
import { ExchangeApiClientContext } from '../api/ExchangeApiClientContext.js';
import { CategoriesPage } from './CategoriesPage.js';

function renderWithClient(client: Partial<ExchangeApiClient>) {
  return render(
    <MemoryRouter>
      <ExchangeApiClientContext.Provider value={client as ExchangeApiClient}>
        <CategoriesPage />
      </ExchangeApiClientContext.Provider>
    </MemoryRouter>,
  );
}

describe('CategoriesPage', () => {
  test('renders a card per distinct category found in the search sample', async () => {
    const client: Partial<ExchangeApiClient> = {
      search: {
        run: vi.fn().mockResolvedValue({
          items: [
            { id: 'pkg-1', categoryId: 'cat-1', categoryName: 'Automotive' },
            { id: 'pkg-2', categoryId: 'cat-2', categoryName: 'Marine' },
          ],
          totalCount: 2,
          totalPages: 1,
          currentPage: 1,
          pageSize: 100,
        }),
      } as unknown as ExchangeApiClient['search'],
    };

    renderWithClient(client);

    await waitFor(() => expect(screen.getByRole('link', { name: 'Automotive' })).toBeDefined());
    expect(screen.getByRole('link', { name: 'Marine' })).toBeDefined();
  });

  test('shows an empty state when no packages are categorized', async () => {
    const client: Partial<ExchangeApiClient> = {
      search: {
        run: vi
          .fn()
          .mockResolvedValue({
            items: [],
            totalCount: 0,
            totalPages: 0,
            currentPage: 1,
            pageSize: 100,
          }),
      } as unknown as ExchangeApiClient['search'],
    };

    renderWithClient(client);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'No categories yet' })).toBeDefined(),
    );
  });
});
