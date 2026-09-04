import type { PackageDto, PackageStatus, SearchResultItemDto } from '@oep-exchange/api-contracts';
import type { PackageCardProps } from '../components/PackageCard.js';

export function searchItemToPackageCardProps(item: SearchResultItemDto): PackageCardProps {
  return {
    id: item.id,
    displayName: item.displayName,
    description: item.description,
    // `SearchResultItemDto.status` is `string` on the wire (it isn't
    // narrowed to `PackageStatus` there — see packages/api-contracts/src
    // /search.ts); the Search REST API only ever returns a real
    // Package's status, so this mirrors the same cast already used at
    // the persistence layer's own row-mapping boundary.
    status: item.status as PackageStatus,
    currentVersion: item.currentVersion,
    publisherName: item.publisherName,
    categoryName: item.categoryName ?? undefined,
  };
}

export function packageDtoToPackageCardProps(pkg: PackageDto): PackageCardProps {
  return {
    id: pkg.id,
    displayName: pkg.displayName,
    description: pkg.description,
    status: pkg.status,
    currentVersion: pkg.currentVersion,
  };
}
