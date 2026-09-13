/**
 * A typed HTTP client SDK for the Exchange REST API, used by the installer, update service, and both web apps.
 *
 * Status: real implementation (WP-EXC-012, Exchange Client API Foundation)
 * — see `docs/tasks/WP-EXC-012.md`. The `ExchangeApiClient`/`ExchangeApiError`
 * surface below was never committed in either repository's history
 * (confirmed by WP-EXC-011's investigation of the upstream `oep_exchange`
 * repository); it is new code, established from `apps/publisher-portal`'s
 * own existing consumer contract and `apps/exchange-api`'s existing
 * routes — not a restoration, and not a redesign of either.
 */
export const PACKAGE_NAME = '@oep-exchange/exchange-client' as const;

export { ExchangeApiClient } from './client.js';
export type { ExchangeApiClientOptions, SearchParams } from './client.js';
export { ExchangeApiError } from './errors.js';
