import { render, screen } from '@testing-library/react';
import { describe, expect, test } from 'vitest';
import { LoadingIndicator } from './LoadingIndicator.js';

describe('LoadingIndicator', () => {
  test('renders a default label and status role', () => {
    render(<LoadingIndicator />);
    expect(screen.getByRole('status').textContent).toContain('Loading…');
  });

  test('renders a custom label', () => {
    render(<LoadingIndicator label="Fetching packages…" />);
    expect(screen.getByRole('status').textContent).toContain('Fetching packages…');
  });
});
