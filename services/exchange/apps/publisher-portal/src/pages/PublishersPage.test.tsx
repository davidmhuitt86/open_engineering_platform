import type { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test, vi } from 'vitest';
import { ExchangeApiClientContext } from '../api/ExchangeApiClientContext.js';
import { PublishersPage } from './PublishersPage.js';

function renderWithClient(client: Partial<ExchangeApiClient>) {
  return render(
    <MemoryRouter>
      <ExchangeApiClientContext.Provider value={client as ExchangeApiClient}>
        <PublishersPage />
      </ExchangeApiClientContext.Provider>
    </MemoryRouter>,
  );
}

describe('PublishersPage', () => {
  test('renders a card per publisher returned by the API', async () => {
    const client: Partial<ExchangeApiClient> = {
      publishers: {
        list: vi.fn().mockResolvedValue([
          {
            id: 'pub-1',
            namespace: 'com.divad',
            publisherType: 'individual',
            displayName: 'Divad Engineering',
            legalName: 'Divad Engineering LLC',
            description: 'Vintage motorcycle wiring diagrams.',
            website: '',
            contactEmail: 'contact@example.com',
            status: 'active',
            createdAt: '2026-01-01T00:00:00.000Z',
            updatedAt: '2026-01-01T00:00:00.000Z',
          },
        ]),
      } as unknown as ExchangeApiClient['publishers'],
    };

    renderWithClient(client);

    await waitFor(() =>
      expect(screen.getByRole('link', { name: 'Divad Engineering' })).toBeDefined(),
    );
  });

  test('shows an empty state when there are no publishers', async () => {
    const client: Partial<ExchangeApiClient> = {
      publishers: {
        list: vi.fn().mockResolvedValue([]),
      } as unknown as ExchangeApiClient['publishers'],
    };

    renderWithClient(client);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'No publishers yet' })).toBeDefined(),
    );
  });

  test('shows an error view when the request fails', async () => {
    const client: Partial<ExchangeApiClient> = {
      publishers: {
        list: vi.fn().mockRejectedValue(new Error('Failed to reach the Exchange API.')),
      } as unknown as ExchangeApiClient['publishers'],
    };

    renderWithClient(client);

    await waitFor(() => expect(screen.getByRole('alert')).toBeDefined());
  });
});
