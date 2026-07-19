/**
 * Domain types for the persistence layer, one per table in
 * `db/migrations/V1__initial_exchange_schema.sql`. `id` is the table's
 * true UUID primary key (WP-EXC-002.md §8 — no separate surrogate key).
 * Every mutable entity carries `rowVersion`, an optimistic-concurrency
 * counter incremented on every UPDATE; append-only event logs
 * (`Download`, `AuditLogEntry`) have none. Field names are camelCase,
 * mapped from the underlying snake_case columns by each repository's
 * row mapper.
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

export type VerificationStatus =
  | 'unverified'
  | 'identity_verified'
  | 'organization_verified'
  | 'oem_verified'
  | 'academic_verified'
  | 'government_verified'
  | 'open_engineering_verified';

export type TrustStatus = 'standard' | 'trusted' | 'flagged';

export type PublisherStatus = 'active' | 'suspended';

export interface Publisher {
  id: string;
  name: string;
  displayName: string;
  namespace: string;
  publisherType: PublisherType;
  verificationStatus: VerificationStatus;
  trustStatus: TrustStatus;
  status: PublisherStatus;
  contactEmail: string;
  rowVersion: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface NewPublisher {
  name: string;
  displayName: string;
  namespace: string;
  publisherType: PublisherType;
  contactEmail?: string;
  verificationStatus?: VerificationStatus;
  trustStatus?: TrustStatus;
}

/** Fields a Publisher may change after creation (TASK-EXC-0003) — `namespace`/`publisherType`/`name` are not included: see docs/architecture/REPOSITORY_STRUCTURE.md. */
export interface PublisherUpdate {
  displayName?: string;
  contactEmail?: string;
  status?: PublisherStatus;
}

export interface PublisherProfile {
  id: string;
  publisherId: string;
  organizationName: string;
  description: string;
  website: string;
  supportContact: string;
  documentationUrl: string;
  logoUrl: string;
  bannerUrl: string;
  engineeringDisciplines: string[];
  country: string;
  languages: string[];
  socialLinks: Record<string, string>;
  verifiedBadges: string[];
  rowVersion: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface NewPublisherProfile {
  publisherId: string;
  organizationName?: string;
  description?: string;
  website?: string;
  supportContact?: string;
  documentationUrl?: string;
  logoUrl?: string;
  bannerUrl?: string;
  engineeringDisciplines?: string[];
  country?: string;
  languages?: string[];
  socialLinks?: Record<string, string>;
  verifiedBadges?: string[];
}

export interface PackageCategory {
  id: string;
  slug: string;
  name: string;
  description: string;
  parentId: string | null;
  rowVersion: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface NewPackageCategory {
  slug: string;
  name: string;
  description?: string;
  parentId?: string | null;
}

export type PackageStatus = 'draft' | 'published' | 'deprecated' | 'suspended';

/** PKG-002 §16 license object — shape intentionally open (spec defers detail). */
export type PackageLicense = Record<string, unknown>;

export interface Package {
  id: string;
  packageId: string;
  publisherId: string;
  title: string;
  summary: string;
  description: string;
  categoryId: string | null;
  engineeringDomains: string[];
  keywords: string[];
  capabilities: string[];
  license: PackageLicense;
  status: PackageStatus;
  latestVersionId: string | null;
  rowVersion: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface NewPackage {
  packageId: string;
  publisherId: string;
  title: string;
  summary?: string;
  description?: string;
  categoryId?: string | null;
  engineeringDomains?: string[];
  keywords?: string[];
  capabilities?: string[];
  license?: PackageLicense;
  status?: PackageStatus;
}

/** Fields a Package may change after creation (TASK-EXC-0004) — `packageId`/`publisherId` are not included: see docs/architecture/REPOSITORY_STRUCTURE.md. */
export interface PackageUpdate {
  title?: string;
  description?: string;
  categoryId?: string | null;
  status?: PackageStatus;
}

export type ReleaseChannel = 'stable' | 'beta' | 'alpha';
export type PackageVersionStatus = 'pending' | 'published' | 'deprecated' | 'yanked';

/** PKG-002 §12 Repository Metadata (installation preview). */
export interface RepositoryStats {
  objects?: number;
  relationships?: number;
  knowledge?: number;
  assets?: number;
  validationRules?: number;
}

/** PKG-002 §13 Statistics (purely informational). */
export interface PackageStatistics {
  compressedSize?: string;
  uncompressedSize?: string;
  objectCount?: string;
  relationshipCount?: string;
}

/** PKG-002 §17 Digital Signatures. */
export interface PackageSignatures {
  algorithm?: string;
  certificateId?: string;
  signatureHash?: string;
  timestamp?: string;
}

/** PKG-002 §18 Build Metadata. */
export interface BuildMetadata {
  tool?: string;
  buildNumber?: string;
  buildDate?: string;
  specVersion?: string;
}

/** PKG-002 §15 dependency entry. */
export interface PackageDependency {
  packageId: string;
  versionConstraint: string;
  required: boolean;
  reason?: string;
}

export interface PackageVersion {
  id: string;
  packageId: string;
  version: string;
  schemaVersion: string;
  manifest: Record<string, unknown>;
  dependencies: PackageDependency[];
  repositoryStats: RepositoryStats;
  statistics: PackageStatistics;
  signatures: PackageSignatures;
  buildMetadata: BuildMetadata;
  releaseChannel: ReleaseChannel;
  status: PackageVersionStatus;
  publishedAt: Date | null;
  rowVersion: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface NewPackageVersion {
  packageId: string;
  version: string;
  schemaVersion?: string;
  manifest: Record<string, unknown>;
  dependencies?: PackageDependency[];
  repositoryStats?: RepositoryStats;
  statistics?: PackageStatistics;
  signatures?: PackageSignatures;
  buildMetadata?: BuildMetadata;
  releaseChannel?: ReleaseChannel;
}

export interface PackageFile {
  id: string;
  packageVersionId: string;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
  storagePath: string;
  sha256: string;
  blake3: string | null;
  signatureAlgorithm: string | null;
  rowVersion: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface NewPackageFile {
  packageVersionId: string;
  fileName: string;
  mimeType?: string;
  sizeBytes: number;
  storagePath: string;
  sha256: string;
  blake3?: string | null;
  signatureAlgorithm?: string | null;
}

export interface Download {
  id: string;
  packageVersionId: string;
  downloadedAt: Date;
  clientIp: string | null;
  userAgent: string | null;
}

export interface NewDownload {
  packageVersionId: string;
  clientIp?: string | null;
  userAgent?: string | null;
}

/** WP-EXC-002.md §4/§6 — an immutable Exchange audit event. */
export interface AuditLogEntry {
  id: string;
  entityType: string;
  entityId: string;
  action: string;
  actor: string | null;
  metadata: Record<string, unknown>;
  occurredAt: Date;
}

export interface NewAuditLogEntry {
  entityType: string;
  entityId: string;
  action: string;
  actor?: string | null;
  metadata?: Record<string, unknown>;
}
