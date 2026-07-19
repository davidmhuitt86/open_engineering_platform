import { describe, expect, test } from 'vitest';
import { normalizeSearchQuery } from './normalize-query.js';

describe('normalizeSearchQuery', () => {
  test('defaults page/pageSize/sortBy/sortDirection when omitted', () => {
    const query = normalizeSearchQuery({});
    expect(query).toEqual({ sortBy: 'createdAt', sortDirection: 'desc', page: 1, pageSize: 20 });
  });

  test('trims and carries through a keyword', () => {
    expect(normalizeSearchQuery({ q: '  wiring diagram  ' }).keyword).toBe('wiring diagram');
  });

  test('omits keyword entirely when blank', () => {
    expect(normalizeSearchQuery({ q: '   ' }).keyword).toBeUndefined();
  });

  test('carries through valid publisherId/categoryId/status', () => {
    const publisherId = '11111111-1111-1111-1111-111111111111';
    const categoryId = '22222222-2222-2222-2222-222222222222';
    const query = normalizeSearchQuery({ publisherId, categoryId, status: 'published' });
    expect(query.publisherId).toBe(publisherId);
    expect(query.categoryId).toBe(categoryId);
    expect(query.status).toBe('published');
  });

  test('rejects a malformed publisherId', () => {
    expect(() => normalizeSearchQuery({ publisherId: 'not-a-uuid' })).toThrow(
      /not a valid Publisher identifier/,
    );
  });

  test('rejects a malformed categoryId', () => {
    expect(() => normalizeSearchQuery({ categoryId: 'not-a-uuid' })).toThrow(
      /not a valid Category identifier/,
    );
  });

  test('rejects an unrecognized status', () => {
    expect(() => normalizeSearchQuery({ status: 'archived' })).toThrow(
      /not a recognized Package status/,
    );
  });

  test('rejects an unrecognized sortBy', () => {
    expect(() => normalizeSearchQuery({ sortBy: 'popularity' })).toThrow(
      /not a recognized sort field/,
    );
  });

  test('rejects an unrecognized sortDirection', () => {
    expect(() => normalizeSearchQuery({ sortDirection: 'sideways' })).toThrow(
      /not a recognized sort direction/,
    );
  });

  test('clamps pageSize to the maximum', () => {
    expect(normalizeSearchQuery({ pageSize: '500' }).pageSize).toBe(100);
  });

  test('clamps a non-positive page to 1', () => {
    expect(normalizeSearchQuery({ page: '-5' }).page).toBe(1);
  });

  test('falls back to defaults for non-numeric page/pageSize', () => {
    const query = normalizeSearchQuery({ page: 'abc', pageSize: 'xyz' });
    expect(query.page).toBe(1);
    expect(query.pageSize).toBe(20);
  });

  test('accepts explicit sortBy/sortDirection', () => {
    const query = normalizeSearchQuery({ sortBy: 'name', sortDirection: 'asc' });
    expect(query.sortBy).toBe('name');
    expect(query.sortDirection).toBe('asc');
  });
});
