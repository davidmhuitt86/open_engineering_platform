import type { PublisherType } from '@oep-exchange/api-contracts';
import { Link } from 'react-router-dom';
import { formatPublisherType } from '../lib/format-publisher-type.js';

export interface PublisherCardProps {
  id: string;
  displayName: string;
  publisherType: PublisherType;
  description: string;
}

export function PublisherCard(props: PublisherCardProps): JSX.Element {
  return (
    <Link to={`/publishers/${props.id}`} className="card" aria-label={props.displayName}>
      <h3 className="card__title">{props.displayName}</h3>
      <p className="card__description">{props.description || 'No description provided.'}</p>
      <div className="card__meta">{formatPublisherType(props.publisherType)}</div>
    </Link>
  );
}
