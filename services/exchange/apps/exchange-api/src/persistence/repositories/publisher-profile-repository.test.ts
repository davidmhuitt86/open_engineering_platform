import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresPublisherProfileRepository } from './publisher-profile-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import type { Publisher } from '../types.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresPublisherProfileRepository (integration)', () => {
  let pool: Pool;
  let profiles: PostgresPublisherProfileRepository;
  let publishers: PostgresPublisherRepository;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    profiles = new PostgresPublisherProfileRepository(pool);
    publishers = new PostgresPublisherRepository(pool);
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

  test('creates a profile for a publisher', async () => {
    const profile = await profiles.upsertForPublisher(publisher.id, {
      publisherId: publisher.id,
      organizationName: 'Divad Engineering LLC',
      website: 'https://divad.example.com',
      engineeringDisciplines: ['Automotive', 'Electrical'],
      country: 'US',
    });

    expect(profile.publisherId).toBe(publisher.id);
    expect(profile.organizationName).toBe('Divad Engineering LLC');
    expect(profile.engineeringDisciplines).toEqual(['Automotive', 'Electrical']);
  });

  test('upserting again updates the existing profile rather than creating a second one', async () => {
    await profiles.upsertForPublisher(publisher.id, { publisherId: publisher.id, country: 'US' });
    const updated = await profiles.upsertForPublisher(publisher.id, {
      publisherId: publisher.id,
      country: 'CA',
    });

    expect(updated.country).toBe('CA');
    const found = await profiles.findByPublisherId(publisher.id);
    expect(found?.country).toBe('CA');
  });

  test('findByPublisherId returns null when no profile exists', async () => {
    await expect(profiles.findByPublisherId(publisher.id)).resolves.toBeNull();
  });

  test('upsertForPublisher throws NotFoundError for an unknown publisher', async () => {
    await expect(
      profiles.upsertForPublisher(randomUUID(), { publisherId: randomUUID() }),
    ).rejects.toThrow(/was not found/);
  });
});
