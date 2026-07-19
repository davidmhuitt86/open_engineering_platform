/**
 * Resolves Engineering Package dependency graphs (PKG-004).
 *
 * Status: Deferred beyond WP-EXC-001's explicit scope. Not explicitly required by WP-EXC-001's MVP scope (a single package install has no dependency graph to resolve yet) — scaffolded now because the directory already existed, left otherwise empty until a future work package needs real multi-package dependency resolution.
 */
export const PACKAGE_NAME = '@oep-exchange/dependency-resolver' as const;
