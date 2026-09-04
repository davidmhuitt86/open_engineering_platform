import { useNavigate } from 'react-router-dom';
import { SearchBar } from './SearchBar.js';

export interface HeaderProps {
  onToggleSidebar: () => void;
}

export function Header({ onToggleSidebar }: HeaderProps): JSX.Element {
  const navigate = useNavigate();

  return (
    <header className="app-header">
      <button
        type="button"
        className="btn btn--secondary app-header__menu-toggle"
        aria-label="Toggle navigation menu"
        onClick={onToggleSidebar}
      >
        ☰
      </button>
      <span className="app-header__brand">OEP Engineering Exchange</span>
      <div className="app-header__search">
        <SearchBar
          placeholder="Search packages…"
          onSubmit={(query) => {
            if (query) {
              navigate(`/search?q=${encodeURIComponent(query)}`);
            } else {
              navigate('/search');
            }
          }}
        />
      </div>
    </header>
  );
}
