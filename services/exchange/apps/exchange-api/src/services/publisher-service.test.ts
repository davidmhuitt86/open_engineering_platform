import { randomUUID } from 'node:crypto';
import { ConflictError, NotFoundError } from '@oep-exchange/core';
import { beforeEach, describe, expect, test } from 'vitest';
import type {
  AuditLogEntry,
  AuditRepository,
  NewAuditLogEntry,
  NewPublisher,
  NewPublisherProfile,
  Publisher,
  PublisherProfile,
  PublisherProfileRepository,
  PublisherRepository,
  PublisherUpdate,
} from '../persistence/index.js';
import { PublisherService } from './publisher-service.js';

/** In-memory fakes (no database), mirroring `oep_acquisition`'s own "Service-layer tests against an in-memory fake repository" precedent. */
class FakePublisherRepository implements PublisherRepository {
  private readonly rows = new Map<string, Publisher>();

  async create(input: NewPublisher): Promise<Publisher> {
    if (await this.findByNamespace(input.namespace)) {
      throw new ConflictError(`Namespace "${input.namespace}" is already owned by a Publisher.`);
    }
    if (await this.findByName(input.name)) {
      throw new ConflictError(`Publisher name "${input.name}" is already in use.`);
    }
    if (input.contactEmail && (await this.findByContactEmail(input.contactEmail))) {
      throw new ConflictError(`Contact email "${input.contactEmail}" is already in use.`);
    }

    const now = new Date();
    const publisher: Publisher = {
      id: randomUUID(),
      name: input.name,
      displayName: input.displayName,
      namespace: input.namespace,
      publisherType: input.publisherType,
      verificationStatus: input.verificationStatus ?? 'unverified',
      trustStatus: input.trustStatus ?? 'standard',
      status: 'active',
      contactEmail: input.contactEmail ?? '',
      rowVersion: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(publisher.id, publisher);
    return publisher;
  }

  async findById(id: string): Promise<Publisher | null> {
    return this.rows.get(id) ?? null;
  }

  async findByNamespace(namespace: string): Promise<Publisher | null> {
    return [...this.rows.values()].find((p) => p.namespace === namespace) ?? null;
  }

  async findByName(name: string): Promise<Publisher | null> {
    return [...this.rows.values()].find((p) => p.name === name) ?? null;
  }

  async findByContactEmail(contactEmail: string): Promise<Publisher | null> {
    return (
      [...this.rows.values()].find(
        (p) => p.contactEmail.toLowerCase() === contactEmail.toLowerCase() && p.contactEmail !== '',
      ) ?? null
    );
  }

  async list(): Promise<Publisher[]> {
    return [...this.rows.values()];
  }

  async getByIdOrThrow(id: string): Promise<Publisher> {
    const publisher = await this.findById(id);
    if (!publisher) throw new NotFoundError('Publisher', id);
    return publisher;
  }

  async update(id: string, changes: PublisherUpdate): Promise<Publisher> {
    const existing = await this.getByIdOrThrow(id);
    if (changes.contactEmail) {
      const owner = await this.findByContactEmail(changes.contactEmail);
      if (owner && owner.id !== id) {
        throw new ConflictError(`Contact email "${changes.contactEmail}" is already in use.`);
      }
    }
    const updated: Publisher = {
      ...existing,
      displayName: changes.displayName ?? existing.displayName,
      contactEmail: changes.contactEmail ?? existing.contactEmail,
      status: changes.status ?? existing.status,
      rowVersion: existing.rowVersion + 1,
      updatedAt: new Date(),
    };
    this.rows.set(id, updated);
    return updated;
  }

  async softDelete(id: string): Promise<void> {
    await this.getByIdOrThrow(id);
    this.rows.delete(id);
  }
}

class FakePublisherProfileRepository implements PublisherProfileRepository {
  private readonly rows = new Map<string, PublisherProfile>();

  async upsertForPublisher(
    publisherId: string,
    input: NewPublisherProfile,
  ): Promise<PublisherProfile> {
    const existing = this.rows.get(publisherId);
    const now = new Date();
    const profile: PublisherProfile = {
      id: existing?.id ?? randomUUID(),
      publisherId,
      organizationName: input.organizationName ?? existing?.organizationName ?? '',
      description: input.description ?? existing?.description ?? '',
      website: input.website ?? existing?.website ?? '',
      supportContact: input.supportContact ?? existing?.supportContact ?? '',
      documentationUrl: input.documentationUrl ?? existing?.documentationUrl ?? '',
      logoUrl: input.logoUrl ?? existing?.logoUrl ?? '',
      bannerUrl: input.bannerUrl ?? existing?.bannerUrl ?? '',
      engineeringDisciplines:
        input.engineeringDisciplines ?? existing?.engineeringDisciplines ?? [],
      country: input.country ?? existing?.country ?? '',
      languages: input.languages ?? existing?.languages ?? [],
      socialLinks: input.socialLinks ?? existing?.socialLinks ?? {},
      verifiedBadges: input.verifiedBadges ?? existing?.verifiedBadges ?? [],
      rowVersion: (existing?.rowVersion ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };
    this.rows.set(publisherId, profile);
    return profile;
  }

  async findByPublisherId(publisherId: string): Promise<PublisherProfile | null> {
    return this.rows.get(publisherId) ?? null;
  }

  async getByPublisherIdOrThrow(publisherId: string): Promise<PublisherProfile> {
    const profile = await this.findByPublisherId(publisherId);
    if (!profile) throw new NotFoundError('PublisherProfile', publisherId);
    return profile;
  }
}

class FakeAuditRepository implements AuditRepository {
  readonly entries: AuditLogEntry[] = [];

  async record(input: NewAuditLogEntry): Promise<AuditLogEntry> {
    const entry: AuditLogEntry = {
      id: randomUUID(),
      entityType: input.entityType,
      entityId: input.entityId,
      action: input.action,
      actor: input.actor ?? null,
      metadata: input.metadata ?? {},
      occurredAt: new Date(),
    };
    this.entries.push(entry);
    return entry;
  }

  async listByEntity(entityType: string, entityId: string): Promise<AuditLogEntry[]> {
    return this.entries.filter((e) => e.entityType === entityType && e.entityId === entityId);
  }
}

describe('PublisherService', () => {
  let publishers: FakePublisherRepository;
  let profiles: FakePublisherProfileRepository;
  let audit: FakeAuditRepository;
  let service: PublisherService;

  const validCreateInput = {
    namespace: 'com.test.divad',
    publisherType: 'individual' as const,
    displayName: 'Divad',
    legalName: 'Divad Engineering LLC',
    contactEmail: 'contact@example.com',
  };

  beforeEach(() => {
    publishers = new FakePublisherRepository();
    profiles = new FakePublisherProfileRepository();
    audit = new FakeAuditRepository();
    service = new PublisherService(publishers, profiles, audit);
  });

  test('create returns a fully-shaped PublisherDto and records a PublisherCreated audit event', async () => {
    const dto = await service.create(validCreateInput);

    expect(dto.id).toBeTruthy();
    expect(dto.namespace).toBe('com.test.divad');
    expect(dto.legalName).toBe('Divad Engineering LLC');
    expect(dto.displayName).toBe('Divad');
    expect(dto.contactEmail).toBe('contact@example.com');
    expect(dto.status).toBe('active');
    expect(dto.description).toBe('');
    expect(dto.website).toBe('');

    expect(audit.entries).toHaveLength(1);
    expect(audit.entries[0]!.action).toBe('PublisherCreated');
  });

  test('create upserts a profile when description/website are provided', async () => {
    const dto = await service.create({
      ...validCreateInput,
      description: 'Engineering knowledge for Honda motorcycles.',
      website: 'https://divad.example.com',
    });

    expect(dto.description).toBe('Engineering knowledge for Honda motorcycles.');
    expect(dto.website).toBe('https://divad.example.com');
  });

  test('create rejects an invalid request before touching the repository', async () => {
    await expect(service.create({ ...validCreateInput, contactEmail: '' })).rejects.toThrow(
      /Missing required field/,
    );
    expect(await publishers.list()).toHaveLength(0);
  });

  test('create propagates a ConflictError for a duplicate namespace', async () => {
    await service.create(validCreateInput);
    await expect(
      service.create({ ...validCreateInput, contactEmail: 'other@example.com' }),
    ).rejects.toThrow(/already owned/);
  });

  test('getById rejects a malformed identifier without querying the repository', async () => {
    await expect(service.getById('not-a-uuid')).rejects.toThrow(/not a valid Publisher identifier/);
  });

  test('getById throws NotFoundError for an unknown id', async () => {
    await expect(service.getById(randomUUID())).rejects.toThrow(/was not found/);
  });

  test('list returns every publisher as a PublisherDto', async () => {
    await service.create(validCreateInput);
    await service.create({
      ...validCreateInput,
      namespace: 'com.test.other',
      legalName: 'Other Publisher LLC',
      contactEmail: 'x@example.com',
    });

    const all = await service.list();
    expect(all).toHaveLength(2);
  });

  test('update changes displayName/contactEmail and records PublisherUpdated', async () => {
    const created = await service.create(validCreateInput);
    const updated = await service.update(created.id, {
      displayName: 'New Name',
      contactEmail: 'new@example.com',
    });

    expect(updated.displayName).toBe('New Name');
    expect(updated.contactEmail).toBe('new@example.com');
    expect(audit.entries.at(-1)?.action).toBe('PublisherUpdated');
  });

  test('update rejects an unrecognized status', async () => {
    const created = await service.create(validCreateInput);
    await expect(service.update(created.id, { status: 'archived' as never })).rejects.toThrow(
      /not a recognized Publisher status/,
    );
  });

  test('update to suspended records PublisherSuspended', async () => {
    const created = await service.create(validCreateInput);
    await service.update(created.id, { status: 'suspended' });
    expect(audit.entries.at(-1)?.action).toBe('PublisherSuspended');
  });

  test('update back to active records PublisherReactivated', async () => {
    const created = await service.create(validCreateInput);
    await service.update(created.id, { status: 'suspended' });
    await service.update(created.id, { status: 'active' });
    expect(audit.entries.at(-1)?.action).toBe('PublisherReactivated');
  });

  test('update merges description/website into the existing profile', async () => {
    const created = await service.create({ ...validCreateInput, description: 'Original' });
    const updated = await service.update(created.id, { website: 'https://example.com' });

    expect(updated.description).toBe('Original');
    expect(updated.website).toBe('https://example.com');
  });

  test('remove soft-deletes the publisher and records PublisherDeleted', async () => {
    const created = await service.create(validCreateInput);
    await service.remove(created.id);

    await expect(service.getById(created.id)).rejects.toThrow(/was not found/);
    expect(audit.entries.at(-1)?.action).toBe('PublisherDeleted');
  });

  test('remove throws NotFoundError for an unknown id', async () => {
    await expect(service.remove(randomUUID())).rejects.toThrow(/was not found/);
  });
});
