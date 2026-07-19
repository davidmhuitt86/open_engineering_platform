import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from './test-support.js';
import { PostgresPackageRepository } from './repositories/package-repository.js';
import { PostgresPackageVersionRepository } from './repositories/package-version-repository.js';
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

  /**
   * `search_index` (docs/tasks/WP-EXC-006.md) — the table deferred from
   * WP-EXC-002 (`REPOSITORY_STRUCTURE.md` §11.1), so it's asserted here
   * rather than folded into the WP-EXC-002 table-list test above.
   */
  test('search_index exists with a GIN-indexed search_vector column', async () => {
    const table = await pool.query<{ table_name: string }>(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = 'search_index'`,
    );
    expect(table.rows).toHaveLength(1);

    const searchVectorColumn = await pool.query<{ data_type: string }>(
      `SELECT data_type FROM information_schema.columns
       WHERE table_name = 'search_index' AND column_name = 'search_vector'`,
    );
    expect(searchVectorColumn.rows[0]?.data_type).toBe('tsvector');

    const ginIndex = await pool.query(
      `SELECT indexname FROM pg_indexes
       WHERE tablename = 'search_index' AND indexdef ILIKE '%USING gin%'`,
    );
    expect(ginIndex.rows.length).toBeGreaterThan(0);
  });

  test('search_index has no row_version column (a derived/denormalized structure, not a primary entity)', async () => {
    const rowVersionColumn = await pool.query(
      `SELECT column_name FROM information_schema.columns
       WHERE table_name = 'search_index' AND column_name = 'row_version'`,
    );
    expect(rowVersionColumn.rows).toHaveLength(0);
  });

  test('inserting a package automatically populates its search_index row via trigger', async () => {
    await truncateAllTables(pool);
    const publishers = new PostgresPublisherRepository(pool);
    const publisher = await publishers.create({
      name: 'Trigger Test Publisher',
      displayName: 'Trigger Test',
      namespace: `com.trigger-test.${randomUUID()}`,
      publisherType: 'company',
    });

    const packageId = `com.trigger-test.widget.${randomUUID()}`;
    const inserted = await pool.query<{ id: string }>(
      `INSERT INTO packages (package_id, publisher_id, title, description)
       VALUES ($1, $2, 'Trigger Test Widget', 'A widget for trigger testing.')
       RETURNING id`,
      [packageId, publisher.id],
    );
    const pkgRowId = inserted.rows[0]!.id;

    const searchRow = await pool.query<{ search_text: string }>(
      `SELECT search_text FROM search_index WHERE package_id = $1`,
      [pkgRowId],
    );
    expect(searchRow.rows).toHaveLength(1);
    expect(searchRow.rows[0]!.search_text).toContain('Trigger Test Widget');
    expect(searchRow.rows[0]!.search_text).toContain(packageId);

    const matched = await pool.query(
      `SELECT 1 FROM search_index
       WHERE package_id = $1 AND search_vector @@ websearch_to_tsquery('english', 'widget')`,
      [pkgRowId],
    );
    expect(matched.rows).toHaveLength(1);
  });

  /**
   * `installations` (docs/tasks/WP-EXC-008.md) — created once per
   * install attempt and updated exactly once more to a terminal state,
   * so (unlike `downloads`/`audit_log`) it carries `row_version` despite
   * being a historical record.
   */
  test('installations exists with a UUID primary key and a row_version column', async () => {
    const pkColumn = await pool.query<{ data_type: string }>(
      `SELECT c.data_type
       FROM information_schema.table_constraints tc
       JOIN information_schema.key_column_usage kcu
         ON kcu.constraint_name = tc.constraint_name AND kcu.table_name = tc.table_name
       JOIN information_schema.columns c
         ON c.table_name = tc.table_name AND c.column_name = kcu.column_name
       WHERE tc.table_name = 'installations' AND tc.constraint_type = 'PRIMARY KEY'`,
    );
    expect(pkColumn.rows[0]?.data_type).toBe('uuid');

    const rowVersionColumn = await pool.query(
      `SELECT column_name FROM information_schema.columns
       WHERE table_name = 'installations' AND column_name = 'row_version'`,
    );
    expect(rowVersionColumn.rows).toHaveLength(1);
  });

  test('installations rejects a status value outside pending/completed/failed', async () => {
    await truncateAllTables(pool);
    const publishers = new PostgresPublisherRepository(pool);
    const packages = new PostgresPackageRepository(pool);
    const versions = new PostgresPackageVersionRepository(pool);

    const publisher = await publishers.create({
      name: 'Schema Test Publisher',
      displayName: 'Schema Test',
      namespace: `com.schema-test.${randomUUID()}`,
      publisherType: 'company',
    });
    const pkg = await packages.create({
      packageId: `com.schema-test.widget.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Schema Test Widget',
    });
    const version = await versions.create({ packageId: pkg.id, version: '1.0.0', manifest: {} });

    await expect(
      pool.query(
        `INSERT INTO installations (package_id, package_version_id, status)
         VALUES ($1, $2, 'not_a_real_status')`,
        [pkg.id, version.id],
      ),
    ).rejects.toThrow(/violates check constraint/);
  });
});
