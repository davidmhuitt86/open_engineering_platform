import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test } from 'vitest';
import { CategoryCard } from './CategoryCard.js';

describe('CategoryCard', () => {
  test('links to a search filtered by this category and pluralizes the count', () => {
    render(
      <MemoryRouter>
        <CategoryCard id="cat-1" name="Automotive" packageCount={3} />
      </MemoryRouter>,
    );

    const link = screen.getByRole('link', { name: 'Automotive' });
    expect(link.getAttribute('href')).toBe('/search?categoryId=cat-1');
    expect(screen.getByText('3 packages')).toBeDefined();
  });

  test('does not pluralize a single package', () => {
    render(
      <MemoryRouter>
        <CategoryCard id="cat-2" name="Marine" packageCount={1} />
      </MemoryRouter>,
    );
    expect(screen.getByText('1 package')).toBeDefined();
  });
});
