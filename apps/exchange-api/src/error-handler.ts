import { toApiErrorResponse } from '@oep-exchange/api-contracts';
import { DomainError, ValidationError } from '@oep-exchange/core';
import type { FastifyError, FastifyInstance } from 'fastify';

/**
 * Maps a thrown `DomainError` to the shared `ApiErrorResponse` envelope
 * with an appropriate HTTP status, so every route can simply `throw new
 * NotFoundError(...)` / `throw new ValidationError(...)` etc. and get a
 * consistent response, instead of each route handler building its own
 * error JSON. Also maps Fastify's own request-schema validation
 * failures (`error.validation`, e.g. a POST /publishers body missing a
 * required field) to the same envelope at 400 — without this, such an
 * error is neither a `DomainError` nor left alone by Fastify (it would
 * otherwise fall through to the generic 500 branch below, since it's a
 * plain `FastifyError`).
 */
export function registerErrorHandler(app: FastifyInstance): void {
  app.setErrorHandler<FastifyError>((error, _request, reply) => {
    if (error instanceof DomainError) {
      const status = statusForCode(error.code);
      reply.status(status).send(toApiErrorResponse(error));
      return;
    }

    if (error.validation) {
      const validationError = new ValidationError(error.message, { validation: error.validation });
      reply.status(400).send(toApiErrorResponse(validationError));
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
