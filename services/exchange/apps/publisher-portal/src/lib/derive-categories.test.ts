import type { SearchResultItemDto } from '@oep-exchange/api-contracts';
import { describe, expect, test } from 'vitest';
import { deriveCategories } from './derive-categories.js';

function item(overrides: Partial<SearchResultItemDto> = {}): SearchResultItemDto {
  return {
    id: 'pkg-1',
    packageId: 'com.divad.honda',
    publisherId: 'pub-1',
    publisherName: 'Divad Engineering',
    displayName: 'Honda GL1200',
    description: '',
    categoryId: 'cat-1',
    categoryName: 'Automotive',
    currentVersion: '1.0.0',
    status: 'published',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
    ...overrides,
  };
}

describe('deriveCategories', () => {
  test('counts packages per category and sorts alphabetically by name', () => {
    const categories = deriveCategories([
      item({ id: 'pkg-1', categoryId: 'cat-2', categoryName: 'Marine' }),
      item({ id: 'pkg-2', categoryId: 'cat-1', categoryName: 'Automotive' }),
      item({ id: 'pkg-3', categoryId: 'cat-1', categoryName: 'Automotive' }),
    ]);

    expect(categories).toEqual([
      { id: 'cat-1', name: 'Automotive', packageCount: 2 },
      { id: 'cat-2', name: 'Marine', packageCount: 1 },
    ]);
  });

  test('skips items with no category', () => {
    const categories = deriveCategories([item({ categoryId: null, categoryName: null })]);
    expect(categories).toEqual([]);
  });

  test('returns an empty array for no items', () => {
    expect(deriveCategories([])).toEqual([]);
  });
});
