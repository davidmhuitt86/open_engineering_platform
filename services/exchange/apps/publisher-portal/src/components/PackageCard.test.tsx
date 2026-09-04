import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test } from 'vitest';
import { PackageCard } from './PackageCard.js';

describe('PackageCard', () => {
  test('links to the package detail page and shows its status/version', () => {
    render(
      <MemoryRouter>
        <PackageCard
          id="pkg-1"
          displayName="Honda GL1200 Electrical"
          description="Wiring diagrams."
          status="published"
          currentVersion="1.0.0"
          publisherName="Divad Engineering"
          categoryName="Automotive"
        />
      </MemoryRouter>,
    );

    const link = screen.getByRole('link', { name: 'Honda GL1200 Electrical' });
    expect(link.getAttribute('href')).toBe('/packages/pkg-1');
    expect(screen.getByText('published')).toBeDefined();
    expect(screen.getByText('v1.0.0')).toBeDefined();
    expect(screen.getByText('Divad Engineering')).toBeDefined();
  });

  test('shows a fallback when there is no published version yet', () => {
    render(
      <MemoryRouter>
        <PackageCard
          id="pkg-2"
          displayName="Unpublished Package"
          description=""
          status="draft"
          currentVersion={null}
        />
      </MemoryRouter>,
    );

    expect(screen.getByText('No published version yet')).toBeDefined();
    expect(screen.getByText('No description provided.')).toBeDefined();
  });
});
