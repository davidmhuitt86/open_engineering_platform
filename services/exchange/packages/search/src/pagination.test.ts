import { describe, expect, test } from 'vitest';
import { computePagination } from './pagination.js';

describe('computePagination', () => {
  test('computes totalPages by ceiling division', () => {
    expect(computePagination(45, 1, 20)).toEqual({
      totalCount: 45,
      totalPages: 3,
      currentPage: 1,
      pageSize: 20,
    });
  });

  test('reports zero totalPages for zero results', () => {
    expect(computePagination(0, 1, 20)).toEqual({
      totalCount: 0,
      totalPages: 0,
      currentPage: 1,
      pageSize: 20,
    });
  });

  test('an exact multiple does not produce an extra empty page', () => {
    expect(computePagination(40, 2, 20).totalPages).toBe(2);
  });

  test('reports the requested currentPage even beyond the last real page', () => {
    expect(computePagination(10, 5, 20).currentPage).toBe(5);
  });
});
