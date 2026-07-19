import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresInstallationRepository } from './installation-repository.js';
import { PostgresPackageRepository } from './package-repository.js';
import { PostgresPackageVersionRepository } from './package-version-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import type { PackageVersion } from '../types.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresInstallationRepository (integration)', () => {
  let pool: Pool;
  let installations: PostgresInstallationRepository;
  let version: PackageVersion;
  let packageRowId: string;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    installations = new PostgresInstallationRepository(pool);
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    const publishers = new PostgresPublisherRepository(pool);
    const packages = new PostgresPackageRepository(pool);
    const versions = new PostgresPackageVersionRepository(pool);

    const publisher = await publishers.create({
      name: 'Divad Engineering',
      displayName: 'Divad',
      namespace: `com.test.${randomUUID()}`,
      publisherType: 'individual',
    });
    const pkg = await packages.create({
      packageId: `com.divad.honda.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Honda GL1200 Electrical',
    });
    packageRowId = pkg.id;
    version = await versions.create({ packageId: pkg.id, version: '1.0.0', manifest: {} });
  });

  afterAll(async () => {
    await pool.end();
  });

  test('creates a pending installation', async () => {
    const created = await installations.create({
      packageId: packageRowId,
      packageVersionId: version.id,
    });

    expect(created.status).toBe('pending');
    expect(created.packageVersionId).toBe(version.id);
    expect(created.repositoryPackageId).toBeNull();
    expect(created.errorMessage).toBeNull();
    expect(created.completedAt).toBeNull();
    expect(created.rowVersion).toBe(1);
  });

  test('complete transitions to status "completed" and increments rowVersion', async () => {
    const created = await installations.create({
      packageId: packageRowId,
      packageVersionId: version.id,
    });

    const completed = await installations.complete(created.id, 'repo-123');
    expect(completed.status).toBe('completed');
    expect(completed.repositoryPackageId).toBe('repo-123');
    expect(completed.completedAt).toBeInstanceOf(Date);
    expect(completed.rowVersion).toBe(created.rowVersion + 1);
  });

  test('fail transitions to status "failed" with an errorMessage', async () => {
    const created = await installations.create({
      packageId: packageRowId,
      packageVersionId: version.id,
    });

    const failed = await installations.fail(created.id, 'disk full');
    expect(failed.status).toBe('failed');
    expect(failed.errorMessage).toBe('disk full');
    expect(failed.completedAt).toBeInstanceOf(Date);
  });

  test('getByIdOrThrow throws NotFoundError for an unknown id', async () => {
    await expect(installations.getByIdOrThrow(randomUUID())).rejects.toThrow(/was not found/);
  });

  test('complete throws NotFoundError for an unknown id', async () => {
    await expect(installations.complete(randomUUID(), null)).rejects.toThrow(/was not found/);
  });

  test('fail throws NotFoundError for an unknown id', async () => {
    await expect(installations.fail(randomUUID(), 'x')).rejects.toThrow(/was not found/);
  });
});
