import type {
  InstallationDto,
  PackageDto,
  PackageStatus,
  PublisherDto,
  PublisherListResponse,
  SearchResponse,
  SearchSortBy,
  SearchSortDirection,
} from '@oep-exchange/api-contracts';
import { HttpTransport } from './transport.js';

export interface ExchangeApiClientOptions {
  /**
   * The Exchange API's origin/prefix, e.g. `/api/v1` (same-origin, dev
   * server proxied) or `https://exchange.example.com/api/v1`. Never
   * hardcoded to a production hostname -- every caller supplies its own
   * (`apps/publisher-portal/src/api/ExchangeApiClientContext.tsx` passes
   * `/api/v1`).
   */
  baseUrl: string;
  /** Overrides the transport's `fetch` implementation -- tests only; defaults to the global `fetch`. */
  fetch?: typeof fetch;
}

/** `client.search.run(...)` parameters -- the exact field set `GET /search`'s query string accepts (`apps/exchange-api/src/routes/search.ts`). */
export interface SearchParams {
  q?: string;
  publisherId?: string;
  categoryId?: string;
  status?: PackageStatus;
  sortBy?: SearchSortBy;
  sortDirection?: SearchSortDirection;
  page?: number;
  pageSize?: number;
}

class SearchResource {
  constructor(private readonly transport: HttpTransport) {}

  /** `GET /search` -- keyword/filter/sort/paginated Package Catalog search. */
  run(params: SearchParams = {}): Promise<SearchResponse> {
    return this.transport.request<SearchResponse>('GET', '/search', { query: { ...params } });
  }
}

class PackagesResource {
  constructor(private readonly transport: HttpTransport) {}

  /** `GET /packages/{id}`. */
  get(packageId: string): Promise<PackageDto> {
    return this.transport.request<PackageDto>('GET', `/packages/${encodeURIComponent(packageId)}`);
  }
}

class PublishersResource {
  constructor(private readonly transport: HttpTransport) {}

  /** `GET /publishers/{id}`. */
  get(publisherId: string): Promise<PublisherDto> {
    return this.transport.request<PublisherDto>(
      'GET',
      `/publishers/${encodeURIComponent(publisherId)}`,
    );
  }

  /**
   * `GET /publishers`, unwrapped to the flat `PublisherDto[]` array
   * consumers expect -- pinned by
   * `apps/publisher-portal/src/pages/PublishersPage.tsx` (`state.data.length`,
   * `state.data.map(...)`), even though the wire response envelope is
   * `{ publishers: PublisherDto[] }` (`PublisherListResponse`,
   * `@oep-exchange/api-contracts`, matching every route's own response
   * schema). The envelope is the wire contract; the flat array is this
   * client's already-established, test-pinned surface -- both are real,
   * they simply differ at this one boundary.
   */
  async list(): Promise<PublisherDto[]> {
    const response = await this.transport.request<PublisherListResponse>('GET', '/publishers');
    return response.publishers;
  }
}

class InstallationsResource {
  constructor(private readonly transport: HttpTransport) {}

  /** `POST /packages/{id}/install` -- `version` omitted installs the Package's current version. */
  install(packageId: string, version?: string): Promise<InstallationDto> {
    return this.transport.request<InstallationDto>(
      'POST',
      `/packages/${encodeURIComponent(packageId)}/install`,
      { body: version ? { version } : {} },
    );
  }

  /** `GET /installations/{installationId}`. */
  get(installationId: string): Promise<InstallationDto> {
    return this.transport.request<InstallationDto>(
      'GET',
      `/installations/${encodeURIComponent(installationId)}`,
    );
  }
}

class DownloadsResource {
  constructor(private readonly transport: HttpTransport) {}

  /**
   * The download URL for a Package's current version -- a plain string
   * for an `<a href>` (`PackageDetailPage.tsx`), never a `fetch` call:
   * the artifact is a binary response
   * (`apps/exchange-api/src/routes/download.ts`), which the browser's own
   * navigation handles natively.
   */
  url(packageId: string): string {
    return this.transport.buildUrl(`/packages/${encodeURIComponent(packageId)}/download`);
  }
}

/**
 * A typed HTTP client SDK for the Exchange REST API (WP-EXC-009.md §3:
 * "No component shall communicate directly with backend services outside
 * the API client layer"). Every method here maps to an existing
 * `apps/exchange-api` route -- no speculative endpoint was added (see
 * `docs/tasks/WP-EXC-012.md` §3 for the full client-method-to-route
 * matrix).
 */
export class ExchangeApiClient {
  readonly search: SearchResource;
  readonly packages: PackagesResource;
  readonly publishers: PublishersResource;
  readonly installations: InstallationsResource;
  readonly downloads: DownloadsResource;

  constructor(options: ExchangeApiClientOptions) {
    const transport = new HttpTransport(options.baseUrl, options.fetch);
    this.search = new SearchResource(transport);
    this.packages = new PackagesResource(transport);
    this.publishers = new PublishersResource(transport);
    this.installations = new InstallationsResource(transport);
    this.downloads = new DownloadsResource(transport);
  }
}
