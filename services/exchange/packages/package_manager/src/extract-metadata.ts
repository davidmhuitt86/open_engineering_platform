import type { PackageManifest } from '@oep-exchange/manifest';
import type { ExtractedPackageMetadata } from './types.js';

/** Projects a parsed `PackageManifest` into the fields the Package Catalog needs (WP-EXC-005.md §5 "Extract metadata"). */
export function extractMetadata(manifest: PackageManifest): ExtractedPackageMetadata {
  return {
    packageId: manifest.packageId,
    version: manifest.version,
    title: manifest.title,
    summary: manifest.summary,
    description: manifest.description,
    category: manifest.category,
    engineeringDomains: manifest.engineeringDomains,
    keywords: manifest.keywords,
    capabilities: manifest.capabilities,
    license: manifest.license,
    dependencies: manifest.dependencies,
    repositoryStats: manifest.repository,
    statistics: manifest.statistics,
    buildMetadata: manifest.build,
    manifestPublisherId: manifest.publisher.id,
  };
}
