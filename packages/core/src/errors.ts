/**
 * Base class for expected, handled domain errors (as opposed to
 * programmer errors/bugs, which should throw a plain `Error` or crash).
 * `code` is a stable, machine-readable identifier — safe to expose in
 * API responses and to switch on in client code — distinct from
 * `message`, which is for humans and may change wording over time.
 */
export class DomainError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = new.target.name;
  }
}

/** The requested resource does not exist. */
export class NotFoundError extends DomainError {
  constructor(resource: string, id: string) {
    super('NOT_FOUND', `${resource} "${id}" was not found.`, { resource, id });
  }
}

/** The request failed validation before any state was changed. */
export class ValidationError extends DomainError {
  constructor(message: string, details?: Record<string, unknown>) {
    super('VALIDATION_ERROR', message, details);
  }
}

/** The caller is authenticated but not permitted to perform this action. */
export class ForbiddenError extends DomainError {
  constructor(message = 'You do not have permission to perform this action.') {
    super('FORBIDDEN', message);
  }
}

/** The request conflicts with the resource's current state (e.g. a duplicate). */
export class ConflictError extends DomainError {
  constructor(message: string, details?: Record<string, unknown>) {
    super('CONFLICT', message, details);
  }
}
