import { Link } from 'react-router-dom';
import { Breadcrumbs } from '../components/Breadcrumbs.js';
import { EmptyState } from '../components/EmptyState.js';
import { useLibrary } from '../state/LibraryContext.js';

/**
 * Authentication is out of scope (WP-EXC-009.md §2), so there is no
 * server-side "my downloads" concept — this page lists the packages
 * *this browser* has downloaded (`LibraryContext`, recorded from
 * `PackageDetailPage`'s Download button), each still pointing at the
 * real Package it came from.
 */
export function DownloadsPage(): JSX.Element {
  const { downloads } = useLibrary();

  return (
    <div className="stack">
      <Breadcrumbs items={[{ label: 'Home', to: '/' }, { label: 'Downloads' }]} />
      <h1>Downloads</h1>

      {downloads.length === 0 ? (
        <EmptyState
          title="No downloads yet"
          message="Packages you download from this browser will appear here."
        />
      ) : (
        <ul className="stack plain-list">
          {downloads.map((download, index) => (
            <li key={`${download.packageId}-${download.downloadedAt}-${index}`} className="card">
              <Link to={`/packages/${download.packageId}`}>{download.packageDisplayName}</Link>
              <div className="card__meta">
                v{download.version} — downloaded {formatTimestamp(download.downloadedAt)}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function formatTimestamp(iso: string): string {
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? iso : date.toLocaleString();
}
