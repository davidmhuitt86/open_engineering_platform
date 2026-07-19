import { describe, expect, test } from 'vitest';
import { parseManifest } from './parse-manifest.js';

function validManifest(): Record<string, unknown> {
  return {
    schemaVersion: '1.0',
    packageId: 'com.divad.honda.gl1200.electrical',
    version: '1.0.0',
    publisher: { id: 'pub-1', name: 'Divad Engineering' },
    title: 'Honda GL1200 Electrical',
    summary: 'Electrical system reference.',
    description: 'Full wiring diagrams and electrical system reference for the Honda GL1200.',
    category: 'Automotive',
    engineeringDomains: ['Automotive', 'Electrical'],
    license: { licenseId: 'proprietary' },
    dependencies: [],
    capabilities: ['diagram'],
    repository: { objects: 10 },
    statistics: { compressedSize: '1MB' },
    signatures: {},
    build: { tool: 'oep-cli' },
  };
}

describe('parseManifest', () => {
  test('accepts a fully-populated, valid manifest', () => {
    const manifest = parseManifest(validManifest());
    expect(manifest.packageId).toBe('com.divad.honda.gl1200.electrical');
    expect(manifest.publisher).toEqual({ id: 'pub-1', name: 'Divad Engineering' });
    expect(manifest.engineeringDomains).toEqual(['Automotive', 'Electrical']);
    expect(manifest.keywords).toEqual([]);
  });

  test('rejects a non-object payload', () => {
    expect(() => parseManifest('not an object')).toThrow(/must be a JSON object/);
    expect(() => parseManifest(null)).toThrow(/must be a JSON object/);
    expect(() => parseManifest([])).toThrow(/must be a JSON object/);
  });

  test.each([
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
  ])('rejects a manifest missing required field %s', (field) => {
    const manifest = validManifest();
    delete manifest[field];
    expect(() => parseManifest(manifest)).toThrow(/missing required field/);
  });

  test('rejects a non-string title', () => {
    expect(() => parseManifest({ ...validManifest(), title: 123 })).toThrow(
      /must be a non-empty string/,
    );
  });

  test('rejects a non-array engineeringDomains', () => {
    expect(() => parseManifest({ ...validManifest(), engineeringDomains: 'Automotive' })).toThrow(
      /must be an array/,
    );
  });

  test('rejects a non-object publisher', () => {
    expect(() => parseManifest({ ...validManifest(), publisher: 'Divad' })).toThrow(
      /must be an object/,
    );
  });

  test('rejects a publisher missing id/name', () => {
    expect(() => parseManifest({ ...validManifest(), publisher: {} })).toThrow(
      /publisher\.id.*must be a non-empty string/,
    );
    expect(() => parseManifest({ ...validManifest(), publisher: { id: 'pub-1' } })).toThrow(
      /publisher\.name.*must be a non-empty string/,
    );
  });

  test('normalizes dependencies to the ManifestDependency shape', () => {
    const manifest = parseManifest({
      ...validManifest(),
      dependencies: [{ packageId: 'com.other.dep', versionConstraint: '^1.0.0', required: false }],
    });
    expect(manifest.dependencies).toEqual([
      { packageId: 'com.other.dep', versionConstraint: '^1.0.0', required: false },
    ]);
  });

  test('defaults dependency.required to true when omitted', () => {
    const manifest = parseManifest({
      ...validManifest(),
      dependencies: [{ packageId: 'com.other.dep', versionConstraint: '^1.0.0' }],
    });
    expect(manifest.dependencies[0]!.required).toBe(true);
  });

  test('carries through optional keywords', () => {
    const manifest = parseManifest({ ...validManifest(), keywords: ['wiring', 'gl1200'] });
    expect(manifest.keywords).toEqual(['wiring', 'gl1200']);
  });
});
