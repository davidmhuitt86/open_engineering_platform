import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test, vi } from 'vitest';
import { Sidebar } from './Sidebar.js';

describe('Sidebar', () => {
  test('renders every primary navigation item', () => {
    render(
      <MemoryRouter>
        <Sidebar isOpen={false} onNavigate={vi.fn()} />
      </MemoryRouter>,
    );

    for (const label of ['Home', 'Search', 'Categories', 'Publishers', 'My Library', 'Downloads']) {
      expect(screen.getByRole('link', { name: label })).toBeDefined();
    }
  });

  test('applies the is-open class when open', () => {
    const { container } = render(
      <MemoryRouter>
        <Sidebar isOpen onNavigate={vi.fn()} />
      </MemoryRouter>,
    );
    expect(container.querySelector('.app-sidebar')?.className).toContain('is-open');
  });

  test('calls onNavigate when a link is clicked', () => {
    const onNavigate = vi.fn();
    render(
      <MemoryRouter>
        <Sidebar isOpen onNavigate={onNavigate} />
      </MemoryRouter>,
    );
    fireEvent.click(screen.getByRole('link', { name: 'Search' }));
    expect(onNavigate).toHaveBeenCalledOnce();
  });
});
