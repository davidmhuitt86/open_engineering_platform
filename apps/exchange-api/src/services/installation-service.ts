import { ForbiddenError, NotFoundError } from '@oep-exchange/core';
import type { InstallationDto } from '@oep-exchange/api-contracts';
import type { RepositoryClient } from '@oep-exchange/installer';
import type {
  AuditRepository,
  Installation,
  InstallationRepository,
  Package,
  PackageFileRepository,
  PackageRepository,
  PackageVersionRepository,
} from '../persistence/index.js';
import type { PackageFileStorage } from '../storage/package-file-storage.js';
import {
  validateInstallationId,
  validatePackageId,
  validateVersionParam,
} from './installation-validation.js';

/**
 * The Repository Installation Integration's business logic
 * (docs/tasks/WP-EXC-008.md §3/§8: "REST API -> Installation Service ->
 * Repository Client -> Exchange Services -> Repository Public API.
 * Business logic shall remain inside InstallationService."). Follows
 * WP-EXC-008.md §5's flow exactly: validate the Package -> resolve the
 * requested version -> locate its artifact ("Exchange Services": the
 * same `PackageRepository`/`PackageVersionRepository`/
 * `PackageFileRepository`/`PackageFileStorage` primitives
 * `DownloadService` uses, TASK-EXC-0007) -> invoke the Repository's
 * public interface (via `RepositoryClient`) -> record and return the
 * resulting Installation status. A Repository-side rejection is a valid,
 * recorded outcome (`status: 'failed'`), not an HTTP error — mirroring
 * `oep_acquisition`'s own Job Execution History precedent (an execution
 * can complete with `status: 'failed'` without the API call itself being
 * an error).
 */
export class InstallationService {
  constructor(
    private readonly packages: PackageRepository,
    private readonly packageVersions: PackageVersionRepository,
    private readonly packageFiles: PackageFileRepository,
    private readonly installations: InstallationRepository,
    private readonly storage: PackageFileStorage,
    private readonly repositoryClient: RepositoryClient,
    private readonly audit: AuditRepository,
  ) {}

  /** `POST /packages/{id}/install` — installs `version`, or the Package's current version when omitted. */
  async install(packageId: string, version?: string): Promise<InstallationDto> {
    validatePackageId(packageId);
    validateVersionParam(version);

    const pkg = await this.packages.getByIdOrThrow(packageId);
    this.assertInstallationPermitted(pkg);

    const packageVersion = version
      ? await this.resolveNamedVersion(pkg, version)
      : await this.resolveLatestVersion(pkg);

    const files = await this.packageFiles.listByVersion(packageVersion.id);
    const file = files.at(-1);
    if (!file) {
      throw new NotFoundError('PackageFile', `${pkg.packageId}@${packageVersion.version}`);
    }

    const installation = await this.installations.create({
      packageId: pkg.id,
      packageVersionId: packageVersion.id,
    });

    const artifact = await this.storage.retrieve(file.storagePath);
    const result = await this.repositoryClient.install({
      packageId: pkg.packageId,
      version: packageVersion.version,
      artifact,
      sha256: file.sha256,
      fileName: file.fileName,
    });

    const updated = result.accepted
      ? await this.installations.complete(installation.id, result.repositoryPackageId ?? null)
      : await this.installations.fail(
          installation.id,
          result.message ?? 'The Repository rejected the installation request.',
        );

    await this.audit.record({
      entityType: 'installation',
      entityId: updated.id,
      action: result.accepted ? 'InstallationCompleted' : 'InstallationFailed',
      metadata: { packageId: pkg.packageId, version: packageVersion.version },
    });

    return this.toDto(updated, pkg.packageId, packageVersion.version);
  }

  /** `GET /installations/{installationId}` — the persisted status of a past installation attempt. */
  async getById(installationId: string): Promise<InstallationDto> {
    validateInstallationId(installationId);
    const installation = await this.installations.getByIdOrThrow(installationId);
    const pkg = await this.packages.getByIdOrThrow(installation.packageId);
    const version = await this.packageVersions.getByIdOrThrow(installation.packageVersionId);
    return this.toDto(installation, pkg.packageId, version.version);
  }

  private async resolveNamedVersion(pkg: Package, version: string) {
    const packageVersion = await this.packageVersions.findByPackageAndVersion(pkg.id, version);
    if (!packageVersion) {
      throw new NotFoundError('PackageVersion', `${pkg.packageId}@${version}`);
    }
    return packageVersion;
  }

  private async resolveLatestVersion(pkg: Package) {
    if (!pkg.latestVersionId) {
      throw new NotFoundError('PackageVersion', `${pkg.packageId} (no version published yet)`);
    }
    return this.packageVersions.getByIdOrThrow(pkg.latestVersionId);
  }

  /** WP-EXC-008.md §6 "Package status permits installation" — a suspended Package is withheld pending review, mirroring `DownloadService`. */
  private assertInstallationPermitted(pkg: Package): void {
    if (pkg.status === 'suspended') {
      throw new ForbiddenError(`Package "${pkg.packageId}" is suspended and cannot be installed.`);
    }
  }

  private toDto(installation: Installation, packageId: string, version: string): InstallationDto {
    return {
      id: installation.id,
      packageId,
      version,
      status: installation.status,
      repositoryPackageId: installation.repositoryPackageId,
      errorMessage: installation.errorMessage,
      requestedAt: installation.requestedAt.toISOString(),
      completedAt: installation.completedAt?.toISOString() ?? null,
    };
  }
}
