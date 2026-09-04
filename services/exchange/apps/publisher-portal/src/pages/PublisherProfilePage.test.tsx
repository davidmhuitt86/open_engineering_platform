import type { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, test, vi } from 'vitest';
import { ExchangeApiClientContext } from '../api/ExchangeApiClientContext.js';
import { PublisherProfilePage } from './PublisherProfilePage.js';

function renderPage(client: Partial<ExchangeApiClient>) {
  return render(
    <MemoryRouter initialEntries={['/publishers/pub-1']}>
      <ExchangeApiClientContext.Provider value={client as ExchangeApiClient}>
        <Routes>
          <Route path="/publishers/:id" element={<PublisherProfilePage />} />
        </Routes>
      </ExchangeApiClientContext.Provider>
    </MemoryRouter>,
  );
}

describe('PublisherProfilePage', () => {
  test('renders the publisher and their packages', async () => {
    const client: Partial<ExchangeApiClient> = {
      publishers: {
        get: vi.fn().mockResolvedValue({
          id: 'pub-1',
          namespace: 'com.divad',
          publisherType: 'community_organization',
          displayName: 'Divad Engineering',
          legalName: 'Divad Engineering LLC',
          description: 'Vintage motorcycle wiring diagrams.',
          website: 'https://divad.example.com',
          contactEmail: 'contact@example.com',
          status: 'active',
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-01-01T00:00:00.000Z',
        }),
      } as unknown as ExchangeApiClient['publishers'],
      search: {
        run: vi.fn().mockResolvedValue({
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
          totalCount: 1,
          totalPages: 1,
          currentPage: 1,
          pageSize: 50,
        }),
      } as unknown as ExchangeApiClient['search'],
    };

    renderPage(client);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'Divad Engineering' })).toBeDefined(),
    );
    expect(screen.getByText('Community Organization')).toBeDefined();
    expect(screen.getByRole('link', { name: 'https://divad.example.com' })).toBeDefined();
    expect(screen.getByRole('link', { name: 'Honda GL1200' })).toBeDefined();

    expect(client.search!.run as ReturnType<typeof vi.fn>).toHaveBeenCalledWith(
      expect.objectContaining({ publisherId: 'pub-1' }),
    );
  });

  test('shows an empty state when the publisher has no packages', async () => {
    const client: Partial<ExchangeApiClient> = {
      publishers: {
        get: vi.fn().mockResolvedValue({
          id: 'pub-1',
          namespace: 'com.divad',
          publisherType: 'individual',
          displayName: 'Divad Engineering',
          legalName: 'Divad Engineering LLC',
          description: '',
          website: '',
          contactEmail: 'contact@example.com',
          status: 'active',
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-01-01T00:00:00.000Z',
        }),
      } as unknown as ExchangeApiClient['publishers'],
      search: {
        run: vi
          .fn()
          .mockResolvedValue({
            items: [],
            totalCount: 0,
            totalPages: 0,
            currentPage: 1,
            pageSize: 50,
          }),
      } as unknown as ExchangeApiClient['search'],
    };

    renderPage(client);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'No packages published yet' })).toBeDefined(),
    );
  });

  test('shows an error view when the publisher fails to load', async () => {
    const client: Partial<ExchangeApiClient> = {
      publishers: {
        get: vi.fn().mockRejectedValue(new Error('Publisher "pub-1" was not found.')),
      } as unknown as ExchangeApiClient['publishers'],
      search: { run: vi.fn() } as unknown as ExchangeApiClient['search'],
    };

    renderPage(client);

    await waitFor(() => expect(screen.getByRole('alert')).toBeDefined());
  });
});
