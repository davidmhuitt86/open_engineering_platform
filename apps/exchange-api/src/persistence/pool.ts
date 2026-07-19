import { Pool, type PoolClient, type QueryResult, type QueryResultRow } from 'pg';
import { loadDatabaseConfig, type DatabaseConfig } from './config.js';

/**
 * The minimal shape every repository depends on — satisfied by both
 * `pg.Pool` and `pg.PoolClient`, and easily satisfied by a fake in unit
 * tests that don't need a real database. Repositories are constructed
 * against this interface, never `Pool` directly, so nothing here
 * couples a repository to connection-pool lifecycle concerns.
 */
export interface Queryable {
  query<T extends QueryResultRow = QueryResultRow>(
    text: string,
    values?: unknown[],
  ): Promise<QueryResult<T>>;
}

/** Creates a connection pool for the given config (defaults to the environment). */
export function createPool(config: DatabaseConfig = loadDatabaseConfig()): Pool {
  return new Pool({
    host: config.host,
    port: config.port,
    database: config.database,
    user: config.user,
    password: config.password,
  });
}

export type { Pool, PoolClient };
