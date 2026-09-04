import { describe, expect, test } from 'vitest';
import { loadDatabaseConfig } from './config.js';

describe('loadDatabaseConfig', () => {
  test('returns dev defaults when no environment variables are set', () => {
    expect(loadDatabaseConfig({})).toEqual({
      host: 'localhost',
      port: 5432,
      database: 'oep_exchange',
      user: 'oep_exchange',
      password: '',
    });
  });

  test('environment variables override the defaults', () => {
    const config = loadDatabaseConfig({
      OEP_EXCHANGE_DB_HOST: 'db.internal',
      OEP_EXCHANGE_DB_PORT: '5433',
      OEP_EXCHANGE_DB_NAME: 'custom_db',
      OEP_EXCHANGE_DB_USER: 'custom_user',
      OEP_EXCHANGE_DB_PASSWORD: 'secret',
    });

    expect(config).toEqual({
      host: 'db.internal',
      port: 5433,
      database: 'custom_db',
      user: 'custom_user',
      password: 'secret',
    });
  });
});
