import { ValidationError } from '@oep-exchange/core';

/**
 * Pure, DB-free validation (docs/tasks/WP-EXC-008.md §6) — identifier
 * format only, mirroring `download-validation.ts`'s split between
 * format validation (here) and data-dependent existence/Repository-
 * response checks (`InstallationService`).
 */

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Throws `ValidationError` if `id` is not a well-formed UUID. */
export function validatePackageId(id: string): void {
  if (!UUID_PATTERN.test(id)) {
    throw new ValidationError(`"${id}" is not a valid Package identifier.`, { id });
  }
}

/** Throws `ValidationError` if `id` is not a well-formed UUID. */
export function validateInstallationId(id: string): void {
  if (!UUID_PATTERN.test(id)) {
    throw new ValidationError(`"${id}" is not a valid Installation identifier.`, { id });
  }
}

/** Throws `ValidationError` if a provided `version` is blank. `undefined` (install the current version) is valid and passes through untouched. */
export function validateVersionParam(version: string | undefined): void {
  if (version !== undefined && !version.trim()) {
    throw new ValidationError('version cannot be blank.');
  }
}
