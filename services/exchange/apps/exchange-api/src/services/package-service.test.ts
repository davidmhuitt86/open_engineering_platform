import { randomUUID } from 'node:crypto';
import { ConflictError, NotFoundError } from '@oep-exchange/core';
import { beforeEach, describe, expect, test } from 'vitest';
import type {
  AuditLogEntry,
  AuditRepository,
  CategoryRepository,
  NewAuditLogEntry,
  NewPackage,
  NewPackageVersion,
  Package,
  PackageCategory,
  PackageRepository,
  PackageUpdate,
  PackageVersion,
  PackageVersionRepository,
  Publisher,
  PublisherRepository,
} from '../persistence/index.js';
import { PackageService } from './package-service.js';

/** In-memory fakes (no database), mirroring `publisher-service.test.ts`'s own precedent. */
class FakePackageRepository implements PackageRepository {
  private readonly rows = new Map<string, Package>();

  async create(input: NewPackage): Promise<Package> {
    if (await this.findByPackageId(input.packageId)) {
      throw new ConflictError(`Package ID "${input.packageId}" is already in use.`);
    }
    if (await this.findByPublisherAndTitle(input.publisherId, input.title)) {
      throw new ConflictError(`This Publisher already has a package named "${input.title}".`);
    }

    const now = new Date();
    const pkg: Package = {
      id: randomUUID(),
      packageId: input.packageId,
      publisherId: input.publisherId,
      title: input.title,
      summary: input.summary ?? '',
      description: input.description ?? '',
      categoryId: input.categoryId ?? null,
      engineeringDomains: input.engineeringDomains ?? [],
      keywords: input.keywords ?? [],
      capabilities: input.capabilities ?? [],
      license: input.license ?? {},
      status: input.status ?? 'draft',
      latestVersionId: null,
      rowVersion: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(pkg.id, pkg);
    return pkg;
  }

  async findById(id: string): Promise<Package | null> {
    return this.rows.get(id) ?? null;
  }

  async findByPackageId(packageId: string): Promise<Package | null> {
    return [...this.rows.values()].find((p) => p.packageId === packageId) ?? null;
  }

  async findByPublisherAndTitle(publisherId: string, title: string): Promise<Package | null> {
    return (
      [...this.rows.values()].find((p) => p.publisherId === publisherId && p.title === title) ??
      null
    );
  }

  async list(): Promise<Package[]> {
    return [...this.rows.values()];
  }

  async listByPublisher(publisherId: string): Promise<Package[]> {
    return [...this.rows.values()].filter((p) => p.publisherId === publisherId);
  }

  async getByIdOrThrow(id: string): Promise<Package> {
    const pkg = await this.findById(id);
    if (!pkg) throw new NotFoundError('Package', id);
    return pkg;
  }

  async setLatestVersion(id: string, versionId: string): Promise<void> {
    const pkg = await this.getByIdOrThrow(id);
    this.rows.set(id, { ...pkg, latestVersionId: versionId, rowVersion: pkg.rowVersion + 1 });
  }

  async update(id: string, changes: PackageUpdate): Promise<Package> {
    const existing = await this.getByIdOrThrow(id);
    if (changes.title) {
      const owner = await this.findByPublisherAndTitle(existing.publisherId, changes.title);
      if (owner && owner.id !== id) {
        throw new ConflictError(`This Publisher already has a package named "${changes.title}".`);
      }
    }
    const updated: Package = {
      ...existing,
      title: changes.title ?? existing.title,
      description: changes.description ?? existing.description,
      categoryId: changes.categoryId !== undefined ? changes.categoryId : existing.categoryId,
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

class FakePublisherRepository {
  private readonly rows = new Map<string, Publisher>();

  seed(publisher: Publisher): void {
    this.rows.set(publisher.id, publisher);
  }

  async findById(id: string): Promise<Publisher | null> {
    return this.rows.get(id) ?? null;
  }
}

class FakeCategoryRepository {
  private readonly rows = new Map<string, PackageCategory>();

  seed(category: PackageCategory): void {
    this.rows.set(category.id, category);
  }

  async findById(id: string): Promise<PackageCategory | null> {
    return this.rows.get(id) ?? null;
  }
}

class FakePackageVersionRepository implements Pick<
  PackageVersionRepository,
  'findById' | 'create'
> {
  private readonly rows = new Map<string, PackageVersion>();

  async create(input: NewPackageVersion): Promise<PackageVersion> {
    const now = new Date();
    const version: PackageVersion = {
      id: randomUUID(),
      packageId: input.packageId,
      version: input.version,
      schemaVersion: input.schemaVersion ?? '1.0',
      manifest: input.manifest,
      dependencies: input.dependencies ?? [],
      repositoryStats: input.repositoryStats ?? {},
      statistics: input.statistics ?? {},
      signatures: input.signatures ?? {},
      buildMetadata: input.buildMetadata ?? {},
      releaseChannel: input.releaseChannel ?? 'stable',
      status: 'pending',
      publishedAt: null,
      rowVersion: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(version.id, version);
    return version;
  }

  async findById(id: string): Promise<PackageVersion | null> {
    return this.rows.get(id) ?? null;
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

function fakePublisher(overrides: Partial<Publisher> = {}): Publisher {
  const now = new Date();
  return {
    id: randomUUID(),
    name: 'Divad Engineering LLC',
    displayName: 'Divad',
    namespace: 'com.test.divad',
    publisherType: 'individual',
    verificationStatus: 'unverified',
    trustStatus: 'standard',
    status: 'active',
    contactEmail: 'contact@example.com',
    rowVersion: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function fakeCategory(overrides: Partial<PackageCategory> = {}): PackageCategory {
  const now = new Date();
  return {
    id: randomUUID(),
    slug: 'automotive',
    name: 'Automotive',
    description: '',
    parentId: null,
    rowVersion: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

describe('PackageService', () => {
  let packages: FakePackageRepository;
  let publishers: FakePublisherRepository;
  let categories: FakeCategoryRepository;
  let packageVersions: FakePackageVersionRepository;
  let audit: FakeAuditRepository;
  let service: PackageService;
  let publisher: Publisher;
  let category: PackageCategory;

  const validCreateInput = () => ({
    packageId: 'com.divad.honda.gl1200.electrical',
    publisherId: publisher.id,
    displayName: 'Honda GL1200 Electrical',
  });

  beforeEach(() => {
    packages = new FakePackageRepository();
    publishers = new FakePublisherRepository();
    categories = new FakeCategoryRepository();
    packageVersions = new FakePackageVersionRepository();
    audit = new FakeAuditRepository();
    service = new PackageService(
      packages,
      publishers as unknown as PublisherRepository,
      categories as unknown as CategoryRepository,
      packageVersions as unknown as PackageVersionRepository,
      audit,
    );

    publisher = fakePublisher();
    publishers.seed(publisher);
    category = fakeCategory();
    categories.seed(category);
  });

  test('create returns a fully-shaped PackageDto and records a PackageCreated audit event', async () => {
    const dto = await service.create(validCreateInput());

    expect(dto.id).toBeTruthy();
    expect(dto.packageId).toBe('com.divad.honda.gl1200.electrical');
    expect(dto.publisherId).toBe(publisher.id);
    expect(dto.displayName).toBe('Honda GL1200 Electrical');
    expect(dto.status).toBe('draft');
    expect(dto.currentVersion).toBeNull();
    expect(dto.categoryId).toBeNull();

    expect(audit.entries).toHaveLength(1);
    expect(audit.entries[0]!.action).toBe('PackageCreated');
  });

  test('create accepts an existing categoryId', async () => {
    const dto = await service.create({ ...validCreateInput(), categoryId: category.id });
    expect(dto.categoryId).toBe(category.id);
  });

  test('create rejects an invalid request before touching the repository', async () => {
    await expect(service.create({ ...validCreateInput(), displayName: '' })).rejects.toThrow(
      /Missing required field/,
    );
    expect(await packages.list()).toHaveLength(0);
  });

  test('create rejects a reference to a nonexistent publisher', async () => {
    await expect(
      service.create({ ...validCreateInput(), publisherId: randomUUID() }),
    ).rejects.toThrow(/does not exist/);
  });

  test('create rejects a reference to a nonexistent category', async () => {
    await expect(
      service.create({ ...validCreateInput(), categoryId: randomUUID() }),
    ).rejects.toThrow(/does not exist/);
  });

  test('create propagates a ConflictError for a duplicate packageId', async () => {
    await service.create(validCreateInput());
    await expect(
      service.create({ ...validCreateInput(), displayName: 'Different Name' }),
    ).rejects.toThrow(/already in use/);
  });

  test('getById rejects a malformed identifier without querying the repository', async () => {
    await expect(service.getById('not-a-uuid')).rejects.toThrow(/not a valid Package identifier/);
  });

  test('getById throws NotFoundError for an unknown id', async () => {
    await expect(service.getById(randomUUID())).rejects.toThrow(/was not found/);
  });

  test('getById merges the current version string when one is registered', async () => {
    const created = await service.create(validCreateInput());
    const version = await packageVersions.create({
      packageId: created.id,
      version: '1.0.0',
      manifest: {},
    });
    await packages.setLatestVersion(created.id, version.id);

    const dto = await service.getById(created.id);
    expect(dto.currentVersion).toBe('1.0.0');
  });

  test('list returns every package as a PackageDto', async () => {
    await service.create(validCreateInput());
    await service.create({
      ...validCreateInput(),
      packageId: 'com.divad.other',
      displayName: 'Other Package',
    });

    const all = await service.list();
    expect(all).toHaveLength(2);
  });

  test('update changes displayName/description and records PackageUpdated', async () => {
    const created = await service.create(validCreateInput());
    const updated = await service.update(created.id, {
      displayName: 'New Name',
      description: 'New description.',
    });

    expect(updated.displayName).toBe('New Name');
    expect(updated.description).toBe('New description.');
    expect(audit.entries.at(-1)?.action).toBe('PackageUpdated');
  });

  test('update rejects an unrecognized status', async () => {
    const created = await service.create(validCreateInput());
    await expect(service.update(created.id, { status: 'archived' as never })).rejects.toThrow(
      /not a recognized Package status/,
    );
  });

  test('update rejects an invalid status transition (deprecated -> published)', async () => {
    const created = await service.create(validCreateInput());
    await service.update(created.id, { status: 'published' });
    await service.update(created.id, { status: 'deprecated' });

    await expect(service.update(created.id, { status: 'published' })).rejects.toThrow(
      /Cannot transition Package status/,
    );
  });

  test('update to published records PackagePublished', async () => {
    const created = await service.create(validCreateInput());
    await service.update(created.id, { status: 'published' });
    expect(audit.entries.at(-1)?.action).toBe('PackagePublished');
  });

  test('update rejects a reference to a nonexistent category', async () => {
    const created = await service.create(validCreateInput());
    await expect(service.update(created.id, { categoryId: randomUUID() })).rejects.toThrow(
      /does not exist/,
    );
  });

  test('update can clear categoryId back to null', async () => {
    const created = await service.create({ ...validCreateInput(), categoryId: category.id });
    const updated = await service.update(created.id, { categoryId: null });
    expect(updated.categoryId).toBeNull();
  });

  test('remove soft-deletes the package and records PackageDeleted', async () => {
    const created = await service.create(validCreateInput());
    await service.remove(created.id);

    await expect(service.getById(created.id)).rejects.toThrow(/was not found/);
    expect(audit.entries.at(-1)?.action).toBe('PackageDeleted');
  });

  test('remove throws NotFoundError for an unknown id', async () => {
    await expect(service.remove(randomUUID())).rejects.toThrow(/was not found/);
  });
});
