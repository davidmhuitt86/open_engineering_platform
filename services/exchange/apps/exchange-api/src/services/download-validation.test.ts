import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';
import { validatePackageId, validateVersionParam } from './download-validation.js';

describe('validatePackageId', () => {
  test('accepts a well-formed UUID', () => {
    expect(() => validatePackageId(randomUUID())).not.toThrow();
  });

  test('rejects a malformed id', () => {
    expect(() => validatePackageId('not-a-uuid')).toThrow(/not a valid Package identifier/);
  });
});

describe('validateVersionParam', () => {
  test('accepts a non-blank version string', () => {
    expect(() => validateVersionParam('1.0.0')).not.toThrow();
  });

  test('rejects an empty version string', () => {
    expect(() => validateVersionParam('')).toThrow(/must be provided/);
  });

  test('rejects a blank (whitespace-only) version string', () => {
    expect(() => validateVersionParam('   ')).toThrow(/must be provided/);
  });
});
