import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';
import {
  validateCategoryId,
  validateFilePresent,
  validatePublisherId,
} from './upload-validation.js';

describe('validatePublisherId', () => {
  test('accepts a well-formed UUID', () => {
    expect(() => validatePublisherId(randomUUID())).not.toThrow();
  });

  test('rejects a malformed identifier', () => {
    expect(() => validatePublisherId('not-a-uuid')).toThrow(/not a valid Publisher identifier/);
  });

  test('rejects an empty identifier', () => {
    expect(() => validatePublisherId('')).toThrow(/not a valid Publisher identifier/);
  });
});

describe('validateCategoryId', () => {
  test('accepts a well-formed UUID', () => {
    expect(() => validateCategoryId(randomUUID())).not.toThrow();
  });

  test('rejects a malformed identifier', () => {
    expect(() => validateCategoryId('not-a-uuid')).toThrow(/not a valid Category identifier/);
  });
});

describe('validateFilePresent', () => {
  test('accepts a non-empty buffer', () => {
    expect(() => validateFilePresent(Buffer.from('data'))).not.toThrow();
  });

  test('rejects undefined', () => {
    expect(() => validateFilePresent(undefined)).toThrow(/No package file was uploaded/);
  });

  test('rejects an empty buffer', () => {
    expect(() => validateFilePresent(Buffer.alloc(0))).toThrow(/No package file was uploaded/);
  });
});
