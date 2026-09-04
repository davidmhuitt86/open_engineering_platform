import type { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import { ExchangeApiClientContext } from '../api/ExchangeApiClientContext.js';
import { LibraryProvider } from '../state/LibraryContext.js';
import { MyLibraryPage } from './MyLibraryPage.js';

const LIBRARY_STORAGE_KEY = 'oep-exchange.publisher-portal.library.v1';

function renderPage(client: Partial<ExchangeApiClient> = {}) {
  return render(
    <MemoryRouter>
      <ExchangeApiClientContext.Provider value={client as ExchangeApiClient}>
        <LibraryProvider>
          <MyLibraryPage />
        </LibraryProvider>
      </ExchangeApiClientContext.Provider>
    </MemoryRouter>,
  );
}

describe('MyLibraryPage', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  afterEach(() => {
    window.localStorage.clear();
  });

  test('shows an empty state when nothing has been installed', () => {
    renderPage();
    expect(screen.getByRole('heading', { name: 'Your library is empty' })).toBeDefined();
  });

  test('lists each recorded installation with its status and a link to the package', () => {
    window.localStorage.setItem(
      LIBRARY_STORAGE_KEY,
      JSON.stringify({
        downloads: [],
        installations: [
          {
            installationId: 'install-1',
            packageId: 'pkg-1',
            packageDisplayName: 'Honda GL1200 Electrical',
            version: '1.0.0',
            status: 'completed',
            requestedAt: '2026-01-01T00:00:00.000Z',
          },
        ],
      }),
    );

    renderPage();

    expect(screen.getByRole('link', { name: 'Honda GL1200 Electrical' }).getAttribute('href')).toBe(
      '/packages/pkg-1',
    );
    expect(screen.getByText('completed')).toBeDefined();
  });

  test('Refresh status re-fetches the installation and updates the badge', async () => {
    window.localStorage.setItem(
      LIBRARY_STORAGE_KEY,
      JSON.stringify({
        downloads: [],
        installations: [
          {
            installationId: 'install-1',
            packageId: 'pkg-1',
            packageDisplayName: 'Honda GL1200 Electrical',
            version: '1.0.0',
            status: 'pending',
            requestedAt: '2026-01-01T00:00:00.000Z',
          },
        ],
      }),
    );

    const get = vi.fn().mockResolvedValue({
      id: 'install-1',
      packageId: 'com.divad.honda',
      version: '1.0.0',
      status: 'completed',
      repositoryPackageId: 'stub-com.divad.honda@1.0.0',
      errorMessage: null,
      requestedAt: '2026-01-01T00:00:00.000Z',
      completedAt: '2026-01-01T00:00:01.000Z',
    });

    renderPage({ installations: { get } as unknown as ExchangeApiClient['installations'] });

    expect(screen.getByText('pending')).toBeDefined();
    fireEvent.click(screen.getByRole('button', { name: 'Refresh status' }));

    await waitFor(() => expect(screen.getByText('completed')).toBeDefined());
    expect(get).toHaveBeenCalledWith('install-1');
  });
});
