import { createHash } from 'node:crypto';
import AdmZip from 'adm-zip';
import { describe, expect, test } from 'vitest';
import { processUpload } from './process-upload.js';

function buildArchive(manifest: Record<string, unknown>): Buffer {
  const zip = new AdmZip();
  zip.addFile('manifest/package.json', Buffer.from(JSON.stringify(manifest), 'utf8'));
  return zip.toBuffer();
}

function validManifest(): Record<string, unknown> {
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
    dependencies: [],
    capabilities: ['diagram'],
    repository: { objects: 10 },
    statistics: { compressedSize: '1MB' },
    signatures: {},
    build: { tool: 'oep-cli' },
  };
}

describe('processUpload', () => {
  test('extracts, parses, and derives metadata from a well-formed archive', () => {
    const archive = buildArchive(validManifest());
    const result = processUpload(archive);

    expect(result.manifest.packageId).toBe('com.divad.honda.gl1200.electrical');
    expect(result.metadata.packageId).toBe('com.divad.honda.gl1200.electrical');
    expect(result.metadata.title).toBe('Honda GL1200 Electrical');
    expect(result.metadata.manifestPublisherId).toBe('pub-1');
    expect(result.metadata.engineeringDomains).toEqual(['Automotive', 'Electrical']);
  });

  test('computes the correct file size and sha256 hash', () => {
    const archive = buildArchive(validManifest());
    const result = processUpload(archive);

    expect(result.file.sizeBytes).toBe(archive.length);
    expect(result.file.sha256).toBe(createHash('sha256').update(archive).digest('hex'));
  });

  test('rejects an archive with a malformed manifest', () => {
    const archive = buildArchive({ title: 'incomplete' });
    expect(() => processUpload(archive)).toThrow(/missing required field/);
  });

  test('rejects a buffer that is not a valid archive', () => {
    expect(() => processUpload(Buffer.from('not a zip', 'utf8'))).toThrow(
      /not a valid package archive/,
    );
  });
});
