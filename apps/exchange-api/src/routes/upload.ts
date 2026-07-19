import { ValidationError } from '@oep-exchange/core';
import type { FastifyInstance } from 'fastify';
import type { UploadService } from '../services/upload-service.js';

interface MultipartFieldPart {
  type: 'field';
  value: string;
}

interface MultipartFilePart {
  type: 'file';
  filename: string;
  mimetype: string;
  toBuffer(): Promise<Buffer>;
}

type MultipartPart = MultipartFieldPart | MultipartFilePart;

function isFilePart(part: MultipartPart | undefined): part is MultipartFilePart {
  return part?.type === 'file';
}

function isFieldPart(part: MultipartPart | undefined): part is MultipartFieldPart {
  return part?.type === 'field';
}

const uploadResponseSchema = {
  type: 'object',
  properties: {
    packageId: { type: 'string' },
    packageVersionId: { type: 'string' },
    packageFileId: { type: 'string' },
    version: { type: 'string' },
    fileName: { type: 'string' },
    sizeBytes: { type: 'number' },
    sha256: { type: 'string' },
    uploadedAt: { type: 'string' },
  },
  required: [
    'packageId',
    'packageVersionId',
    'packageFileId',
    'version',
    'fileName',
    'sizeBytes',
    'sha256',
    'uploadedAt',
  ],
} as const;

/**
 * `POST /packages/upload` (docs/tasks/WP-EXC-005.md §4) — a
 * `multipart/form-data` request carrying the `.oep` package archive
 * (field `file`) plus `publisherId` (required) and `categoryId`
 * (optional) form fields. Thin per CONTRIBUTING_ARCHITECTURE.md rule 8:
 * this handler only extracts the multipart parts and calls
 * `UploadService` — every actual pipeline step (parsing, extraction,
 * validation, registration) lives there.
 *
 * No `body` JSON Schema is declared here: `@fastify/multipart`'s
 * `attachFieldsToBody` wraps every part in a `{ type, value | toBuffer
 * }` envelope that doesn't correspond to the plain-object shape Fastify's
 * schema validator expects, so validation happens in the handler and
 * `UploadService` instead (the same place it would happen regardless).
 */
export async function registerUploadRoute(
  app: FastifyInstance,
  service: UploadService,
): Promise<void> {
  app.post(
    '/packages/upload',
    {
      schema: {
        description: 'Upload a .oep package archive and register it with the Package Catalog.',
        consumes: ['multipart/form-data'],
        response: { 201: uploadResponseSchema },
      },
    },
    async (request, reply) => {
      const body = request.body as Record<string, MultipartPart> | undefined;

      const filePart = body?.file;
      if (!isFilePart(filePart)) {
        throw new ValidationError('No package file was uploaded.');
      }

      const publisherIdPart = body?.publisherId;
      if (!isFieldPart(publisherIdPart) || !publisherIdPart.value) {
        throw new ValidationError('Missing required field(s): publisherId.', {
          missing: ['publisherId'],
        });
      }

      const categoryIdPart = body?.categoryId;
      const categoryId = isFieldPart(categoryIdPart) ? categoryIdPart.value : undefined;

      const fileBuffer = await filePart.toBuffer();

      const result = await service.upload({
        publisherId: publisherIdPart.value,
        ...(categoryId ? { categoryId } : {}),
        fileBuffer,
        fileName: filePart.filename,
      });

      reply.status(201);
      return result;
    },
  );
}
