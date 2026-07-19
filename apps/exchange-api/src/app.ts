import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { EXCHANGE_API_VERSION } from '@oep-exchange/api-contracts';
import Fastify, { type FastifyInstance } from 'fastify';
import { registerErrorHandler } from './error-handler.js';
import {
  createPool,
  PostgresAuditRepository,
  PostgresCategoryRepository,
  PostgresPackageRepository,
  PostgresPackageVersionRepository,
  PostgresPublisherProfileRepository,
  PostgresPublisherRepository,
  type Queryable,
} from './persistence/index.js';
import { registerHealthRoute } from './routes/health.js';
import { registerPackageRoutes } from './routes/packages.js';
import { registerPublisherRoutes } from './routes/publishers.js';
import { PackageService } from './services/package-service.js';
import { PublisherService } from './services/publisher-service.js';

export interface BuildAppOptions {
  logger?: boolean;
  /** Injectable database connection — defaults to `createPool()`. Tests pass a pool pointed at a test database. */
  db?: Queryable;
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

  await app.register(swagger, {
    openapi: {
      info: {
        title: 'OEP Engineering Exchange API',
        version: EXCHANGE_API_VERSION,
      },
    },
  });
  await app.register(swaggerUi, { routePrefix: '/documentation' });

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

  await app.register(
    async (api) => {
      await registerHealthRoute(api);
      await registerPublisherRoutes(api, publisherService);
      await registerPackageRoutes(api, packageService);
    },
    { prefix: `/api/${EXCHANGE_API_VERSION}` },
  );

  return app;
}
