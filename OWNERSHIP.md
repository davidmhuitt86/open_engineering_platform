# Ownership

Ownership responsibilities for every application and package currently in this repository. This is a statement of what each unit _owns_ — the concerns it is the single, authoritative home for — not an implementation-status report (see each package's own README, `docs/tasks/WP-EXC-001.md`, and `IMPLEMENTATION_STATUS.md`-equivalent tracking for that).

See `CONTRIBUTING_ARCHITECTURE.md` for the rules that keep these boundaries real, and `docs/architecture/DEPENDENCY_GRAPH.md` for how ownership maps to allowed dependency direction.

---

## Applications (`apps/`)

### `exchange-api`

- The Exchange REST API (Fastify) — the single server every client (both web apps, any future third-party integration) talks to.
- Publisher API, Package API, Search API, Download API, Administration API.
- Request validation, error-response shaping (`DomainError` → `ApiErrorResponse`), and OpenAPI documentation generation.
- Owns nothing about _how_ a request is fulfilled beyond routing/validation/response shaping — the actual work is delegated to `packages/*` service packages (`manifest`, `signing`, `search`, `package-manager`).
- Owns the database connection and every query issued against it (no other app or package talks to PostgreSQL directly).

### `publisher-portal`

- The publisher- and engineer-facing web experience: Home, Search, Package Details, Publisher Profile, Upload, My Packages.
- Publisher experience and package management from the publisher's point of view; package discovery and download from the engineer's point of view.
- Owns UI state and presentation only — no direct database or filesystem access; every capability it offers is a call through `exchange-client` to `exchange-api`.

### `exchange-admin`

- Administration: reviewing/approving submitted packages, moderation, publisher/account management, platform configuration visible to administrators.
- Kept separate from `publisher-portal` specifically so Administration can be deployed and access-controlled independently.
- Same UI-only ownership boundary as `publisher-portal` — no direct persistence access.

---

## Packages (`packages/`)

### `core`

- Domain primitives and shared engineering types: `Result<T,E>`, the `DomainError` family, `newId()`, the injectable `Clock`.
- The error-model vocabulary every other package and the API surface build on.
- Owns nothing Exchange-domain-specific (no Publisher/Package/Search concepts) — if it's specific to what the Exchange does, it does not belong here.

### `api-contracts`

- The versioned REST wire contract: request/response DTOs, schemas, the `ApiErrorResponse` envelope, `EXCHANGE_API_VERSION`.
- The single source of truth both `exchange-api` (the server) and every client (`exchange-client`, and transitively both web apps) compile against — a contract change is one change here, not a change duplicated in multiple places.
- Owns type definitions only — no HTTP client logic (that's `exchange-client`) and no server-side handling (that's `exchange-api`).

### `exchange-client`

- The typed HTTP client SDK for the Exchange REST API.
- Used by `installer`, `update-service`, and both web apps as their only path to `exchange-api` — no consumer is expected to construct its own HTTP requests against the API directly.

### `manifest`

- Parsing and validating OEP Package Manifests (PKG-002).
- The authoritative answer to "is this manifest well-formed," consumed by `package-manager`'s upload pipeline and (eventually) `dependency-resolver`.

### `signing`

- Verifying package digital signatures (PKG-005) during upload.
- Owns signature _verification_ only, not key management/issuance (out of this repository's scope per WP-EXC-001 — see `docs/specifications/package/PKG-005-OEP_PACKAGE_TRUST_AND_DIGITAL_SIGNATURE_SPECIFICATION.md`).

### `search`

- Package Catalog search indexing and querying: keyword, category, publisher, version lookup.
- Owns the search index itself — no other package queries or writes to it directly.

### `package-manager`

- Orchestrates the upload pipeline end to end: validation → manifest parsing → metadata extraction → signature verification → catalog registration → publication.
- The single place that sequences `manifest`, `signing`, and catalog writes — no other package/app is expected to re-implement any part of this pipeline.

### `dependency-resolver`

- Resolving Engineering Package dependency graphs (PKG-004), for the eventual case where installing one package requires installing its declared dependencies too.
- Deferred beyond WP-EXC-001's MVP scope (a single-package install has no graph to resolve yet) — owns this responsibility once a future work package needs it, not before.

### `installer`

- Invoking the Package Transaction Engine and Repository Merge Engine, through public Repository interfaces only, to install a downloaded package into an OEP Repository.
- The one and only place a cross-repository "install into Foundation's Repository" call is made from — see `packages/interfaces` for the contract this will eventually depend on.

### `update-service`

- Checking installed packages for available updates.
- Deferred beyond WP-EXC-001's explicit deliverable list.

### `licensing`

- License issuance, entitlements, subscription validation (EXC-005).
- Explicitly excluded from WP-EXC-001's scope ("Licensing beyond Free Packages"); owned here as a placeholder for WP-EXC-003.

### `payments`

- Commerce: purchases, subscriptions, revenue distribution (EXC-010).
- Explicitly excluded from WP-EXC-001's scope; owned here as a placeholder for WP-EXC-004.

### `reviews`

- Ratings, reviews, verification badges, publisher reputation (EXC-006).
- Explicitly excluded from WP-EXC-001's scope; owned here as a placeholder for WP-EXC-002.

### `interfaces`

- Future cross-repository integration contracts only (`RepositoryService`, `IdentityService`, `AuditService`, `GovernanceService`, `PackageTransactionService`, and any others as they become needed) — never an implementation.
- Owns the _shape_ of a future cross-repository call, once specified; owns nothing that runs.

---

## Database (`db/`)

- Owns the Exchange's own PostgreSQL schema and every Flyway migration that has ever changed it (forward-only, no manual changes).
- No package or app other than `exchange-api` connects to this database directly.
