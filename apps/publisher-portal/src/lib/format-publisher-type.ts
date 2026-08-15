import type { PublisherType } from '@oep-exchange/api-contracts';

export function formatPublisherType(type: PublisherType): string {
  return type
    .split('_')
    .map((word) => word[0]?.toUpperCase() + word.slice(1))
    .join(' ');
}
