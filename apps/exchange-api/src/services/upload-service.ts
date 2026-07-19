import { ForbiddenError, ValidationError } from '@oep-exchange/core';
import type { UploadResultDto } from '@oep-exchange/api-contracts';
import { processUpload } from '@oep-exchange/package-manager';
import type {
  AuditRepository,
  CategoryRepository,
  PackageFileRepository,
  PackageRepository,
  PackageVersionRepository,
  PublisherRepository,
} from '../persistence/index.js';
import type { PackageFileStorage } from '../storage/package-file-storage.js';
import {
  validateCategoryId,
  validateFilePresent,
  validatePublisherId,
} from './upload-validation.js';

export interface UploadInput {
  publisherId: string;
  categoryId?: string | null;
  fileBuffer: Buffer;
  fileName: string;
}

/**
 * The Package Upload Pipeline's business logic (WP-EXC-005.md §3: "REST
 * API -> Upload Service -> Manifest Parser -> Metadata Extraction ->
 * Package Repository -> File Storage. Business logic shall remain
 * within the Upload Service."). Calls `@oep-exchange/package-manager`'s
 * `processUpload()` for the pure archive-extraction/manifest-parsing/
 * metadata-extraction stages, then performs the actual catalog
 * registration and file storage — the same "lives inside exchange-api
 * because it needs the persistence layer" reasoning as
 * `PublisherService`/`PackageService` (see
 * docs/architecture/REPOSITORY_STRUCTURE.md §13.2/§14.2/§15.2).
 */
export class UploadService {
  constructor(
    private readonly packages: PackageRepository,
    private readonly packageVersions: PackageVersionRepository,
    private readonly packageFiles: PackageFileRepository,
    private readonly publishers: PublisherRepository,
    private readonly categories: CategoryRepository,
    private readonly storage: PackageFileStorage,
    private readonly audit: AuditRepository,
  ) {}

  async upload(input: UploadInput): Promise<UploadResultDto> {
    validatePublisherId(input.publisherId);
    if (input.categoryId) {
      validateCategoryId(input.categoryId);
    }
    validateFilePresent(input.fileBuffer);

    const publisher = await this.publishers.findById(input.publisherId);
    if (!publisher) {
      throw new ValidationError(`Publisher "${input.publisherId}" does not exist.`, {
        publisherId: input.publisherId,
      });
    }

    if (input.categoryId) {
      const category = await this.categories.findById(input.categoryId);
      if (!category) {
        throw new ValidationError(`Category "${input.categoryId}" does not exist.`, {
          categoryId: input.categoryId,
        });
      }
    }

    // Manifest Parser -> Metadata Extraction (WP-EXC-005.md §3), pure and DB-free.
    const processed = processUpload(input.fileBuffer);
    const { metadata, file } = processed;

    if (
      metadata.packageId !== publisher.namespace &&
      !metadata.packageId.startsWith(`${publisher.namespace}.`)
    ) {
      throw new ValidationError(
        `Package ID "${metadata.packageId}" does not belong to Publisher namespace "${publisher.namespace}".`,
        { packageId: metadata.packageId, namespace: publisher.namespace },
      );
    }

    let pkg = await this.packages.findByPackageId(metadata.packageId);
    if (pkg && pkg.publisherId !== input.publisherId) {
      throw new ForbiddenError(
        `Package ID "${metadata.packageId}" is already owned by a different Publisher.`,
      );
    }

    const existingVersion = pkg
      ? await this.packageVersions.findByPackageAndVersion(pkg.id, metadata.version)
      : null;
    if (existingVersion) {
      throw new ValidationError(
        `Version "${metadata.version}" already exists for package "${metadata.packageId}".`,
        { packageId: metadata.packageId, version: metadata.version },
      );
    }

    if (!pkg) {
      pkg = await this.packages.create({
        packageId: metadata.packageId,
        publisherId: input.publisherId,
        title: metadata.title,
        summary: metadata.summary,
        description: metadata.description,
        categoryId: input.categoryId ?? null,
        engineeringDomains: metadata.engineeringDomains,
        keywords: metadata.keywords,
        capabilities: metadata.capabilities,
        license: metadata.license,
      });
    }

    const stored = await this.storage.store(input.fileBuffer, file.sha256);

    const version = await this.packageVersions.create({
      packageId: pkg.id,
      version: metadata.version,
      schemaVersion: processed.manifest.schemaVersion,
      manifest: processed.manifest as unknown as Record<string, unknown>,
      dependencies: metadata.dependencies,
      repositoryStats: metadata.repositoryStats,
      statistics: metadata.statistics,
      buildMetadata: metadata.buildMetadata,
    });

    const packageFile = await this.packageFiles.create({
      packageVersionId: version.id,
      fileName: input.fileName,
      mimeType: 'application/vnd.oep.package',
      sizeBytes: stored.sizeBytes,
      storagePath: stored.storagePath,
      sha256: stored.sha256,
    });

    await this.packages.setLatestVersion(pkg.id, version.id);

    await this.audit.record({
      entityType: 'package',
      entityId: pkg.id,
      action: 'PackageVersionUploaded',
      metadata: { packageId: metadata.packageId, version: metadata.version, sha256: file.sha256 },
    });

    return {
      packageId: pkg.id,
      packageVersionId: version.id,
      packageFileId: packageFile.id,
      version: metadata.version,
      fileName: input.fileName,
      sizeBytes: stored.sizeBytes,
      sha256: stored.sha256,
      uploadedAt: packageFile.createdAt.toISOString(),
    };
  }
}
