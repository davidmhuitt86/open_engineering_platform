import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

/** WP-EXC-005.md §8: what a stored package artifact yields — enough for a `package_files` row. */
export interface StoredPackageFile {
  storagePath: string;
  sizeBytes: number;
  sha256: string;
}

export interface PackageFileStorage {
  store(buffer: Buffer, sha256: string): Promise<StoredPackageFile>;
  /** Reads back the bytes at `storagePath` (WP-EXC-007.md §3/§5 "Locate artifact"). */
  retrieve(storagePath: string): Promise<Buffer>;
}

/**
 * Content-addressable local-disk storage for uploaded `.oep` package
 * artifacts, sharded by the first two hex characters of the file's
 * SHA-256 hash — the same convention `oep_acquisition`'s Reference
 * Vault already established platform-wide (`compute_vault_path`:
 * `{root}/{first-two-hex}/{hash}`), with a `.oep` extension appended for
 * on-disk clarity. The hash is computed by the caller (`@oep-exchange/
 * package-manager`'s `computeFileMetadata`, WP-EXC-005.md §5 "Extract
 * metadata") and passed in rather than recomputed here, so this class
 * has exactly one job: writing bytes to a deterministic path.
 */
export class LocalPackageFileStorage implements PackageFileStorage {
  constructor(private readonly rootDir: string) {}

  async store(buffer: Buffer, sha256: string): Promise<StoredPackageFile> {
    const storagePath = this.computePath(sha256);
    await mkdir(dirname(storagePath), { recursive: true });
    await writeFile(storagePath, buffer);
    return { storagePath, sizeBytes: buffer.length, sha256 };
  }

  async retrieve(storagePath: string): Promise<Buffer> {
    return readFile(storagePath);
  }

  private computePath(sha256: string): string {
    return join(this.rootDir, sha256.slice(0, 2), `${sha256}.oep`);
  }
}
