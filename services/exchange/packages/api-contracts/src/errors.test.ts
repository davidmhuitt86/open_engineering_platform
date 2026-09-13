import { ForbiddenError, NotFoundError } from '@oep-exchange/core';
import { describe, expect, it } from 'vitest';
import { toApiErrorResponse } from './errors.js';

describe('toApiErrorResponse', () => {
  it('serializes a DomainError into the stable API error envelope', () => {
    const error = new NotFoundError('Package', 'abc-123');
    expect(toApiErrorResponse(error)).toEqual({
      error: {
        code: 'NOT_FOUND',
        message: error.message,
        details: { resource: 'Package', id: 'abc-123' },
      },
    });
  });

  it('omits the details field entirely when the error has none', () => {
    const response = toApiErrorResponse(new ForbiddenError());
    expect('details' in response.error).toBe(false);
  });
});
