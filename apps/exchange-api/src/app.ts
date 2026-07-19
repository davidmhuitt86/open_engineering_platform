import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { EXCHANGE_API_VERSION } from '@oep-exchange/api-contracts';
import Fastify, { type FastifyInstance } from 'fastify';
import { registerErrorHandler } from './error-handler.js';
import { registerHealthRoute } from './routes/health.js';

export interface BuildAppOptions {
  logger?: boolean;
}

/**
 * Builds a Fastify instance without starting it listening — kept
 * separate from `server.ts`'s `start()` so tests can exercise routes via
 * `app.inject()` (in-process, no real socket) rather than needing a
 * live port.
 */
export async function buildApp(options: BuildAppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({ logger: options.logger ?? false });

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

  await app.register(
    async (api) => {
      await registerHealthRoute(api);
    },
    { prefix: `/api/${EXCHANGE_API_VERSION}` },
  );

  return app;
}
