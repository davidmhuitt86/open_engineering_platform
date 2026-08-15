import { useParams } from 'react-router-dom';
import { useExchangeApiClient } from '../api/ExchangeApiClientContext.js';
import { Breadcrumbs } from '../components/Breadcrumbs.js';
import { ErrorView } from '../components/ErrorView.js';
import { LoadingIndicator } from '../components/LoadingIndicator.js';
import { PackageList } from '../components/PackageList.js';
import { useAsync } from '../hooks/use-async.js';
import { formatPublisherType } from '../lib/format-publisher-type.js';
import { searchItemToPackageCardProps } from '../lib/to-package-card-props.js';

const PUBLISHER_PACKAGES_PAGE_SIZE = 50;

export function PublisherProfilePage(): JSX.Element {
  // Only rendered under the `/publishers/:id` route, so `id` is always present.
  const { id } = useParams<{ id: string }>();
  const publisherId = id as string;

  const client = useExchangeApiClient();

  const state = useAsync(async () => {
    const publisher = await client.publishers.get(publisherId);
    const packages = await client.search.run({
      publisherId,
      sortBy: 'name',
      sortDirection: 'asc',
      pageSize: PUBLISHER_PACKAGES_PAGE_SIZE,
    });
    return { publisher, packages };
  }, [client, publisherId]);

  if (state.status === 'loading') {
    return <LoadingIndicator label="Loading publisher…" />;
  }

  if (state.status === 'error') {
    return <ErrorView message={state.message} />;
  }

  const { publisher, packages } = state.data;

  return (
    <div className="stack">
      <Breadcrumbs
        items={[
          { label: 'Home', to: '/' },
          { label: 'Publishers', to: '/publishers' },
          { label: publisher.displayName },
        ]}
      />

      <div>
        <h1>{publisher.displayName}</h1>
        <p className="card__meta">{formatPublisherType(publisher.publisherType)}</p>
      </div>

      <p>{publisher.description || 'No description provided.'}</p>

      {publisher.website ? (
        <p>
          <a href={publisher.website} target="_blank" rel="noreferrer">
            {publisher.website}
          </a>
        </p>
      ) : null}

      <section>
        <div className="section-heading">
          <h2>Packages by {publisher.displayName}</h2>
        </div>
        <PackageList
          items={packages.items.map(searchItemToPackageCardProps)}
          emptyTitle="No packages published yet"
          emptyMessage="This publisher hasn't published any packages yet."
        />
      </section>
    </div>
  );
}
