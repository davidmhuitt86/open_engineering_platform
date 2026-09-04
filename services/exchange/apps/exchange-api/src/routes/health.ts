import type { HealthCheckResponse } from '@oep-exchange/api-contracts';
import { EXCHANGE_API_VERSION } from '@oep-exchange/api-contracts';
import type { FastifyInstance } from 'fastify';

/** `GET /api/v1/health` — a liveness check with no dependency on the database. */
export async function registerHealthRoute(app: FastifyInstance): Promise<void> {
  app.get(
    '/health',
    {
      schema: {
        description: 'Liveness check.',
        response: {
          200: {
            type: 'object',
            properties: {
              status: { type: 'string', enum: ['ok'] },
              version: { type: 'string' },
            },
            required: ['status', 'version'],
          },
        },
      },
    },
    async (): Promise<HealthCheckResponse> => ({ status: 'ok', version: EXCHANGE_API_VERSION }),
  );
}
