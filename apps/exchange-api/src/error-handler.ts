import { toApiErrorResponse } from '@oep-exchange/api-contracts';
import { DomainError } from '@oep-exchange/core';
import type { FastifyInstance } from 'fastify';

/**
 * Maps a thrown `DomainError` to the shared `ApiErrorResponse` envelope
 * with an appropriate HTTP status, so every future route (TASK-EXC-0003
 * onward) can simply `throw new NotFoundError(...)` / `throw new
 * ValidationError(...)` etc. and get a consistent response, instead of
 * each route handler building its own error JSON.
 */
export function registerErrorHandler(app: FastifyInstance): void {
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof DomainError) {
      const status = statusForCode(error.code);
      reply.status(status).send(toApiErrorResponse(error));
      return;
    }

    app.log.error(error);
    reply
      .status(500)
      .send({ error: { code: 'INTERNAL_ERROR', message: 'An unexpected error occurred.' } });
  });
}

function statusForCode(code: string): number {
  switch (code) {
    case 'NOT_FOUND':
      return 404;
    case 'VALIDATION_ERROR':
      return 400;
    case 'FORBIDDEN':
      return 403;
    case 'CONFLICT':
      return 409;
    default:
      return 400;
  }
}
