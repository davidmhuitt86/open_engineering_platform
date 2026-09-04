import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresDownloadRepository } from './download-repository.js';
import { PostgresPackageRepository } from './package-repository.js';
import { PostgresPackageVersionRepository } from './package-version-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import type { PackageVersion } from '../types.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresDownloadRepository (integration)', () => {
  let pool: Pool;
  let downloads: PostgresDownloadRepository;
  let version: PackageVersion;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    downloads = new PostgresDownloadRepository(pool);
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

  test('records a download event', async () => {
    const recorded = await downloads.record({
      packageVersionId: version.id,
      clientIp: '203.0.113.1',
      userAgent: 'oep-installer/1.0',
    });

    expect(recorded.packageVersionId).toBe(version.id);
    expect(recorded.downloadedAt).toBeInstanceOf(Date);
  });

  test('countByVersion aggregates recorded downloads', async () => {
    await downloads.record({ packageVersionId: version.id });
    await downloads.record({ packageVersionId: version.id });

    await expect(downloads.countByVersion(version.id)).resolves.toBe(2);
  });

  test('listByVersion returns downloads in chronological order', async () => {
    await downloads.record({ packageVersionId: version.id, userAgent: 'first' });
    await downloads.record({ packageVersionId: version.id, userAgent: 'second' });

    const all = await downloads.listByVersion(version.id);
    expect(all.map((d) => d.userAgent)).toEqual(['first', 'second']);
  });
});
