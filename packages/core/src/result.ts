/**
 * Explicit success/failure for operations whose failure is an expected,
 * handled outcome (validation, lookup misses, business-rule rejection)
 * rather than a programmer error — those still throw. Consumers switch
 * on `.ok` rather than wrapping every call in try/catch.
 */
export type Result<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

export function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}
