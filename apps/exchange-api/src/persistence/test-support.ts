import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Pool } from 'pg';
import type { DatabaseConfig } from './config.js';

/**
 * Shared test-database bootstrap, mirroring `oep_acquisition`'s own
 * established testing precedent (see its README's "Repository/API/
 * migration categories" section): repository/integration tests apply
 * the real, committed migration files from disk against a real database
 * when one is reachable, `TRUNCATE ... CASCADE` between test runs, and
 * skip (never fail) when no database is reachable. Connection settings
 * are overridable via `OEP_EXCHANGE_TEST_DB_*` environment variables,
 * which take precedence over the defaults below.
 */

const __dirname = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = join(__dirname, '../../../../db/migrations');

const DEFAULT_TEST_CONFIG: DatabaseConfig = {
  host: 'localhost',
  port: 5432,
  database: 'oep_exchange',
  user: 'oep_exchange',
  password: '',
};

export function loadTestDatabaseConfig(env: NodeJS.ProcessEnv = process.env): DatabaseConfig {
  return {
    host: env.OEP_EXCHANGE_TEST_DB_HOST ?? DEFAULT_TEST_CONFIG.host,
    port: env.OEP_EXCHANGE_TEST_DB_PORT
      ? Number(env.OEP_EXCHANGE_TEST_DB_PORT)
      : DEFAULT_TEST_CONFIG.port,
    database: env.OEP_EXCHANGE_TEST_DB_NAME ?? DEFAULT_TEST_CONFIG.database,
    user: env.OEP_EXCHANGE_TEST_DB_USER ?? DEFAULT_TEST_CONFIG.user,
    password: env.OEP_EXCHANGE_TEST_DB_PASSWORD ?? DEFAULT_TEST_CONFIG.password,
  };
}

let sharedPool: Pool | null | undefined;
let migrationsApplied = false;

async function connectIfReachable(): Promise<Pool | null> {
  const config = loadTestDatabaseConfig();
  const pool = new Pool({ ...config, connectionTimeoutMillis: 2000 });
  try {
    await pool.query('SELECT 1');
    return pool;
  } catch {
    await pool.end();
    return null;
  }
}

/** Returns a connected pool, or `null` if no test database is reachable. Memoized per test file. */
export async function getTestPool(): Promise<Pool | null> {
  if (sharedPool === undefined) {
    sharedPool = await connectIfReachable();
  }
  return sharedPool;
}

/** Whether a real test database is reachable — use with `describe.skipIf(!(await isTestDatabaseAvailable()))`. */
export async function isTestDatabaseAvailable(): Promise<boolean> {
  return (await getTestPool()) !== null;
}

async function applyMigrationsIfNeeded(pool: Pool): Promise<void> {
  if (migrationsApplied) {
    return;
  }

  const existing = await pool.query<{ to_regclass: string | null }>(
    `SELECT to_regclass('public.publishers') AS to_regclass`,
  );
  if (existing.rows[0]?.to_regclass === null) {
    const migrationFiles = readdirSync(MIGRATIONS_DIR)
      .filter((file) => file.endsWith('.sql'))
      .sort();
    for (const file of migrationFiles) {
      const sql = readFileSync(join(MIGRATIONS_DIR, file), 'utf-8');
      await pool.query(sql);
    }
  }
  migrationsApplied = true;
}

/** Connects (if reachable), applies migrations on first use, and returns the pool — or `null`. */
export async function setupTestDatabase(): Promise<Pool | null> {
  const pool = await getTestPool();
  if (!pool) {
    return null;
  }
  await applyMigrationsIfNeeded(pool);
  return pool;
}

/**
 * Clears every table seeded/written by tests between test runs.
 * `package_categories` is deliberately excluded — it holds
 * `V2__seed_categories.sql`'s reference data, not per-test fixtures.
 * Every other mutable table cascades from `publishers` alone; `audit_log`
 * is truncated explicitly since its `entity_id` is a polymorphic
 * reference (see `V1__initial_exchange_schema.sql`), not a foreign key
 * that `publishers`'s cascade would reach.
 */
export async function truncateAllTables(pool: Pool): Promise<void> {
  await pool.query('TRUNCATE TABLE publishers, audit_log CASCADE');
}
