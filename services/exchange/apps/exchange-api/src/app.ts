import multipart from '@fastify/multipart';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { EXCHANGE_API_VERSION } from '@oep-exchange/api-contracts';
import { StubRepositoryClient, type RepositoryClient } from '@oep-exchange/installer';
import Fastify, { type FastifyInstance } from 'fastify';
import { registerErrorHandler } from './error-handler.js';
import {
  createPool,
  PostgresAuditRepository,
  PostgresCategoryRepository,
  PostgresDownloadRepository,
  PostgresInstallationRepository,
  PostgresPackageFileRepository,
  PostgresPackageRepository,
  PostgresPackageVersionRepository,
  PostgresPublisherProfileRepository,
  PostgresPublisherRepository,
  PostgresSearchRepository,
  type Queryable,
} from './persistence/index.js';
import { registerDownloadRoutes } from './routes/download.js';
import { registerHealthRoute } from './routes/health.js';
import { registerInstallationRoutes } from './routes/installation.js';
import { registerPackageRoutes } from './routes/packages.js';
import { registerPublisherRoutes } from './routes/publishers.js';
import { registerSearchRoute } from './routes/search.js';
import { registerUploadRoute } from './routes/upload.js';
import { DownloadService } from './services/download-service.js';
import { InstallationService } from './services/installation-service.js';
import { PackageService } from './services/package-service.js';
import { PublisherService } from './services/publisher-service.js';
import { SearchService } from './services/search-service.js';
import { UploadService } from './services/upload-service.js';
import {
  LocalPackageFileStorage,
  type PackageFileStorage,
} from './storage/package-file-storage.js';
import { loadStorageDir } from './storage/storage-config.js';

/** 100 MiB — generous for a real `.oep` package while still bounding worst-case memory use for an untrusted upload. */
const MAX_UPLOAD_BYTES = 100 * 1024 * 1024;

export interface BuildAppOptions {
  logger?: boolean;
  /** Injectable database connection — defaults to `createPool()`. Tests pass a pool pointed at a test database. */
  db?: Queryable;
  /** Injectable package artifact storage — defaults to `LocalPackageFileStorage` rooted at `loadStorageDir()`. */
  storage?: PackageFileStorage;
  /**
   * Injectable `RepositoryClient` — defaults to `StubRepositoryClient`,
   * since no real OEP Repository exists to integrate against yet
   * (WP-EXC-008.md §2 explicitly excludes "Repository implementation").
   * Swap in `HttpRepositoryClient` once a real Repository is reachable.
   */
  repositoryClient?: RepositoryClient;
}

/**
 * Builds a Fastify instance without starting it listening — kept
 * separate from `server.ts`'s `start()` so tests can exercise routes via
 * `app.inject()` (in-process, no real socket) rather than needing a
 * live port.
 */
export async function buildApp(options: BuildAppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({ logger: options.logger ?? false });
  const db = options.db ?? createPool();
  const storage = options.storage ?? new LocalPackageFileStorage(loadStorageDir());
  const repositoryClient = options.repositoryClient ?? new StubRepositoryClient();

  await app.register(swagger, {
    openapi: {
      info: {
        title: 'OEP Engineering Exchange API',
        version: EXCHANGE_API_VERSION,
      },
    },
  });
  await app.register(swaggerUi, { routePrefix: '/documentation' });
  await app.register(multipart, {
    attachFieldsToBody: true,
    limits: { fileSize: MAX_UPLOAD_BYTES },
  });

  registerErrorHandler(app);

  const publisherService = new PublisherService(
    new PostgresPublisherRepository(db),
    new PostgresPublisherProfileRepository(db),
    new PostgresAuditRepository(db),
  );

  const packageService = new PackageService(
    new PostgresPackageRepository(db),
    new PostgresPublisherRepository(db),
    new PostgresCategoryRepository(db),
    new PostgresPackageVersionRepository(db),
    new PostgresAuditRepository(db),
  );

  const uploadService = new UploadService(
    new PostgresPackageRepository(db),
    new PostgresPackageVersionRepository(db),
    new PostgresPackageFileRepository(db),
    new PostgresPublisherRepository(db),
    new PostgresCategoryRepository(db),
    storage,
    new PostgresAuditRepository(db),
  );

  const searchService = new SearchService(new PostgresSearchRepository(db));

  const downloadService = new DownloadService(
    new PostgresPackageRepository(db),
    new PostgresPackageVersionRepository(db),
    new PostgresPackageFileRepository(db),
    new PostgresDownloadRepository(db),
    storage,
  );

  const installationService = new InstallationService(
    new PostgresPackageRepository(db),
    new PostgresPackageVersionRepository(db),
    new PostgresPackageFileRepository(db),
    new PostgresInstallationRepository(db),
    storage,
    repositoryClient,
    new PostgresAuditRepository(db),
  );

  await app.register(
    async (api) => {
      await registerHealthRoute(api);
      await registerPublisherRoutes(api, publisherService);
      await registerPackageRoutes(api, packageService);
      await registerUploadRoute(api, uploadService);
      await registerSearchRoute(api, searchService);
      await registerDownloadRoutes(api, downloadService);
      await registerInstallationRoutes(api, installationService);
    },
    { prefix: `/api/${EXCHANGE_API_VERSION}` },
  );

  return app;
}
