import type { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import { ExchangeApiClientContext } from '../api/ExchangeApiClientContext.js';
import { LibraryProvider } from '../state/LibraryContext.js';
import { PackageDetailPage } from './PackageDetailPage.js';

const LIBRARY_STORAGE_KEY = 'oep-exchange.publisher-portal.library.v1';

function fakePackage(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    id: 'pkg-1',
    packageId: 'com.divad.honda.gl1200',
    publisherId: 'pub-1',
    displayName: 'Honda GL1200 Electrical',
    description: 'Wiring diagrams.',
    categoryId: 'cat-1',
    currentVersion: '1.0.0',
    status: 'published',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
    ...overrides,
  };
}

function fakePublisher(overrides: Partial<Record<string, unknown>> = {}) {
  return {
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
    ...overrides,
  };
}

function renderPage(client: Partial<ExchangeApiClient>) {
  return render(
    <MemoryRouter initialEntries={['/packages/pkg-1']}>
      <ExchangeApiClientContext.Provider value={client as ExchangeApiClient}>
        <LibraryProvider>
          <Routes>
            <Route path="/packages/:id" element={<PackageDetailPage />} />
          </Routes>
        </LibraryProvider>
      </ExchangeApiClientContext.Provider>
    </MemoryRouter>,
  );
}

describe('PackageDetailPage', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  afterEach(() => {
    window.localStorage.clear();
  });

  test('renders the package and publisher once both load', async () => {
    const client: Partial<ExchangeApiClient> = {
      packages: {
        get: vi.fn().mockResolvedValue(fakePackage()),
      } as unknown as ExchangeApiClient['packages'],
      publishers: {
        get: vi.fn().mockResolvedValue(fakePublisher()),
      } as unknown as ExchangeApiClient['publishers'],
      downloads: {
        url: vi.fn().mockReturnValue('/api/v1/packages/pkg-1/download'),
      } as unknown as ExchangeApiClient['downloads'],
    };

    renderPage(client);

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'Honda GL1200 Electrical' })).toBeDefined(),
    );
    expect(screen.getByRole('link', { name: 'Divad Engineering' }).getAttribute('href')).toBe(
      '/publishers/pub-1',
    );
    expect(screen.getByText('published')).toBeDefined();
    expect(screen.getByText('1.0.0')).toBeDefined();
  });

  test('shows an error view when the package fails to load', async () => {
    const client: Partial<ExchangeApiClient> = {
      packages: {
        get: vi.fn().mockRejectedValue(new Error('Package "pkg-1" was not found.')),
      } as unknown as ExchangeApiClient['packages'],
      publishers: { get: vi.fn() } as unknown as ExchangeApiClient['publishers'],
    };

    renderPage(client);

    await waitFor(() => expect(screen.getByRole('alert')).toBeDefined());
    expect(screen.getByRole('alert').textContent).toContain('was not found');
  });

  test('clicking Download records a download in the library', async () => {
    const client: Partial<ExchangeApiClient> = {
      packages: {
        get: vi.fn().mockResolvedValue(fakePackage()),
      } as unknown as ExchangeApiClient['packages'],
      publishers: {
        get: vi.fn().mockResolvedValue(fakePublisher()),
      } as unknown as ExchangeApiClient['publishers'],
      downloads: {
        url: vi.fn().mockReturnValue('/api/v1/packages/pkg-1/download'),
      } as unknown as ExchangeApiClient['downloads'],
    };

    renderPage(client);

    const downloadLink = await waitFor(() =>
      screen.getByRole('link', { name: /Download v1\.0\.0/ }),
    );
    expect(downloadLink.getAttribute('href')).toBe('/api/v1/packages/pkg-1/download');

    fireEvent.click(downloadLink);

    await waitFor(() => {
      const stored = JSON.parse(window.localStorage.getItem(LIBRARY_STORAGE_KEY) ?? '{}');
      expect(stored.downloads).toHaveLength(1);
      expect(stored.downloads[0].packageId).toBe('pkg-1');
    });
  });

  test('clicking Install shows the installation progress and records success', async () => {
    const client: Partial<ExchangeApiClient> = {
      packages: {
        get: vi.fn().mockResolvedValue(fakePackage()),
      } as unknown as ExchangeApiClient['packages'],
      publishers: {
        get: vi.fn().mockResolvedValue(fakePublisher()),
      } as unknown as ExchangeApiClient['publishers'],
      downloads: {
        url: vi.fn().mockReturnValue('/x'),
      } as unknown as ExchangeApiClient['downloads'],
      installations: {
        install: vi.fn().mockResolvedValue({
          id: 'install-1',
          packageId: 'com.divad.honda.gl1200',
          version: '1.0.0',
          status: 'completed',
          repositoryPackageId: 'stub-com.divad.honda.gl1200@1.0.0',
          errorMessage: null,
          requestedAt: '2026-01-01T00:00:00.000Z',
          completedAt: '2026-01-01T00:00:01.000Z',
        }),
      } as unknown as ExchangeApiClient['installations'],
    };

    renderPage(client);

    const installButton = await waitFor(() =>
      screen.getByRole('button', { name: 'Install into Repository' }),
    );
    fireEvent.click(installButton);

    await waitFor(() =>
      expect(screen.getByText(/Installed successfully/).textContent).toContain(
        'stub-com.divad.honda.gl1200@1.0.0',
      ),
    );

    const stored = JSON.parse(window.localStorage.getItem(LIBRARY_STORAGE_KEY) ?? '{}');
    expect(stored.installations).toHaveLength(1);
    expect(stored.installations[0].status).toBe('completed');
  });

  test('shows the Repository rejection message when installation fails', async () => {
    const client: Partial<ExchangeApiClient> = {
      packages: {
        get: vi.fn().mockResolvedValue(fakePackage()),
      } as unknown as ExchangeApiClient['packages'],
      publishers: {
        get: vi.fn().mockResolvedValue(fakePublisher()),
      } as unknown as ExchangeApiClient['publishers'],
      downloads: {
        url: vi.fn().mockReturnValue('/x'),
      } as unknown as ExchangeApiClient['downloads'],
      installations: {
        install: vi.fn().mockResolvedValue({
          id: 'install-1',
          packageId: 'com.divad.honda.gl1200',
          version: '1.0.0',
          status: 'failed',
          repositoryPackageId: null,
          errorMessage: 'The Repository rejected the installation request.',
          requestedAt: '2026-01-01T00:00:00.000Z',
          completedAt: '2026-01-01T00:00:01.000Z',
        }),
      } as unknown as ExchangeApiClient['installations'],
    };

    renderPage(client);

    const installButton = await waitFor(() =>
      screen.getByRole('button', { name: 'Install into Repository' }),
    );
    fireEvent.click(installButton);

    await waitFor(() =>
      expect(screen.getByRole('alert').textContent).toContain(
        'The Repository rejected the installation request.',
      ),
    );
  });
});
