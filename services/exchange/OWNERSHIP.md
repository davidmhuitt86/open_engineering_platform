# Ownership

Ownership responsibilities for every application and package currently in this repository. This is a statement of what each unit _owns_ — the concerns it is the single, authoritative home for — not an implementation-status report (see each package's own README, `docs/tasks/WP-EXC-001.md`, and `IMPLEMENTATION_STATUS.md`-equivalent tracking for that).

See `CONTRIBUTING_ARCHITECTURE.md` for the rules that keep these boundaries real, and `docs/architecture/DEPENDENCY_GRAPH.md` for how ownership maps to allowed dependency direction.

---

## Applications (`apps/`)

### `exchange-api`

- The Exchange REST API (Fastify) — the single server every client (both web apps, any future third-party integration) talks to.
- Publisher API, Package API, Search API, Download API, Installation API, Administration API.
- Request validation, error-response shaping (`DomainError` → `ApiErrorResponse`), and OpenAPI documentation generation.
- Owns nothing about _how_ a request is fulfilled beyond routing/validation/response shaping. For capabilities a `packages/*` package owns (manifest parsing, signing, search query normalization, Repository communication), the actual work is delegated there. The Publisher Registry (TASK-EXC-0003), Package Catalog (TASK-EXC-0004), Upload Pipeline (TASK-EXC-0005), Package Search (TASK-EXC-0006), Package Download Service (TASK-EXC-0007), and Repository Installation Integration (TASK-EXC-0008) are the exceptions: their business logic (`src/services/publisher-service.ts`, `src/services/package-service.ts`, `src/services/upload-service.ts`, `src/services/search-service.ts`, `src/services/download-service.ts`, `src/services/installation-service.ts`, and each one's validation module) lives inside `exchange-api` itself rather than a package, because it calls straight into `src/persistence/`, which no package can depend on (see `docs/architecture/DEPENDENCY_GRAPH.md` §3 and `docs/architecture/REPOSITORY_STRUCTURE.md` §13.2/§14.2/§15.2/§16.1/§17.1/§18.2).
- Owns the `search_index` query (`src/persistence/repositories/search-repository.ts`, TASK-EXC-0006) — the only place `search_index` is read; it is kept current by a PostgreSQL trigger on `packages` (`db/migrations/V5__search_index.sql`), not by any application code.
- Owns the database connection and every query issued against it (no other app or package talks to PostgreSQL directly) — its persistence layer lives at `src/persistence/` (config, pooling, domain types, and one repository interface + PostgreSQL implementation per table in `db/migrations/V1__initial_exchange_schema.sql`), built in TASK-EXC-0002.
- Owns uploaded package artifact storage (`src/storage/`, TASK-EXC-0005) — content-addressable local-disk storage for `.oep` archives, the on-disk counterpart to the `package_files` table. No other app or package writes (or, since TASK-EXC-0007's `retrieve()`, reads) package artifacts on disk directly.

### `publisher-portal`

- The Engineering Exchange Web Application (real implementation since TASK-EXC-0009): Marketplace Home, Search Results, Package Detail, Publisher Profile, Downloads, My Library, 404, plus the application shell and responsive navigation.
- Package discovery, search, download, and installation from the engineer's point of view. Publisher self-service (package upload, publisher account management) is explicitly out of TASK-EXC-0009's scope and remains unbuilt.
- Owns UI state and presentation only — no direct database or filesystem access; every capability it offers is a call through `exchange-client` to `exchange-api`. Owns one piece of browser-local state, `LibraryContext` (the Downloads/My Library history) — necessary only because authentication (and therefore a server-side "current user") is out of scope; every value it stores still comes from a real API response.

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

- The typed HTTP client SDK for the Exchange REST API (real implementation since TASK-EXC-0009: `ExchangeApiClient` with `publishers`/`packages`/`search`/`installations`/`downloads` resources, each a thin wrapper over one shared `HttpClient`).
- Used by `installer`, `update-service`, and both web apps as their only path to `exchange-api` — no consumer is expected to construct its own HTTP requests against the API directly. `publisher-portal` is its first real consumer.

### `manifest`

- Parsing and validating OEP Package Manifests (PKG-002), including extracting the manifest from a `.oep` archive (PKG-001 §5's ZIP container) — real implementation since TASK-EXC-0005.
- The authoritative answer to "is this manifest well-formed," consumed by `package-manager`'s upload pipeline and (eventually) `dependency-resolver`.

### `signing`

- Verifying package digital signatures (PKG-005) during upload.
- Owns signature _verification_ only, not key management/issuance (out of this repository's scope per WP-EXC-001 — see `docs/specifications/package/PKG-005-OEP_PACKAGE_TRUST_AND_DIGITAL_SIGNATURE_SPECIFICATION.md`).

### `search`

- Validating and normalizing raw Package Catalog search queries, and computing pagination metadata (real implementation since TASK-EXC-0006): identifier/enum validation, `page`/`pageSize` clamping, `totalPages`/`currentPage` math.
- Does not query or write the search index itself — this package cannot hold a database connection or depend on an application (`docs/architecture/DEPENDENCY_GRAPH.md` §3), so `exchange-api`'s `SearchRepository`/`SearchService` own the actual `search_index` query and the index is kept current by a database trigger, not application code — see `docs/architecture/REPOSITORY_STRUCTURE.md` §16.1/§16.2.

### `package-manager`

- Orchestrates the non-persistence stages of the upload pipeline: archive extraction → manifest parsing → metadata extraction (real implementation since TASK-EXC-0005). Signature verification is read but not yet performed (excluded from WP-EXC-005.md §2 — `signing`'s real implementation is a future task's deliverable); catalog registration and file storage are `exchange-api`'s `UploadService`'s job, since this package cannot hold a database connection or depend on an application (`docs/architecture/DEPENDENCY_GRAPH.md` §3) — see `docs/architecture/REPOSITORY_STRUCTURE.md` §15.1/§15.2.
- The single place that sequences `manifest` parsing and metadata extraction — no other package/app is expected to re-implement any part of this pipeline.

### `dependency-resolver`

- Resolving Engineering Package dependency graphs (PKG-004), for the eventual case where installing one package requires installing its declared dependencies too.
- Deferred beyond WP-EXC-001's MVP scope (a single-package install has no graph to resolve yet) — owns this responsibility once a future work package needs it, not before.

### `installer`

- Invoking the Package Transaction Engine and Repository Merge Engine, through public Repository interfaces only, to install a downloaded package into an OEP Repository — real implementation since TASK-EXC-0008.
- The one and only place a cross-repository "install into Foundation's Repository" call is made from: `RepositoryClient` (the contract, defined in `packages/interfaces`), `HttpRepositoryClient` (a real HTTP implementation against a configurable Repository base URL), and `StubRepositoryClient` (a deterministic stand-in, used by default until a real Repository is reachable — no Repository implementation exists in this platform yet, `docs/tasks/WP-EXC-008.md` §2). `apps/exchange-api`'s `InstallationService` is the only consumer.

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

- Cross-repository integration contracts only — never an implementation. `RepositoryClient` (TASK-EXC-0008) is the first of these actually defined; `IdentityService`, `AuditService`, `GovernanceService`, and any others remain future, not-yet-specified contracts.
- Owns the _shape_ of a cross-repository call, once specified; owns nothing that runs. Only `installer` depends on it, and only for `RepositoryClient`.

---

## Database (`db/`)

- Owns the Exchange's own PostgreSQL schema and every Flyway migration that has ever changed it (forward-only, no manual changes).
- No package or app other than `exchange-api` connects to this database directly.
