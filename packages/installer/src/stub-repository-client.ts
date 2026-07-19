import type {
  RepositoryClient,
  RepositoryInstallRequest,
  RepositoryInstallResult,
} from '@oep-exchange/interfaces';

export interface StubRepositoryClientOptions {
  /** When `true`, every install attempt reports rejection — exercises the failure path (WP-EXC-008.md §6 "Repository response"). */
  simulateFailure?: boolean;
  /** The rejection message used when `simulateFailure` is set. */
  failureMessage?: string;
}

/**
 * A deterministic, in-memory stand-in `RepositoryClient` — no real OEP
 * Repository exists to integrate against yet, and "Repository
 * implementation" is explicitly excluded from this task's scope
 * (WP-EXC-008.md §2). This lets `InstallationService` and its callers be
 * fully built, wired, and tested end to end today; swapping in
 * `HttpRepositoryClient` once a real Repository is reachable requires no
 * change to `InstallationService` itself, since both implement the same
 * `RepositoryClient` contract.
 */
export class StubRepositoryClient implements RepositoryClient {
  constructor(private readonly options: StubRepositoryClientOptions = {}) {}

  async install(request: RepositoryInstallRequest): Promise<RepositoryInstallResult> {
    if (this.options.simulateFailure) {
      return {
        accepted: false,
        message: this.options.failureMessage ?? 'The Repository rejected the installation request.',
      };
    }

    return {
      accepted: true,
      repositoryPackageId: `stub-${request.packageId}@${request.version}`,
    };
  }
}
