import type { RawSearchQuery } from '@oep-exchange/search';
import type { FastifyInstance } from 'fastify';
import type { SearchService } from '../services/search-service.js';

const searchResultItemSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    packageId: { type: 'string' },
    publisherId: { type: 'string' },
    publisherName: { type: 'string' },
    displayName: { type: 'string' },
    description: { type: 'string' },
    categoryId: { type: ['string', 'null'] },
    categoryName: { type: ['string', 'null'] },
    currentVersion: { type: ['string', 'null'] },
    status: { type: 'string' },
    createdAt: { type: 'string' },
    updatedAt: { type: 'string' },
  },
  required: [
    'id',
    'packageId',
    'publisherId',
    'publisherName',
    'displayName',
    'description',
    'categoryId',
    'categoryName',
    'currentVersion',
    'status',
    'createdAt',
    'updatedAt',
  ],
} as const;

const searchQuerystringSchema = {
  type: 'object',
  properties: {
    q: { type: 'string' },
    publisherId: { type: 'string' },
    categoryId: { type: 'string' },
    status: { type: 'string' },
    sortBy: { type: 'string' },
    sortDirection: { type: 'string' },
    page: { type: 'string' },
    pageSize: { type: 'string' },
  },
} as const;

const searchResponseSchema = {
  type: 'object',
  properties: {
    items: { type: 'array', items: searchResultItemSchema },
    totalCount: { type: 'number' },
    totalPages: { type: 'number' },
    currentPage: { type: 'number' },
    pageSize: { type: 'number' },
  },
  required: ['items', 'totalCount', 'totalPages', 'currentPage', 'pageSize'],
} as const;

/**
 * `/search` REST route (docs/tasks/WP-EXC-006.md §4: "GET /api/v1/search").
 * Thin per CONTRIBUTING_ARCHITECTURE.md rule 8 — the query string is
 * passed through to `SearchService` untouched; validation/normalization
 * happens there (via `@oep-exchange/search`), not in this route.
 */
export async function registerSearchRoute(
  app: FastifyInstance,
  service: SearchService,
): Promise<void> {
  app.get(
    '/search',
    {
      schema: {
        description: 'Search the Package Catalog (keyword, filters, sorting, pagination).',
        querystring: searchQuerystringSchema,
        response: { 200: searchResponseSchema },
      },
    },
    async (request) => service.search(request.query as RawSearchQuery),
  );
}
