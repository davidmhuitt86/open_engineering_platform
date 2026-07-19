import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresPackageRepository } from './package-repository.js';
import { PostgresPackageVersionRepository } from './package-version-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import type { Package } from '../types.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresPackageVersionRepository (integration)', () => {
  let pool: Pool;
  let versions: PostgresPackageVersionRepository;
  let packages: PostgresPackageRepository;
  let publishers: PostgresPublisherRepository;
  let pkg: Package;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    versions = new PostgresPackageVersionRepository(pool);
    packages = new PostgresPackageRepository(pool);
    publishers = new PostgresPublisherRepository(pool);
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    const publisher = await publishers.create({
      name: 'Divad Engineering',
      displayName: 'Divad',
      namespace: `com.test.${randomUUID()}`,
      publisherType: 'individual',
    });
    pkg = await packages.create({
      packageId: `com.divad.honda.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Honda GL1200 Electrical',
    });
  });

  afterAll(async () => {
    await pool.end();
  });

  test('creates a version with a full manifest and defaults to pending status', async () => {
    const created = await versions.create({
      packageId: pkg.id,
      version: '1.0.0',
      manifest: { schemaVersion: '1.0', packageId: pkg.packageId, version: '1.0.0' },
      dependencies: [{ packageId: 'com.other.dep', versionConstraint: '^1.0.0', required: true }],
      repositoryStats: { objects: 10, relationships: 5 },
    });

    expect(created.status).toBe('pending');
    expect(created.publishedAt).toBeNull();
    expect(created.dependencies).toEqual([
      { packageId: 'com.other.dep', versionConstraint: '^1.0.0', required: true },
    ]);
    expect(created.repositoryStats).toEqual({ objects: 10, relationships: 5 });

    const found = await versions.findByPackageAndVersion(pkg.id, '1.0.0');
    expect(found?.id).toBe(created.id);
  });

  test('publish sets status to published and stamps publishedAt', async () => {
    const created = await versions.create({
      packageId: pkg.id,
      version: '1.0.0',
      manifest: { schemaVersion: '1.0' },
    });

    const published = await versions.publish(created.id);
    expect(published.status).toBe('published');
    expect(published.publishedAt).not.toBeNull();
  });

  test('rejects a duplicate version for the same package with a ConflictError', async () => {
    await versions.create({ packageId: pkg.id, version: '1.0.0', manifest: {} });
    await expect(
      versions.create({ packageId: pkg.id, version: '1.0.0', manifest: {} }),
    ).rejects.toThrow(/already exists/);
  });

  test('listByPackage returns every version for that package in creation order', async () => {
    await versions.create({ packageId: pkg.id, version: '1.0.0', manifest: {} });
    await versions.create({ packageId: pkg.id, version: '1.1.0', manifest: {} });

    const all = await versions.listByPackage(pkg.id);
    expect(all.map((v) => v.version)).toEqual(['1.0.0', '1.1.0']);
  });

  test('getByIdOrThrow throws NotFoundError for an unknown id', async () => {
    await expect(versions.getByIdOrThrow(randomUUID())).rejects.toThrow(/was not found/);
  });
});
