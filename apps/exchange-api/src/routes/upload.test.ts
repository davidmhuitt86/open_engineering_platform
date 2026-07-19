import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import AdmZip from 'adm-zip';
import type { FastifyInstance } from 'fastify';
import type { Pool } from 'pg';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { buildApp } from '../app.js';
import { PostgresPublisherRepository } from '../persistence/repositories/publisher-repository.js';
import {
  isTestDatabaseAvailable,
  setupTestDatabase,
  truncateAllTables,
} from '../persistence/test-support.js';
import type { Publisher } from '../persistence/types.js';
import { LocalPackageFileStorage } from '../storage/package-file-storage.js';

const BOUNDARY = '----oepExchangeUploadTestBoundary';

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
 * REST API tests (docs/tasks/WP-EXC-005.md §9) exercising
 * `POST /api/v1/packages/upload` end to end against a real database and
 * a real (temp-directory) `LocalPackageFileStorage` — skip (never fail)
 * if no database is reachable, per `db/README.md` "Testing without a
 * live database".
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('POST /api/v1/packages/upload (REST API)', () => {
  let pool: Pool;
  let app: FastifyInstance;
  let storageDir: string;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    storageDir = await mkdtemp(join(tmpdir(), 'oep-exchange-upload-test-'));
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

  test('uploads a well-formed package archive and registers it', async () => {
    const archive = buildArchive(validManifest());
    const body = buildMultipartBody(
      { publisherId: publisher.id },
      { name: 'honda-gl1200-1.0.0.oep', buffer: archive },
    );

    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages/upload',
      headers: { 'content-type': `multipart/form-data; boundary=${BOUNDARY}` },
      payload: body,
    });

    expect(response.statusCode).toBe(201);
    const result = response.json();
    expect(result.version).toBe('1.0.0');
    expect(result.fileName).toBe('honda-gl1200-1.0.0.oep');
    expect(result.sizeBytes).toBe(archive.length);

    const registered = await app.inject({
      method: 'GET',
      url: `/api/v1/packages/${result.packageId}`,
    });
    expect(registered.statusCode).toBe(200);
    expect(registered.json().currentVersion).toBe('1.0.0');
  });

  test('rejects an upload with no publisherId', async () => {
    const body = buildMultipartBody({}, { name: 'x.oep', buffer: buildArchive(validManifest()) });
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages/upload',
      headers: { 'content-type': `multipart/form-data; boundary=${BOUNDARY}` },
      payload: body,
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });

  test('rejects an upload for a nonexistent publisher', async () => {
    const body = buildMultipartBody(
      { publisherId: randomUUID() },
      { name: 'x.oep', buffer: buildArchive(validManifest()) },
    );
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages/upload',
      headers: { 'content-type': `multipart/form-data; boundary=${BOUNDARY}` },
      payload: body,
    });
    expect(response.statusCode).toBe(400);
  });

  test('rejects a duplicate version upload with 400', async () => {
    const archive = buildArchive(validManifest());
    const firstBody = buildMultipartBody(
      { publisherId: publisher.id },
      { name: 'v1.oep', buffer: archive },
    );
    await app.inject({
      method: 'POST',
      url: '/api/v1/packages/upload',
      headers: { 'content-type': `multipart/form-data; boundary=${BOUNDARY}` },
      payload: firstBody,
    });

    const secondBody = buildMultipartBody(
      { publisherId: publisher.id },
      { name: 'v1-again.oep', buffer: archive },
    );
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/packages/upload',
      headers: { 'content-type': `multipart/form-data; boundary=${BOUNDARY}` },
      payload: secondBody,
    });
    expect(response.statusCode).toBe(400);
  });

  test('the upload route appears in the generated OpenAPI document', async () => {
    const response = await app.inject({ method: 'GET', url: '/documentation/json' });
    expect(response.statusCode).toBe(200);
    expect(response.json().paths['/api/v1/packages/upload']).toBeDefined();
  });
});
