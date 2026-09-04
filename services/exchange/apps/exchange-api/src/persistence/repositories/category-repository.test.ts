import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, afterEach, beforeAll, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase } from '../test-support.js';
import { PostgresCategoryRepository } from './category-repository.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresCategoryRepository (integration)', () => {
  let pool: Pool;
  let repository: PostgresCategoryRepository;
  const createdSlugs: string[] = [];

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    repository = new PostgresCategoryRepository(pool);
  });

  afterEach(async () => {
    // `package_categories` holds V2's seed reference data (shared across
    // every test file), so tests clean up only the rows they created —
    // never a blanket truncate of this table.
    if (createdSlugs.length > 0) {
      await pool.query('DELETE FROM package_categories WHERE slug = ANY($1)', [createdSlugs]);
      createdSlugs.length = 0;
    }
  });

  afterAll(async () => {
    await pool.end();
  });

  test('V2 seed categories are present', async () => {
    const all = await repository.list();
    const slugs = all.map((category) => category.slug);
    expect(slugs).toEqual(
      expect.arrayContaining([
        'automotive',
        'industrial',
        'residential',
        'commercial',
        'marine',
        'powersports',
        'robotics',
        'education',
      ]),
    );
  });

  test('creates and finds a category by slug', async () => {
    const slug = `test-category-${randomUUID()}`;
    createdSlugs.push(slug);

    const created = await repository.create({ slug, name: 'Test Category' });
    const found = await repository.findBySlug(slug);
    expect(found).toEqual(created);
  });

  test('supports a hierarchical parent category', async () => {
    const parentSlug = `test-parent-${randomUUID()}`;
    const childSlug = `test-child-${randomUUID()}`;
    createdSlugs.push(parentSlug, childSlug);

    const parent = await repository.create({ slug: parentSlug, name: 'Parent' });
    const child = await repository.create({ slug: childSlug, name: 'Child', parentId: parent.id });

    expect(child.parentId).toBe(parent.id);
  });

  test('rejects a duplicate slug with a ConflictError', async () => {
    const slug = `test-dup-${randomUUID()}`;
    createdSlugs.push(slug);

    await repository.create({ slug, name: 'First' });
    await expect(repository.create({ slug, name: 'Second' })).rejects.toThrow(/already exists/);
  });

  test('getByIdOrThrow throws NotFoundError for an unknown id', async () => {
    await expect(repository.getByIdOrThrow(randomUUID())).rejects.toThrow(/was not found/);
  });
});
