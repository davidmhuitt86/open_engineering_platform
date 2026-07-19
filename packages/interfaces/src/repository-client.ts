/**
 * The `RepositoryClient` contract (docs/tasks/WP-EXC-008.md §7/§8) — the
 * first cross-repository contract to actually land in this package (see
 * this package's own README, which anticipated it as "`RepositoryService`,
 * the `installer` package's eventual dependency"; WP-EXC-008.md itself
 * names the abstraction `RepositoryClient`, so that is the name used
 * here).
 *
 * Type-only, per this package's charter — `@oep-exchange/installer` is
 * the only package that may depend on this file and the only one
 * expected to implement it (`docs/architecture/DEPENDENCY_GRAPH.md` §3).
 * No implementation lives here, and nothing here reaches toward
 * `oep_foundation`/`oep_repository` internals — it describes only the
 * shape of a future network call (WP-EXC-008.md §7: "communicates only
 * through the Repository's approved public interface").
 */

/** What the Repository needs to accept and install a Package artifact. */
export interface RepositoryInstallRequest {
  /** The reverse-domain Package identifier (PKG-001/PKG-002). */
  packageId: string;
  /** The semver version string being installed. */
  version: string;
  /** The raw `.oep` archive bytes. */
  artifact: Buffer;
  /** The artifact's SHA-256 hash, for the Repository to verify on its side. */
  sha256: string;
  /** The original file name, for the Repository's own bookkeeping. */
  fileName: string;
}

/** What the Repository's public interface reports back for an install attempt. */
export interface RepositoryInstallResult {
  /** Whether the Repository accepted and installed the package. */
  accepted: boolean;
  /** The id the Repository assigned to the installed package, when accepted. */
  repositoryPackageId?: string;
  /** A human-readable reason, populated when `accepted` is `false`. */
  message?: string;
}

/**
 * The Exchange's only allowed path to the Repository (WP-EXC-008.md §7:
 * "The Exchange shall never depend upon Repository internals... isolated
 * behind the Repository Client"). Implementations live in
 * `@oep-exchange/installer`.
 */
export interface RepositoryClient {
  install(request: RepositoryInstallRequest): Promise<RepositoryInstallResult>;
}
