import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test } from 'vitest';
import { NotFoundPage } from './NotFoundPage.js';

describe('NotFoundPage', () => {
  test('renders a not-found message and a link back home', () => {
    render(
      <MemoryRouter>
        <NotFoundPage />
      </MemoryRouter>,
    );

    expect(screen.getByRole('heading', { name: 'Page not found' })).toBeDefined();
    expect(screen.getByRole('link', { name: 'Back to home' }).getAttribute('href')).toBe('/');
  });
});
