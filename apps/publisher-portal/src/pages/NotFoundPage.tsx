import { Link } from 'react-router-dom';
import { EmptyState } from '../components/EmptyState.js';

export function NotFoundPage(): JSX.Element {
  return (
    <EmptyState
      title="Page not found"
      message="The page you're looking for doesn't exist or may have moved."
      action={
        <Link to="/" className="btn btn--primary">
          Back to home
        </Link>
      }
    />
  );
}
