import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { ExchangeApiClientProvider } from './api/ExchangeApiClientContext.js';
import { AppShell } from './components/AppShell.js';
import { CategoriesPage } from './pages/CategoriesPage.js';
import { DownloadsPage } from './pages/DownloadsPage.js';
import { MarketplaceHomePage } from './pages/MarketplaceHomePage.js';
import { MyLibraryPage } from './pages/MyLibraryPage.js';
import { NotFoundPage } from './pages/NotFoundPage.js';
import { PackageDetailPage } from './pages/PackageDetailPage.js';
import { PublisherProfilePage } from './pages/PublisherProfilePage.js';
import { PublishersPage } from './pages/PublishersPage.js';
import { SearchResultsPage } from './pages/SearchResultsPage.js';
import { LibraryProvider } from './state/LibraryContext.js';

/**
 * The Engineering Exchange Web Application's root component
 * (TASK-EXC-0009, docs/tasks/WP-EXC-009.md). `ExchangeApiClientProvider`
 * and `LibraryProvider` wrap the router so every page shares the same
 * `ExchangeApiClient` instance (§3: "No component shall communicate
 * directly with backend services outside the API client layer") and the
 * same local Downloads/My Library history.
 */
export function App(): JSX.Element {
  return (
    <ExchangeApiClientProvider>
      <LibraryProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<AppShell />}>
              <Route index element={<MarketplaceHomePage />} />
              <Route path="search" element={<SearchResultsPage />} />
              <Route path="categories" element={<CategoriesPage />} />
              <Route path="publishers" element={<PublishersPage />} />
              <Route path="publishers/:id" element={<PublisherProfilePage />} />
              <Route path="packages/:id" element={<PackageDetailPage />} />
              <Route path="library" element={<MyLibraryPage />} />
              <Route path="downloads" element={<DownloadsPage />} />
              <Route path="*" element={<NotFoundPage />} />
            </Route>
          </Routes>
        </BrowserRouter>
      </LibraryProvider>
    </ExchangeApiClientProvider>
  );
}
