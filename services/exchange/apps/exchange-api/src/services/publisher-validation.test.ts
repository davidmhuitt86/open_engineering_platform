import { randomUUID } from 'node:crypto';
import { describe, expect, test } from 'vitest';
import {
  validateCreatePublisherRequest,
  validatePublisherId,
  validateStatusTransition,
  validateUpdatePublisherRequest,
} from './publisher-validation.js';

describe('validatePublisherId', () => {
  test('accepts a well-formed UUID', () => {
    expect(() => validatePublisherId(randomUUID())).not.toThrow();
  });

  test('rejects a malformed identifier', () => {
    expect(() => validatePublisherId('not-a-uuid')).toThrow(/not a valid Publisher identifier/);
  });
});

describe('validateCreatePublisherRequest', () => {
  const valid = {
    namespace: 'com.test.divad',
    publisherType: 'individual' as const,
    displayName: 'Divad',
    legalName: 'Divad Engineering LLC',
    contactEmail: 'contact@example.com',
  };

  test('accepts a fully-populated request', () => {
    expect(() => validateCreatePublisherRequest(valid)).not.toThrow();
  });

  test.each(['namespace', 'publisherType', 'displayName', 'legalName', 'contactEmail'] as const)(
    'rejects a request missing %s',
    (field) => {
      const input = { ...valid, [field]: '' };
      expect(() => validateCreatePublisherRequest(input)).toThrow(/Missing required field/);
    },
  );

  test('rejects an unrecognized publisherType', () => {
    const input = { ...valid, publisherType: 'not_a_real_type' as never };
    expect(() => validateCreatePublisherRequest(input)).toThrow(/not a recognized publisher type/);
  });

  test('rejects a malformed contactEmail', () => {
    const input = { ...valid, contactEmail: 'not-an-email' };
    expect(() => validateCreatePublisherRequest(input)).toThrow(/not a valid email address/);
  });
});

describe('validateUpdatePublisherRequest', () => {
  test('accepts an empty patch', () => {
    expect(() => validateUpdatePublisherRequest({})).not.toThrow();
  });

  test('rejects a blank displayName', () => {
    expect(() => validateUpdatePublisherRequest({ displayName: '   ' })).toThrow(/cannot be blank/);
  });

  test('rejects a malformed contactEmail', () => {
    expect(() => validateUpdatePublisherRequest({ contactEmail: 'bad' })).toThrow(
      /not a valid email address/,
    );
  });

  test('allows clearing contactEmail to an empty string', () => {
    expect(() => validateUpdatePublisherRequest({ contactEmail: '' })).not.toThrow();
  });
});

describe('validateStatusTransition', () => {
  test('allows active -> suspended', () => {
    expect(() => validateStatusTransition('active', 'suspended')).not.toThrow();
  });

  test('allows suspended -> active', () => {
    expect(() => validateStatusTransition('suspended', 'active')).not.toThrow();
  });

  test('allows an idempotent same-status transition', () => {
    expect(() => validateStatusTransition('active', 'active')).not.toThrow();
  });

  test('rejects an unrecognized status', () => {
    expect(() => validateStatusTransition('active', 'archived')).toThrow(
      /not a recognized Publisher status/,
    );
  });
});
