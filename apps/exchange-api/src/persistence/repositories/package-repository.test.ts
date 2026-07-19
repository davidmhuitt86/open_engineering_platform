import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresCategoryRepository } from './category-repository.js';
import { PostgresPackageRepository } from './package-repository.js';
import { PostgresPackageVersionRepository } from './package-version-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import type { Publisher } from '../types.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresPackageRepository (integration)', () => {
  let pool: Pool;
  let packages: PostgresPackageRepository;
  let publishers: PostgresPublisherRepository;
  let categories: PostgresCategoryRepository;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    packages = new PostgresPackageRepository(pool);
    publishers = new PostgresPublisherRepository(pool);
    categories = new PostgresCategoryRepository(pool);
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    publisher = await publishers.create({
      name: 'Divad Engineering',
      displayName: 'Divad',
      namespace: `com.test.${randomUUID()}`,
      publisherType: 'individual',
    });
  });

  afterAll(async () => {
    await pool.end();
  });

  test('creates a package owned by a publisher', async () => {
    const category = (await categories.list()).find((c) => c.slug === 'automotive')!;

    const created = await packages.create({
      packageId: `com.divad.honda.gl1200.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Honda GL1200 Electrical',
      categoryId: category.id,
      engineeringDomains: ['Automotive', 'Electrical'],
    });

    expect(created.publisherId).toBe(publisher.id);
    expect(created.categoryId).toBe(category.id);
    expect(created.status).toBe('draft');
    expect(created.latestVersionId).toBeNull();

    const found = await packages.findByPackageId(created.packageId);
    expect(found?.id).toBe(created.id);
  });

  test('rejects a duplicate package id with a ConflictError', async () => {
    const packageId = `com.divad.dup.${randomUUID()}`;
    await packages.create({ packageId, publisherId: publisher.id, title: 'First' });

    await expect(
      packages.create({ packageId, publisherId: publisher.id, title: 'Second' }),
    ).rejects.toThrow(/already in use/);
  });

  test("listByPublisher returns only that publisher's packages", async () => {
    const otherPublisher = await publishers.create({
      name: 'Other',
      displayName: 'Other',
      namespace: `com.other.${randomUUID()}`,
      publisherType: 'company',
    });

    await packages.create({
      packageId: `com.divad.a.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'A',
    });
    await packages.create({
      packageId: `com.other.b.${randomUUID()}`,
      publisherId: otherPublisher.id,
      title: 'B',
    });

    const found = await packages.listByPublisher(publisher.id);
    expect(found).toHaveLength(1);
    expect(found[0]!.title).toBe('A');
  });

  test('getByIdOrThrow throws NotFoundError for an unknown id', async () => {
    await expect(packages.getByIdOrThrow(randomUUID())).rejects.toThrow(/was not found/);
  });

  test('setLatestVersion points the package at a published version', async () => {
    const versions = new PostgresPackageVersionRepository(pool);
    const created = await packages.create({
      packageId: `com.divad.setversion.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Versioned Package',
    });
    const version = await versions.create({
      packageId: created.id,
      version: '1.0.0',
      manifest: {},
    });

    await packages.setLatestVersion(created.id, version.id);

    const updated = await packages.getByIdOrThrow(created.id);
    expect(updated.latestVersionId).toBe(version.id);
  });

  test('rejects a duplicate title within the same publisher with a ConflictError', async () => {
    await packages.create({
      packageId: `com.divad.dupname.a.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Duplicate Title',
    });

    await expect(
      packages.create({
        packageId: `com.divad.dupname.b.${randomUUID()}`,
        publisherId: publisher.id,
        title: 'Duplicate Title',
      }),
    ).rejects.toThrow(/already has a package named/);
  });

  test('allows the same title across two different publishers', async () => {
    const otherPublisher = await publishers.create({
      name: 'Other',
      displayName: 'Other',
      namespace: `com.other.${randomUUID()}`,
      publisherType: 'company',
    });

    await packages.create({
      packageId: `com.divad.shared.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Shared Title',
    });

    await expect(
      packages.create({
        packageId: `com.other.shared.${randomUUID()}`,
        publisherId: otherPublisher.id,
        title: 'Shared Title',
      }),
    ).resolves.toBeTruthy();
  });

  test('list returns every active package regardless of publisher', async () => {
    const otherPublisher = await publishers.create({
      name: 'Other',
      displayName: 'Other',
      namespace: `com.other.${randomUUID()}`,
      publisherType: 'company',
    });
    await packages.create({
      packageId: `com.divad.list-a.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'A',
    });
    await packages.create({
      packageId: `com.other.list-b.${randomUUID()}`,
      publisherId: otherPublisher.id,
      title: 'B',
    });

    const all = await packages.list();
    expect(all).toHaveLength(2);
  });

  test('updates title/description/categoryId/status and increments rowVersion', async () => {
    const category = (await categories.list()).find((c) => c.slug === 'industrial')!;
    const created = await packages.create({
      packageId: `com.divad.update.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Before',
    });

    const updated = await packages.update(created.id, {
      title: 'After',
      description: 'New description.',
      categoryId: category.id,
      status: 'published',
    });

    expect(updated.title).toBe('After');
    expect(updated.description).toBe('New description.');
    expect(updated.categoryId).toBe(category.id);
    expect(updated.status).toBe('published');
    expect(updated.rowVersion).toBe(created.rowVersion + 1);
  });

  test('update can clear categoryId back to null', async () => {
    const category = (await categories.list()).find((c) => c.slug === 'marine')!;
    const created = await packages.create({
      packageId: `com.divad.clearcat.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Has Category',
      categoryId: category.id,
    });

    const updated = await packages.update(created.id, { categoryId: null });
    expect(updated.categoryId).toBeNull();
  });

  test('update throws NotFoundError for an unknown id', async () => {
    await expect(packages.update(randomUUID(), { title: 'X' })).rejects.toThrow(/was not found/);
  });

  test('softDelete removes the package from subsequent lookups', async () => {
    const created = await packages.create({
      packageId: `com.divad.delete.${randomUUID()}`,
      publisherId: publisher.id,
      title: 'Deletable',
    });

    await packages.softDelete(created.id);

    await expect(packages.findById(created.id)).resolves.toBeNull();
  });

  test('softDelete throws NotFoundError for an unknown id', async () => {
    await expect(packages.softDelete(randomUUID())).rejects.toThrow(/was not found/);
  });
});
