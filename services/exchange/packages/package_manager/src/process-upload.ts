import { extractManifestFromArchive, parseManifest } from '@oep-exchange/manifest';
import { computeFileMetadata } from './compute-file-metadata.js';
import { extractMetadata } from './extract-metadata.js';
import type { ProcessedUpload } from './types.js';

/**
 * Orchestrates the non-persistence stages of the Package Upload
 * Pipeline (WP-EXC-005.md §3/§5: "Manifest Parser -> Metadata
 * Extraction", everything before "Package Repository"/"File Storage")
 * — the single place that sequences archive extraction, manifest
 * parsing, and metadata extraction (OWNERSHIP.md). Pure and DB-free:
 * `apps/exchange-api`'s `UploadService` calls this first, then performs
 * the actual catalog registration and file storage with the result.
 *
 * Digital signature verification (`manifest.signatures`) is deliberately
 * not performed here — explicitly excluded from WP-EXC-005.md §2, and
 * `@oep-exchange/signing`'s real implementation is a later task's
 * deliverable.
 */
export function processUpload(archive: Buffer): ProcessedUpload {
  const rawManifest = extractManifestFromArchive(archive);
  const manifest = parseManifest(rawManifest);
  return {
    manifest,
    metadata: extractMetadata(manifest),
    file: computeFileMetadata(archive),
  };
}
