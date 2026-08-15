import type { PackageStatus, SearchSortBy, SearchSortDirection } from '@oep-exchange/api-contracts';
import { useSearchParams } from 'react-router-dom';
import { useExchangeApiClient } from '../api/ExchangeApiClientContext.js';
import { Breadcrumbs } from '../components/Breadcrumbs.js';
import { ErrorView } from '../components/ErrorView.js';
import { LoadingIndicator } from '../components/LoadingIndicator.js';
import { PackageList } from '../components/PackageList.js';
import { Pagination } from '../components/Pagination.js';
import { SearchBar } from '../components/SearchBar.js';
import { useAsync } from '../hooks/use-async.js';
import { searchItemToPackageCardProps } from '../lib/to-package-card-props.js';

const STATUS_OPTIONS: PackageStatus[] = ['draft', 'published', 'deprecated', 'suspended'];
const SORT_BY_OPTIONS: { value: SearchSortBy; label: string }[] = [
  { value: 'createdAt', label: 'Newest' },
  { value: 'updatedAt', label: 'Recently updated' },
  { value: 'name', label: 'Name' },
];

export function SearchResultsPage(): JSX.Element {
  const client = useExchangeApiClient();
  const [searchParams, setSearchParams] = useSearchParams();

  const q = searchParams.get('q') ?? '';
  const categoryId = searchParams.get('categoryId') ?? undefined;
  const publisherId = searchParams.get('publisherId') ?? undefined;
  const status = (searchParams.get('status') as PackageStatus | null) ?? undefined;
  const sortBy = (searchParams.get('sortBy') as SearchSortBy | null) ?? 'createdAt';
  const sortDirection = (searchParams.get('sortDirection') as SearchSortDirection | null) ?? 'desc';
  const page = Number.parseInt(searchParams.get('page') ?? '1', 10) || 1;

  const state = useAsync(
    () =>
      client.search.run({
        ...(q ? { q } : {}),
        ...(categoryId ? { categoryId } : {}),
        ...(publisherId ? { publisherId } : {}),
        ...(status ? { status } : {}),
        sortBy,
        sortDirection,
        page,
        pageSize: 20,
      }),
    [client, q, categoryId, publisherId, status, sortBy, sortDirection, page],
  );

  function updateParams(patch: Record<string, string | undefined>): void {
    const next = new URLSearchParams(searchParams);
    for (const [key, value] of Object.entries(patch)) {
      if (value) {
        next.set(key, value);
      } else {
        next.delete(key);
      }
    }
    if (!('page' in patch)) {
      next.delete('page');
    }
    setSearchParams(next);
  }

  return (
    <div className="stack">
      <Breadcrumbs items={[{ label: 'Home', to: '/' }, { label: 'Search' }]} />
      <h1>Search packages</h1>

      <SearchBar initialValue={q} onSubmit={(query) => updateParams({ q: query })} />

      <div className="search-filters">
        <label>
          <span className="visually-hidden">Status</span>
          <select
            className="select-input"
            value={status ?? ''}
            onChange={(event) => updateParams({ status: event.target.value || undefined })}
          >
            <option value="">Any status</option>
            {STATUS_OPTIONS.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span className="visually-hidden">Sort by</span>
          <select
            className="select-input"
            value={sortBy}
            onChange={(event) => updateParams({ sortBy: event.target.value })}
          >
            {SORT_BY_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span className="visually-hidden">Sort direction</span>
          <select
            className="select-input"
            value={sortDirection}
            onChange={(event) => updateParams({ sortDirection: event.target.value })}
          >
            <option value="desc">Descending</option>
            <option value="asc">Ascending</option>
          </select>
        </label>
      </div>

      {state.status === 'loading' ? <LoadingIndicator label="Searching…" /> : null}
      {state.status === 'error' ? <ErrorView message={state.message} /> : null}
      {state.status === 'success' ? (
        <>
          <p className="card__meta">{state.data.totalCount} result(s)</p>
          <PackageList
            items={state.data.items.map(searchItemToPackageCardProps)}
            emptyTitle="No packages match your search"
            emptyMessage="Try a different keyword or clear your filters."
          />
          <Pagination
            currentPage={state.data.currentPage}
            totalPages={state.data.totalPages}
            onPageChange={(nextPage) => updateParams({ page: String(nextPage) })}
          />
        </>
      ) : null}
    </div>
  );
}
