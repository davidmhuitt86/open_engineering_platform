import { describe, expect, test } from 'vitest';
import { loadStorageDir } from './storage-config.js';

describe('loadStorageDir', () => {
  test('returns the default when no environment variable is set', () => {
    expect(loadStorageDir({})).toBe('./storage/packages');
  });

  test('returns the environment variable when set', () => {
    expect(loadStorageDir({ OEP_EXCHANGE_STORAGE_DIR: '/var/oep/packages' })).toBe(
      '/var/oep/packages',
    );
  });
});
