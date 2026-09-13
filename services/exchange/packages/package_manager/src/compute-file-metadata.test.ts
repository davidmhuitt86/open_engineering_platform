import { createHash } from 'node:crypto';
import { describe, expect, test } from 'vitest';
import { computeFileMetadata } from './compute-file-metadata.js';

describe('computeFileMetadata', () => {
  test('reports the buffer length as sizeBytes', () => {
    const buffer = Buffer.from('hello world', 'utf8');
    expect(computeFileMetadata(buffer).sizeBytes).toBe(buffer.length);
  });

  test('computes a matching sha256 hex digest', () => {
    const buffer = Buffer.from('hello world', 'utf8');
    const expected = createHash('sha256').update(buffer).digest('hex');
    expect(computeFileMetadata(buffer).sha256).toBe(expected);
  });

  test('is deterministic for identical input', () => {
    const buffer = Buffer.from('deterministic', 'utf8');
    expect(computeFileMetadata(buffer)).toEqual(computeFileMetadata(Buffer.from(buffer)));
  });
});
