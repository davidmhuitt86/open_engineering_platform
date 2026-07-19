import type { DomainError } from '@oep-exchange/core';

/**
 * The wire shape every failed Exchange API response uses — a thin,
 * stable envelope around `DomainError`'s own `code`/`message`/`details`,
 * so a `DomainError` thrown anywhere in a route handler can be
 * serialized consistently without each route hand-rolling its own error
 * JSON shape.
 */
export interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

export function toApiErrorResponse(error: DomainError): ApiErrorResponse {
  return {
    error: {
      code: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
    },
  };
}
