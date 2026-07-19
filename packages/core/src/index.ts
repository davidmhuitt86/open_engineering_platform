export type { Result } from './result.js';
export { ok, err } from './result.js';
export {
  DomainError,
  NotFoundError,
  ValidationError,
  ForbiddenError,
  ConflictError,
} from './errors.js';
export { newId } from './id.js';
export type { Clock } from './clock.js';
export { SystemClock } from './clock.js';
