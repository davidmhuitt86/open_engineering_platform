import { render, screen } from '@testing-library/react';
import { describe, expect, test } from 'vitest';
import { Footer } from './Footer.js';

describe('Footer', () => {
  test('renders the marketplace footer text', () => {
    render(<Footer />);
    expect(screen.getByText(/OEP Engineering Exchange/)).toBeDefined();
  });
});
