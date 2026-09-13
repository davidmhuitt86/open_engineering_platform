import { describe, expect, it } from 'vitest';
import { newId } from './id.js';

describe('newId', () => {
  it('generates a well-formed UUID', () => {
    expect(newId()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
  });

  it('generates a different id on each call', () => {
    expect(newId()).not.toBe(newId());
  });
});
