import type { InstallRequest } from '@oep-exchange/api-contracts';
import type { FastifyInstance } from 'fastify';
import type { InstallationService } from '../services/installation-service.js';

const INSTALLATION_STATUS_ENUM = ['pending', 'completed', 'failed'];

const installationResponseSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    packageId: { type: 'string' },
    version: { type: 'string' },
    status: { type: 'string', enum: INSTALLATION_STATUS_ENUM },
    repositoryPackageId: { type: ['string', 'null'] },
    errorMessage: { type: ['string', 'null'] },
    requestedAt: { type: 'string' },
    completedAt: { type: ['string', 'null'] },
  },
  required: [
    'id',
    'packageId',
    'version',
    'status',
    'repositoryPackageId',
    'errorMessage',
    'requestedAt',
    'completedAt',
  ],
} as const;

const packageIdParamsSchema = {
  type: 'object',
  properties: { id: { type: 'string' } },
  required: ['id'],
} as const;

const installationIdParamsSchema = {
  type: 'object',
  properties: { installationId: { type: 'string' } },
  required: ['installationId'],
} as const;

const installBodySchema = {
  type: 'object',
  properties: { version: { type: 'string' } },
} as const;

/**
 * `/packages/{id}/install` and `/installations/{installationId}`
 * (docs/tasks/WP-EXC-008.md §4). Thin per CONTRIBUTING_ARCHITECTURE.md
 * rule 8: parse the request and call `InstallationService`, which owns
 * every actual validation/orchestration step.
 */
export async function registerInstallationRoutes(
  app: FastifyInstance,
  service: InstallationService,
): Promise<void> {
  app.post(
    '/packages/:id/install',
    {
      schema: {
        description:
          "Install a Package version into an OEP Repository (the Package's current version when body.version is omitted).",
        params: packageIdParamsSchema,
        body: installBodySchema,
        response: { 201: installationResponseSchema },
      },
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const body = (request.body as InstallRequest | undefined) ?? {};
      const installation = await service.install(id, body.version);
      reply.status(201);
      return installation;
    },
  );

  app.get(
    '/installations/:installationId',
    {
      schema: {
        description: 'Get the status of a past installation attempt.',
        params: installationIdParamsSchema,
        response: { 200: installationResponseSchema },
      },
    },
    async (request) => {
      const { installationId } = request.params as { installationId: string };
      return service.getById(installationId);
    },
  );
}
