import { Link } from 'react-router-dom';

export interface CategoryCardProps {
  id: string;
  name: string;
  packageCount: number;
}

export function CategoryCard({ id, name, packageCount }: CategoryCardProps): JSX.Element {
  return (
    <Link to={`/search?categoryId=${encodeURIComponent(id)}`} className="card" aria-label={name}>
      <h3 className="card__title">{name}</h3>
      <div className="card__meta">
        {packageCount} package{packageCount === 1 ? '' : 's'}
      </div>
    </Link>
  );
}
