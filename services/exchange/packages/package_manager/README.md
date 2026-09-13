# @oep-exchange/package-manager

Orchestrates the non-persistence stages of the Package Upload Pipeline: manifest extraction, parsing, and metadata derivation.

**Status:** Real implementation (TASK-EXC-0005, Upload Pipeline) — signature verification and catalog registration are not performed here; see below.

## What this package owns

- `processUpload(archive: Buffer): ProcessedUpload` — the single place that sequences archive extraction (`@oep-exchange/manifest`), manifest parsing, and metadata extraction (WP-EXC-005.md §3/§5). Pure and DB-free.
- `extractMetadata(manifest)` / `computeFileMetadata(archive)` — the two sub-steps `processUpload` composes, exported individually for direct testing/reuse.

## What this package deliberately does not do

- **Signature verification** — `manifest.signatures` is read but never verified. Explicitly excluded from WP-EXC-005.md §2; real verification is `@oep-exchange/signing`'s future deliverable.
- **Catalog registration** (writing `Package`/`PackageVersion`/`PackageFile` rows) — this package has no PostgreSQL access and none is possible for it: `DEPENDENCY_GRAPH.md` §3 forbids a package from depending on an application, and the persistence layer lives inside `exchange-api` (see `docs/architecture/REPOSITORY_STRUCTURE.md` §11.1). `apps/exchange-api`'s `UploadService` calls `processUpload()` first, then performs the actual database writes and file storage with the result — this package sequences the pure computation the registration decision is based on, per its own charter in `OWNERSHIP.md`.

## Dependency direction

Depends on `@oep-exchange/core`, `@oep-exchange/manifest`, `@oep-exchange/signing` (listed for the future signature-verification step; not yet called). No dependency on PostgreSQL, Fastify, or any application.
