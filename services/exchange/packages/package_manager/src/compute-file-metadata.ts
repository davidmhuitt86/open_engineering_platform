import { createHash } from 'node:crypto';
import type { UploadedFileMetadata } from './types.js';

/** Computes file-level metadata (WP-EXC-005.md §8: "File size, Hash") from the raw uploaded bytes. */
export function computeFileMetadata(archive: Buffer): UploadedFileMetadata {
  return {
    sizeBytes: archive.length,
    sha256: createHash('sha256').update(archive).digest('hex'),
  };
}
