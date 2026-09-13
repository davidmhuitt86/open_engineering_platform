import { describe, expect, it } from 'vitest';
import { err, ok } from './result.js';

describe('Result', () => {
  it('ok() produces a success result carrying the value', () => {
    const result = ok(42);
    expect(result.ok).toBe(true);
    expect(result.ok && result.value).toBe(42);
  });

  it('err() produces a failure result carrying the error', () => {
    const result = err('bad input');
    expect(result.ok).toBe(false);
    expect(!result.ok && result.error).toBe('bad input');
  });
});
