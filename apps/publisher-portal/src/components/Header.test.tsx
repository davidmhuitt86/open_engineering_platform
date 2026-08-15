import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test, vi } from 'vitest';
import { Header } from './Header.js';

describe('Header', () => {
  test('calls onToggleSidebar when the menu button is clicked', () => {
    const onToggleSidebar = vi.fn();
    render(
      <MemoryRouter>
        <Header onToggleSidebar={onToggleSidebar} />
      </MemoryRouter>,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Toggle navigation menu' }));
    expect(onToggleSidebar).toHaveBeenCalledOnce();
  });

  test('renders the brand and a search box', () => {
    render(
      <MemoryRouter>
        <Header onToggleSidebar={vi.fn()} />
      </MemoryRouter>,
    );

    expect(screen.getByText('OEP Engineering Exchange')).toBeDefined();
    expect(screen.getByRole('searchbox')).toBeDefined();
  });
});
