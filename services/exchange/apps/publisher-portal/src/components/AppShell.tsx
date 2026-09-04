import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Footer } from './Footer.js';
import { Header } from './Header.js';
import { Sidebar } from './Sidebar.js';

/**
 * The Engineering Exchange's application shell (WP-EXC-009.md §4/§6):
 * header (brand + search), a responsive sidebar (collapses to a toggled
 * off-canvas menu on tablet/mobile, `global.css`'s `@media` rules), main
 * content (routed pages via `<Outlet/>`), and a footer.
 */
export function AppShell(): JSX.Element {
  const [isSidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="app-shell">
      <Header onToggleSidebar={() => setSidebarOpen((open) => !open)} />
      <Sidebar isOpen={isSidebarOpen} onNavigate={() => setSidebarOpen(false)} />
      <main className="app-main">
        <Outlet />
      </main>
      <Footer />
    </div>
  );
}
