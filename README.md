# OEP Acquisition (Engineering Acquisition Manager)

The Trust Layer of the Open Engineering Platform (OEP): engineering
acquisition, provenance, integrity, licensing, and trusted evidence. See
`oep_architecture/docs/architecture/PLATFORM_SERVICES_ARCHITECTURE.md`
and this repository's own `docs/architecture/SDD-R013` through
`SDD-R019` for the full architecture.

## Status

**WORK_PACKAGE_001 through WORK_PACKAGE_006 implemented, plus ADR-0008
(Connector Content Retrieval Interface).** WORK_PACKAGE_006 (Engineering
Downloader) retrieves engineering artifacts exclusively through the
Source Connector Framework's `fetch` operation (ADR-0008), validates the
requesting Job and Connector, stores the artifact in a configurable
local workspace, and tracks progress/history -- but, like every work
package before it, `StubConnector` remains the only connector type and
performs no real network communication (`fetch` writes a small
placeholder file locally). Integrity verification, metadata extraction,
Reference Vault publication, and Engineering Object creation are
explicitly out of scope for the Downloader; browser automation, license
management, and the Reference Vault itself remain out of scope
platform-wide -- see `docs/tasks/WORK_PACKAGE_001.md` through
`docs/tasks/WORK_PACKAGE_006.md` and
`docs/decisions/ADR-0002-PROPOSED-CONNECTOR-CONTENT-RETRIEVAL.md`
(superseded by `oep_architecture`'s ratified ADR-0008).

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

### Acquisition Execution Engine API

Once a database with the `acquisition_job_execution_history` table (see
`migrations/V4__job_execution_history.sql`) is reachable:

```
POST /jobs/{id}/execute   Advance the job by one execution step
POST /jobs/{id}/cancel    Cancel a Queued or Running job
GET  /jobs/{id}/status    Current status + started_at/completed_at/
                          error_message + full execution history
```

```
curl -X POST http://127.0.0.1:8080/jobs/<id>/execute
```

Each `POST .../execute` call advances the job by exactly one step along
`created -> queued -> running -> completed` -- call it three times to
run a job to completion (see "Implementation Decisions" for why one
generic action advances by a single step rather than one endpoint per
edge, or jumping straight to `completed`). `POST .../cancel` moves a
`queued` or `running` job to `cancelled`. Both return `409` with
`"error":"invalid_transition"` if the job's current status has no valid
edge for the requested action (e.g. calling `execute` on a `completed`
job), and `execute` additionally returns `409` with
`"error":"source_unavailable"` if the job's Official Source is archived
or no longer exists (soft-deleted). Both return `404` if the job doesn't
exist or is soft-deleted. Every transition is appended to an immutable
execution history, returned in order by `GET /jobs/{id}/status`.

### Source Connector Framework API

Connectors are registered in-memory by `main.cpp` at startup (there is
no `POST /connectors` -- see "Implementation Decisions"), so this API
is read-only:

```
GET /connectors                      List every registered connector
GET /connectors/{id}                 Fetch one connector's configuration
GET /connectors/{id}/capabilities    That connector's declared capabilities
GET /connectors/{id}/health          That connector's current health check result
```

```
curl http://127.0.0.1:8080/connectors
```

The process registers one example connector of type `"stub"` at
startup (`StubConnector` -- performs no real network communication,
proves the framework end to end) so `/connectors` is never empty in a
fresh checkout. All four routes return `404` for an unknown connector
id.

`IConnector` also exposes `fetch(const AcquisitionRequest&) ->
AcquisitionResult` (ADR-0008) -- there is still no REST route for it on
`/connectors` itself (retrieving content is the Downloader's concern,
below, not this framework's), but it is no longer only reachable from
tests: `POST /downloads` now calls it for real.

### Engineering Downloader API

```
POST /downloads                   Start a download (JSON body)
GET  /downloads                   List downloads; optional query filters:
                                   status, job_id, connector_id
GET  /downloads/{id}              Fetch one download
GET  /downloads/{id}/status       Status + progress + timing only
POST /downloads/{id}/cancel       Cancel a Pending or Downloading download
```

```
curl -X POST http://127.0.0.1:8080/downloads \
  -H "Content-Type: application/json" \
  -d '{"job_id":"<a Job id from /jobs>","connector_id":"example-stub","source_uri":"stub://example/artifact.pdf"}'
```

`job_id`, `connector_id`, and `source_uri` are required; `file_name` is
optional (derived from `source_uri`'s last path segment if omitted).
`POST /downloads` validates, in order (WORK_PACKAGE-006 Validation
Rules), that the job exists (`422 unknown_job`) and is executable (`409
job_not_executable` -- reuses `next_execution_status`'s definition of
"executable": Created, Queued, or Running, i.e. not yet terminal), that
the connector exists (`422 unknown_connector`) and is healthy (`409
connector_unhealthy`), and that the computed local storage destination
is usable (`422 invalid_destination`). It then **synchronously**
resolves the destination under `[storage] workspace_path`, calls
`fetch`, and returns the Download in its final state (`completed` or
`failed`) -- see "Implementation Decisions" for why this is synchronous
rather than backgrounded. `POST .../cancel` returns `409
invalid_transition` for a download that isn't `pending` or
`downloading` (in practice, with only the instant `StubConnector`
available, every download normally reaches a terminal state before a
client could ever call cancel -- see "Implementation Decisions" and
"Future Considerations"). All routes return `404` for an unknown
download id.

## Test

```
ctest --test-dir build --output-on-failure
```

Configuration parsing, the database connection wrapper's failure path,
a real end-to-end `GET /health` request against the embedded HTTP
server (bound to an OS-assigned ephemeral port, so tests never collide
with a fixed port number or each other), and -- for the Official Source
Registry and the Acquisition Job Engine -- validation, Service-layer
(against an in-memory fake repository), Repository-layer, REST API, and
migration/schema-shape tests. The Execution Engine adds: pure state-
transition unit tests, Service-layer tests (against in-memory fakes for
all three of its repository dependencies), a Repository-layer test for
the execution history table, and REST API tests covering the full
execute-to-completion lifecycle, cancellation, and every rejection case
(terminal state, archived/deleted source, unknown/deleted job). The
Connector Framework adds Factory tests, Registry tests (unique-id,
unknown-type, and failed-validation rejection), `StubConnector` tests
(capability parsing, configurable health status, validate_configuration),
and a REST API test that doubles as WORK_PACKAGE-005's integration test
(Factory + Registry + REST layer wired together exactly as `main.cpp`
wires them) -- entirely in-memory, so unlike every other category above,
none of it needs a database and none of it ever `SKIP`s. ADR-0008 adds
`StubConnector.fetch` tests: successful write-to-disk with a real
temporary file, configurable MIME type and failure outcome, the
overwrite guard (both respected and bypassed), an already-cancelled
`std::stop_token` short-circuiting before any file is written, and
progress-callback invocation -- also entirely in-memory/local-disk, no
database needed. WORK_PACKAGE-006 adds validation tests, a dedicated
progress-tracking test suite for `clamp_progress_percentage` (pure,
in-memory -- exact percentages, an unknown-total edge case, and the
over/under-100 clamping rule), Service-layer tests (against an
in-memory fake Download repository, a fake Job repository, and a real
in-memory `ConnectorRegistry`/`StubConnector`, covering the full
success/failure path and every Validation Rule rejection),
Repository-layer tests, migration/schema-shape tests, and a REST API
test covering the full lifecycle plus cancelling a `Pending` download
seeded directly via the repository (see "Implementation Decisions" for
why that's the only deterministic way to test cancellation with a
synchronous, instant `StubConnector`).

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

The Repository/API/migration tests apply `migrations/V1__initial_schema.sql`
through `migrations/V5__download_sessions.sql` verbatim from disk the
first time they run against a given database (so they exercise the
real, committed migration files) and `TRUNCATE ... CASCADE` the
affected tables between test runs -- `CASCADE` matters here: once
`acquisition_jobs` and its dependents exist, truncating
`official_sources` alone fails on its own foreign key unless the
dependent tables are truncated too (or `CASCADE` is used), which is
exactly what happened when WORK_PACKAGE_004's history table first made
the chain three tables deep -- see `tests/registry_test_support.cpp`,
`tests/jobs_test_support.cpp`, and `tests/downloads_test_support.cpp`.
No Flyway CLI install is required to run these tests, though a
production deployment should still apply migrations via Flyway
(`migrations/flyway.toml`).

## Directory Layout

```
CMakeLists.txt          Root build: C++23, FetchContent dependencies, subdirectories
config/
  config.toml            Example/default process configuration
include/oep/acquisition/  Public headers, one subdirectory per module
  common/                 Config, Logger, uuid (shared UUID-shape check),
                           time (shared UTC timestamp formatting)
  database/                DatabaseConnection (connection only, libpq)
  registry/                Official Source Registry domain model,
                           validation, Repository interface + PostgreSQL
                           implementation (libpqxx), Service
  acquisition/             Acquisition Job Engine + Execution Engine
                           domain models, validation, Repository
                           interfaces + PostgreSQL implementations
                           (libpqxx), Services
  connectors/              Source Connector Framework: IConnector
                           interface (incl. ADR-0008's fetch/
                           AcquisitionRequest/AcquisitionResult),
                           ConnectorFactory, ConnectorRegistry,
                           StubConnector (no PostgreSQL dependency)
  downloads/               Engineering Downloader: Download domain model,
                           validation, Repository interface + PostgreSQL
                           implementation (libpqxx), Service
  api/                     ApiServer (GET /health, /sources, /jobs,
                           /jobs/{id}/execute|cancel|status, /connectors,
                           /downloads routes)
src/
  common/                 Logging + TOML configuration loading + uuid + time
  database/                PostgreSQL connection management (libpq)
  registry/                Official Source Registry (WORK_PACKAGE_002)
  acquisition/             Acquisition Job Engine (WORK_PACKAGE_003) +
                           Execution Engine (WORK_PACKAGE_004) -- reuses
                           the directory WORK_PACKAGE_001 reserved under
                           this name (see "Implementation Decisions")
  connectors/              Source Connector Framework (WORK_PACKAGE_005)
                           -- a new directory; none of WORK_PACKAGE_001's
                           reserved names fit (see "Implementation Decisions")
  downloads/               Engineering Downloader (WORK_PACKAGE_006) --
                           also a new directory, for the same reason
  api/                     Embedded HTTP server: GET /health, /sources,
                           /jobs, /jobs/{id}/execute|cancel|status,
                           /connectors, /downloads
  app/                     main() -- wires the above together
  browser/ integrity/ licensing/ metadata/
  vault/ workspace/        Reserved for future work packages (empty --
                           see "Out of Scope" in WORK_PACKAGE_001.md
                           through WORK_PACKAGE_006.md). Distinct from
                           `[storage] workspace_path` below, which is a
                           runtime filesystem path, not a source directory.
migrations/
  V1__initial_schema.sql          Flyway migration placeholder (WORK_PACKAGE_001)
  V2__official_sources.sql        official_sources table (WORK_PACKAGE_002)
  V3__acquisition_jobs.sql        acquisition_jobs table (WORK_PACKAGE_003)
  V4__job_execution_history.sql   acquisition_job_execution_history table (WORK_PACKAGE_004)
  V5__download_sessions.sql       download_sessions table (WORK_PACKAGE_006)
  flyway.toml                     Flyway configuration (not yet invoked)
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

**`POST /jobs/{id}/execute` advances a job by exactly one state, not
straight to `completed`.** WORK_PACKAGE_004's state diagram lists three
distinct forward edges (`created->queued`, `queued->running`,
`running->completed`) but its Functional Requirements name only one
action, "Execute Job" -- it doesn't say whether one call performs the
whole pipeline or one edge. Since "No background scheduler," "No
parallel execution," and "No retry policies" are explicitly excluded,
nothing exists yet that could make a real execution actually fail or
take time, so jumping straight to `completed` in one call was tempting
but would have made the three explicitly-listed edges untestable as
distinct events and given "Query Job Execution Status" nothing
meaningful to observe between calls. Advancing one edge per call keeps
all three transitions independently reachable, observable via
`GET /jobs/{id}/status`'s history, and gives a future work package that
adds real work an obvious seam: replace what happens *during* the
`queued->running` or `running->completed` edge without changing the
one-edge-per-call contract.

**A job's Official Source counts as "not available for execution" if
it's archived *or* if it no longer resolves at all (soft-deleted).**
WORK_PACKAGE_004 only states "attempting to execute an archived source
shall fail," but a soft-deleted source is a strictly stronger case of
the same failure mode from a caller's perspective -- both mean "this
source is no longer a trust anchor jobs should execute against." Both
map to the same `SourceNotAvailableError` / `409 source_unavailable`
response rather than treating a missing source as a different error
class.

**Execution history is a new, append-only table
(`acquisition_job_execution_history`), not new columns on
`acquisition_jobs`.** WORK_PACKAGE_004 requires "Execution history shall
be recorded" while also saying "Reuse the existing acquisition_jobs
table. No schema redesign. Only add a Flyway migration if additional
execution metadata is required" -- a job has exactly one current state,
but history is inherently multi-valued (every transition, not just the
latest), so it cannot fit into `acquisition_jobs`'s row-per-job shape
without redesigning it. A separate table is additive metadata, not a
redesign, and rows are never updated or deleted (Engineering Principle
8: Engineering Evidence Is Immutable).

**`src/connectors/` is a new directory, not a reuse of any
WORK_PACKAGE_001-reserved name.** Unlike WORK_PACKAGE_003's `acquisition`
reuse, none of the remaining reserved directories (`browser`,
`integrity`, `licensing`, `metadata`, `vault`, `workspace`) fit: `browser`
is reserved for `docs/architecture/SDD-R019`'s much heavier future
Browser & Acquisition Engine (sessions, certificates, downloads, browser
automation) -- a *consumer* this framework would eventually serve, not
the framework itself. WORK_PACKAGE_001's reserved list was a one-time
guess at WORK_PACKAGE_001-era future needs, not a closed set implicitly
constraining every later work package; introducing a new, clearly-named
directory when nothing reserved fits is expected growth, not a
deviation.

**No Flyway migration; the Connector Registry is in-memory only,
populated by `main.cpp` at startup.** WORK_PACKAGE-005 says "Create a
Flyway migration only if persistent connector configuration metadata is
required. Avoid schema changes unless necessary" -- and since its own
REST API section is entirely `GET` (connectors are never created
through the API, only queried), there is no requirement forcing
connector configuration to survive a process restart via a mechanism
other than the compiled-in registration code itself. A future work
package that adds a `POST /connectors` endpoint (or otherwise needs
connector configuration to be user-editable at runtime) would be the
point to reassess this.

**Connector capabilities are `std::set<std::string>`, not a closed C++
enum.** WORK_PACKAGE-005 explicitly states "Capabilities shall be
extensible," unlike Job/Source Status or Trust Level, which were never
described that way. A closed enum would require a code change (and a
recompile) to add a capability a future connector type needs; a string
set lets any future connector type declare a novel capability with zero
change to `IConnector`, `ConnectorFactory`, or `ConnectorRegistry`. The
six capabilities WORK_PACKAGE-005 lists as examples are provided as
named `constexpr` string constants (`connector.hpp`'s `capability::`
namespace) purely for convenience and typo-safety, not as a closed set.

**`StubConnector` is the only connector type this work package ships,
and is explicitly a framework-validation vehicle, not a preview of a
real connector.** WORK_PACKAGE-005 excludes an HTTP client, FTP client,
browser automation, and authentication protocols, and states "No
implementation shall perform actual network communication" -- so
whatever concrete `IConnector` exists here cannot do real work. Naming
it `"stub"` rather than something like `"http"` (with a subset of real
HTTP-connector fields) avoids presupposing a future work package's
design for a real transport; its `connect`/`disconnect` only toggle an
in-memory flag, and its `health_check`/`capabilities` are entirely
driven by `ConnectorConfig::settings` so tests (and this framework's own
`GET /connectors/{id}/health` route) can exercise every response shape
without a real check ever existing.

**Connectors are not yet associated with Official Sources or
Acquisition Jobs.** WORK_PACKAGE-005's own text never mentions
`source_id` or any relationship to `official_sources`/`acquisition_jobs`,
unlike WORK_PACKAGE-003's explicit "Source ID required." Presupposing
that relationship (e.g. adding a `source_id` field to
`ConnectorConfig`, or a foreign key) would be inventing architecture a
future work package hasn't asked for yet -- see "Future Considerations."

**ADR-0008 (Connector Content Retrieval Interface): `IConnector` gains
`fetch(const AcquisitionRequest&) -> AcquisitionResult`.** WORK_PACKAGE-006
(Engineering Downloader) paused when it became clear it needed to
retrieve content "exclusively through the Source Connector Framework,"
but `IConnector` had no such operation -- WORK_PACKAGE-005 deliberately
scoped it out. `oep_architecture` ratified ADR-0008 to close that gap
(superseding this repository's own proposed
`docs/decisions/ADR-0002-PROPOSED-CONNECTOR-CONTENT-RETRIEVAL.md`,
written while the gap was still unresolved). Implemented here exactly as
ADR-0008 decided -- a request/result object pair rather than a primitive
parameter list, so future fields never change `fetch`'s signature -- with
two casing/type choices left to this repository's own conventions, since
ADR-0008's interface listing (like every SDD/ADR in `oep_architecture`)
is illustrative pseudocode, not literal target-language code:

- Method and member names stay `snake_case` (`fetch`, `job_id`,
  `source_uri`, ...), matching every other method and struct member in
  this codebase, rather than the ADR listing's `PascalCase`/`camelCase`
  (`Fetch`, `jobId`). The existing `connect`/`disconnect`/`health_check`/
  `capabilities`/`validate_configuration` methods were *not* renamed to
  match the ADR's casing -- ADR-0008 only decided to add `fetch`, not to
  rename WORK_PACKAGE-005's already-shipped methods.
- `cancellation` is a real `std::stop_token` (`<stop_token>`, standard
  since C++20) rather than a custom `CancellationToken` type -- the
  standard library already provides exactly what ADR-0008 asks for.
- `ProgressCallback`'s signature (`void(bytes_transferred, total_bytes)`)
  and `AcquisitionResult::checksum`'s meaning (a transfer-level checksum
  the connector reports as a byproduct of the fetch, not a cryptographic
  hash and explicitly not the platform's Integrity Verification stage,
  which ADR-0008 itself excludes from Connector Responsibilities) fill in
  details ADR-0008 left unspecified, the same way Job Priority's value
  range (WORK_PACKAGE-003) and `execute`'s single-step semantics
  (WORK_PACKAGE-004) did.

`StubConnector::fetch` writes a small, deterministic placeholder file to
`request.destination` -- still no real network communication (only a
local write), configurable via new `ConnectorConfig::settings` keys
(`"fetch_outcome"`, `"fetch_mime_type"`) following the same pattern
`"health_status"` already established.

**A new `[storage] workspace_path` config field, distinct from the
existing `root_path`.** WORK_PACKAGE-006 requires "Downloaded artifacts
shall be stored in a temporary acquisition workspace... Persistent
storage location shall be configurable" and, separately, "The downloader
shall not publish files into the Reference Vault." `StorageConfig::root_path`
already existed (`./data/vault` by default), but WORK_PACKAGE_001's own
comment on it says it was reserved specifically for "where acquired
evidence will eventually be written (Reference Vault)" -- reusing it for
the Downloader's temporary workspace would have been semantically wrong
given WORK_PACKAGE-006's explicit vault exclusion, so a second field,
`workspace_path` (default `./data/workspace`), was added instead.
`root_path` remains reserved, still unused, for the Reference Vault.

**`POST /downloads` runs entirely synchronously -- no background
thread, no async execution model.** WORK_PACKAGE-006 excludes
"Background scheduling" and "Parallel downloads," and its REST API has
no second endpoint analogous to how `POST /jobs/{id}/execute`
(WORK_PACKAGE-004) could be called repeatedly to advance one step at a
time -- `POST /downloads` is both "create" and "start" in one call.
Building genuine async execution (a worker thread per download, an
in-memory cancellation-token registry keyed by download id, a shared
mutable `Download` row updated concurrently) to make "Cancel Download"
racily interruptible would be speculative engineering for a hypothetical
slow connector that doesn't exist yet -- `StubConnector::fetch` still
completes in microseconds, so nothing would actually exercise that
machinery today. `Download` still models `pending`/`downloading` as
real, distinct, correctly-validated states (the transition logic and
`InvalidTransitionError` are fully implemented and tested), but in
normal operation a download reaches `completed`/`failed` before
`POST /downloads` even returns -- so cancelling an in-flight download is,
for now, only reachable in tests via a `Download` seeded directly in
`pending` through the repository, not through a naturally-occurring
race via the REST API. This mirrors WORK_PACKAGE-004's precedent
exactly: `Failed` was a fully modeled Job State that nothing in that
work package could actually produce automatically either. A future work
package introducing a real, slow connector type is the natural point to
revisit this and move `fetch` execution onto its own thread.

**"Job shall be executable" reuses `acquisition::next_execution_status`'s
definition rather than inventing a new one.** WORK_PACKAGE-006 never
defines "executable." Its wording echoes WORK_PACKAGE-004's own
"Execution Engine"/"execute" terminology closely enough that reusing the
exact predicate already validated there (a job is executable if it is
Created, Queued, or Running -- i.e. `next_execution_status` returns a
value, meaning it is not yet Completed/Failed/Cancelled) was preferred
over guessing a new, narrower definition (e.g. "only Running jobs are
executable") that WORK_PACKAGE-006's text does not actually state.

**`connector_id` is a plain `TEXT` column, not a foreign key.**
Unlike `job_id` (a real `REFERENCES acquisition_jobs (uuid)`, since both
tables live in this database), the Connector Registry
(WORK_PACKAGE-005) is in-memory only with no backing table -- "Connector
shall exist"/"Connector shall be healthy" are validated by
`DownloadService` against the live `ConnectorRegistry` at request time
instead, the only mechanism available given WORK_PACKAGE-005's own
no-persistence decision.

**Destination validation sanitizes `file_name` down to its filename
component (discarding any directory parts) rather than attempting to
detect and reject path traversal patterns.** WORK_PACKAGE-006 requires
"Download destination shall validate"; `std::filesystem::path(file_name).filename()`
makes a `"../../etc/passwd"`-style `file_name` structurally incapable of
escaping `workspace_path` (only the trailing `"passwd"` component
survives) rather than relying on pattern-matching that could miss an
encoding this codebase didn't anticipate -- a stronger guarantee via a
simpler mechanism.

**Dependency management: CMake `FetchContent`, not vcpkg/Conan.** No
package manager was already set up in this environment or evidenced
elsewhere in the platform. `FetchContent` is built into CMake itself,
needs no additional tool install, and pins every dependency to an
explicit tagged version (never a floating branch) for reproducible
builds.

## TODOs

- WORK_PACKAGE_007 onward: real connector types (HTTP, FTP, browser
  automation) implementing `IConnector`/`fetch`, wiring Connectors to
  Official Sources/Acquisition Jobs, Integrity Verification, Metadata
  Extraction, Reference Vault publication -- per
  `docs/architecture/SDD-R013` through `SDD-R019`.
- `migrations/flyway.toml` is still not invoked by any automated
  process (see Future Considerations below).

## Future Considerations

- `migrations/flyway.toml` is not yet invoked by any automated process
  -- a future work package should wire `flyway migrate` into the build
  or a deployment step. Repository/API/migration tests currently apply
  `V1__initial_schema.sql` through `V5__download_sessions.sql`
  verbatim themselves (see "Test" above) as a stand-in.
- Moving `fetch` execution onto a background thread once a real, slow
  connector type exists -- see "Implementation Decisions" for why
  `POST /downloads` is fully synchronous today and why that makes
  `POST /downloads/{id}/cancel` mostly untestable via a natural race
  in normal operation (only via a `Download` seeded directly as
  `pending`).
- Connectors have no relationship to Official Sources or Acquisition
  Jobs yet (see "Implementation Decisions") -- a future work package
  will need to decide how a Source or a Job selects which connector
  services it (e.g. a `connector_id` field on `OfficialSource`, or
  resolving by matching capabilities). WORK_PACKAGE-006 works around
  this by requiring the REST client to name `connector_id` directly in
  the `POST /downloads` body.
- No pagination (`limit`/`offset`/`cursor`) is implemented for
  `GET /downloads`, matching every other list endpoint in this
  repository -- see the existing `GET /sources` pagination note below.
- The Connector Registry is populated once at process startup with no
  way to add, remove, or reconfigure a connector without a restart --
  WORK_PACKAGE-005's REST API section is entirely read-only, so this
  wasn't in scope to change. A future work package should decide
  whether connector management needs its own write API (and, if so,
  whether that revisits the "no persistence" decision above) or remains
  purely a startup-time/configuration-file concern.
- `StubConnector` is the only registered connector type; real transports
  (HTTP, FTP, browser automation) are explicitly excluded from
  WORK_PACKAGE-005 and remain future work.
- A connection pool for `PostgresOfficialSourceRepository`,
  `PostgresAcquisitionJobRepository`, `PostgresJobExecutionHistoryRepository`,
  and `PostgresDownloadRepository` (each currently one `pqxx::connection`
  per repository instance, held for the process's lifetime) should be
  reassessed once concurrent request volume makes single-connection
  serialization a bottleneck.
- `PUT /jobs/{id}` (WORK_PACKAGE_003) still accepts any status value
  with no transition validation, while `POST /jobs/{id}/execute` and
  `/cancel` (WORK_PACKAGE_004) strictly enforce
  `next_execution_status`/`can_cancel`. WORK_PACKAGE_004's scope was the
  new execute/cancel/status endpoints ("Continue supporting all existing
  endpoints" -- it didn't ask for `PUT`'s behavior to change), so this
  implementation left `PUT`'s original unrestricted manual override
  intact rather than retrofitting state-machine validation onto it. A
  client can still bypass the execution state machine entirely via
  `PUT` (e.g. jumping `created` straight to `completed`) without
  recording any execution history. A future work package should decide
  whether `PUT` should be restricted to the same transitions, or
  whether its unrestricted-override role is intentional (e.g. for
  administrative correction).
- No real work happens during `queued->running` or `running->completed`
  -- WORK_PACKAGE_004 explicitly excludes an HTTP client, downloading,
  metadata extraction, integrity verification, a background scheduler,
  parallel execution, and retry policies. Every `execute` call today
  always succeeds (assuming a valid transition and available source);
  `Failed` is defined as a Job State but nothing in this work package
  can actually produce it -- it remains reachable only via `PUT`. The
  work package that adds real execution will need to decide how a
  failure encountered mid-execution reports itself (presumably setting
  `status=failed` and `error_message` through the same Repository
  methods this Execution Engine already uses).
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
