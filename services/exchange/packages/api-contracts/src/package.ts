/**
 * Package Catalog wire contracts (TASK-EXC-0004, docs/tasks/WP-EXC-004.md
 * §5). Field-mapping notes (see `docs/architecture/REPOSITORY_STRUCTURE.md`
 * §14.1 for the full reasoning — this is a gap-fill against an
 * ambiguous task-doc field list, not a conflict with anything already
 * approved):
 * - "Package ID" -> `id` (the persistence layer's UUID primary key).
 * - "Package Name" -> `packageId` (the persistence layer's `package_id`
 *   column — PKG-001/PKG-002's reverse-domain package identifier).
 * - "Display Name" -> `displayName` (the persistence layer's `title`
 *   column — PKG-002's manifest "title" field).
 * - "Current Version" -> `currentVersion`, the semver string of the
 *   Package's `latestVersionId` (looked up and merged in, not stored
 *   redundantly) — `null` until a version has been registered.
 * Manifest-derived fields already on the persistence layer
 * (`engineeringDomains`, `keywords`, `capabilities`, `license`) are not
 * part of this task's model — WP-EXC-004.md §2 excludes manifest
 * parsing, so those remain at their column defaults until the Upload
 * task populates them.
 */
export type PackageStatus = 'draft' | 'published' | 'deprecated' | 'suspended';

export interface PackageDto {
  id: string;
  packageId: string;
  publisherId: string;
  displayName: string;
  description: string;
  categoryId: string | null;
  currentVersion: string | null;
  status: PackageStatus;
  createdAt: string;
  updatedAt: string;
}

export interface CreatePackageRequest {
  packageId: string;
  publisherId: string;
  displayName: string;
  description?: string;
  categoryId?: string | null;
}

/** Fields a Package may change after creation — `packageId`/`publisherId` are immutable identity, not editable here. */
export interface UpdatePackageRequest {
  displayName?: string;
  description?: string;
  categoryId?: string | null;
  status?: PackageStatus;
}

export interface PackageListResponse {
  packages: PackageDto[];
}
