import type { CreatePublisherRequest, UpdatePublisherRequest } from '@oep-exchange/api-contracts';
import type { FastifyInstance } from 'fastify';
import type { PublisherService } from '../services/publisher-service.js';

const PUBLISHER_TYPE_ENUM = [
  'individual',
  'company',
  'oem',
  'educational_institution',
  'government',
  'standards_organization',
  'enterprise',
  'community_organization',
];
const PUBLISHER_STATUS_ENUM = ['active', 'suspended'];

const publisherResponseSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    namespace: { type: 'string' },
    publisherType: { type: 'string', enum: PUBLISHER_TYPE_ENUM },
    displayName: { type: 'string' },
    legalName: { type: 'string' },
    description: { type: 'string' },
    website: { type: 'string' },
    contactEmail: { type: 'string' },
    status: { type: 'string', enum: PUBLISHER_STATUS_ENUM },
    createdAt: { type: 'string' },
    updatedAt: { type: 'string' },
  },
  required: [
    'id',
    'namespace',
    'publisherType',
    'displayName',
    'legalName',
    'description',
    'website',
    'contactEmail',
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

const createPublisherBodySchema = {
  type: 'object',
  properties: {
    namespace: { type: 'string' },
    publisherType: { type: 'string', enum: PUBLISHER_TYPE_ENUM },
    displayName: { type: 'string' },
    legalName: { type: 'string' },
    contactEmail: { type: 'string' },
    description: { type: 'string' },
    website: { type: 'string' },
  },
  required: ['namespace', 'publisherType', 'displayName', 'legalName', 'contactEmail'],
} as const;

const updatePublisherBodySchema = {
  type: 'object',
  properties: {
    displayName: { type: 'string' },
    contactEmail: { type: 'string' },
    description: { type: 'string' },
    website: { type: 'string' },
    status: { type: 'string', enum: PUBLISHER_STATUS_ENUM },
  },
} as const;

/**
 * `/publishers` REST routes (docs/tasks/WP-EXC-003.md §4). Thin per
 * CONTRIBUTING_ARCHITECTURE.md rule 8: parse/validate the request via
 * Fastify's JSON Schema, call `PublisherService`, shape the response —
 * every actual business rule (required fields, duplicate detection,
 * status transitions) lives in the service and its validation module.
 */
export async function registerPublisherRoutes(
  app: FastifyInstance,
  service: PublisherService,
): Promise<void> {
  app.get(
    '/publishers',
    {
      schema: {
        description: 'List Publishers.',
        response: {
          200: {
            type: 'object',
            properties: { publishers: { type: 'array', items: publisherResponseSchema } },
            required: ['publishers'],
          },
        },
      },
    },
    async () => ({ publishers: await service.list() }),
  );

  app.get(
    '/publishers/:id',
    {
      schema: {
        description: 'Get a Publisher by id.',
        params: idParamsSchema,
        response: { 200: publisherResponseSchema },
      },
    },
    async (request) => {
      const { id } = request.params as { id: string };
      return service.getById(id);
    },
  );

  app.post(
    '/publishers',
    {
      schema: {
        description: 'Register a new Publisher.',
        body: createPublisherBodySchema,
        response: { 201: publisherResponseSchema },
      },
    },
    async (request, reply) => {
      const publisher = await service.create(request.body as CreatePublisherRequest);
      reply.status(201);
      return publisher;
    },
  );

  app.put(
    '/publishers/:id',
    {
      schema: {
        description: 'Update a Publisher.',
        params: idParamsSchema,
        body: updatePublisherBodySchema,
        response: { 200: publisherResponseSchema },
      },
    },
    async (request) => {
      const { id } = request.params as { id: string };
      return service.update(id, request.body as UpdatePublisherRequest);
    },
  );

  app.delete(
    '/publishers/:id',
    {
      schema: {
        description: 'Delete (soft-delete) a Publisher.',
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
