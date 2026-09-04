import { ValidationError } from '@oep-exchange/core';

/**
 * Pure, DB-free validation for the Upload Service (WP-EXC-005.md §6) —
 * identifier format and the file-presence check. Manifest/archive
 * validity is `@oep-exchange/manifest`'s job (it throws `ValidationError`
 * itself); publisher/category reference validity and namespace
 * ownership are data-dependent and live in `UploadService` instead.
 */
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validatePublisherId(publisherId: string): void {
  if (!publisherId || !UUID_PATTERN.test(publisherId)) {
    throw new ValidationError(`"${publisherId}" is not a valid Publisher identifier.`, {
      publisherId,
    });
  }
}

export function validateCategoryId(categoryId: string): void {
  if (!UUID_PATTERN.test(categoryId)) {
    throw new ValidationError(`"${categoryId}" is not a valid Category identifier.`, {
      categoryId,
    });
  }
}

export function validateFilePresent(fileBuffer: Buffer | undefined): asserts fileBuffer is Buffer {
  if (!fileBuffer || fileBuffer.length === 0) {
    throw new ValidationError('No package file was uploaded.');
  }
}
