import { randomUUID } from 'node:crypto';

/** Generates a new random identifier (UUID v4) for a new entity. */
export function newId(): string {
  return randomUUID();
}
