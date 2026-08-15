import type { PackageStatus } from '@oep-exchange/api-contracts';
import { Link } from 'react-router-dom';

export interface PackageCardProps {
  id: string;
  displayName: string;
  description: string;
  status: PackageStatus;
  currentVersion: string | null;
  publisherName?: string;
  categoryName?: string;
}

export function PackageCard(props: PackageCardProps): JSX.Element {
  return (
    <Link to={`/packages/${props.id}`} className="card" aria-label={props.displayName}>
      <span className={`badge badge--${props.status}`}>{props.status}</span>
      <h3 className="card__title">{props.displayName}</h3>
      <p className="card__description">{props.description || 'No description provided.'}</p>
      <div className="card__meta">
        {props.publisherName ? <div>{props.publisherName}</div> : null}
        {props.categoryName ? <div>{props.categoryName}</div> : null}
        <div>{props.currentVersion ? `v${props.currentVersion}` : 'No published version yet'}</div>
      </div>
    </Link>
  );
}
