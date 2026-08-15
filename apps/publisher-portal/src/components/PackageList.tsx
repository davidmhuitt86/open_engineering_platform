import { EmptyState } from './EmptyState.js';
import { PackageCard, type PackageCardProps } from './PackageCard.js';

export interface PackageListProps {
  items: PackageCardProps[];
  emptyTitle?: string;
  emptyMessage?: string;
}

export function PackageList({
  items,
  emptyTitle = 'No packages found',
  emptyMessage = 'Try a different search or check back later.',
}: PackageListProps): JSX.Element {
  if (items.length === 0) {
    return <EmptyState title={emptyTitle} message={emptyMessage} />;
  }

  return (
    <div className="card-grid">
      {items.map((item) => (
        <PackageCard key={item.id} {...item} />
      ))}
    </div>
  );
}
