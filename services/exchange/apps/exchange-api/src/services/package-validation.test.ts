import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';
import {
  validateCreatePackageRequest,
  validatePackageId,
  validateStatusTransition,
  validateUpdatePackageRequest,
} from './package-validation.js';

describe('validatePackageId', () => {
  test('accepts a well-formed UUID', () => {
    expect(() => validatePackageId(randomUUID())).not.toThrow();
  });

  test('rejects a malformed identifier', () => {
    expect(() => validatePackageId('not-a-uuid')).toThrow(/not a valid Package identifier/);
  });
});

describe('validateCreatePackageRequest', () => {
  const valid = {
    packageId: 'com.divad.honda.gl1200.electrical',
    publisherId: randomUUID(),
    displayName: 'Honda GL1200 Electrical',
  };

  test('accepts a fully-populated request', () => {
    expect(() => validateCreatePackageRequest(valid)).not.toThrow();
  });

  test.each(['packageId', 'publisherId', 'displayName'] as const)(
    'rejects a request missing %s',
    (field) => {
      const input = { ...valid, [field]: '' };
      expect(() => validateCreatePackageRequest(input)).toThrow(/Missing required field/);
    },
  );

  test('rejects a malformed publisherId', () => {
    expect(() => validateCreatePackageRequest({ ...valid, publisherId: 'not-a-uuid' })).toThrow(
      /not a valid Publisher identifier/,
    );
  });

  test('rejects a malformed packageId', () => {
    expect(() => validateCreatePackageRequest({ ...valid, packageId: 'NotReverseDomain' })).toThrow(
      /not a valid Package ID/,
    );
  });

  test('rejects a malformed categoryId when provided', () => {
    expect(() => validateCreatePackageRequest({ ...valid, categoryId: 'not-a-uuid' })).toThrow(
      /not a valid Category identifier/,
    );
  });

  test('accepts a valid categoryId', () => {
    expect(() =>
      validateCreatePackageRequest({ ...valid, categoryId: randomUUID() }),
    ).not.toThrow();
  });

  test('accepts a null categoryId', () => {
    expect(() => validateCreatePackageRequest({ ...valid, categoryId: null })).not.toThrow();
  });
});

describe('validateUpdatePackageRequest', () => {
  test('accepts an empty patch', () => {
    expect(() => validateUpdatePackageRequest({})).not.toThrow();
  });

  test('rejects a blank displayName', () => {
    expect(() => validateUpdatePackageRequest({ displayName: '   ' })).toThrow(/cannot be blank/);
  });

  test('rejects a malformed categoryId', () => {
    expect(() => validateUpdatePackageRequest({ categoryId: 'bad' })).toThrow(
      /not a valid Category identifier/,
    );
  });

  test('allows clearing categoryId to null', () => {
    expect(() => validateUpdatePackageRequest({ categoryId: null })).not.toThrow();
  });
});

describe('validateStatusTransition', () => {
  test('allows draft -> published', () => {
    expect(() => validateStatusTransition('draft', 'published')).not.toThrow();
  });

  test('allows published -> deprecated', () => {
    expect(() => validateStatusTransition('published', 'deprecated')).not.toThrow();
  });

  test('allows suspended -> draft', () => {
    expect(() => validateStatusTransition('suspended', 'draft')).not.toThrow();
  });

  test('rejects deprecated -> published (no un-deprecating)', () => {
    expect(() => validateStatusTransition('deprecated', 'published')).toThrow(
      /Cannot transition Package status/,
    );
  });

  test('rejects an unrecognized status', () => {
    expect(() => validateStatusTransition('draft', 'archived')).toThrow(
      /not a recognized Package status/,
    );
  });

  test('allows an idempotent same-status transition', () => {
    expect(() => validateStatusTransition('published', 'published')).not.toThrow();
  });
});
