import { ValidationError } from '@oep-exchange/core';

/**
 * Pure, DB-free validation (docs/tasks/WP-EXC-007.md §6) — identifier
 * format only. Package/version/artifact _existence_ and package-status
 * permission are data-dependent and are enforced by `DownloadService`
 * instead, the same split `package-validation.ts` already established.
 */

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Throws `ValidationError` if `id` is not a well-formed UUID. */
export function validatePackageId(id: string): void {
  if (!UUID_PATTERN.test(id)) {
    throw new ValidationError(`"${id}" is not a valid Package identifier.`, { id });
  }
}

/** Throws `ValidationError` if `version` is missing or blank. */
export function validateVersionParam(version: string): void {
  if (!version?.trim()) {
    throw new ValidationError('A package version must be provided.');
  }
}
