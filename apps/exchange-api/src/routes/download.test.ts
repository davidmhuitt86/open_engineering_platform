import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import AdmZip from 'adm-zip';
import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { buildApp } from '../app.js';
import { PostgresDownloadRepository } from '../persistence/repositories/download-repository.js';
import { PostgresPackageRepository } from '../persistence/repositories/package-repository.js';
import { PostgresPublisherRepository } from '../persistence/repositories/publisher-repository.js';
import {
  isTestDatabaseAvailable,
  setupTestDatabase,
  truncateAllTables,
} from '../persistence/test-support.js';
import type { Publisher } from '../persistence/types.js';
import { LocalPackageFileStorage } from '../storage/package-file-storage.js';

const BOUNDARY = '----oepExchangeDownloadTestBoundary';

function buildMultipartBody(
  fields: Record<string, string>,
  file: { name: string; buffer: Buffer },
): Buffer {
  const parts: Buffer[] = [];
  for (const [name, value] of Object.entries(fields)) {
    parts.push(
      Buffer.from(
        `--${BOUNDARY}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n`,
        'utf8',
      ),
    );
  }
  parts.push(
    Buffer.from(
      `--${BOUNDARY}\r\nContent-Disposition: form-data; name="file"; filename="${file.name}"\r\nContent-Type: application/vnd.oep.package\r\n\r\n`,
      'utf8',
    ),
  );
  parts.push(file.buffer);
  parts.push(Buffer.from(`\r\n--${BOUNDARY}--\r\n`, 'utf8'));
  return Buffer.concat(parts);
}

function buildArchive(manifest: Record<string, unknown>): Buffer {
  const zip = new AdmZip();
  zip.addFile('manifest/package.json', Buffer.from(JSON.stringify(manifest), 'utf8'));
  return zip.toBuffer();
}

function validManifest(overrides: Record<string, unknown> = {}): Record<string, unknown> {
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
    ...overrides,
  };
}

/**
 * REST API tests (docs/tasks/WP-EXC-007.md §9) exercising both download
 * endpoints end to end against a real database and a real
 * (temp-directory) `LocalPackageFileStorage` — skip (never fail) if no
 * database is reachable, per `db/README.md` "Testing without a live
 * database". Uploads a real archive first (same helper pattern as
 * `upload.test.ts`) so there is a real, content-addressed artifact on
 * disk to download back.
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('GET /api/v1/packages/{id}/download (REST API)', () => {
  let pool: Pool;
  let app: FastifyInstance;
  let storageDir: string;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    storageDir = await mkdtemp(join(tmpdir(), 'oep-exchange-download-test-'));
    app = await buildApp({ db: pool, storage: new LocalPackageFileStorage(storageDir) });
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    publisher = await new PostgresPublisherRepository(pool).create({
      name: 'Divad Engineering LLC',
      displayName: 'Divad',
      namespace: 'com.divad',
      publisherType: 'individual',
    });
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
    await rm(storageDir, { recursive: true, force: true });
  });

  async function uploadPackage(
    archive: Buffer,
    fileName: string,
  ): Promise<{ packageId: string; version: string }> {
    const body = buildMultipartBody(
      { publisherId: publisher.id },
      { name: fileName, buffer: archive },
    );
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages/upload',
      headers: { 'content-type': `multipart/form-data; boundary=${BOUNDARY}` },
      payload: body,
    });
    expect(response.statusCode).toBe(201);
    const result = response.json();
    return { packageId: result.packageId, version: result.version };
  }

  test('downloads the current (latest) version and its bytes match the upload', async () => {
    const archive = buildArchive(validManifest());
    const { packageId } = await uploadPackage(archive, 'honda-gl1200-1.0.0.oep');

    const response = await app.inject({
      method: 'GET',
      url: `/api/v1/packages/${packageId}/download`,
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['content-disposition']).toContain('honda-gl1200-1.0.0.oep');
    expect(response.headers['x-package-version']).toBe('1.0.0');
    expect(Buffer.compare(response.rawPayload, archive)).toBe(0);
  });

  test('downloads a specific version by number', async () => {
    const archive = buildArchive(validManifest({ version: '2.1.0' }));
    const { packageId } = await uploadPackage(archive, 'honda-2.1.0.oep');

    const response = await app.inject({
      method: 'GET',
      url: `/api/v1/packages/${packageId}/versions/2.1.0/download`,
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['x-package-version']).toBe('2.1.0');
    expect(Buffer.compare(response.rawPayload, archive)).toBe(0);
  });

  test('records a download event for each successful download', async () => {
    const archive = buildArchive(validManifest());
    const { packageId } = await uploadPackage(archive, 'honda-gl1200-1.0.0.oep');

    await app.inject({ method: 'GET', url: `/api/v1/packages/${packageId}/download` });
    await app.inject({ method: 'GET', url: `/api/v1/packages/${packageId}/download` });

    const pkg = await new PostgresPackageRepository(pool).findByPackageId(packageId);
    const count = await new PostgresDownloadRepository(pool).countByVersion(pkg!.latestVersionId!);
    expect(count).toBe(2);
  });

  test('GET an unknown package id returns 404', async () => {
    const response = await app.inject({
      method: 'GET',
      url: `/api/v1/packages/${randomUUID()}/download`,
    });
    expect(response.statusCode).toBe(404);
    expect(response.json().error.code).toBe('NOT_FOUND');
  });

  test('GET a malformed package id returns 400', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/packages/not-a-uuid/download',
    });
    expect(response.statusCode).toBe(400);
  });

  test('a nonexistent version returns 404', async () => {
    const archive = buildArchive(validManifest());
    const { packageId } = await uploadPackage(archive, 'honda-gl1200-1.0.0.oep');

    const response = await app.inject({
      method: 'GET',
      url: `/api/v1/packages/${packageId}/versions/9.9.9/download`,
    });
    expect(response.statusCode).toBe(404);
  });

  test('a suspended package cannot be downloaded', async () => {
    const archive = buildArchive(validManifest());
    const { packageId } = await uploadPackage(archive, 'honda-gl1200-1.0.0.oep');

    await app.inject({
      method: 'PUT',
      url: `/api/v1/packages/${packageId}`,
      payload: { status: 'suspended' },
    });

    const response = await app.inject({
      method: 'GET',
      url: `/api/v1/packages/${packageId}/download`,
    });
    expect(response.statusCode).toBe(403);
    expect(response.json().error.code).toBe('FORBIDDEN');
  });

  test('the download routes appear in the generated OpenAPI document', async () => {
    const response = await app.inject({ method: 'GET', url: '/documentation/json' });
    expect(response.statusCode).toBe(200);
    const spec = response.json();
    expect(spec.paths['/api/v1/packages/{id}/download']).toBeDefined();
    expect(spec.paths['/api/v1/packages/{id}/versions/{version}/download']).toBeDefined();
  });
});
