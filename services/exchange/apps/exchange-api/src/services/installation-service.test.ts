import { randomUUID } from 'node:crypto';
import { NotFoundError } from '@oep-exchange/core';
import type {
  RepositoryClient,
  RepositoryInstallRequest,
  RepositoryInstallResult,
} from '@oep-exchange/installer';
import { beforeEach, describe, expect, test } from 'vitest';
import type {
  AuditLogEntry,
  AuditRepository,
  Installation,
  InstallationRepository,
  NewAuditLogEntry,
  NewInstallation,
  Package,
  PackageFile,
  PackageFileRepository,
  PackageRepository,
  PackageVersion,
  PackageVersionRepository,
} from '../persistence/index.js';
import type { PackageFileStorage, StoredPackageFile } from '../storage/package-file-storage.js';
import { InstallationService } from './installation-service.js';

/** In-memory fakes (no database), mirroring `download-service.test.ts`'s own precedent. */
class FakePackageRepository implements Pick<PackageRepository, 'getByIdOrThrow'> {
  private readonly rows = new Map<string, Package>();

  seed(pkg: Package): void {
    this.rows.set(pkg.id, pkg);
  }

  async getByIdOrThrow(id: string): Promise<Package> {
    const pkg = this.rows.get(id);
    if (!pkg) throw new NotFoundError('Package', id);
    return pkg;
  }
}

class FakePackageVersionRepository implements Pick<
  PackageVersionRepository,
  'getByIdOrThrow' | 'findByPackageAndVersion'
> {
  private readonly rows = new Map<string, PackageVersion>();

  seed(version: PackageVersion): void {
    this.rows.set(version.id, version);
  }

  async getByIdOrThrow(id: string): Promise<PackageVersion> {
    const version = this.rows.get(id);
    if (!version) throw new NotFoundError('PackageVersion', id);
    return version;
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
}

class FakePackageFileRepository implements Pick<PackageFileRepository, 'listByVersion'> {
  private readonly rows = new Map<string, PackageFile[]>();

  seed(packageVersionId: string, file: PackageFile): void {
    this.rows.set(packageVersionId, [...(this.rows.get(packageVersionId) ?? []), file]);
  }

  async listByVersion(packageVersionId: string): Promise<PackageFile[]> {
    return this.rows.get(packageVersionId) ?? [];
  }
}

class FakeInstallationRepository implements InstallationRepository {
  private readonly rows = new Map<string, Installation>();

  async create(input: NewInstallation): Promise<Installation> {
    const now = new Date();
    const installation: Installation = {
      id: randomUUID(),
      packageId: input.packageId,
      packageVersionId: input.packageVersionId,
      status: 'pending',
      repositoryPackageId: null,
      errorMessage: null,
      requestedAt: now,
      completedAt: null,
      rowVersion: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(installation.id, installation);
    return installation;
  }

  async findById(id: string): Promise<Installation | null> {
    return this.rows.get(id) ?? null;
  }

  async getByIdOrThrow(id: string): Promise<Installation> {
    const installation = await this.findById(id);
    if (!installation) throw new NotFoundError('Installation', id);
    return installation;
  }

  async complete(id: string, repositoryPackageId: string | null): Promise<Installation> {
    const existing = await this.getByIdOrThrow(id);
    const updated: Installation = {
      ...existing,
      status: 'completed',
      repositoryPackageId,
      completedAt: new Date(),
      rowVersion: existing.rowVersion + 1,
      updatedAt: new Date(),
    };
    this.rows.set(id, updated);
    return updated;
  }

  async fail(id: string, errorMessage: string): Promise<Installation> {
    const existing = await this.getByIdOrThrow(id);
    const updated: Installation = {
      ...existing,
      status: 'failed',
      errorMessage,
      completedAt: new Date(),
      rowVersion: existing.rowVersion + 1,
      updatedAt: new Date(),
    };
    this.rows.set(id, updated);
    return updated;
  }
}

class FakePackageFileStorage implements PackageFileStorage {
  private readonly files = new Map<string, Buffer>();

  seed(storagePath: string, buffer: Buffer): void {
    this.files.set(storagePath, buffer);
  }

  async store(buffer: Buffer, sha256: string): Promise<StoredPackageFile> {
    const storagePath = `/fake/${sha256}.oep`;
    this.files.set(storagePath, buffer);
    return { storagePath, sizeBytes: buffer.length, sha256 };
  }

  async retrieve(storagePath: string): Promise<Buffer> {
    const buffer = this.files.get(storagePath);
    if (!buffer) throw new Error(`No fake file at ${storagePath}`);
    return buffer;
  }
}

class FakeRepositoryClient implements RepositoryClient {
  lastRequest: RepositoryInstallRequest | undefined;

  constructor(private readonly result: RepositoryInstallResult) {}

  async install(request: RepositoryInstallRequest): Promise<RepositoryInstallResult> {
    this.lastRequest = request;
    return this.result;
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

function fakePackage(overrides: Partial<Package> = {}): Package {
  const now = new Date();
  return {
    id: randomUUID(),
    packageId: 'com.divad.honda.gl1200',
    publisherId: randomUUID(),
    title: 'Honda GL1200 Electrical',
    summary: '',
    description: '',
    categoryId: null,
    engineeringDomains: [],
    keywords: [],
    capabilities: [],
    license: {},
    status: 'published',
    latestVersionId: null,
    rowVersion: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function fakeVersion(overrides: Partial<PackageVersion> = {}): PackageVersion {
  const now = new Date();
  return {
    id: randomUUID(),
    packageId: randomUUID(),
    version: '1.0.0',
    schemaVersion: '1.0',
    manifest: {},
    dependencies: [],
    repositoryStats: {},
    statistics: {},
    signatures: {},
    buildMetadata: {},
    releaseChannel: 'stable',
    status: 'published',
    publishedAt: null,
    rowVersion: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function fakeFile(overrides: Partial<PackageFile> = {}): PackageFile {
  const now = new Date();
  return {
    id: randomUUID(),
    packageVersionId: randomUUID(),
    fileName: 'package.oep',
    mimeType: 'application/vnd.oep.package',
    sizeBytes: 42,
    storagePath: '/fake/deadbeef.oep',
    sha256: 'deadbeef',
    blake3: null,
    signatureAlgorithm: null,
    rowVersion: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

describe('InstallationService', () => {
  let packages: FakePackageRepository;
  let packageVersions: FakePackageVersionRepository;
  let packageFiles: FakePackageFileRepository;
  let installations: FakeInstallationRepository;
  let storage: FakePackageFileStorage;
  let audit: FakeAuditRepository;

  beforeEach(() => {
    packages = new FakePackageRepository();
    packageVersions = new FakePackageVersionRepository();
    packageFiles = new FakePackageFileRepository();
    installations = new FakeInstallationRepository();
    storage = new FakePackageFileStorage();
    audit = new FakeAuditRepository();
  });

  function buildService(repositoryClient: RepositoryClient) {
    return new InstallationService(
      packages as unknown as PackageRepository,
      packageVersions as unknown as PackageVersionRepository,
      packageFiles as unknown as PackageFileRepository,
      installations,
      storage,
      repositoryClient,
      audit,
    );
  }

  function seedPackageWithVersionAndFile(
    overrides: {
      pkg?: Partial<Package>;
      version?: Partial<PackageVersion>;
      fileBuffer?: Buffer;
    } = {},
  ) {
    const version = fakeVersion(overrides.version);
    const pkg = fakePackage({ latestVersionId: version.id, ...overrides.pkg });
    version.packageId = pkg.id;
    const buffer = overrides.fileBuffer ?? Buffer.from('fake .oep archive bytes', 'utf8');
    const file = fakeFile({ packageVersionId: version.id, storagePath: '/fake/deadbeef.oep' });
    storage.seed(file.storagePath, buffer);

    packages.seed(pkg);
    packageVersions.seed(version);
    packageFiles.seed(version.id, file);

    return { pkg, version, file, buffer };
  }

  test('a successful install records status "completed" and an audit event', async () => {
    const { pkg, version } = seedPackageWithVersionAndFile();
    const repositoryClient = new FakeRepositoryClient({
      accepted: true,
      repositoryPackageId: 'repo-123',
    });
    const service = buildService(repositoryClient);

    const dto = await service.install(pkg.id);

    expect(dto.packageId).toBe(pkg.packageId);
    expect(dto.version).toBe(version.version);
    expect(dto.status).toBe('completed');
    expect(dto.repositoryPackageId).toBe('repo-123');
    expect(dto.errorMessage).toBeNull();
    expect(dto.completedAt).not.toBeNull();

    expect(audit.entries).toHaveLength(1);
    expect(audit.entries[0]!.action).toBe('InstallationCompleted');

    expect(repositoryClient.lastRequest?.packageId).toBe(pkg.packageId);
    expect(repositoryClient.lastRequest?.version).toBe(version.version);
    expect(repositoryClient.lastRequest?.sha256).toBe('deadbeef');
  });

  test('a Repository rejection records status "failed" without throwing', async () => {
    const { pkg } = seedPackageWithVersionAndFile();
    const repositoryClient = new FakeRepositoryClient({
      accepted: false,
      message: 'disk full',
    });
    const service = buildService(repositoryClient);

    const dto = await service.install(pkg.id);

    expect(dto.status).toBe('failed');
    expect(dto.errorMessage).toBe('disk full');
    expect(dto.repositoryPackageId).toBeNull();
    expect(audit.entries[0]!.action).toBe('InstallationFailed');
  });

  test('a Repository rejection with no message gets a default errorMessage', async () => {
    const { pkg } = seedPackageWithVersionAndFile();
    const service = buildService(new FakeRepositoryClient({ accepted: false }));

    const dto = await service.install(pkg.id);
    expect(dto.errorMessage).toMatch(/rejected/);
  });

  test('installs a specific requested version', async () => {
    const { pkg } = seedPackageWithVersionAndFile({ version: { version: '2.1.0' } });
    const service = buildService(new FakeRepositoryClient({ accepted: true }));

    const dto = await service.install(pkg.id, '2.1.0');
    expect(dto.version).toBe('2.1.0');
  });

  test('rejects a malformed package id without touching the repository', async () => {
    const service = buildService(new FakeRepositoryClient({ accepted: true }));
    await expect(service.install('not-a-uuid')).rejects.toThrow(/not a valid Package identifier/);
  });

  test('throws NotFoundError for an unknown package', async () => {
    const service = buildService(new FakeRepositoryClient({ accepted: true }));
    await expect(service.install(randomUUID())).rejects.toThrow(/was not found/);
  });

  test('throws ForbiddenError for a suspended package', async () => {
    const { pkg } = seedPackageWithVersionAndFile({ pkg: { status: 'suspended' } });
    const service = buildService(new FakeRepositoryClient({ accepted: true }));
    await expect(service.install(pkg.id)).rejects.toThrow(/suspended/);
  });

  test('throws NotFoundError when the package has no published version yet', async () => {
    const pkg = fakePackage({ latestVersionId: null });
    packages.seed(pkg);
    const service = buildService(new FakeRepositoryClient({ accepted: true }));
    await expect(service.install(pkg.id)).rejects.toThrow(/was not found/);
  });

  test('throws NotFoundError for an unknown requested version', async () => {
    const { pkg } = seedPackageWithVersionAndFile();
    const service = buildService(new FakeRepositoryClient({ accepted: true }));
    await expect(service.install(pkg.id, '9.9.9')).rejects.toThrow(/was not found/);
  });

  test('throws NotFoundError when the version has no artifact on file', async () => {
    const version = fakeVersion();
    const pkg = fakePackage({ latestVersionId: version.id });
    version.packageId = pkg.id;
    packages.seed(pkg);
    packageVersions.seed(version);
    // deliberately no packageFiles.seed(...) call

    const service = buildService(new FakeRepositoryClient({ accepted: true }));
    await expect(service.install(pkg.id)).rejects.toThrow(/was not found/);
  });

  describe('getById', () => {
    test('returns the persisted installation as a DTO', async () => {
      const { pkg, version } = seedPackageWithVersionAndFile();
      const service = buildService(new FakeRepositoryClient({ accepted: true }));
      const created = await service.install(pkg.id);

      const fetched = await service.getById(created.id);
      expect(fetched).toEqual(created);
      expect(fetched.version).toBe(version.version);
    });

    test('rejects a malformed installation id', async () => {
      const service = buildService(new FakeRepositoryClient({ accepted: true }));
      await expect(service.getById('not-a-uuid')).rejects.toThrow(
        /not a valid Installation identifier/,
      );
    });

    test('throws NotFoundError for an unknown installation id', async () => {
      const service = buildService(new FakeRepositoryClient({ accepted: true }));
      await expect(service.getById(randomUUID())).rejects.toThrow(/was not found/);
    });
  });
});
