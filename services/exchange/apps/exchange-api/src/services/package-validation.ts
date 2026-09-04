import type {
  CreatePackageRequest,
  PackageStatus,
  UpdatePackageRequest,
} from '@oep-exchange/api-contracts';
import { ValidationError } from '@oep-exchange/core';

/**
 * Pure, DB-free validation (docs/tasks/WP-EXC-004.md §6/§7) — required
 * fields, identifier format, and status-transition rules. Duplicate
 * package name/id detection and publisher/category reference checks are
 * data-dependent and are enforced by `PostgresPackageRepository`
 * (duplicates, via `ConflictError`) and `PackageService` (references,
 * by looking the referenced rows up) instead of here.
 */

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** PKG-001 §10 / PKG-002 §7: lowercase, reverse-domain, no spaces. */
const PACKAGE_ID_PATTERN = /^[a-z0-9]+(\.[a-z0-9-]+)+$/;

const PACKAGE_STATUSES: ReadonlySet<PackageStatus> = new Set([
  'draft',
  'published',
  'deprecated',
  'suspended',
]);

/**
 * Allowed target statuses for a given current status. `draft` is the
 * only entry point; `published` may deprecate or be suspended;
 * `suspended` may return to either `draft` (for re-review) or
 * `published` directly; `deprecated` is treated as a rest state that can
 * still be suspended (e.g. for a policy violation found after the fact)
 * but never un-deprecated — reintroducing a deprecated package's
 * content happens through a new package, not resurrecting the old one.
 */
const STATUS_TRANSITIONS: Record<PackageStatus, ReadonlySet<PackageStatus>> = {
  draft: new Set(['draft', 'published', 'suspended']),
  published: new Set(['published', 'deprecated', 'suspended']),
  suspended: new Set(['suspended', 'draft', 'published']),
  deprecated: new Set(['deprecated', 'suspended']),
};

/** Throws `ValidationError` if `id` is not a well-formed UUID. */
export function validatePackageId(id: string): void {
  if (!UUID_PATTERN.test(id)) {
    throw new ValidationError(`"${id}" is not a valid Package identifier.`, { id });
  }
}

/** Throws `ValidationError` if `input` is missing a required field or has a malformed one. */
export function validateCreatePackageRequest(input: CreatePackageRequest): void {
  const missing: string[] = [];
  if (!input.packageId?.trim()) missing.push('packageId');
  if (!input.publisherId?.trim()) missing.push('publisherId');
  if (!input.displayName?.trim()) missing.push('displayName');
  if (missing.length > 0) {
    throw new ValidationError(`Missing required field(s): ${missing.join(', ')}.`, { missing });
  }

  if (!UUID_PATTERN.test(input.publisherId)) {
    throw new ValidationError(`"${input.publisherId}" is not a valid Publisher identifier.`, {
      publisherId: input.publisherId,
    });
  }

  if (!PACKAGE_ID_PATTERN.test(input.packageId)) {
    throw new ValidationError(
      `"${input.packageId}" is not a valid Package ID (expected lowercase reverse-domain notation, e.g. "com.example.package").`,
      { packageId: input.packageId },
    );
  }

  if (
    input.categoryId !== undefined &&
    input.categoryId !== null &&
    !UUID_PATTERN.test(input.categoryId)
  ) {
    throw new ValidationError(`"${input.categoryId}" is not a valid Category identifier.`, {
      categoryId: input.categoryId,
    });
  }
}

/** Throws `ValidationError` if any provided field in `input` is malformed. */
export function validateUpdatePackageRequest(input: UpdatePackageRequest): void {
  if (input.displayName !== undefined && !input.displayName.trim()) {
    throw new ValidationError('displayName cannot be blank.');
  }

  if (
    input.categoryId !== undefined &&
    input.categoryId !== null &&
    !UUID_PATTERN.test(input.categoryId)
  ) {
    throw new ValidationError(`"${input.categoryId}" is not a valid Category identifier.`, {
      categoryId: input.categoryId,
    });
  }
}

/** Throws `ValidationError` for an unrecognized status or a transition not permitted from `current`. */
export function validateStatusTransition(current: PackageStatus, requested: string): void {
  if (!PACKAGE_STATUSES.has(requested as PackageStatus)) {
    throw new ValidationError(`"${requested}" is not a recognized Package status.`, {
      status: requested,
    });
  }

  const allowed = STATUS_TRANSITIONS[current];
  if (!allowed.has(requested as PackageStatus)) {
    throw new ValidationError(
      `Cannot transition Package status from "${current}" to "${requested}".`,
      {
        from: current,
        to: requested,
      },
    );
  }
}
