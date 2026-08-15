import { useState, type FormEvent } from 'react';

export interface SearchBarProps {
  initialValue?: string;
  placeholder?: string;
  onSubmit: (query: string) => void;
}

export function SearchBar({
  initialValue = '',
  placeholder,
  onSubmit,
}: SearchBarProps): JSX.Element {
  const [value, setValue] = useState(initialValue);

  function handleSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    onSubmit(value.trim());
  }

  return (
    <form className="search-bar" role="search" onSubmit={handleSubmit}>
      <label htmlFor="exchange-search-input" className="visually-hidden">
        Search packages
      </label>
      <input
        id="exchange-search-input"
        type="search"
        className="text-input search-bar__input"
        placeholder={placeholder ?? 'Search packages…'}
        value={value}
        onChange={(event) => setValue(event.target.value)}
      />
      <button type="submit" className="btn btn--primary">
        Search
      </button>
    </form>
  );
}
