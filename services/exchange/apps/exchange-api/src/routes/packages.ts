import type { CreatePackageRequest, UpdatePackageRequest } from '@oep-exchange/api-contracts';
import type { FastifyInstance } from 'fastify';
import type { PackageService } from '../services/package-service.js';

const PACKAGE_STATUS_ENUM = ['draft', 'published', 'deprecated', 'suspended'];

const packageResponseSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    packageId: { type: 'string' },
    publisherId: { type: 'string' },
    displayName: { type: 'string' },
    description: { type: 'string' },
    categoryId: { type: ['string', 'null'] },
    currentVersion: { type: ['string', 'null'] },
    status: { type: 'string', enum: PACKAGE_STATUS_ENUM },
    createdAt: { type: 'string' },
    updatedAt: { type: 'string' },
  },
  required: [
    'id',
    'packageId',
    'publisherId',
    'displayName',
    'description',
    'categoryId',
    'currentVersion',
    'status',
    'createdAt',
    'updatedAt',
  ],
} as const;

const idParamsSchema = {
  type: 'object',
  properties: { id: { type: 'string' } },
  required: ['id'],
} as const;

const createPackageBodySchema = {
  type: 'object',
  properties: {
    packageId: { type: 'string' },
    publisherId: { type: 'string' },
    displayName: { type: 'string' },
    description: { type: 'string' },
    categoryId: { type: ['string', 'null'] },
  },
  required: ['packageId', 'publisherId', 'displayName'],
} as const;

const updatePackageBodySchema = {
  type: 'object',
  properties: {
    displayName: { type: 'string' },
    description: { type: 'string' },
    categoryId: { type: ['string', 'null'] },
    status: { type: 'string', enum: PACKAGE_STATUS_ENUM },
  },
} as const;

/**
 * `/packages` REST routes (docs/tasks/WP-EXC-004.md §4). Thin per
 * CONTRIBUTING_ARCHITECTURE.md rule 8: parse/validate the request via
 * Fastify's JSON Schema, call `PackageService`, shape the response —
 * every actual business rule (required fields, duplicate/reference
 * checks, status transitions) lives in the service and its validation
 * module.
 */
export async function registerPackageRoutes(
  app: FastifyInstance,
  service: PackageService,
): Promise<void> {
  app.get(
    '/packages',
    {
      schema: {
        description: 'List Packages.',
        response: {
          200: {
            type: 'object',
            properties: { packages: { type: 'array', items: packageResponseSchema } },
            required: ['packages'],
          },
        },
      },
    },
    async () => ({ packages: await service.list() }),
  );

  app.get(
    '/packages/:id',
    {
      schema: {
        description: 'Get a Package by id.',
        params: idParamsSchema,
        response: { 200: packageResponseSchema },
      },
    },
    async (request) => {
      const { id } = request.params as { id: string };
      return service.getById(id);
    },
  );

  app.post(
    '/packages',
    {
      schema: {
        description: 'Register a new Package.',
        body: createPackageBodySchema,
        response: { 201: packageResponseSchema },
      },
    },
    async (request, reply) => {
      const pkg = await service.create(request.body as CreatePackageRequest);
      reply.status(201);
      return pkg;
    },
  );

  app.put(
    '/packages/:id',
    {
      schema: {
        description: 'Update a Package.',
        params: idParamsSchema,
        body: updatePackageBodySchema,
        response: { 200: packageResponseSchema },
      },
    },
    async (request) => {
      const { id } = request.params as { id: string };
      return service.update(id, request.body as UpdatePackageRequest);
    },
  );

  app.delete(
    '/packages/:id',
    {
      schema: {
        description: 'Delete (soft-delete) a Package.',
        params: idParamsSchema,
        response: { 204: { type: 'null' } },
      },
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      await service.remove(id);
      reply.status(204);
    },
  );
}
