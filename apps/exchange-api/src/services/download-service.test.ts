import { randomUUID } from 'node:crypto';
import { NotFoundError } from '@oep-exchange/core';
import { beforeEach, describe, expect, test } from 'vitest';
import type {
  Download,
  DownloadRepository,
  NewDownload,
  Package,
  PackageFile,
  PackageFileRepository,
  PackageRepository,
  PackageVersion,
  PackageVersionRepository,
} from '../persistence/index.js';
import type { PackageFileStorage, StoredPackageFile } from '../storage/package-file-storage.js';
import { DownloadService } from './download-service.js';

/** In-memory fakes (no database), mirroring `package-service.test.ts`'s own precedent. */
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

class FakeDownloadRepository implements Pick<DownloadRepository, 'record'> {
  readonly recorded: NewDownload[] = [];

  async record(input: NewDownload): Promise<Download> {
    this.recorded.push(input);
    return {
      id: randomUUID(),
      packageVersionId: input.packageVersionId,
      downloadedAt: new Date(),
      clientIp: input.clientIp ?? null,
      userAgent: input.userAgent ?? null,
    };
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

describe('DownloadService', () => {
  let packages: FakePackageRepository;
  let packageVersions: FakePackageVersionRepository;
  let packageFiles: FakePackageFileRepository;
  let downloads: FakeDownloadRepository;
  let storage: FakePackageFileStorage;
  let service: DownloadService;

  beforeEach(() => {
    packages = new FakePackageRepository();
    packageVersions = new FakePackageVersionRepository();
    packageFiles = new FakePackageFileRepository();
    downloads = new FakeDownloadRepository();
    storage = new FakePackageFileStorage();
    service = new DownloadService(
      packages as unknown as PackageRepository,
      packageVersions as unknown as PackageVersionRepository,
      packageFiles as unknown as PackageFileRepository,
      downloads as unknown as DownloadRepository,
      storage,
    );
  });

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

  describe('downloadLatest', () => {
    test('returns the artifact and records a download', async () => {
      const { pkg, version, buffer } = seedPackageWithVersionAndFile();

      const result = await service.downloadLatest(pkg.id, {
        clientIp: '203.0.113.5',
        userAgent: 'oep-installer/1.0',
      });

      expect(result.buffer.equals(buffer)).toBe(true);
      expect(result.packageId).toBe(pkg.packageId);
      expect(result.version).toBe(version.version);
      expect(result.fileName).toBe('package.oep');
      expect(result.sha256).toBe('deadbeef');

      expect(downloads.recorded).toHaveLength(1);
      expect(downloads.recorded[0]).toEqual({
        packageVersionId: version.id,
        clientIp: '203.0.113.5',
        userAgent: 'oep-installer/1.0',
      });
    });

    test('rejects a malformed package id without querying the repository', async () => {
      await expect(service.downloadLatest('not-a-uuid', {})).rejects.toThrow(
        /not a valid Package identifier/,
      );
      expect(downloads.recorded).toHaveLength(0);
    });

    test('throws NotFoundError for an unknown package', async () => {
      await expect(service.downloadLatest(randomUUID(), {})).rejects.toThrow(/was not found/);
    });

    test('throws ForbiddenError for a suspended package', async () => {
      const { pkg } = seedPackageWithVersionAndFile({ pkg: { status: 'suspended' } });
      await expect(service.downloadLatest(pkg.id, {})).rejects.toThrow(/suspended/);
    });

    test('throws NotFoundError when the package has no published version yet', async () => {
      const pkg = fakePackage({ latestVersionId: null });
      packages.seed(pkg);
      await expect(service.downloadLatest(pkg.id, {})).rejects.toThrow(/was not found/);
    });

    test('throws NotFoundError when the version has no artifact on file', async () => {
      const version = fakeVersion();
      const pkg = fakePackage({ latestVersionId: version.id });
      version.packageId = pkg.id;
      packages.seed(pkg);
      packageVersions.seed(version);
      // deliberately no packageFiles.seed(...) call

      await expect(service.downloadLatest(pkg.id, {})).rejects.toThrow(/was not found/);
    });
  });

  describe('downloadVersion', () => {
    test('returns the artifact for the requested version', async () => {
      const { pkg, buffer } = seedPackageWithVersionAndFile({
        version: { version: '2.1.0' },
      });

      const result = await service.downloadVersion(pkg.id, '2.1.0', {});
      expect(result.buffer.equals(buffer)).toBe(true);
      expect(result.version).toBe('2.1.0');
    });

    test('rejects a blank version before querying the repository', async () => {
      await expect(service.downloadVersion(randomUUID(), '  ', {})).rejects.toThrow(
        /must be provided/,
      );
    });

    test('throws NotFoundError for a version that does not exist', async () => {
      const { pkg } = seedPackageWithVersionAndFile();
      await expect(service.downloadVersion(pkg.id, '9.9.9', {})).rejects.toThrow(/was not found/);
    });

    test('throws ForbiddenError for a suspended package regardless of version', async () => {
      const { pkg } = seedPackageWithVersionAndFile({
        pkg: { status: 'suspended' },
        version: { version: '1.0.0' },
      });
      await expect(service.downloadVersion(pkg.id, '1.0.0', {})).rejects.toThrow(/suspended/);
    });
  });
});
