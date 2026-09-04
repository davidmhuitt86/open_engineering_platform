import { render, screen } from '@testing-library/react';
import { describe, expect, test } from 'vitest';
import { EmptyState } from './EmptyState.js';

describe('EmptyState', () => {
  test('renders the title and optional message', () => {
    render(<EmptyState title="No packages found" message="Try a different search." />);
    expect(screen.getByRole('heading', { name: 'No packages found' })).toBeDefined();
    expect(screen.getByText('Try a different search.')).toBeDefined();
  });

  test('renders without a message', () => {
    render(<EmptyState title="Nothing here yet" />);
    expect(screen.getByRole('heading', { name: 'Nothing here yet' })).toBeDefined();
  });
});
