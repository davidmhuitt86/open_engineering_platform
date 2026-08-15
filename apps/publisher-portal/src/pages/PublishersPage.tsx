import { useExchangeApiClient } from '../api/ExchangeApiClientContext.js';
import { Breadcrumbs } from '../components/Breadcrumbs.js';
import { EmptyState } from '../components/EmptyState.js';
import { ErrorView } from '../components/ErrorView.js';
import { LoadingIndicator } from '../components/LoadingIndicator.js';
import { PublisherCard } from '../components/PublisherCard.js';
import { useAsync } from '../hooks/use-async.js';

export function PublishersPage(): JSX.Element {
  const client = useExchangeApiClient();
  const state = useAsync(() => client.publishers.list(), [client]);

  return (
    <div className="stack">
      <Breadcrumbs items={[{ label: 'Home', to: '/' }, { label: 'Publishers' }]} />
      <h1>Publishers</h1>

      {state.status === 'loading' ? <LoadingIndicator label="Loading publishers…" /> : null}
      {state.status === 'error' ? <ErrorView message={state.message} /> : null}
      {state.status === 'success' ? (
        state.data.length === 0 ? (
          <EmptyState title="No publishers yet" message="Check back soon." />
        ) : (
          <div className="card-grid">
            {state.data.map((publisher) => (
              <PublisherCard
                key={publisher.id}
                id={publisher.id}
                displayName={publisher.displayName}
                publisherType={publisher.publisherType}
                description={publisher.description}
              />
            ))}
          </div>
        )
      ) : null}
    </div>
  );
}
