import { describe, expect, it } from 'vitest';
import {
  ConflictError,
  DomainError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from './errors.js';

describe('DomainError family', () => {
  it('NotFoundError carries a stable code and identifies the missing resource', () => {
    const error = new NotFoundError('Package', 'abc-123');
    expect(error).toBeInstanceOf(DomainError);
    expect(error.code).toBe('NOT_FOUND');
    expect(error.message).toContain('Package');
    expect(error.message).toContain('abc-123');
    expect(error.details).toEqual({ resource: 'Package', id: 'abc-123' });
  });

  it('ValidationError uses the VALIDATION_ERROR code', () => {
    const error = new ValidationError('name is required');
    expect(error.code).toBe('VALIDATION_ERROR');
  });

  it('ForbiddenError has a sensible default message', () => {
    const error = new ForbiddenError();
    expect(error.code).toBe('FORBIDDEN');
    expect(error.message.length).toBeGreaterThan(0);
  });

  it('ConflictError carries the CONFLICT code and details', () => {
    const error = new ConflictError('duplicate package name', { name: 'widget' });
    expect(error.code).toBe('CONFLICT');
    expect(error.details).toEqual({ name: 'widget' });
  });

  it('each error subclass name matches its class (not just "DomainError")', () => {
    expect(new NotFoundError('X', '1').name).toBe('NotFoundError');
  });
});
