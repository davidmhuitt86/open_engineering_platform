import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test } from 'vitest';
import { Breadcrumbs } from './Breadcrumbs.js';

describe('Breadcrumbs', () => {
  test('renders a link for items with a target and plain text for the current page', () => {
    render(
      <MemoryRouter>
        <Breadcrumbs
          items={[
            { label: 'Home', to: '/' },
            { label: 'Search', to: '/search' },
            { label: 'Honda GL1200' },
          ]}
        />
      </MemoryRouter>,
    );

    const homeLink = screen.getByRole('link', { name: 'Home' });
    expect(homeLink.getAttribute('href')).toBe('/');
    expect(screen.getByRole('link', { name: 'Search' }).getAttribute('href')).toBe('/search');
    expect(screen.queryByRole('link', { name: 'Honda GL1200' })).toBeNull();
    expect(screen.getByText('Honda GL1200')).toBeDefined();
  });
});
