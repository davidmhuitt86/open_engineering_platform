import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { StubRepositoryClient } from '@oep-exchange/installer';
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

const BOUNDARY = '----oepExchangeInstallationTestBoundary';

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
 * REST API tests (docs/tasks/WP-EXC-008.md §9) exercising
 * `POST /api/v1/packages/{id}/install` and
 * `GET /api/v1/installations/{installationId}` end to end against a real
 * database and a real (temp-directory) `LocalPackageFileStorage` — skip
 * (never fail) if no database is reachable, per `db/README.md` "Testing
 * without a live database". Uploads a real archive first (same helper
 * pattern as `upload.test.ts`/`download.test.ts`) so there is a real
 * artifact to install.
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('Installation REST API', () => {
  let pool: Pool;
  let storageDir: string;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    storageDir = await mkdtemp(join(tmpdir(), 'oep-exchange-installation-test-'));
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
    await pool.end();
    await rm(storageDir, { recursive: true, force: true });
  });

  async function uploadPackage(
    app: FastifyInstance,
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

  test('installs the current version and reports status "completed"', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const archive = buildArchive(validManifest());
      const { packageId } = await uploadPackage(app, archive, 'honda-gl1200-1.0.0.oep');

      const response = await app.inject({
        method: 'POST',
        url: `/api/v1/packages/${packageId}/install`,
      });

      expect(response.statusCode).toBe(201);
      const body = response.json();
      expect(body.packageId).toBe(packageId);
      expect(body.version).toBe('1.0.0');
      expect(body.status).toBe('completed');
      expect(body.repositoryPackageId).toBeTruthy();
      expect(body.errorMessage).toBeNull();

      const fetched = await app.inject({
        method: 'GET',
        url: `/api/v1/installations/${body.id}`,
      });
      expect(fetched.statusCode).toBe(200);
      expect(fetched.json()).toEqual(body);
    } finally {
      await app.close();
    }
  });

  test('installs a specific requested version', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const archive = buildArchive(validManifest({ version: '2.1.0' }));
      const { packageId } = await uploadPackage(app, archive, 'honda-2.1.0.oep');

      const response = await app.inject({
        method: 'POST',
        url: `/api/v1/packages/${packageId}/install`,
        payload: { version: '2.1.0' },
      });

      expect(response.statusCode).toBe(201);
      expect(response.json().version).toBe('2.1.0');
    } finally {
      await app.close();
    }
  });

  test('a Repository rejection is reported as status "failed" with 201, not an HTTP error', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient({
        simulateFailure: true,
        failureMessage: 'The Repository is out of disk space.',
      }),
    });
    try {
      const archive = buildArchive(validManifest());
      const { packageId } = await uploadPackage(app, archive, 'honda-gl1200-1.0.0.oep');

      const response = await app.inject({
        method: 'POST',
        url: `/api/v1/packages/${packageId}/install`,
      });

      expect(response.statusCode).toBe(201);
      const body = response.json();
      expect(body.status).toBe('failed');
      expect(body.errorMessage).toBe('The Repository is out of disk space.');
      expect(body.repositoryPackageId).toBeNull();
    } finally {
      await app.close();
    }
  });

  test('an unknown package id returns 404', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const response = await app.inject({
        method: 'POST',
        url: `/api/v1/packages/${randomUUID()}/install`,
      });
      expect(response.statusCode).toBe(404);
      expect(response.json().error.code).toBe('NOT_FOUND');
    } finally {
      await app.close();
    }
  });

  test('a malformed package id returns 400', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const response = await app.inject({
        method: 'POST',
        url: '/api/v1/packages/not-a-uuid/install',
      });
      expect(response.statusCode).toBe(400);
    } finally {
      await app.close();
    }
  });

  test('a nonexistent requested version returns 404', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const archive = buildArchive(validManifest());
      const { packageId } = await uploadPackage(app, archive, 'honda-gl1200-1.0.0.oep');

      const response = await app.inject({
        method: 'POST',
        url: `/api/v1/packages/${packageId}/install`,
        payload: { version: '9.9.9' },
      });
      expect(response.statusCode).toBe(404);
    } finally {
      await app.close();
    }
  });

  test('a suspended package cannot be installed', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const archive = buildArchive(validManifest());
      const { packageId } = await uploadPackage(app, archive, 'honda-gl1200-1.0.0.oep');

      await app.inject({
        method: 'PUT',
        url: `/api/v1/packages/${packageId}`,
        payload: { status: 'suspended' },
      });

      const response = await app.inject({
        method: 'POST',
        url: `/api/v1/packages/${packageId}/install`,
      });
      expect(response.statusCode).toBe(403);
      expect(response.json().error.code).toBe('FORBIDDEN');
    } finally {
      await app.close();
    }
  });

  test('GET an unknown installation id returns 404', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const response = await app.inject({
        method: 'GET',
        url: `/api/v1/installations/${randomUUID()}`,
      });
      expect(response.statusCode).toBe(404);
    } finally {
      await app.close();
    }
  });

  test('GET a malformed installation id returns 400', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/installations/not-a-uuid',
      });
      expect(response.statusCode).toBe(400);
    } finally {
      await app.close();
    }
  });

  test('the installation routes appear in the generated OpenAPI document', async () => {
    const app = await buildApp({
      db: pool,
      storage: new LocalPackageFileStorage(storageDir),
      repositoryClient: new StubRepositoryClient(),
    });
    try {
      const response = await app.inject({ method: 'GET', url: '/documentation/json' });
      expect(response.statusCode).toBe(200);
      const spec = response.json();
      expect(spec.paths['/api/v1/packages/{id}/install']).toBeDefined();
      expect(spec.paths['/api/v1/installations/{installationId}']).toBeDefined();
    } finally {
      await app.close();
    }
  });
});
