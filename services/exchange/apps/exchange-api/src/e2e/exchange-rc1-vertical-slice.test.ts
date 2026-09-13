import { createHash, randomUUID } from 'node:crypto';
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

const BOUNDARY = '----oepExchangeRc1E2eBoundary';

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

/** Same shape/helper pattern as `routes/upload.test.ts`/`download.test.ts` --
 * an `adm-zip` archive is a real, valid `.oep` package for Exchange's
 * own HTTP/storage layer (which is compression-method-agnostic; only
 * Foundation's installer requires the Stored method, exercised
 * separately by WP-EXC-013's own Dart fixture,
 * `platform/oep_studio/test/fixtures/oep_package_fixture.dart`, reused
 * verbatim by WP-EXC-014's Dart-side test). Not a second, competing
 * `.oep` format -- this tier never reaches Foundation; it only proves
 * the real Exchange server's own search/detail/download/checksum
 * behavior. */
function buildArchive(manifest: Record<string, unknown>): Buffer {
  const zip = new AdmZip();
  zip.addFile('manifest/package.json', Buffer.from(JSON.stringify(manifest), 'utf8'));
  return zip.toBuffer();
}

function rc1Manifest(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    schemaVersion: '1.0',
    packageId: 'com.exchange.rc1.e2e.backend',
    version: '1.0.0',
    publisher: { id: 'pub-1', name: 'RC1 E2E Publisher' },
    title: 'RC1 E2E Backend Package',
    summary: 'WP-EXC-014 backend vertical-slice fixture.',
    description: 'Seeded by the WP-EXC-014 real-server test to prove search/detail/download/checksum.',
    category: 'Automotive',
    engineeringDomains: ['Automotive'],
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
 * WP-EXC-014 (Exchange RC1 End-to-End Verification), Tier A: proves
 * `apps/exchange-api`'s own real, unmodified backend -- real PostgreSQL,
 * real `LocalPackageFileStorage`, real Fastify route handlers via
 * `.inject()` (this repository's own established "real dispatch,
 * not a mock" test mechanism; see every other file under
 * `apps/exchange-api/src/routes/*.test.ts`) -- genuinely performs RC1
 * steps 1-4: seed a publisher and a real package archive through the
 * real `POST /packages/upload` route, confirm it is discoverable
 * through the real `GET /search`, confirm its detail through the real
 * `GET /packages/{id}`, and confirm `GET /packages/{id}/download`
 * returns the exact original bytes plus an `X-Checksum-Sha256` header
 * that matches their real SHA-256.
 *
 * This is the Postgres-backed half of WP-EXC-014's vertical slice; the
 * Foundation-install half (checksum verification through
 * `ExchangeInstallBridge`, `FoundationBridge.installPackage`,
 * Repository registration, Engineering Object/Relationship creation) is
 * proven separately and directly in
 * `platform/oep_studio/test/exchange_rc1_e2e_test.dart`, which
 * substitutes a minimal local HTTP server for this real one only because
 * this sandbox's local PostgreSQL has no `oep_exchange` role configured
 * (the exact same, pre-existing condition that already gates this file
 * itself and 17 others -- see `db/README.md` "Testing without a live
 * database"). Wherever a real test database *is* configured, this file
 * runs for real and both tiers together are the full, real, unmocked
 * RC1 vertical slice.
 */
const databaseAvailable = await isTestDatabaseAvailable();

describe.skipIf(!databaseAvailable)('WP-EXC-014 RC1 vertical slice (real Exchange API backend)', () => {
  let pool: Pool;
  let app: FastifyInstance;
  let storageDir: string;
  let publisher: Publisher;

  beforeAll(async () => {
    pool = (await setupTestDatabase())!;
    storageDir = await mkdtemp(join(tmpdir(), 'oep-exchange-rc1-e2e-'));
    app = await buildApp({ db: pool, storage: new LocalPackageFileStorage(storageDir) });
  });

  beforeEach(async () => {
    await truncateAllTables(pool);
    publisher = await new PostgresPublisherRepository(pool).create({
      name: 'RC1 E2E Publisher LLC',
      displayName: 'RC1 E2E Publisher',
      namespace: `com.test.${randomUUID()}`,
      publisherType: 'individual',
    });
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
    await rm(storageDir, { recursive: true, force: true });
  });

  test('AC-01/AC-02/AC-03/AC-04: a seeded package is searchable, retrievable, and downloads with a verifiable checksum', async () => {
    const archive = buildArchive(rc1Manifest());
    const expectedChecksum = createHash('sha256').update(archive).digest('hex');

    const uploadBody = buildMultipartBody(
      { publisherId: publisher.id },
      { name: 'rc1-e2e-backend-1.0.0.oep', buffer: archive },
    );
    const uploadResponse = await app.inject({
      method: 'POST',
      url: '/api/v1/packages/upload',
      headers: { 'content-type': `multipart/form-data; boundary=${BOUNDARY}` },
      payload: uploadBody,
    });
    expect(uploadResponse.statusCode).toBe(201);
    const uploaded = uploadResponse.json();
    const packageId = uploaded.packageId as string;

    // AC-01: real search finds it.
    const searchResponse = await app.inject({
      method: 'GET',
      url: `/api/v1/search?q=${encodeURIComponent('RC1 E2E Backend Package')}`,
    });
    expect(searchResponse.statusCode).toBe(200);
    const searchResult = searchResponse.json();
    expect(searchResult.items.map((item: { packageId: string }) => item.packageId)).toContain(packageId);

    // AC-02: real package detail.
    const detailResponse = await app.inject({ method: 'GET', url: `/api/v1/packages/${packageId}` });
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.json().currentVersion).toBe('1.0.0');

    // AC-03/AC-04: real download returns the exact original bytes, with
    // a checksum header the client/install bridge can verify against.
    const downloadResponse = await app.inject({
      method: 'GET',
      url: `/api/v1/packages/${packageId}/download`,
    });
    expect(downloadResponse.statusCode).toBe(200);
    expect(downloadResponse.headers['x-checksum-sha256']).toBe(expectedChecksum);
    expect(Buffer.compare(downloadResponse.rawPayload, archive)).toBe(0);
  });
});
