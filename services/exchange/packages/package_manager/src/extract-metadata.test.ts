import { describe, expect, test } from 'vitest';
import type { PackageManifest } from '@oep-exchange/manifest';
import { extractMetadata } from './extract-metadata.js';

function manifest(): PackageManifest {
  return {
    schemaVersion: '1.0',
    packageId: 'com.divad.honda.gl1200.electrical',
    version: '1.0.0',
    publisher: { id: 'pub-1', name: 'Divad Engineering' },
    title: 'Honda GL1200 Electrical',
    summary: 'Electrical system reference.',
    description: 'Full wiring diagrams for the Honda GL1200.',
    category: 'Automotive',
    engineeringDomains: ['Automotive', 'Electrical'],
    license: { licenseId: 'proprietary' },
    dependencies: [{ packageId: 'com.other.dep', versionConstraint: '^1.0.0', required: true }],
    capabilities: ['diagram'],
    repository: { objects: 10 },
    statistics: { compressedSize: '1MB' },
    signatures: {},
    build: { tool: 'oep-cli' },
    keywords: ['wiring'],
  };
}

describe('extractMetadata', () => {
  test('projects every field the Package Catalog needs', () => {
    const metadata = extractMetadata(manifest());

    expect(metadata).toEqual({
      packageId: 'com.divad.honda.gl1200.electrical',
      version: '1.0.0',
      title: 'Honda GL1200 Electrical',
      summary: 'Electrical system reference.',
      description: 'Full wiring diagrams for the Honda GL1200.',
      category: 'Automotive',
      engineeringDomains: ['Automotive', 'Electrical'],
      keywords: ['wiring'],
      capabilities: ['diagram'],
      license: { licenseId: 'proprietary' },
      dependencies: [{ packageId: 'com.other.dep', versionConstraint: '^1.0.0', required: true }],
      repositoryStats: { objects: 10 },
      statistics: { compressedSize: '1MB' },
      buildMetadata: { tool: 'oep-cli' },
      manifestPublisherId: 'pub-1',
    });
  });
});
