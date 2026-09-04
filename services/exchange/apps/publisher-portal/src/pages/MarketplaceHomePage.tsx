import { Link } from 'react-router-dom';
import { useExchangeApiClient } from '../api/ExchangeApiClientContext.js';
import { CategoryCard } from '../components/CategoryCard.js';
import { EmptyState } from '../components/EmptyState.js';
import { ErrorView } from '../components/ErrorView.js';
import { LoadingIndicator } from '../components/LoadingIndicator.js';
import { PackageList } from '../components/PackageList.js';
import { useAsync } from '../hooks/use-async.js';
import { deriveCategories } from '../lib/derive-categories.js';
import { searchItemToPackageCardProps } from '../lib/to-package-card-props.js';

const FEATURED_CATEGORY_COUNT = 6;

export function MarketplaceHomePage(): JSX.Element {
  const client = useExchangeApiClient();
  const state = useAsync(
    () =>
      client.search.run({
        status: 'published',
        sortBy: 'updatedAt',
        sortDirection: 'desc',
        pageSize: 12,
      }),
    [client],
  );

  if (state.status === 'loading') {
    return <LoadingIndicator label="Loading the marketplace…" />;
  }

  if (state.status === 'error') {
    return <ErrorView message={state.message} />;
  }

  const categories = deriveCategories(state.data.items).slice(0, FEATURED_CATEGORY_COUNT);

  return (
    <div className="stack">
      <section>
        <h1>OEP Engineering Exchange</h1>
        <p>Discover, download, and install published engineering packages.</p>
      </section>

      <section>
        <div className="section-heading">
          <h2>Browse by category</h2>
          <Link to="/categories">View all categories</Link>
        </div>
        {categories.length === 0 ? (
          <EmptyState
            title="No categories yet"
            message="Published packages will appear here once they're categorized."
          />
        ) : (
          <div className="card-grid">
            {categories.map((category) => (
              <CategoryCard key={category.id} {...category} />
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="section-heading">
          <h2>Recently updated packages</h2>
          <Link to="/search">Browse all packages</Link>
        </div>
        <PackageList
          items={state.data.items.map(searchItemToPackageCardProps)}
          emptyTitle="No packages published yet"
          emptyMessage="Check back soon — this is where new packages will appear."
        />
      </section>
    </div>
  );
}
