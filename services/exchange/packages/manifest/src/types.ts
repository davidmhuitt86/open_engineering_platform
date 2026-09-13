/**
 * The OEP Package Manifest (PKG-002) — the authoritative metadata
 * document describing a package, read from `manifest/package.json`
 * inside a `.oep` archive (PKG-001 §5/§9). This is `packages/manifest`'s
 * own copy of the shape, independent of (though structurally similar
 * to) `apps/exchange-api/src/persistence/types.ts`'s `PackageVersion`
 * fields — the two represent different concerns (wire/file format vs.
 * database row) and evolve independently; `packages/manifest` cannot
 * import from `exchange-api` in any case (DEPENDENCY_GRAPH.md §3).
 */

/** PKG-002 §9 Publisher block embedded in the manifest. */
export interface ManifestPublisher {
  id: string;
  name: string;
  verified?: boolean;
  website?: string;
  support?: string;
}

/** PKG-002 §15 dependency entry. */
export interface ManifestDependency {
  packageId: string;
  versionConstraint: string;
  required: boolean;
  reason?: string;
}

/** PKG-002 §12 Repository Metadata (installation preview). */
export interface ManifestRepositoryStats {
  objects?: number;
  relationships?: number;
  knowledge?: number;
  assets?: number;
  validationRules?: number;
}

/** PKG-002 §13 Statistics (purely informational). */
export interface ManifestStatistics {
  compressedSize?: string;
  uncompressedSize?: string;
  objectCount?: string;
  relationshipCount?: string;
}

/** PKG-002 §17 Digital Signatures — read but not verified by this task (signature verification is excluded, WP-EXC-005.md §2). */
export interface ManifestSignatures {
  algorithm?: string;
  certificateId?: string;
  signatureHash?: string;
  timestamp?: string;
}

/** PKG-002 §18 Build Metadata. */
export interface ManifestBuildMetadata {
  tool?: string;
  buildNumber?: string;
  buildDate?: string;
  specVersion?: string;
}

/** The parsed, validated manifest (PKG-002 §5 required fields, plus §10's optional `keywords`). */
export interface PackageManifest {
  schemaVersion: string;
  packageId: string;
  version: string;
  publisher: ManifestPublisher;
  title: string;
  summary: string;
  description: string;
  category: string;
  engineeringDomains: string[];
  license: Record<string, unknown>;
  dependencies: ManifestDependency[];
  capabilities: string[];
  repository: ManifestRepositoryStats;
  statistics: ManifestStatistics;
  signatures: ManifestSignatures;
  build: ManifestBuildMetadata;
  keywords: string[];
}
