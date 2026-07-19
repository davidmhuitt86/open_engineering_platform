import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresPackageFileRepository } from './package-file-repository.js';
import { PostgresPackageRepository } from './package-repository.js';
import { PostgresPackageVersionRepository } from './package-version-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import type { PackageVersion } from '../types.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresPackageFileRepository (integration)', () => {
  let pool: Pool;
  let files: PostgresPackageFileRepository;
  let version: PackageVersion;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    files = new PostgresPackageFileRepository(pool);
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
    version = await versions.create({ packageId: pkg.id, version: '1.0.0', manifest: {} });
  });

  afterAll(async () => {
    await pool.end();
  });

  test('records a package file with required integrity hashes', async () => {
    const created = await files.create({
      packageVersionId: version.id,
      fileName: 'honda-gl1200-electrical-1.0.0.oep',
      sizeBytes: 4096,
      storagePath: '/vault/ab/cd/abcd1234.oep',
      sha256: 'a'.repeat(64),
      blake3: 'b'.repeat(64),
      signatureAlgorithm: 'Ed25519',
    });

    expect(created.mimeType).toBe('application/vnd.oep.package');
    expect(created.sizeBytes).toBe(4096);

    const found = await files.getByIdOrThrow(created.id);
    expect(found.sha256).toBe('a'.repeat(64));
  });

  test('listByVersion returns every file for a version', async () => {
    await files.create({
      packageVersionId: version.id,
      fileName: 'a.oep',
      sizeBytes: 1,
      storagePath: '/vault/a',
      sha256: 'a'.repeat(64),
    });
    await files.create({
      packageVersionId: version.id,
      fileName: 'b.oep',
      sizeBytes: 2,
      storagePath: '/vault/b',
      sha256: 'b'.repeat(64),
    });

    const all = await files.listByVersion(version.id);
    expect(all).toHaveLength(2);
  });

  test('getByIdOrThrow throws NotFoundError for an unknown id', async () => {
    await expect(files.getByIdOrThrow(randomUUID())).rejects.toThrow(/was not found/);
  });
});
