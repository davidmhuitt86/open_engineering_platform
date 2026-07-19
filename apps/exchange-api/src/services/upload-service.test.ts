import { randomUUID } from 'node:crypto';
import AdmZip from 'adm-zip';
import { ConflictError, NotFoundError } from '@oep-exchange/core';
import { beforeEach, describe, expect, test } from 'vitest';
import type {
  AuditLogEntry,
  AuditRepository,
  CategoryRepository,
  NewAuditLogEntry,
  NewPackage,
  NewPackageFile,
  NewPackageVersion,
  Package,
  PackageCategory,
  PackageFile,
  PackageFileRepository,
  PackageRepository,
  PackageUpdate,
  PackageVersion,
  PackageVersionRepository,
  Publisher,
  PublisherRepository,
} from '../persistence/index.js';
import type { PackageFileStorage, StoredPackageFile } from '../storage/package-file-storage.js';
import { UploadService } from './upload-service.js';

class FakePackageRepository implements PackageRepository {
  private readonly rows = new Map<string, Package>();

  async create(input: NewPackage): Promise<Package> {
    if (await this.findByPackageId(input.packageId)) {
      throw new ConflictError(`Package ID "${input.packageId}" is already in use.`);
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

class FakePackageVersionRepository implements PackageVersionRepository {
  private readonly rows = new Map<string, PackageVersion>();

  async create(input: NewPackageVersion): Promise<PackageVersion> {
    const existing = await this.findByPackageAndVersion(input.packageId, input.version);
    if (existing) {
      throw new ConflictError(`Version "${input.version}" already exists for this package.`);
    }
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

  async findByPackageAndVersion(
    packageId: string,
    version: string,
  ): Promise<PackageVersion | null> {
    return (
      [...this.rows.values()].find((v) => v.packageId === packageId && v.version === version) ??
      null
    );
  }

  async listByPackage(packageId: string): Promise<PackageVersion[]> {
    return [...this.rows.values()].filter((v) => v.packageId === packageId);
  }

  async getByIdOrThrow(id: string): Promise<PackageVersion> {
    const version = await this.findById(id);
    if (!version) throw new NotFoundError('PackageVersion', id);
    return version;
  }

  async publish(id: string): Promise<PackageVersion> {
    const version = await this.getByIdOrThrow(id);
    const updated = { ...version, status: 'published' as const, publishedAt: new Date() };
    this.rows.set(id, updated);
    return updated;
  }
}

class FakePackageFileRepository implements PackageFileRepository {
  private readonly rows = new Map<string, PackageFile>();

  async create(input: NewPackageFile): Promise<PackageFile> {
    const now = new Date();
    const file: PackageFile = {
      id: randomUUID(),
      packageVersionId: input.packageVersionId,
      fileName: input.fileName,
      mimeType: input.mimeType ?? 'application/vnd.oep.package',
      sizeBytes: input.sizeBytes,
      storagePath: input.storagePath,
      sha256: input.sha256,
      blake3: input.blake3 ?? null,
      signatureAlgorithm: input.signatureAlgorithm ?? null,
      rowVersion: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(file.id, file);
    return file;
  }

  async findById(id: string): Promise<PackageFile | null> {
    return this.rows.get(id) ?? null;
  }

  async listByVersion(packageVersionId: string): Promise<PackageFile[]> {
    return [...this.rows.values()].filter((f) => f.packageVersionId === packageVersionId);
  }

  async getByIdOrThrow(id: string): Promise<PackageFile> {
    const file = await this.findById(id);
    if (!file) throw new NotFoundError('PackageFile', id);
    return file;
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

class FakePackageFileStorage implements PackageFileStorage {
  readonly stored: Array<{ buffer: Buffer; sha256: string }> = [];

  async store(buffer: Buffer, sha256: string): Promise<StoredPackageFile> {
    this.stored.push({ buffer, sha256 });
    return { storagePath: `/fake/storage/${sha256}.oep`, sizeBytes: buffer.length, sha256 };
  }

  async retrieve(storagePath: string): Promise<Buffer> {
    const entry = this.stored.find((s) => `/fake/storage/${s.sha256}.oep` === storagePath);
    if (!entry) throw new Error(`No fake file stored at ${storagePath}`);
    return entry.buffer;
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
    namespace: 'com.divad',
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

function buildArchive(manifest: Record<string, unknown>): Buffer {
  const zip = new AdmZip();
  zip.addFile('manifest/package.json', Buffer.from(JSON.stringify(manifest), 'utf8'));
  return zip.toBuffer();
}

function validManifest(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    schemaVersion: '1.0',
    packageId: 'com.divad.honda.gl1200.electrical',
    version: '1.0.0',
    publisher: { id: 'pub-1', name: 'Divad Engineering' },
    title: 'Honda GL1200 Electrical',
    summary: 'Electrical system reference.',
    description: 'Full wiring diagrams for the Honda GL1200.',
    category: 'Automotive',
    engineeringDomains: ['Automotive', 'Electrical'],
    license: { licenseId: 'proprietary' },
    dependencies: [],
    capabilities: ['diagram'],
    repository: { objects: 10 },
    statistics: { compressedSize: '1MB' },
    signatures: {},
    build: { tool: 'oep-cli' },
    ...overrides,
  };
}

describe('UploadService', () => {
  let packages: FakePackageRepository;
  let packageVersions: FakePackageVersionRepository;
  let packageFiles: FakePackageFileRepository;
  let publishers: FakePublisherRepository;
  let categories: FakeCategoryRepository;
  let storage: FakePackageFileStorage;
  let audit: FakeAuditRepository;
  let service: UploadService;
  let publisher: Publisher;

  beforeEach(() => {
    packages = new FakePackageRepository();
    packageVersions = new FakePackageVersionRepository();
    packageFiles = new FakePackageFileRepository();
    publishers = new FakePublisherRepository();
    categories = new FakeCategoryRepository();
    storage = new FakePackageFileStorage();
    audit = new FakeAuditRepository();
    service = new UploadService(
      packages,
      packageVersions,
      packageFiles,
      publishers as unknown as PublisherRepository,
      categories as unknown as CategoryRepository,
      storage,
      audit,
    );

    publisher = fakePublisher();
    publishers.seed(publisher);
  });

  test('registers a new Package and PackageVersion from a well-formed upload', async () => {
    const archive = buildArchive(validManifest());
    const result = await service.upload({
      publisherId: publisher.id,
      fileBuffer: archive,
      fileName: 'honda-gl1200-electrical-1.0.0.oep',
    });

    expect(result.version).toBe('1.0.0');
    expect(result.sizeBytes).toBe(archive.length);
    expect(result.fileName).toBe('honda-gl1200-electrical-1.0.0.oep');

    const pkg = await packages.findByPackageId('com.divad.honda.gl1200.electrical');
    expect(pkg).not.toBeNull();
    expect(pkg!.publisherId).toBe(publisher.id);
    expect(pkg!.title).toBe('Honda GL1200 Electrical');
    expect(pkg!.latestVersionId).toBe(result.packageVersionId);

    expect(storage.stored).toHaveLength(1);
    expect(audit.entries.at(-1)?.action).toBe('PackageVersionUploaded');
  });

  test('registers a second version onto an existing Package without duplicating it', async () => {
    await service.upload({
      publisherId: publisher.id,
      fileBuffer: buildArchive(validManifest()),
      fileName: 'v1.oep',
    });

    const result = await service.upload({
      publisherId: publisher.id,
      fileBuffer: buildArchive(validManifest({ version: '1.1.0' })),
      fileName: 'v1.1.oep',
    });

    expect(result.version).toBe('1.1.0');
    const allPackages = await packages.list();
    expect(allPackages).toHaveLength(1);

    const versions = await packageVersions.listByPackage(allPackages[0]!.id);
    expect(versions).toHaveLength(2);
  });

  test('rejects an upload with no file', async () => {
    await expect(
      service.upload({ publisherId: publisher.id, fileBuffer: Buffer.alloc(0), fileName: 'x.oep' }),
    ).rejects.toThrow(/No package file was uploaded/);
  });

  test('rejects an upload for a nonexistent publisher', async () => {
    await expect(
      service.upload({
        publisherId: randomUUID(),
        fileBuffer: buildArchive(validManifest()),
        fileName: 'x.oep',
      }),
    ).rejects.toThrow(/does not exist/);
  });

  test('rejects a reference to a nonexistent category', async () => {
    await expect(
      service.upload({
        publisherId: publisher.id,
        categoryId: randomUUID(),
        fileBuffer: buildArchive(validManifest()),
        fileName: 'x.oep',
      }),
    ).rejects.toThrow(/does not exist/);
  });

  test('rejects a packageId outside the uploading publisher namespace', async () => {
    await expect(
      service.upload({
        publisherId: publisher.id,
        fileBuffer: buildArchive(validManifest({ packageId: 'com.someoneelse.thing' })),
        fileName: 'x.oep',
      }),
    ).rejects.toThrow(/does not belong to Publisher namespace/);
  });

  test('rejects uploading under a packageId already owned by a different publisher', async () => {
    await service.upload({
      publisherId: publisher.id,
      fileBuffer: buildArchive(validManifest()),
      fileName: 'v1.oep',
    });

    const otherPublisher = fakePublisher({ namespace: 'com.divad', id: randomUUID() });
    publishers.seed(otherPublisher);

    await expect(
      service.upload({
        publisherId: otherPublisher.id,
        fileBuffer: buildArchive(validManifest({ version: '2.0.0' })),
        fileName: 'v2.oep',
      }),
    ).rejects.toThrow(/already owned by a different Publisher/);
  });

  test('rejects a duplicate version for the same package', async () => {
    await service.upload({
      publisherId: publisher.id,
      fileBuffer: buildArchive(validManifest()),
      fileName: 'v1.oep',
    });

    await expect(
      service.upload({
        publisherId: publisher.id,
        fileBuffer: buildArchive(validManifest()),
        fileName: 'v1-again.oep',
      }),
    ).rejects.toThrow(/already exists/);
  });

  test('rejects a malformed archive', async () => {
    await expect(
      service.upload({
        publisherId: publisher.id,
        fileBuffer: Buffer.from('not a zip', 'utf8'),
        fileName: 'bad.oep',
      }),
    ).rejects.toThrow(/not a valid package archive/);
  });
});
