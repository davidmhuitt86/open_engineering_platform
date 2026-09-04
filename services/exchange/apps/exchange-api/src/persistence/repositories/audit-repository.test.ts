import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { isTestDatabaseAvailable, setupTestDatabase, truncateAllTables } from '../test-support.js';
import { PostgresAuditRepository } from './audit-repository.js';
import { PostgresPublisherRepository } from './publisher-repository.js';
import type { Publisher } from '../types.js';

const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('PostgresAuditRepository (integration)', () => {
  let pool: Pool;
  let audit: PostgresAuditRepository;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    audit = new PostgresAuditRepository(pool);
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    const publishers = new PostgresPublisherRepository(pool);
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

  test('records an audit event for an entity', async () => {
    const recorded = await audit.record({
      entityType: 'publisher',
      entityId: publisher.id,
      action: 'PublisherCreated',
      actor: 'system',
      metadata: { namespace: publisher.namespace },
    });

    expect(recorded.entityType).toBe('publisher');
    expect(recorded.entityId).toBe(publisher.id);
    expect(recorded.action).toBe('PublisherCreated');
    expect(recorded.metadata).toEqual({ namespace: publisher.namespace });
    expect(recorded.occurredAt).toBeInstanceOf(Date);
  });

  test('listByEntity returns only events for that entity, in order', async () => {
    const otherPublisher = await new PostgresPublisherRepository(pool).create({
      name: 'Other',
      displayName: 'Other',
      namespace: `com.other.${randomUUID()}`,
      publisherType: 'company',
    });

    await audit.record({
      entityType: 'publisher',
      entityId: publisher.id,
      action: 'PublisherCreated',
    });
    await audit.record({
      entityType: 'publisher',
      entityId: publisher.id,
      action: 'PublisherVerified',
    });
    await audit.record({
      entityType: 'publisher',
      entityId: otherPublisher.id,
      action: 'PublisherCreated',
    });

    const events = await audit.listByEntity('publisher', publisher.id);
    expect(events.map((e) => e.action)).toEqual(['PublisherCreated', 'PublisherVerified']);
  });

  test('defaults actor to null and metadata to an empty object', async () => {
    const recorded = await audit.record({
      entityType: 'publisher',
      entityId: publisher.id,
      action: 'PublisherUpdated',
    });

    expect(recorded.actor).toBeNull();
    expect(recorded.metadata).toEqual({});
  });
});
