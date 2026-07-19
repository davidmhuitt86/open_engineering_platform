import AdmZip from 'adm-zip';
import { describe, expect, test } from 'vitest';
import {
  extractManifestFromArchive,
  extractManifestJson,
} from './extract-manifest-from-archive.js';

function buildArchive(manifestJson: string | undefined): Buffer {
  const zip = new AdmZip();
  if (manifestJson !== undefined) {
    zip.addFile('manifest/package.json', Buffer.from(manifestJson, 'utf8'));
  }
  zip.addFile('package.info', Buffer.from('OEP Package', 'utf8'));
  return zip.toBuffer();
}

describe('extractManifestJson / extractManifestFromArchive', () => {
  test('extracts the manifest JSON text from a well-formed archive', () => {
    const archive = buildArchive('{"title":"Test Package"}');
    expect(extractManifestJson(archive)).toBe('{"title":"Test Package"}');
  });

  test('extractManifestFromArchive parses the extracted JSON', () => {
    const archive = buildArchive('{"title":"Test Package"}');
    expect(extractManifestFromArchive(archive)).toEqual({ title: 'Test Package' });
  });

  test('rejects a buffer that is not a valid ZIP', () => {
    const notAZip = Buffer.from('this is definitely not a zip file', 'utf8');
    expect(() => extractManifestJson(notAZip)).toThrow(/not a valid package archive/);
  });

  test('rejects an archive with no manifest entry', () => {
    const archive = buildArchive(undefined);
    expect(() => extractManifestJson(archive)).toThrow(/does not contain a manifest/);
  });

  test('rejects an archive whose manifest is not valid JSON', () => {
    const archive = buildArchive('{not valid json');
    expect(() => extractManifestFromArchive(archive)).toThrow(/not valid JSON/);
  });
});
