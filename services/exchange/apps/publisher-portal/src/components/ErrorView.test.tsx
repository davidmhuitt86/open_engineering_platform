import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, test, vi } from 'vitest';
import { ErrorView } from './ErrorView.js';

describe('ErrorView', () => {
  test('renders the error message with an alert role', () => {
    render(<ErrorView message="Something went wrong." />);
    expect(screen.getByRole('alert').textContent).toContain('Something went wrong.');
  });

  test('calls onRetry when the retry button is clicked', () => {
    const onRetry = vi.fn();
    render(<ErrorView message="Failed to load." onRetry={onRetry} />);
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));
    expect(onRetry).toHaveBeenCalledOnce();
  });

  test('does not render a retry button when onRetry is omitted', () => {
    render(<ErrorView message="Failed to load." />);
    expect(screen.queryByRole('button')).toBeNull();
  });
});
