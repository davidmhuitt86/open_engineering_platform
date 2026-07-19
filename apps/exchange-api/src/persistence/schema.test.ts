import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from './test-support.js';
import { PostgresPublisherRepository } from './repositories/publisher-repository.js';

/**
 * Migration/constraint/rollback tests (docs/tasks/WP-EXC-002.md §10),
 * distinct from each repository's own CRUD-behavior tests: these assert
 * the applied schema itself has the shape and guarantees
 * `V1__initial_exchange_schema.sql`/`V2__seed_categories.sql` promise,
 * mirroring `oep_acquisition`'s own "migration/schema-shape tests"
 * precedent.
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('database schema (migration/constraint/rollback)', () => {
  let pool: Pool;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
  });

  afterAll(async () => {
    await pool.end();
  });

  test('every table from WP-EXC-002.md §4 exists after migration', async () => {
    const expectedTables = [
      'publishers',
      'publisher_profiles',
      'packages',
      'package_versions',
      'package_categories',
      'package_files',
      'downloads',
      'audit_log',
    ];

    const result = await pool.query<{ table_name: string }>(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = ANY($1)`,
      [expectedTables],
    );

    expect(result.rows.map((r) => r.table_name).sort()).toEqual([...expectedTables].sort());
  });

  test('every mutable table has a UUID primary key and a row_version column', async () => {
    const mutableTables = [
      'publishers',
      'publisher_profiles',
      'packages',
      'package_versions',
      'package_categories',
      'package_files',
    ];

    for (const table of mutableTables) {
      const pkColumn = await pool.query<{ data_type: string }>(
        `SELECT c.data_type
         FROM information_schema.table_constraints tc
         JOIN information_schema.key_column_usage kcu
           ON kcu.constraint_name = tc.constraint_name AND kcu.table_name = tc.table_name
         JOIN information_schema.columns c
           ON c.table_name = tc.table_name AND c.column_name = kcu.column_name
         WHERE tc.table_name = $1 AND tc.constraint_type = 'PRIMARY KEY'`,
        [table],
      );
      expect(pkColumn.rows[0]?.data_type, `${table}.id should be uuid`).toBe('uuid');

      const rowVersionColumn = await pool.query<{ column_default: string | null }>(
        `SELECT column_default FROM information_schema.columns
         WHERE table_name = $1 AND column_name = 'row_version'`,
        [table],
      );
      expect(rowVersionColumn.rows).toHaveLength(1);
    }
  });

  test('append-only tables (downloads, audit_log) have no row_version column', async () => {
    for (const table of ['downloads', 'audit_log']) {
      const rowVersionColumn = await pool.query(
        `SELECT column_name FROM information_schema.columns
         WHERE table_name = $1 AND column_name = 'row_version'`,
        [table],
      );
      expect(rowVersionColumn.rows).toHaveLength(0);
    }
  });

  test('a rejected duplicate namespace leaves no partial row (rollback behavior)', async () => {
    await truncateAllTables(pool);
    const publishers = new PostgresPublisherRepository(pool);
    const namespace = `com.rollback-test.${randomUUID()}`;

    await publishers.create({
      name: 'First',
      displayName: 'First',
      namespace,
      publisherType: 'company',
    });

    await expect(
      publishers.create({
        name: 'Second',
        displayName: 'Second',
        namespace,
        publisherType: 'company',
      }),
    ).rejects.toThrow(/already owned/);

    const countResult = await pool.query<{ count: string }>(
      'SELECT COUNT(*) AS count FROM publishers WHERE namespace = $1',
      [namespace],
    );
    expect(Number(countResult.rows[0]!.count)).toBe(1);
  });

  test('a database-level CHECK constraint rejects an invalid enum value', async () => {
    await expect(
      pool.query(
        `INSERT INTO publishers (name, display_name, namespace, publisher_type)
         VALUES ('Invalid', 'Invalid', $1, 'not_a_real_type')`,
        [`com.invalid-test.${randomUUID()}`],
      ),
    ).rejects.toThrow(/violates check constraint/);
  });
});
