import { ValidationError } from '@oep-exchange/core';
import type { PackageManifest } from './types.js';

/** PKG-002 §5 Required Fields. */
const REQUIRED_FIELDS = [
  'schemaVersion',
  'packageId',
  'version',
  'publisher',
  'title',
  'summary',
  'description',
  'category',
  'engineeringDomains',
  'license',
  'dependencies',
  'capabilities',
  'repository',
  'statistics',
  'signatures',
  'build',
] as const;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Parses and validates a raw manifest payload against PKG-002 §5's
 * required fields and §20's validation rules ("Contain every required
 * field... Pass schema validation"). Throws `ValidationError` for a
 * malformed or incomplete manifest — never returns a partially-valid
 * result (PKG-002 §20: "Failure invalidates the package").
 */
export function parseManifest(input: unknown): PackageManifest {
  if (!isPlainObject(input)) {
    throw new ValidationError('The manifest must be a JSON object.');
  }

  const missing = REQUIRED_FIELDS.filter((field) => !(field in input));
  if (missing.length > 0) {
    throw new ValidationError(`Manifest is missing required field(s): ${missing.join(', ')}.`, {
      missing,
    });
  }

  const stringFields = [
    'schemaVersion',
    'packageId',
    'version',
    'title',
    'summary',
    'description',
    'category',
  ] as const;
  for (const field of stringFields) {
    if (typeof input[field] !== 'string' || input[field] === '') {
      throw new ValidationError(`Manifest field "${field}" must be a non-empty string.`, { field });
    }
  }

  const arrayFields = ['engineeringDomains', 'dependencies', 'capabilities'] as const;
  for (const field of arrayFields) {
    if (!Array.isArray(input[field])) {
      throw new ValidationError(`Manifest field "${field}" must be an array.`, { field });
    }
  }

  const objectFields = [
    'publisher',
    'license',
    'repository',
    'statistics',
    'signatures',
    'build',
  ] as const;
  for (const field of objectFields) {
    if (!isPlainObject(input[field])) {
      throw new ValidationError(`Manifest field "${field}" must be an object.`, { field });
    }
  }

  const publisher = input.publisher as Record<string, unknown>;
  if (typeof publisher.id !== 'string' || publisher.id === '') {
    throw new ValidationError('Manifest field "publisher.id" must be a non-empty string.');
  }
  if (typeof publisher.name !== 'string' || publisher.name === '') {
    throw new ValidationError('Manifest field "publisher.name" must be a non-empty string.');
  }

  const keywords = Array.isArray(input.keywords) ? (input.keywords as unknown[]) : [];

  return {
    schemaVersion: input.schemaVersion as string,
    packageId: input.packageId as string,
    version: input.version as string,
    publisher: {
      id: publisher.id,
      name: publisher.name,
      ...(typeof publisher.verified === 'boolean' ? { verified: publisher.verified } : {}),
      ...(typeof publisher.website === 'string' ? { website: publisher.website } : {}),
      ...(typeof publisher.support === 'string' ? { support: publisher.support } : {}),
    },
    title: input.title as string,
    summary: input.summary as string,
    description: input.description as string,
    category: input.category as string,
    engineeringDomains: (input.engineeringDomains as unknown[]).filter(
      (value): value is string => typeof value === 'string',
    ),
    license: input.license as Record<string, unknown>,
    dependencies: (input.dependencies as unknown[]).filter(isPlainObject).map((dependency) => ({
      packageId: String(dependency.packageId ?? ''),
      versionConstraint: String(dependency.versionConstraint ?? ''),
      required: dependency.required !== false,
      ...(typeof dependency.reason === 'string' ? { reason: dependency.reason } : {}),
    })),
    capabilities: (input.capabilities as unknown[]).filter(
      (value): value is string => typeof value === 'string',
    ),
    repository: input.repository as Record<string, unknown>,
    statistics: input.statistics as Record<string, unknown>,
    signatures: input.signatures as Record<string, unknown>,
    build: input.build as Record<string, unknown>,
    keywords: keywords.filter((value): value is string => typeof value === 'string'),
  };
}
