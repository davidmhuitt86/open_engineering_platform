import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';
import {
  validateInstallationId,
  validatePackageId,
  validateVersionParam,
} from './installation-validation.js';

describe('validatePackageId', () => {
  test('accepts a well-formed UUID', () => {
    expect(() => validatePackageId(randomUUID())).not.toThrow();
  });

  test('rejects a malformed id', () => {
    expect(() => validatePackageId('not-a-uuid')).toThrow(/not a valid Package identifier/);
  });
});

describe('validateInstallationId', () => {
  test('accepts a well-formed UUID', () => {
    expect(() => validateInstallationId(randomUUID())).not.toThrow();
  });

  test('rejects a malformed id', () => {
    expect(() => validateInstallationId('not-a-uuid')).toThrow(
      /not a valid Installation identifier/,
    );
  });
});

describe('validateVersionParam', () => {
  test('accepts undefined (install the current version)', () => {
    expect(() => validateVersionParam(undefined)).not.toThrow();
  });

  test('accepts a non-blank version string', () => {
    expect(() => validateVersionParam('1.0.0')).not.toThrow();
  });

  test('rejects a blank (whitespace-only) version string', () => {
    expect(() => validateVersionParam('   ')).toThrow(/cannot be blank/);
  });
});
