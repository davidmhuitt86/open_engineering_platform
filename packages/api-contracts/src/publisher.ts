/**
 * Publisher wire contracts (TASK-EXC-0003, docs/tasks/WP-EXC-003.md §5).
 * `legalName` is `docs/tasks/WP-EXC-003.md`'s "Legal Name" field, mapped
 * to the Publisher persistence layer's `name` column (EXC-002 §4's
 * "Publisher Name") — see `docs/architecture/REPOSITORY_STRUCTURE.md`
 * for why this is a mapping rather than a new column. `namespace` and
 * `publisherType` aren't named in WP-EXC-003.md §5's field list but are
 * required by the already-approved schema (TASK-EXC-0002, EXC-002 §5/§6)
 * and so remain required here too.
 */
export type PublisherType =
  | 'individual'
  | 'company'
  | 'oem'
  | 'educational_institution'
  | 'government'
  | 'standards_organization'
  | 'enterprise'
  | 'community_organization';

export type PublisherStatus = 'active' | 'suspended';

export interface PublisherDto {
  id: string;
  namespace: string;
  publisherType: PublisherType;
  displayName: string;
  legalName: string;
  description: string;
  website: string;
  contactEmail: string;
  status: PublisherStatus;
  createdAt: string;
  updatedAt: string;
}

export interface CreatePublisherRequest {
  namespace: string;
  publisherType: PublisherType;
  displayName: string;
  legalName: string;
  contactEmail: string;
  description?: string;
  website?: string;
}

/** Fields a Publisher may change after creation — see `PublisherUpdate` in the persistence layer for why `namespace`/`publisherType`/`legalName` aren't included. */
export interface UpdatePublisherRequest {
  displayName?: string;
  contactEmail?: string;
  description?: string;
  website?: string;
  status?: PublisherStatus;
}

export interface PublisherListResponse {
  publishers: PublisherDto[];
}
