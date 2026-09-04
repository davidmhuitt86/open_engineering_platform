/**
 * Database connection configuration, sourced from the environment with
 * dev-friendly defaults matching `db/migrations/flyway.toml`. Kept
 * separate from `pool.ts` so a config object (rather than a live `Pool`)
 * can be constructed, inspected, or overridden independently — e.g. by
 * `persistence/test-support.ts`, which builds its own config from a
 * distinct set of `OEP_EXCHANGE_TEST_DB_*` environment variables.
 */
export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

const DEFAULT_DATABASE_CONFIG: DatabaseConfig = {
  host: 'localhost',
  port: 5432,
  database: 'oep_exchange',
  user: 'oep_exchange',
  password: '',
};

/** Loads connection settings for the application's own runtime database. */
export function loadDatabaseConfig(env: NodeJS.ProcessEnv = process.env): DatabaseConfig {
  return {
    host: env.OEP_EXCHANGE_DB_HOST ?? DEFAULT_DATABASE_CONFIG.host,
    port: env.OEP_EXCHANGE_DB_PORT
      ? Number(env.OEP_EXCHANGE_DB_PORT)
      : DEFAULT_DATABASE_CONFIG.port,
    database: env.OEP_EXCHANGE_DB_NAME ?? DEFAULT_DATABASE_CONFIG.database,
    user: env.OEP_EXCHANGE_DB_USER ?? DEFAULT_DATABASE_CONFIG.user,
    password: env.OEP_EXCHANGE_DB_PASSWORD ?? DEFAULT_DATABASE_CONFIG.password,
  };
}
