import { useExchangeApiClient } from '../api/ExchangeApiClientContext.js';
import { Breadcrumbs } from '../components/Breadcrumbs.js';
import { CategoryCard } from '../components/CategoryCard.js';
import { EmptyState } from '../components/EmptyState.js';
import { ErrorView } from '../components/ErrorView.js';
import { LoadingIndicator } from '../components/LoadingIndicator.js';
import { useAsync } from '../hooks/use-async.js';
import { deriveCategories } from '../lib/derive-categories.js';

/** A large single page over `GET /search` (no dedicated categories endpoint exists) is enough to derive every category currently in use. */
const CATEGORY_SAMPLE_SIZE = 100;

export function CategoriesPage(): JSX.Element {
  const client = useExchangeApiClient();
  const state = useAsync(() => client.search.run({ pageSize: CATEGORY_SAMPLE_SIZE }), [client]);

  return (
    <div className="stack">
      <Breadcrumbs items={[{ label: 'Home', to: '/' }, { label: 'Categories' }]} />
      <h1>Categories</h1>

      {state.status === 'loading' ? <LoadingIndicator label="Loading categories…" /> : null}
      {state.status === 'error' ? <ErrorView message={state.message} /> : null}
      {state.status === 'success'
        ? (() => {
            const categories = deriveCategories(state.data.items);
            return categories.length === 0 ? (
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
            );
          })()
        : null}
    </div>
  );
}
