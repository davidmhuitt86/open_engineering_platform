/**
 * Invokes the Package Transaction Engine and Repository Merge Engine, through public Repository interfaces only, to install a downloaded package into an OEP Repository.
 *
 * Status: Real implementation (TASK-EXC-0008, Repository Integration).
 * `apps/exchange-api`'s `InstallationService` is the only consumer — it
 * resolves the Package/version/artifact and hands the bytes to a
 * `RepositoryClient` implementation from this package.
 */
export const PACKAGE_NAME = '@oep-exchange/installer' as const;

export type {
  RepositoryClient,
  RepositoryInstallRequest,
  RepositoryInstallResult,
} from '@oep-exchange/interfaces';
export { HttpRepositoryClient } from './http-repository-client.js';
export type { HttpRepositoryClientOptions } from './http-repository-client.js';
export { StubRepositoryClient } from './stub-repository-client.js';
export type { StubRepositoryClientOptions } from './stub-repository-client.js';
