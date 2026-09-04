import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test } from 'vitest';
import { PackageList } from './PackageList.js';

describe('PackageList', () => {
  test('renders a card for each package', () => {
    render(
      <MemoryRouter>
        <PackageList
          items={[
            {
              id: 'pkg-1',
              displayName: 'Honda GL1200',
              description: '',
              status: 'published',
              currentVersion: '1.0.0',
            },
            {
              id: 'pkg-2',
              displayName: 'Yamaha XS650',
              description: '',
              status: 'published',
              currentVersion: '2.0.0',
            },
          ]}
        />
      </MemoryRouter>,
    );

    expect(screen.getByRole('link', { name: 'Honda GL1200' })).toBeDefined();
    expect(screen.getByRole('link', { name: 'Yamaha XS650' })).toBeDefined();
  });

  test('renders an empty state when there are no packages', () => {
    render(
      <MemoryRouter>
        <PackageList items={[]} emptyTitle="No packages found" />
      </MemoryRouter>,
    );

    expect(screen.getByRole('heading', { name: 'No packages found' })).toBeDefined();
  });
});
