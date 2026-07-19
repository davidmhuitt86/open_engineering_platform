import AdmZip from 'adm-zip';
import { ValidationError } from '@oep-exchange/core';

/** PKG-001 §5: the manifest always lives at this path inside a `.oep` archive. */
const MANIFEST_ENTRY_PATH = 'manifest/package.json';

/** A manifest entry larger than this is rejected outright rather than parsed — a well-formed manifest is metadata, not payload. */
const MAX_MANIFEST_BYTES = 10 * 1024 * 1024;

/**
 * Opens a `.oep` package archive (PKG-001 §5/§14: a deterministic ZIP
 * container) and returns the raw JSON text of `manifest/package.json`.
 * Throws `ValidationError` for anything that isn't a valid, readable
 * ZIP archive, or that lacks a manifest entry — WP-EXC-005.md §6 "Valid
 * package format".
 */
export function extractManifestJson(archive: Buffer): string {
  let zip: AdmZip;
  try {
    zip = new AdmZip(archive);
  } catch {
    throw new ValidationError(
      'The uploaded file is not a valid package archive (not a readable ZIP).',
    );
  }

  const entry = zip.getEntry(MANIFEST_ENTRY_PATH);
  if (!entry) {
    throw new ValidationError(
      `The uploaded package archive does not contain a manifest at "${MANIFEST_ENTRY_PATH}".`,
    );
  }

  if (entry.header.size > MAX_MANIFEST_BYTES) {
    throw new ValidationError('The package manifest entry is unexpectedly large.');
  }

  try {
    return zip.readAsText(entry, 'utf8');
  } catch {
    throw new ValidationError('The package manifest entry could not be read from the archive.');
  }
}

/** Extracts and JSON-parses the manifest from a `.oep` archive. Throws `ValidationError` if the archive or its manifest JSON is malformed. */
export function extractManifestFromArchive(archive: Buffer): unknown {
  const text = extractManifestJson(archive);
  try {
    return JSON.parse(text);
  } catch {
    throw new ValidationError('The package manifest is not valid JSON.');
  }
}
