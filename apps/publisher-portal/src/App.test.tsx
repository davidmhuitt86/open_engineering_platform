import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { App } from './App.js';

describe('App', () => {
  it('renders the Publisher Portal placeholder heading', () => {
    render(<App />);
    expect(screen.getByRole('heading', { name: 'OEP Engineering Exchange' })).toBeDefined();
    expect(screen.getByText(/Publisher Portal/)).toBeDefined();
  });
});
