import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useExchangeApiClient } from '../api/ExchangeApiClientContext.js';
import { Breadcrumbs } from '../components/Breadcrumbs.js';
import { EmptyState } from '../components/EmptyState.js';
import { useLibrary } from '../state/LibraryContext.js';

/**
 * Authentication is out of scope (WP-EXC-009.md §2), so there is no
 * server-side "my library" concept — this page lists the packages
 * *this browser* has requested installation for (`LibraryContext`,
 * recorded from `PackageDetailPage`'s Install button). "Refresh status"
 * re-fetches the real `Installation` record (WP-EXC-008.md) rather than
 * trusting the locally cached status forever.
 */
export function MyLibraryPage(): JSX.Element {
  const client = useExchangeApiClient();
  const { installations, updateInstallationStatus } = useLibrary();
  const [refreshingId, setRefreshingId] = useState<string | null>(null);

  async function handleRefresh(installationId: string): Promise<void> {
    setRefreshingId(installationId);
    try {
      const installation = await client.installations.get(installationId);
      updateInstallationStatus(installationId, installation.status);
    } finally {
      setRefreshingId(null);
    }
  }

  return (
    <div className="stack">
      <Breadcrumbs items={[{ label: 'Home', to: '/' }, { label: 'My Library' }]} />
      <h1>My Library</h1>

      {installations.length === 0 ? (
        <EmptyState
          title="Your library is empty"
          message="Packages you install from this browser will appear here."
        />
      ) : (
        <ul className="stack plain-list">
          {installations.map((installation) => (
            <li key={installation.installationId} className="card">
              <span className={`badge badge--${badgeVariant(installation.status)}`}>
                {installation.status}
              </span>
              <Link to={`/packages/${installation.packageId}`}>
                {installation.packageDisplayName}
              </Link>
              <div className="card__meta">
                v{installation.version} — requested {formatTimestamp(installation.requestedAt)}
              </div>
              <button
                type="button"
                className="btn btn--secondary"
                disabled={refreshingId === installation.installationId}
                onClick={() => handleRefresh(installation.installationId)}
              >
                {refreshingId === installation.installationId ? 'Refreshing…' : 'Refresh status'}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function badgeVariant(status: string): string {
  return status === 'completed' ? 'published' : status === 'failed' ? 'suspended' : 'draft';
}

function formatTimestamp(iso: string): string {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? iso : date.toLocaleString();
}
