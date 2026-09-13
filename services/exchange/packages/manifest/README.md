# @oep-exchange/manifest

Parses and validates OEP Package Manifests (PKG-002).

**Status:** Real implementation (TASK-EXC-0005, Upload Pipeline).

## What this package owns

- `extractManifestFromArchive(archive: Buffer)` / `extractManifestJson(archive: Buffer)` — opens a `.oep` package archive (a ZIP container, PKG-001 §5/§14) and reads `manifest/package.json` out of it.
- `parseManifest(input: unknown): PackageManifest` — validates the raw manifest JSON against PKG-002 §5's required fields and §20's validation rules, returning a normalized, strongly-typed `PackageManifest`.

Both throw `@oep-exchange/core`'s `ValidationError` for a malformed archive or manifest — never a partially-valid result (PKG-002 §20: "Failure invalidates the package").

Digital signature verification (PKG-002 §17's `signatures` block is read but never verified) and dependency resolution are explicitly out of scope here — see `docs/tasks/WP-EXC-005.md` §2 and `@oep-exchange/signing` / `@oep-exchange/dependency-resolver`.

## Dependency direction

Depends on `@oep-exchange/core` and `adm-zip` (ZIP archive reading). No dependency on PostgreSQL, Fastify, or any application — this package is pure, DB-free, and consumed by `@oep-exchange/package-manager`.
