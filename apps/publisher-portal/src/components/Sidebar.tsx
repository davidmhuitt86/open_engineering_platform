import { NavLink } from 'react-router-dom';

const NAV_ITEMS = [
  { to: '/', label: 'Home', end: true },
  { to: '/search', label: 'Search' },
  { to: '/categories', label: 'Categories' },
  { to: '/publishers', label: 'Publishers' },
  { to: '/library', label: 'My Library' },
  { to: '/downloads', label: 'Downloads' },
];

export interface SidebarProps {
  isOpen: boolean;
  onNavigate: () => void;
}

export function Sidebar({ isOpen, onNavigate }: SidebarProps): JSX.Element {
  return (
    <aside className={`app-sidebar${isOpen ? ' is-open' : ''}`}>
      <nav className="app-nav" aria-label="Primary">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => `app-nav__link${isActive ? ' is-active' : ''}`}
            onClick={onNavigate}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
