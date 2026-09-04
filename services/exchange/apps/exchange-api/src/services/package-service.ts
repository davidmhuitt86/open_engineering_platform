import type {
  CreatePackageRequest,
  PackageDto,
  UpdatePackageRequest,
} from '@oep-exchange/api-contracts';
import { ValidationError } from '@oep-exchange/core';
import type {
  AuditRepository,
  CategoryRepository,
  Package,
  PackageRepository,
  PackageVersionRepository,
  PublisherRepository,
} from '../persistence/index.js';
import {
  validateCreatePackageRequest,
  validatePackageId,
  validateStatusTransition,
  validateUpdatePackageRequest,
} from './package-validation.js';

/**
 * The Package Catalog's business logic (docs/tasks/WP-EXC-004.md §3:
 * "REST API -> Package Service -> Package Repository -> PostgreSQL.
 * Business logic shall remain within the Package Service."). Routes
 * (`routes/packages.ts`) call this and shape the response; they never
 * issue SQL or apply validation themselves (CONTRIBUTING_ARCHITECTURE.md
 * rule 8). Merges each Package's current `package_versions` row (via
 * `latestVersionId`, built in TASK-EXC-0002) into a `currentVersion`
 * semver string, and records an `audit_log` entry for every mutation
 * (WP-EXC-001 §4 "All transactions are audited").
 */
export class PackageService {
  constructor(
    private readonly packages: PackageRepository,
    private readonly publishers: PublisherRepository,
    private readonly categories: CategoryRepository,
    private readonly packageVersions: PackageVersionRepository,
    private readonly audit: AuditRepository,
  ) {}

  async list(): Promise<PackageDto[]> {
    const all = await this.packages.list();
    return Promise.all(all.map((pkg) => this.toDto(pkg)));
  }

  async getById(id: string): Promise<PackageDto> {
    validatePackageId(id);
    const pkg = await this.packages.getByIdOrThrow(id);
    return this.toDto(pkg);
  }

  async create(input: CreatePackageRequest): Promise<PackageDto> {
    validateCreatePackageRequest(input);

    const publisher = await this.publishers.findById(input.publisherId);
    if (!publisher) {
      throw new ValidationError(`Publisher "${input.publisherId}" does not exist.`, {
        publisherId: input.publisherId,
      });
    }

    if (input.categoryId) {
      await this.assertCategoryExists(input.categoryId);
    }

    const created = await this.packages.create({
      packageId: input.packageId,
      publisherId: input.publisherId,
      title: input.displayName,
      description: input.description ?? '',
      categoryId: input.categoryId ?? null,
    });

    await this.audit.record({
      entityType: 'package',
      entityId: created.id,
      action: 'PackageCreated',
      metadata: { packageId: created.packageId, publisherId: created.publisherId },
    });

    return this.toDto(created);
  }

  async update(id: string, input: UpdatePackageRequest): Promise<PackageDto> {
    validatePackageId(id);
    validateUpdatePackageRequest(input);

    const current = await this.packages.getByIdOrThrow(id);

    if (input.status !== undefined) {
      validateStatusTransition(current.status, input.status);
    }

    if (input.categoryId) {
      await this.assertCategoryExists(input.categoryId);
    }

    const updated = await this.packages.update(id, {
      ...(input.displayName !== undefined ? { title: input.displayName } : {}),
      ...(input.description !== undefined ? { description: input.description } : {}),
      ...(input.categoryId !== undefined ? { categoryId: input.categoryId } : {}),
      ...(input.status !== undefined ? { status: input.status } : {}),
    });

    await this.audit.record({
      entityType: 'package',
      entityId: id,
      action: this.describeUpdateAction(current.status, input.status),
      metadata: { changes: input },
    });

    return this.toDto(updated);
  }

  async remove(id: string): Promise<void> {
    validatePackageId(id);
    await this.packages.getByIdOrThrow(id);
    await this.packages.softDelete(id);

    await this.audit.record({
      entityType: 'package',
      entityId: id,
      action: 'PackageDeleted',
    });
  }

  private async assertCategoryExists(categoryId: string): Promise<void> {
    const category = await this.categories.findById(categoryId);
    if (!category) {
      throw new ValidationError(`Category "${categoryId}" does not exist.`, { categoryId });
    }
  }

  private describeUpdateAction(previousStatus: string, requestedStatus?: string): string {
    if (requestedStatus !== undefined && requestedStatus !== previousStatus) {
      switch (requestedStatus) {
        case 'published':
          return 'PackagePublished';
        case 'deprecated':
          return 'PackageDeprecated';
        case 'suspended':
          return 'PackageSuspended';
        default:
          return 'PackageUpdated';
      }
    }
    return 'PackageUpdated';
  }

  private async toDto(pkg: Package): Promise<PackageDto> {
    const currentVersion = pkg.latestVersionId
      ? await this.packageVersions.findById(pkg.latestVersionId)
      : null;

    return {
      id: pkg.id,
      packageId: pkg.packageId,
      publisherId: pkg.publisherId,
      displayName: pkg.title,
      description: pkg.description,
      categoryId: pkg.categoryId,
      currentVersion: currentVersion?.version ?? null,
      status: pkg.status,
      createdAt: pkg.createdAt.toISOString(),
      updatedAt: pkg.updatedAt.toISOString(),
    };
  }
}
