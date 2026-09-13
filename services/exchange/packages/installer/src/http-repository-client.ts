import type {
  RepositoryClient,
  RepositoryInstallRequest,
  RepositoryInstallResult,
} from '@oep-exchange/interfaces';

export interface HttpRepositoryClientOptions {
  /** The Repository's base URL (e.g. `http://localhost:8080`). No trailing slash required. */
  baseUrl: string;
  /** Injectable for testing — defaults to the global `fetch`. */
  fetchFn?: typeof fetch;
}

interface RepositoryInstallResponseBody {
  accepted?: boolean;
  repositoryPackageId?: string;
  message?: string;
}

/**
 * The real `RepositoryClient` (docs/tasks/WP-EXC-008.md §7) — reaches the
 * Repository exclusively over HTTP against its published install
 * endpoint, never through a source-level import of any
 * `oep_foundation`/`oep_repository` code (`docs/architecture/
 * DEPENDENCY_GRAPH.md` §5: "a network call (REST/HTTP) against a
 * published API, never a source-level import"). The artifact is sent
 * base64-encoded in a JSON body — no assumption is made about the
 * endpoint beyond what WP-EXC-008.md itself anticipates ("Repository
 * Public API"); this is a plain POST to a configurable base URL, not a
 * dependency on any concrete Repository implementation (which is
 * explicitly out of this task's scope, WP-EXC-008.md §2).
 */
export class HttpRepositoryClient implements RepositoryClient {
  private readonly baseUrl: string;
  private readonly fetchFn: typeof fetch;

  constructor(options: HttpRepositoryClientOptions) {
    this.baseUrl = options.baseUrl.replace(/\/+$/, '');
    this.fetchFn = options.fetchFn ?? fetch;
  }

  async install(request: RepositoryInstallRequest): Promise<RepositoryInstallResult> {
    let response: Response;
    try {
      response = await this.fetchFn(`${this.baseUrl}/api/v1/packages/install`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          packageId: request.packageId,
          version: request.version,
          sha256: request.sha256,
          fileName: request.fileName,
          artifactBase64: request.artifact.toString('base64'),
        }),
      });
    } catch (error) {
      return {
        accepted: false,
        message: `Could not reach the Repository: ${error instanceof Error ? error.message : String(error)}`,
      };
    }

    if (!response.ok) {
      return { accepted: false, message: `The Repository responded with HTTP ${response.status}.` };
    }

    const body = (await response.json()) as RepositoryInstallResponseBody;
    return {
      accepted: body.accepted === true,
      ...(body.repositoryPackageId !== undefined
        ? { repositoryPackageId: body.repositoryPackageId }
        : {}),
      ...(body.message !== undefined ? { message: body.message } : {}),
    };
  }
}
