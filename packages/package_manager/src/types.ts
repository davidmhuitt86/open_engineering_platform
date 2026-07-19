import type {
  ManifestBuildMetadata,
  ManifestDependency,
  ManifestRepositoryStats,
  ManifestStatistics,
  PackageManifest,
} from '@oep-exchange/manifest';

/**
 * The Package Catalog fields derived from a parsed manifest (WP-EXC-005.md
 * §5 "Extract metadata"). A plain projection of `PackageManifest` — no
 * new information, just the shape `exchange-api`'s `UploadService` needs
 * to register a Package/PackageVersion, so it never has to reach into
 * manifest internals itself.
 */
export interface ExtractedPackageMetadata {
  packageId: string;
  version: string;
  title: string;
  summary: string;
  description: string;
  category: string;
  engineeringDomains: string[];
  keywords: string[];
  capabilities: string[];
  license: Record<string, unknown>;
  dependencies: ManifestDependency[];
  repositoryStats: ManifestRepositoryStats;
  statistics: ManifestStatistics;
  buildMetadata: ManifestBuildMetadata;
  /** The manifest's own self-declared publisher id (WP-EXC-005.md §6 "Invalid publisher" is validated by `exchange-api` against its Publisher Registry, not trusted from this field alone). */
  manifestPublisherId: string;
}

/** File-level metadata computed from the raw uploaded bytes (WP-EXC-005.md §8). */
export interface UploadedFileMetadata {
  sizeBytes: number;
  sha256: string;
}

/** The full result of processing one uploaded package archive. */
export interface ProcessedUpload {
  manifest: PackageManifest;
  metadata: ExtractedPackageMetadata;
  file: UploadedFileMetadata;
}
