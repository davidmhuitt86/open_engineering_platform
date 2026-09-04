import type { InstallationDto, PackageDto } from '@oep-exchange/api-contracts';
import { ExchangeApiError } from '@oep-exchange/exchange-client';
import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useExchangeApiClient } from '../api/ExchangeApiClientContext.js';
import { Breadcrumbs } from '../components/Breadcrumbs.js';
import { ErrorView } from '../components/ErrorView.js';
import { LoadingIndicator } from '../components/LoadingIndicator.js';
import { useAsync } from '../hooks/use-async.js';
import { useLibrary } from '../state/LibraryContext.js';

type InstallState = 'idle' | 'installing' | 'completed' | 'failed';

export function PackageDetailPage(): JSX.Element {
  // Only rendered under the `/packages/:id` route, so `id` is always present.
  const { id } = useParams<{ id: string }>();
  const packageId = id as string;

  const client = useExchangeApiClient();
  const library = useLibrary();

  const state = useAsync(async () => {
    const pkg = await client.packages.get(packageId);
    const publisher = await client.publishers.get(pkg.publisherId);
    return { pkg, publisher };
  }, [client, packageId]);

  const [installState, setInstallState] = useState<InstallState>('idle');
  const [installResult, setInstallResult] = useState<InstallationDto | null>(null);
  const [installErrorMessage, setInstallErrorMessage] = useState<string | null>(null);

  async function handleInstall(pkg: PackageDto): Promise<void> {
    setInstallState('installing');
    setInstallErrorMessage(null);

    try {
      const installation = await client.installations.install(pkg.id);
      setInstallResult(installation);
      setInstallState(installation.status === 'completed' ? 'completed' : 'failed');
      library.recordInstallation({
        installationId: installation.id,
        packageId: pkg.id,
        packageDisplayName: pkg.displayName,
        version: installation.version,
        status: installation.status,
        requestedAt: installation.requestedAt,
      });
    } catch (error) {
      setInstallState('failed');
      setInstallErrorMessage(
        error instanceof ExchangeApiError ? error.message : 'Installation failed unexpectedly.',
      );
    }
  }

  function handleDownloadClick(pkg: PackageDto): void {
    if (!pkg.currentVersion) {
      return;
    }
    library.recordDownload({
      packageId: pkg.id,
      packageDisplayName: pkg.displayName,
      version: pkg.currentVersion,
      downloadedAt: new Date().toISOString(),
    });
    // No preventDefault: the anchor's own href still navigates the browser
    // to the real download endpoint (WP-EXC-007.md), triggering a native
    // file download; this handler only records the local library entry.
  }

  if (state.status === 'loading') {
    return <LoadingIndicator label="Loading package…" />;
  }

  if (state.status === 'error') {
    return <ErrorView message={state.message} />;
  }

  const { pkg, publisher } = state.data;

  return (
    <div className="stack">
      <Breadcrumbs
        items={[
          { label: 'Home', to: '/' },
          { label: 'Search', to: '/search' },
          { label: pkg.displayName },
        ]}
      />

      <div>
        <span className={`badge badge--${pkg.status}`}>{pkg.status}</span>
        <h1>{pkg.displayName}</h1>
        <p>
          By <Link to={`/publishers/${publisher.id}`}>{publisher.displayName}</Link>
        </p>
      </div>

      <p>{pkg.description || 'No description provided.'}</p>

      <dl>
        <dt>Package ID</dt>
        <dd>{pkg.packageId}</dd>
        <dt>Current version</dt>
        <dd>{pkg.currentVersion ?? 'Not yet published'}</dd>
        {pkg.categoryId ? (
          <>
            <dt>Category</dt>
            <dd>
              <Link to={`/search?categoryId=${encodeURIComponent(pkg.categoryId)}`}>
                Browse this category
              </Link>
            </dd>
          </>
        ) : null}
      </dl>

      <section className="stack">
        <h2>Get this package</h2>
        {pkg.currentVersion ? (
          <a
            className="btn btn--primary"
            href={client.downloads.url(pkg.id)}
            onClick={() => handleDownloadClick(pkg)}
          >
            Download v{pkg.currentVersion}
          </a>
        ) : (
          <p>No published version is available to download yet.</p>
        )}

        <button
          type="button"
          className="btn btn--secondary"
          disabled={!pkg.currentVersion || installState === 'installing'}
          onClick={() => handleInstall(pkg)}
        >
          {installState === 'installing' ? 'Installing…' : 'Install into Repository'}
        </button>
      </section>

      {installState !== 'idle' ? (
        <section className="stack" aria-live="polite">
          <h3>Installation progress</h3>
          {installState === 'installing' ? <LoadingIndicator label="Installing…" /> : null}
          {installState === 'completed' && installResult ? (
            <p>
              Installed successfully
              {installResult.repositoryPackageId ? (
                <>
                  {' '}
                  as <code>{installResult.repositoryPackageId}</code>
                </>
              ) : null}
              .
            </p>
          ) : null}
          {installState === 'failed' ? (
            <ErrorView
              message={installResult?.errorMessage ?? installErrorMessage ?? 'Installation failed.'}
            />
          ) : null}
        </section>
      ) : null}
    </div>
  );
}
