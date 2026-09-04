import { ForbiddenError, NotFoundError } from '@oep-exchange/core';
import type {
  DownloadRepository,
  Package,
  PackageFileRepository,
  PackageRepository,
  PackageVersionRepository,
} from '../persistence/index.js';
import type { PackageFileStorage } from '../storage/package-file-storage.js';
import { validatePackageId, validateVersionParam } from './download-validation.js';

export interface DownloadClientInfo {
  clientIp?: string | null;
  userAgent?: string | null;
}

/** What a completed download yields — the route handler shapes the HTTP response from this. */
export interface DownloadResult {
  buffer: Buffer;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  packageId: string;
  version: string;
}

/**
 * The Package Download Service's business logic (docs/tasks/WP-EXC-007.md
 * §3/§7: "REST API -> Download Service -> Download Repository -> Package
 * Storage -> Package Artifact. Business logic shall remain within the
 * Download Service."). Routes (`routes/download.ts`) call this and shape
 * the HTTP response; they never touch the repositories or storage
 * themselves (CONTRIBUTING_ARCHITECTURE.md rule 8). Follows WP-EXC-007.md
 * §5's flow exactly: validate package -> locate artifact -> record
 * download -> return artifact.
 */
export class DownloadService {
  constructor(
    private readonly packages: PackageRepository,
    private readonly packageVersions: PackageVersionRepository,
    private readonly packageFiles: PackageFileRepository,
    private readonly downloads: DownloadRepository,
    private readonly storage: PackageFileStorage,
  ) {}

  /** `GET /packages/{id}/download` — the Package's current (latest) version. */
  async downloadLatest(packageId: string, client: DownloadClientInfo): Promise<DownloadResult> {
    validatePackageId(packageId);
    const pkg = await this.packages.getByIdOrThrow(packageId);
    this.assertDownloadPermitted(pkg);

    if (!pkg.latestVersionId) {
      throw new NotFoundError('PackageVersion', `${pkg.packageId} (no version published yet)`);
    }
    const version = await this.packageVersions.getByIdOrThrow(pkg.latestVersionId);

    return this.deliver(pkg, version.id, version.version, client);
  }

  /** `GET /packages/{id}/versions/{version}/download` — one specific version. */
  async downloadVersion(
    packageId: string,
    versionString: string,
    client: DownloadClientInfo,
  ): Promise<DownloadResult> {
    validatePackageId(packageId);
    validateVersionParam(versionString);
    const pkg = await this.packages.getByIdOrThrow(packageId);
    this.assertDownloadPermitted(pkg);

    const version = await this.packageVersions.findByPackageAndVersion(pkg.id, versionString);
    if (!version) {
      throw new NotFoundError('PackageVersion', `${pkg.packageId}@${versionString}`);
    }

    return this.deliver(pkg, version.id, version.version, client);
  }

  /** WP-EXC-007.md §6 "Package status permits download" — a suspended Package is withheld pending review. */
  private assertDownloadPermitted(pkg: Package): void {
    if (pkg.status === 'suspended') {
      throw new ForbiddenError(`Package "${pkg.packageId}" is suspended and cannot be downloaded.`);
    }
  }

  private async deliver(
    pkg: Package,
    packageVersionId: string,
    version: string,
    client: DownloadClientInfo,
  ): Promise<DownloadResult> {
    const files = await this.packageFiles.listByVersion(packageVersionId);
    const file = files.at(-1);
    if (!file) {
      throw new NotFoundError('PackageFile', `${pkg.packageId}@${version}`);
    }

    const buffer = await this.storage.retrieve(file.storagePath);

    await this.downloads.record({
      packageVersionId,
      clientIp: client.clientIp ?? null,
      userAgent: client.userAgent ?? null,
    });

    return {
      buffer,
      fileName: file.fileName,
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
      sha256: file.sha256,
      packageId: pkg.packageId,
      version,
    };
  }
}
