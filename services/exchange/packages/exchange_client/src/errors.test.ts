import { describe, expect, it } from 'vitest';
import { ExchangeApiError } from './errors.js';

describe('ExchangeApiError', () => {
  it('is a real Error subclass carrying status/code/message', () => {
    const error = new ExchangeApiError(404, 'NOT_FOUND', 'not found');

    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(ExchangeApiError);
    expect(error.status).toBe(404);
    expect(error.code).toBe('NOT_FOUND');
    expect(error.message).toBe('not found');
    expect(error.name).toBe('ExchangeApiError');
  });
});
