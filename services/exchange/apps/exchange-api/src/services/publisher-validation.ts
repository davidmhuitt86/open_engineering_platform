import type {
  CreatePublisherRequest,
  PublisherType,
  UpdatePublisherRequest,
} from '@oep-exchange/api-contracts';
import { ValidationError } from '@oep-exchange/core';
import type { PublisherStatus } from '../persistence/index.js';

/**
 * Pure, DB-free validation (docs/tasks/WP-EXC-003.md §6/§7) — required
 * fields, identifier format, and status-transition rules. Duplicate
 * name/namespace/contact-email checks are data-dependent and are
 * enforced by `PostgresPublisherRepository` instead (its `create`/
 * `update` already throw `ConflictError`); `PublisherService` relies on
 * that rather than re-querying here.
 */

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const PUBLISHER_TYPES: ReadonlySet<PublisherType> = new Set([
  'individual',
  'company',
  'oem',
  'educational_institution',
  'government',
  'standards_organization',
  'enterprise',
  'community_organization',
]);

const PUBLISHER_STATUSES: ReadonlySet<PublisherStatus> = new Set(['active', 'suspended']);

/** Allowed target statuses for a given current status — both directions are valid transitions today; same-state is idempotent. */
const STATUS_TRANSITIONS: Record<PublisherStatus, ReadonlySet<PublisherStatus>> = {
  active: new Set(['active', 'suspended']),
  suspended: new Set(['suspended', 'active']),
};

/** Throws `ValidationError` if `id` is not a well-formed UUID (WP-EXC-003.md §6 "Invalid identifiers"). */
export function validatePublisherId(id: string): void {
  if (!UUID_PATTERN.test(id)) {
    throw new ValidationError(`"${id}" is not a valid Publisher identifier.`, { id });
  }
}

/** Throws `ValidationError` if `input` is missing a required field or has a malformed one. */
export function validateCreatePublisherRequest(input: CreatePublisherRequest): void {
  const missing: string[] = [];
  if (!input.namespace?.trim()) missing.push('namespace');
  if (!input.publisherType) missing.push('publisherType');
  if (!input.displayName?.trim()) missing.push('displayName');
  if (!input.legalName?.trim()) missing.push('legalName');
  if (!input.contactEmail?.trim()) missing.push('contactEmail');
  if (missing.length > 0) {
    throw new ValidationError(`Missing required field(s): ${missing.join(', ')}.`, { missing });
  }

  if (!PUBLISHER_TYPES.has(input.publisherType)) {
    throw new ValidationError(`"${input.publisherType}" is not a recognized publisher type.`, {
      publisherType: input.publisherType,
    });
  }

  if (!EMAIL_PATTERN.test(input.contactEmail)) {
    throw new ValidationError(`"${input.contactEmail}" is not a valid email address.`, {
      contactEmail: input.contactEmail,
    });
  }
}

/** Throws `ValidationError` if any provided field in `input` is malformed. */
export function validateUpdatePublisherRequest(input: UpdatePublisherRequest): void {
  if (input.displayName !== undefined && !input.displayName.trim()) {
    throw new ValidationError('displayName cannot be blank.');
  }

  if (
    input.contactEmail !== undefined &&
    input.contactEmail !== '' &&
    !EMAIL_PATTERN.test(input.contactEmail)
  ) {
    throw new ValidationError(`"${input.contactEmail}" is not a valid email address.`, {
      contactEmail: input.contactEmail,
    });
  }
}

/** Throws `ValidationError` for an unrecognized status or a transition not permitted from `current`. */
export function validateStatusTransition(current: PublisherStatus, requested: string): void {
  if (!PUBLISHER_STATUSES.has(requested as PublisherStatus)) {
    throw new ValidationError(`"${requested}" is not a recognized Publisher status.`, {
      status: requested,
    });
  }

  const allowed = STATUS_TRANSITIONS[current];
  if (!allowed.has(requested as PublisherStatus)) {
    throw new ValidationError(
      `Cannot transition Publisher status from "${current}" to "${requested}".`,
      { from: current, to: requested },
    );
  }
}
