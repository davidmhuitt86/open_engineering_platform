import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, test } from 'vitest';
import { PublisherCard } from './PublisherCard.js';

describe('PublisherCard', () => {
  test('links to the publisher profile page and formats the publisher type', () => {
    render(
      <MemoryRouter>
        <PublisherCard
          id="pub-1"
          displayName="Divad Engineering"
          publisherType="community_organization"
          description="A community of vintage motorcycle enthusiasts."
        />
      </MemoryRouter>,
    );

    const link = screen.getByRole('link', { name: 'Divad Engineering' });
    expect(link.getAttribute('href')).toBe('/publishers/pub-1');
    expect(screen.getByText('Community Organization')).toBeDefined();
  });
});
