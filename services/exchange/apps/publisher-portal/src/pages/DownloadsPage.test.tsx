import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, test } from 'vitest';
import { LibraryProvider } from '../state/LibraryContext.js';
import { DownloadsPage } from './DownloadsPage.js';

const LIBRARY_STORAGE_KEY = 'oep-exchange.publisher-portal.library.v1';

function renderPage() {
  return render(
    <MemoryRouter>
      <LibraryProvider>
        <DownloadsPage />
      </LibraryProvider>
    </MemoryRouter>,
  );
}

describe('DownloadsPage', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  afterEach(() => {
    window.localStorage.clear();
  });

  test('shows an empty state when nothing has been downloaded', () => {
    renderPage();
    expect(screen.getByRole('heading', { name: 'No downloads yet' })).toBeDefined();
  });

  test('lists each recorded download linking back to its package', () => {
    window.localStorage.setItem(
      LIBRARY_STORAGE_KEY,
      JSON.stringify({
        downloads: [
          {
            packageId: 'pkg-1',
            packageDisplayName: 'Honda GL1200 Electrical',
            version: '1.0.0',
            downloadedAt: '2026-01-01T00:00:00.000Z',
          },
        ],
        installations: [],
      }),
    );

    renderPage();

    const link = screen.getByRole('link', { name: 'Honda GL1200 Electrical' });
    expect(link.getAttribute('href')).toBe('/packages/pkg-1');
    expect(screen.getByText(/v1\.0\.0/).textContent).toContain('v1.0.0');
  });
});
