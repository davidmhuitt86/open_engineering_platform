const DEFAULT_STORAGE_DIR = './storage/packages';

/** Where uploaded package artifacts are written (WP-EXC-005.md §8) — overridable via `OEP_EXCHANGE_STORAGE_DIR`. */
export function loadStorageDir(env: NodeJS.ProcessEnv = process.env): string {
  return env.OEP_EXCHANGE_STORAGE_DIR ?? DEFAULT_STORAGE_DIR;
}
