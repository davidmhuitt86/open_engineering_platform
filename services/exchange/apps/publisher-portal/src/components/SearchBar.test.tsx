import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, test, vi } from 'vitest';
import { SearchBar } from './SearchBar.js';

describe('SearchBar', () => {
  test('submits the trimmed input value', () => {
    const onSubmit = vi.fn();
    render(<SearchBar onSubmit={onSubmit} />);

    const input = screen.getByRole('searchbox');
    fireEvent.change(input, { target: { value: '  turbocharger  ' } });
    fireEvent.click(screen.getByRole('button', { name: 'Search' }));

    expect(onSubmit).toHaveBeenCalledWith('turbocharger');
  });

  test('pre-fills the input from initialValue', () => {
    render(<SearchBar initialValue="honda" onSubmit={vi.fn()} />);
    expect(screen.getByRole('searchbox')).toHaveProperty('value', 'honda');
  });
});
