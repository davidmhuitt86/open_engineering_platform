import { ValidationError } from '@oep-exchange/core';
import type { NormalizedSearchQuery, PackageStatusFilter, RawSearchQuery } from './types.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STATUS_VALUES = new Set(['draft', 'published', 'deprecated', 'suspended']);
const SORT_BY_VALUES = new Set(['name', 'createdAt', 'updatedAt']);
const SORT_DIRECTION_VALUES = new Set(['asc', 'desc']);

const DEFAULT_PAGE = 1;
const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;
const DEFAULT_SORT_BY = 'createdAt';
const DEFAULT_SORT_DIRECTION = 'desc';

/**
 * Validates and defaults a raw REST search query (WP-EXC-006.md
 * §5/§6/§7/§8). Enum-valued fields (`status`, `sortBy`, `sortDirection`)
 * and identifier format (`publisherId`/`categoryId`) throw
 * `ValidationError` when malformed; `page`/`pageSize` are clamped to
 * sane bounds instead of rejected, matching common REST pagination
 * practice — an out-of-range page number isn't a client error, it's
 * just a page with no results.
 */
export function normalizeSearchQuery(raw: RawSearchQuery): NormalizedSearchQuery {
  if (raw.publisherId !== undefined && !UUID_PATTERN.test(raw.publisherId)) {
    throw new ValidationError(`"${raw.publisherId}" is not a valid Publisher identifier.`, {
      publisherId: raw.publisherId,
    });
  }
  if (raw.categoryId !== undefined && !UUID_PATTERN.test(raw.categoryId)) {
    throw new ValidationError(`"${raw.categoryId}" is not a valid Category identifier.`, {
      categoryId: raw.categoryId,
    });
  }
  if (raw.status !== undefined && !STATUS_VALUES.has(raw.status)) {
    throw new ValidationError(`"${raw.status}" is not a recognized Package status.`, {
      status: raw.status,
    });
  }
  if (raw.sortBy !== undefined && !SORT_BY_VALUES.has(raw.sortBy)) {
    throw new ValidationError(`"${raw.sortBy}" is not a recognized sort field.`, {
      sortBy: raw.sortBy,
    });
  }
  if (raw.sortDirection !== undefined && !SORT_DIRECTION_VALUES.has(raw.sortDirection)) {
    throw new ValidationError(`"${raw.sortDirection}" is not a recognized sort direction.`, {
      sortDirection: raw.sortDirection,
    });
  }

  const page = clampInteger(raw.page, DEFAULT_PAGE, 1, Number.MAX_SAFE_INTEGER);
  const pageSize = clampInteger(raw.pageSize, DEFAULT_PAGE_SIZE, 1, MAX_PAGE_SIZE);

  return {
    ...(raw.q?.trim() ? { keyword: raw.q.trim() } : {}),
    ...(raw.publisherId !== undefined ? { publisherId: raw.publisherId } : {}),
    ...(raw.categoryId !== undefined ? { categoryId: raw.categoryId } : {}),
    ...(raw.status !== undefined ? { status: raw.status as PackageStatusFilter } : {}),
    sortBy: (raw.sortBy as NormalizedSearchQuery['sortBy']) ?? DEFAULT_SORT_BY,
    sortDirection:
      (raw.sortDirection as NormalizedSearchQuery['sortDirection']) ?? DEFAULT_SORT_DIRECTION,
    page,
    pageSize,
  };
}

function clampInteger(raw: string | undefined, fallback: number, min: number, max: number): number {
  if (raw === undefined) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, min), max);
}
