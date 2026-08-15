import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, test } from 'vitest';
import { AppShell } from './AppShell.js';

describe('AppShell', () => {
  test('renders the header, sidebar navigation, footer, and the routed page content', () => {
    render(
      <MemoryRouter initialEntries={['/hello']}>
        <Routes>
          <Route element={<AppShell />}>
            <Route path="/hello" element={<p>Hello from a page</p>} />
          </Route>
        </Routes>
      </MemoryRouter>,
    );

    expect(screen.getByText('OEP Engineering Exchange')).toBeDefined();
    expect(screen.getByRole('link', { name: 'Home' })).toBeDefined();
    expect(screen.getByText('Hello from a page')).toBeDefined();
    expect(screen.getByText(/Marketplace/)).toBeDefined();
  });
});
