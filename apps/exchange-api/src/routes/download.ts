import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type { DownloadResult, DownloadService } from '../services/download-service.js';

const idParamsSchema = {
  type: 'object',
  properties: { id: { type: 'string' } },
  required: ['id'],
} as const;

const versionParamsSchema = {
  type: 'object',
  properties: { id: { type: 'string' }, version: { type: 'string' } },
  required: ['id', 'version'],
} as const;

function clientInfo(request: FastifyRequest): { clientIp: string; userAgent: string | null } {
  return { clientIp: request.ip, userAgent: request.headers['user-agent'] ?? null };
}

/**
 * `/packages/{id}/download` and `/packages/{id}/versions/{version}/download`
 * (docs/tasks/WP-EXC-007.md §4). Thin per CONTRIBUTING_ARCHITECTURE.md
 * rule 8: extract path params and client info, call `DownloadService`,
 * and shape the binary response (WP-EXC-007.md §8 "Download metadata" is
 * carried as response headers — filename, checksum, resolved version —
 * alongside the raw artifact bytes, which is what §5 "Return package
 * artifact" means for a download endpoint). No response JSON Schema is
 * declared for the 200 case since the body is an opaque binary blob, not
 * JSON.
 */
export async function registerDownloadRoutes(
  app: FastifyInstance,
  service: DownloadService,
): Promise<void> {
  app.get(
    '/packages/:id/download',
    {
      schema: {
        description: "Download a Package's current (latest) version.",
        params: idParamsSchema,
      },
    },
    async (request, reply) => {
      const { id } = request.params as { id: string };
      const result = await service.downloadLatest(id, clientInfo(request));
      return sendArtifact(reply, result);
    },
  );

  app.get(
    '/packages/:id/versions/:version/download',
    {
      schema: {
        description: 'Download one specific Package version.',
        params: versionParamsSchema,
      },
    },
    async (request, reply) => {
      const { id, version } = request.params as { id: string; version: string };
      const result = await service.downloadVersion(id, version, clientInfo(request));
      return sendArtifact(reply, result);
    },
  );
}

function sendArtifact(reply: FastifyReply, result: DownloadResult): Buffer {
  reply
    .header('Content-Type', result.mimeType)
    .header('Content-Length', result.sizeBytes)
    .header('Content-Disposition', `attachment; filename="${result.fileName}"`)
    .header('X-Checksum-Sha256', result.sha256)
    .header('X-Package-Id', result.packageId)
    .header('X-Package-Version', result.version)
    .status(200);
  return result.buffer;
}
