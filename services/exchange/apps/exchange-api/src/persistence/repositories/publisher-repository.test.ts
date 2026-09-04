import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresPublisherRepository } from './publisher-repository.js';

/**
 * Applies real migration files from disk against a real database when
 * one is reachable and skips (never fails) otherwise — see
 * `db/README.md` "Testing without a live database".
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresPublisherRepository (integration)', () => {
  let pool: Pool;
  let repository: PostgresPublisherRepository;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    repository = new PostgresPublisherRepository(pool);
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
  });

  afterAll(async () => {
    await pool.end();
  });

  test('creates a publisher and finds it by id', async () => {
    const namespace = `com.test.${randomUUID()}`;
    const created = await repository.create({
      name: 'Divad Engineering',
      displayName: 'Divad',
      namespace,
      publisherType: 'individual',
    });

    expect(created.id).toBeTruthy();
    expect(created.namespace).toBe(namespace);
    expect(created.verificationStatus).toBe('unverified');
    expect(created.trustStatus).toBe('standard');
    expect(created.status).toBe('active');

    const found = await repository.findById(created.id);
    expect(found).toEqual(created);
  });

  test('finds a publisher by namespace', async () => {
    const namespace = `org.university.${randomUUID()}`;
    const created = await repository.create({
      name: 'MIT',
      displayName: 'MIT',
      namespace,
      publisherType: 'educational_institution',
    });

    const found = await repository.findByNamespace(namespace);
    expect(found?.id).toBe(created.id);
  });

  test('rejects a duplicate namespace with a ConflictError', async () => {
    const namespace = `com.test.${randomUUID()}`;
    await repository.create({
      name: 'First',
      displayName: 'First',
      namespace,
      publisherType: 'company',
    });

    await expect(
      repository.create({
        name: 'Second',
        displayName: 'Second',
        namespace,
        publisherType: 'company',
      }),
    ).rejects.toThrow(/already owned/);
  });

  test('findById returns null for an unknown id', async () => {
    await expect(repository.findById(randomUUID())).resolves.toBeNull();
  });

  test('getByIdOrThrow throws NotFoundError for an unknown id', async () => {
    await expect(repository.getByIdOrThrow(randomUUID())).rejects.toThrow(/was not found/);
  });

  test('list returns every active publisher', async () => {
    await repository.create({
      name: 'A',
      displayName: 'A',
      namespace: `com.a.${randomUUID()}`,
      publisherType: 'individual',
    });
    await repository.create({
      name: 'B',
      displayName: 'B',
      namespace: `com.b.${randomUUID()}`,
      publisherType: 'individual',
    });

    const all = await repository.list();
    expect(all).toHaveLength(2);
  });

  test('rejects a duplicate publisher name with a ConflictError', async () => {
    await repository.create({
      name: 'Duplicate Name',
      displayName: 'First',
      namespace: `com.dup-name.a.${randomUUID()}`,
      publisherType: 'company',
    });

    await expect(
      repository.create({
        name: 'Duplicate Name',
        displayName: 'Second',
        namespace: `com.dup-name.b.${randomUUID()}`,
        publisherType: 'company',
      }),
    ).rejects.toThrow(/already in use/);
  });

  test('rejects a duplicate contact email (case-insensitive) with a ConflictError', async () => {
    await repository.create({
      name: 'Email Owner',
      displayName: 'Email Owner',
      namespace: `com.dup-email.a.${randomUUID()}`,
      publisherType: 'company',
      contactEmail: 'contact@example.com',
    });

    await expect(
      repository.create({
        name: 'Email Other',
        displayName: 'Email Other',
        namespace: `com.dup-email.b.${randomUUID()}`,
        publisherType: 'company',
        contactEmail: 'Contact@Example.com',
      }),
    ).rejects.toThrow(/already in use/);
  });

  test('allows multiple publishers with a blank contact email', async () => {
    await repository.create({
      name: 'Blank A',
      displayName: 'Blank A',
      namespace: `com.blank.a.${randomUUID()}`,
      publisherType: 'individual',
    });
    await expect(
      repository.create({
        name: 'Blank B',
        displayName: 'Blank B',
        namespace: `com.blank.b.${randomUUID()}`,
        publisherType: 'individual',
      }),
    ).resolves.toBeTruthy();
  });

  test('updates displayName/contactEmail/status and increments rowVersion', async () => {
    const created = await repository.create({
      name: 'Updatable',
      displayName: 'Before',
      namespace: `com.update.${randomUUID()}`,
      publisherType: 'individual',
    });

    const updated = await repository.update(created.id, {
      displayName: 'After',
      contactEmail: 'after@example.com',
      status: 'suspended',
    });

    expect(updated.displayName).toBe('After');
    expect(updated.contactEmail).toBe('after@example.com');
    expect(updated.status).toBe('suspended');
    expect(updated.rowVersion).toBe(created.rowVersion + 1);
  });

  test('update throws NotFoundError for an unknown id', async () => {
    await expect(repository.update(randomUUID(), { displayName: 'X' })).rejects.toThrow(
      /was not found/,
    );
  });

  test('softDelete removes the publisher from subsequent lookups', async () => {
    const created = await repository.create({
      name: 'Deletable',
      displayName: 'Deletable',
      namespace: `com.delete.${randomUUID()}`,
      publisherType: 'individual',
    });

    await repository.softDelete(created.id);

    await expect(repository.findById(created.id)).resolves.toBeNull();
  });

  test('softDelete throws NotFoundError for an unknown id', async () => {
    await expect(repository.softDelete(randomUUID())).rejects.toThrow(/was not found/);
  });
});
