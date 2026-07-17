# OEP Acquisition (Engineering Acquisition Manager)

The Trust Layer of the Open Engineering Platform (OEP): engineering
acquisition, provenance, integrity, licensing, and trusted evidence. See
`oep_architecture/docs/architecture/PLATFORM_SERVICES_ARCHITECTURE.md`
and this repository's own `docs/architecture/SDD-R013` through
`SDD-R019` for the full architecture.

## Status

**WORK_PACKAGE_001 (Repository Bootstrap), WORK_PACKAGE_002 (Official
Source Registry), and WORK_PACKAGE_003 (Engineering Acquisition Job
Engine) implemented.** The Job Engine is the orchestration layer for
future acquisition operations: it creates, tracks, and validates
acquisition jobs, each referencing a registered Official Source, but
performs no network communication, downloading, metadata extraction, or
integrity verification itself -- no background workers, scheduling, or
parallel execution exist yet either. Browser automation, the download
engine, metadata extraction, integrity verification, license management,
and the Reference Vault remain out of scope -- see
`docs/tasks/WORK_PACKAGE_001.md`, `docs/tasks/WORK_PACKAGE_002.md`, and
`docs/tasks/WORK_PACKAGE_003.md`.

## Build

Requires:

- CMake 3.25+
- A C++23 compiler (MSVC, or another compiler with equivalent C++23 support)
- PostgreSQL 18 development files (headers + `libpq`) -- see
  [postgresql.org/download](https://www.postgresql.org/download/); on
  Windows this ships with the standard installer
- Network access the first time you configure (CMake's `FetchContent`
  downloads spdlog, nlohmann/json, tomlplusplus, cpp-httplib, and
  Catch2 -- see "Implementation Decisions" below)

From a shell with your C++ toolchain on `PATH` (e.g. a Visual Studio
Developer Command Prompt on Windows):

```
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

If CMake cannot find PostgreSQL automatically, point it at your
installation explicitly:

```
cmake -S . -B build -DCMAKE_PREFIX_PATH="C:/Program Files/PostgreSQL/18"
```

## Run

```
build/src/app/oep_acquisition[.exe] config/config.toml
```

The config file argument is optional -- every setting has a documented
default (`include/oep/acquisition/common/config.hpp`) and the process
starts without one. On Windows, `libpq.dll` (and its own dependencies)
must be reachable on `PATH` at runtime; PostgreSQL's own `bin/`
directory already contains it:

```
set PATH=C:\Program Files\PostgreSQL\18\bin;%PATH%
```

Verify it's alive:

```
curl http://127.0.0.1:8080/health
# {"status":"ok"}
```

A database connection failure is logged as a warning, never fatal --
WORK_PACKAGE_001 requires the connection object to exist and behave
correctly, not that a matching PostgreSQL instance is running wherever
the process starts. WORK-PACKAGE-002's Official Source Registry
repository follows the same non-fatal precedent: if it cannot connect
at startup, the process still starts with `GET /health` only --
`/sources` becomes available again on the next restart once the
database is reachable.

### Official Source Registry API

Once a database with the `official_sources` table (see
`migrations/V2__official_sources.sql`) is reachable:

```
GET    /sources                List sources; optional query filters:
                                status, trust_level, category, country
GET    /sources/{id}           Fetch one source by UUID
POST   /sources                Create a source (JSON body)
PUT    /sources/{id}           Replace a source (JSON body)
DELETE /sources/{id}           Soft-delete a source
```

```
curl -X POST http://127.0.0.1:8080/sources \
  -H "Content-Type: application/json" \
  -d '{"name":"IEEE","base_url":"https://ieee.org","trust_level":5,"status":"active"}'
```

`name`, `base_url`, `trust_level` (0-5), and `status` (`proposed`,
`approved`, `active`, `suspended`, `deprecated`, `archived`) are
required; `authentication_type` (`none`, `username_password`,
`api_key`, `oauth2`, `client_certificate`) defaults to `none`. `id` and
`created_at` are assigned by the database and immutable afterward --
attempting to change either on `PUT` returns `422`.

### Acquisition Job Engine API

Once a database with the `acquisition_jobs` table (see
`migrations/V3__acquisition_jobs.sql`) is reachable:

```
GET    /jobs                   List jobs; optional query filters:
                                status, priority, source_id, requested_by
GET    /jobs/{id}               Fetch one job by UUID
POST   /jobs                   Create a job (JSON body) -- always starts
                                in the "created" status
PUT    /jobs/{id}               Replace a job (JSON body); this is how a
                                job's status/started_at/completed_at/
                                error_message are changed
DELETE /jobs/{id}               Soft-delete a job
```

```
curl -X POST http://127.0.0.1:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{"source_id":"<a Source id from /sources>","name":"Acquire IEEE 802.11","priority":2}'
```

`name`, `source_id`, and `priority` (0-3) are required; `source_id` must
reference an existing Official Source (`/sources/{id}`) or the request
returns `422` (`"error":"unknown_source"`). `status` is never accepted
on `POST` -- a job always starts in the `created` status ("Jobs shall
remain in the Created state unless explicitly changed through the
API" -- WORK_PACKAGE_003) -- and is only changed via a subsequent `PUT`,
which requires `status` (`created`, `queued`, `running`, `completed`,
`failed`, `cancelled`) and accepts optional `started_at`/`completed_at`/
`error_message`. As with Sources, `id` and `created_at` are immutable
after creation.

## Test

```
ctest --test-dir build --output-on-failure
```

Configuration parsing, the database connection wrapper's failure path,
a real end-to-end `GET /health` request against the embedded HTTP
server (bound to an OS-assigned ephemeral port, so tests never collide
with a fixed port number or each other), and -- for both the Official
Source Registry and the Acquisition Job Engine -- validation,
Service-layer (against an in-memory fake repository), Repository-layer,
REST API, and migration/schema-shape tests.

The Repository/API/migration categories need a real PostgreSQL database
and `SKIP` (not fail) if one isn't reachable, continuing
WORK_PACKAGE_001's precedent that the suite stays runnable without a
live database, just less exercised. To run them for real, create a
role and database matching `config/config.toml`'s defaults:

```sql
CREATE ROLE oep_acquisition LOGIN PASSWORD 'your-local-dev-password';
CREATE DATABASE oep_acquisition OWNER oep_acquisition;
```

then either edit `config/config.toml`'s `[database] password` locally
(never commit a real credential there) or point the tests at different
connection settings via environment variables, which take precedence:

```
OEP_TEST_DB_HOST, OEP_TEST_DB_PORT, OEP_TEST_DB_NAME,
OEP_TEST_DB_USER, OEP_TEST_DB_PASSWORD
```

The Repository/API/migration tests apply `migrations/V1__initial_schema.sql`,
`migrations/V2__official_sources.sql`, and (for the Job Engine's own
tests) `migrations/V3__acquisition_jobs.sql` verbatim from disk the
first time they run against a given database (so they exercise the
real, committed migration files) and `TRUNCATE` the affected tables
between test runs -- no Flyway CLI install is required to run them,
though a production deployment should still apply migrations via
Flyway (`migrations/flyway.toml`).

## Directory Layout

```
CMakeLists.txt          Root build: C++23, FetchContent dependencies, subdirectories
config/
  config.toml            Example/default process configuration
include/oep/acquisition/  Public headers, one subdirectory per module
  common/                 Config, Logger, uuid (shared UUID-shape check)
  database/                DatabaseConnection (connection only, libpq)
  registry/                Official Source Registry domain model,
                           validation, Repository interface + PostgreSQL
                           implementation (libpqxx), Service
  acquisition/             Acquisition Job Engine domain model,
                           validation, Repository interface + PostgreSQL
                           implementation (libpqxx), Service
  api/                     ApiServer (GET /health, /sources, /jobs routes)
src/
  common/                 Logging + TOML configuration loading + uuid
  database/                PostgreSQL connection management (libpq)
  registry/                Official Source Registry (WORK_PACKAGE_002)
  acquisition/             Acquisition Job Engine (WORK_PACKAGE_003) --
                           reuses the directory WORK_PACKAGE_001 reserved
                           under this name (see "Implementation Decisions")
  api/                     Embedded HTTP server: GET /health, /sources, /jobs
  app/                     main() -- wires the above together
  browser/ integrity/ licensing/ metadata/
  vault/ workspace/        Reserved for future work packages (empty --
                           see "Out of Scope" in WORK_PACKAGE_001.md,
                           WORK_PACKAGE_002.md, and WORK_PACKAGE_003.md)
migrations/
  V1__initial_schema.sql       Flyway migration placeholder (WORK_PACKAGE_001)
  V2__official_sources.sql     official_sources table (WORK_PACKAGE_002)
  V3__acquisition_jobs.sql     acquisition_jobs table (WORK_PACKAGE_003)
  flyway.toml                  Flyway configuration (not yet invoked)
tests/                    Catch2 test suite
docs/
  architecture/            SDD-R013 through SDD-R019 (ratified architecture)
  specifications/          Schema and API specifications
  decisions/               ADRs
  tasks/                   Work package specifications
```

## Implementation Decisions

Recorded here per CLAUDE.md's "Document assumptions" default behavior
-- none of these redesign approved architecture; each fills a gap
WORK_PACKAGE_001 itself left unspecified.

**API framework: embedded C++ (`cpp-httplib`), not Node/Fastify.**
`PROJECT_CONTEXT.md` lists "Primary API: Fastify" in the platform's
technology stack, but WORK_PACKAGE_001's own text asks only for a
minimal `GET /health` endpoint alongside an otherwise entirely-C++
bootstrap (CMake, spdlog, TOML, PostgreSQL, Catch2), and no
Fastify/Node code exists anywhere else in the platform yet. Introducing
an entire second language/runtime for one hardcoded JSON response,
with no binding layer to the C++ core described anywhere in this work
package, was confirmed out of scope for this work package rather than
assumed. The API framework itself has not been ratified and is
expected to be decided by a future architecture decision record; this
bootstrap uses a lightweight, header-only, in-process C++ HTTP library
so the single `/health` route has somewhere to live today.

**Database client: raw `libpq` for connection management (WORK_PACKAGE_001),
`libpqxx` for the Repository layer (WORK-PACKAGE-002).**
WORK_PACKAGE_001 asked only for "connection management. Connection
only. No schema. No repositories," so `DatabaseConnection`
(`src/database/database_connection.cpp`) stayed a small RAII wrapper
directly over the raw C API. WORK-PACKAGE-002 introduces the first real
Repository layer -- parameterized CRUD plus dynamic filtering -- which
is exactly the reassessment this file's "Future Considerations"
previously flagged; `libpqxx` (fetched via `FetchContent`, pinned to
`7.9.2`, same as every other dependency) now sits alongside raw `libpq`
so `PostgresOfficialSourceRepository` gets safe parameter binding, RAII
transactions, and typed field access instead of hand-rolled C-string
query building. `DatabaseConnection` itself is unchanged.

**`trust_level`/`status`/`authentication_type` stored as constrained
values, not native PostgreSQL `ENUM` types.** WORK-PACKAGE-002's Source
Model note ("Future fields shall not require schema redesign") is
better served by a `CHECK` constraint than a native enum: adding an
allowed value to a `CHECK` constraint is a plain, ordinary migration,
while adding a value to a PostgreSQL enum type carries additional
transactional restrictions (a newly added enum value cannot be used in
the same transaction that added it). See
`migrations/V2__official_sources.sql`.

**Externally-visible `id` is a UUID column, distinct from the
internal surrogate primary key.** WORK-PACKAGE-002's suggested column
list includes both `id` and `uuid`; this repository treats the
`BIGSERIAL id` as an internal-only storage key (never returned by the
API) and the `UUID` column as the identifier used throughout the REST
API and JSON bodies (`"id"` in a response is this UUID, not the
internal row number) -- both because REST resources are conventionally
addressed by a natural/opaque key rather than a sequential row number,
and because a sequential id would leak the row-insertion order and
approximate total row count to any API client.

**`src/acquisition/` reuses the directory WORK_PACKAGE_001 reserved
under that name, rather than a new `src/jobs/`.** WORK_PACKAGE_001's
reserved-but-empty directories were named after Out-of-Scope items it
listed (`registry`, `vault`, `integrity`, `metadata`, `browser`,
`licensing`, `workspace`) plus one extra, `acquisition`, with no
corresponding named item -- the natural reading is that it was reserved
for the acquisition orchestration work itself (what SDD-A001 calls the
"Engineering Acquisition Manager": "Create acquisition jobs, monitor
acquisition progress"), which is exactly WORK_PACKAGE_003's Job Engine.
Reusing it keeps the directory-name -> namespace -> CMake-target
convention established by `registry` without introducing a directory
WORK_PACKAGE_001 didn't already anticipate. The one cost is a namespace
stutter, `oep::acquisition::acquisition::AcquisitionJob` -- accepted as
the smaller deviation. The CMake target itself is named
`oep_acquisition_jobs` rather than the doubled `oep_acquisition_acquisition`,
since the target name is an internal build detail, not part of the
public API surface.

**`source_id` is a real PostgreSQL foreign key to `official_sources(uuid)`,
not just an application-level presence check.** WORK_PACKAGE_003's only
stated rule is "Source ID required," but both tables live in this same
repository/database, so a genuine `REFERENCES` constraint (see
`migrations/V3__acquisition_jobs.sql`) enforces that a job's source
actually exists as real relational integrity (Engineering Principle 5:
Deterministic Systems) rather than a second, potentially-divergent
check reimplemented in the Job Engine's own service layer. A foreign
key violation is caught and re-thrown as a domain-specific
`UnknownSourceError`, surfaced over REST as `422`, so callers don't need
to know the Job repository is backed by PostgreSQL to handle it.

**Job `Priority` is a small integer enum (`Low`/`Normal`/`High`/`Urgent`,
0-3), an assumption filling a genuine gap.** Unlike Job Status,
WORK_PACKAGE_003's own text never enumerates Priority's allowed values
-- it only says "Priority required." A small ordered scale matching
Trust Level's precedent (WORK_PACKAGE_002) was chosen over an
unconstrained integer so "required" has a concrete, validated meaning
and "Future fields shall not require schema redesign" is satisfied by a
`CHECK` constraint the same way Status/Trust Level are. `Requested By`
is treated as a free-text field (no validation beyond optional), since
no identity/session system exists anywhere in the platform yet for a
job's requester to be derived from (SDD-P002 is listed as a
WORK_PACKAGE_003 dependency for context, not as something this work
package implements -- consistent with how WORK_PACKAGE_002 treated the
same five platform SDDs).

**Dependency management: CMake `FetchContent`, not vcpkg/Conan.** No
package manager was already set up in this environment or evidenced
elsewhere in the platform. `FetchContent` is built into CMake itself,
needs no additional tool install, and pins every dependency to an
explicit tagged version (never a floating branch) for reproducible
builds.

## TODOs

- WORK_PACKAGE_004 onward: Browser automation, the download engine
  itself (an HTTP client acquiring real evidence via a Job), Integrity,
  Licensing, Reference Vault, Metadata Extraction -- per
  `docs/architecture/SDD-R013` through `SDD-R019`.
- `migrations/flyway.toml` is still not invoked by any automated
  process (see Future Considerations below).

## Future Considerations

- `migrations/flyway.toml` is not yet invoked by any automated process
  -- a future work package should wire `flyway migrate` into the build
  or a deployment step. Repository/API/migration tests currently apply
  `V1__initial_schema.sql`, `V2__official_sources.sql`, and
  `V3__acquisition_jobs.sql` verbatim themselves (see "Test" above) as a
  stand-in.
- A connection pool for `PostgresOfficialSourceRepository` and
  `PostgresAcquisitionJobRepository` (each currently one
  `pqxx::connection` per repository instance, held for the process's
  lifetime) should be reassessed once concurrent request volume makes
  single-connection serialization a bottleneck.
- No background workers, scheduling, or parallel execution exist to
  actually run a Job -- WORK_PACKAGE_003 explicitly excludes them. A
  Job's `status`/`started_at`/`completed_at`/`error_message` are only
  ever changed by whatever calls `PUT /jobs/{id}` today; the future work
  package that adds an execution engine will need to decide who calls
  that (or an equivalent internal API) and whether any transition
  restrictions belong on top of what's currently an unrestricted manual
  state change (WORK_PACKAGE_003: "No automatic state transitions are
  required," which this reads as also meaning no restriction on which
  manual transitions are valid).
- WORK-PACKAGE-002's REST API section lists exactly five `/sources`
  routes plus `/health`, with no dedicated enable/disable endpoints,
  even though its Functional Requirements section separately lists
  "Enable Source" / "Disable Source". `OfficialSourceService::enable`/
  `disable` exist and are unit-tested, reachable today only via the
  Service layer (or, over REST, a generic `PUT` status change) -- a
  future work package should decide whether dedicated
  `POST /sources/{id}/enable` style routes are warranted.
- No pagination (`limit`/`offset`/`cursor`) is implemented for
  `GET /sources` -- WORK-PACKAGE-002's own REST API section doesn't
  ask for it, unlike `docs/specifications/ENGINEERING_ACQUISTION_API_SPECIFICATION.md`'s
  broader target-state API (versioned `/api/v1` prefix, cursor
  pagination, OAuth2/JWT authentication on every request, events). That
  document describes the Engineering Acquisition Manager's long-term
  API vision; WORK-PACKAGE-002 is a deliberately smaller Milestone-1
  slice of it (no versioned prefix, no authentication -- explicitly out
  of scope: "Authentication providers"). Implementing this work package
  to the letter of its own REST API section, rather than the broader
  specification, matches ARCHITECTURE_AMENDMENT_POLICY.md's "do not
  expand scope" guidance; reconciling the two documents (likely via a
  future ADR or an updated SDD) is recommended before a work package
  that adds authentication or versioning to this API.
- `docs/architecture/SDD-R014-OFFICIAL_SOURCE_REGISTRY.md` and
  `docs/specifications/OFFICIAL_SOURCE_SCHEMA.md` describe a richer,
  hierarchical Organization -> Endpoint -> Service model (each with its
  own identifier, type enumeration, and metadata) than WORK-PACKAGE-002's
  flat `OfficialSource` entity. WORK-PACKAGE-002's own Trust Levels and
  Source Status values match `oep_architecture`'s
  `docs/acquisition/SDD-A002-OFFICIAL_SOURCE_REGISTRY.md` closely
  (both platform-level documents), suggesting the flat model is the
  reconciled Milestone-1 design and the repository-local SDD-R014/
  OFFICIAL_SOURCE_SCHEMA.md describe a longer-term richer vision not
  yet folded into an approved work package. This implementation follows
  WORK-PACKAGE-002 (the approved, most specific instruction) as written;
  a future work package that needs to model multiple endpoints/services
  per organization will need to reconcile these documents, likely via
  an ADR or an updated SDD-R014, before extending the schema.
