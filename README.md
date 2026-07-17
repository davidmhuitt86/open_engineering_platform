# OEP Acquisition (Engineering Acquisition Manager)

The Trust Layer of the Open Engineering Platform (OEP): engineering
acquisition, provenance, integrity, licensing, and trusted evidence. See
`oep_architecture/docs/architecture/PLATFORM_SERVICES_ARCHITECTURE.md`
and this repository's own `docs/architecture/SDD-R013` through
`SDD-R019` for the full architecture.

## Status

**WORK_PACKAGE_001 through WORK_PACKAGE_009 implemented, plus ADR-0008
(Connector Content Retrieval Interface) -- Milestone 1 (Engineering
Acquisition MVP) is complete.** WORK_PACKAGE_009 (Engineering Reference
Vault) is the final Milestone-1 pipeline stage: it publishes an artifact
whose Metadata Extraction succeeded into an immutable,
content-addressable permanent store, re-validating the full Metadata ->
Verification -> Download chain first (metadata exists and succeeded, not
already published, verification succeeded, artifact exists and its
recomputed SHA-256 matches the Verification record) and rejecting the
request outright if any of those fail -- unlike every prior stage, a
failed precondition here is never recorded as a "Failed" row, since
"Publish Verified Artifact" has no "Re-publish" counterpart and
publication is meant to be a single, immutable, permanent fact. The
artifact is copied (never moved) from the temporary acquisition workspace
into `[storage] root_path` (the location WORK_PACKAGE_001 reserved for
exactly this eight work packages ago), addressed solely by its SHA-256
hash under a sharded `<root>/<first-2-hex-chars>/<full-hash>` layout; a
second artifact with identical content is deduplicated at the filesystem
level while still getting its own Vault Entry row. It performs no
Engineering Object creation, knowledge graph generation, OCR, AI
analysis, search indexing, document interpretation, semantic
classification, duplicate detection, or lifecycle management -- those
remain later, unimplemented pipeline stages (Milestone 2's Engineering
Knowledge Engine). WORK_PACKAGE_008 (Engineering Metadata Extraction
Engine) records descriptive metadata about artifacts the Integrity
Verification Engine has already verified: it resolves a Verification
(rejecting one that doesn't exist or wasn't successful), resolves the
underlying Download's artifact, runs File Type Detection (magic-byte
signatures with an extension-based fallback, across at least
PDF/ZIP/7Z/TAR/GZIP/PNG/JPEG/SVG/XML/JSON/YAML/CSV/TXT/HTML/Markdown) and
Basic Document Inspection (PDF version/page count today), and records the
outcome as an immutable ArtifactMetadata row -- entirely synchronously,
mirroring WORK_PACKAGE_007's own `POST /verifications`. WORK_PACKAGE_007
(Engineering Integrity Verification Engine) validates artifacts the
Engineering Downloader has already retrieved: it resolves a Download
Session, computes a SHA-256 hash of the file at its `local_storage_path`,
and records the outcome (`verified`/`failed`) as an immutable
Verification row -- entirely synchronously, mirroring WORK_PACKAGE_006's
own `POST /downloads`. WORK_PACKAGE_006 (Engineering Downloader) retrieves
engineering artifacts exclusively through the Source Connector
Framework's `fetch` operation (ADR-0008), validates the requesting Job
and Connector, stores the artifact in a configurable local workspace, and
tracks progress/history -- but, like every work package before it,
`StubConnector` remains the only connector type and performs no real
network communication (`fetch` writes a small placeholder file locally).
Everything the Engineering Knowledge Engine covers (Milestone 2) is
explicitly out of scope for Milestone 1; browser automation and license
management also remain out of scope -- see `docs/tasks/WORK_PACKAGE_001.md`
through `docs/tasks/WORK_PACKAGE_009.md` and
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
  downloads spdlog, nlohmann/json, tomlplusplus, cpp-httplib, Catch2,
  libpqxx, and PicoSHA2 -- see "Implementation Decisions" below)

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

### Engineering Integrity Verification Engine API

```
POST /verifications                Verify a Download Session's artifact (JSON body)
GET  /verifications                List verifications; optional query filters:
                                    status, download_session_id
GET  /verifications/{id}           Fetch one verification
GET  /verifications/{id}/status    Status + hash + timing only
```

```
curl -X POST http://127.0.0.1:8080/verifications \
  -H "Content-Type: application/json" \
  -d '{"download_session_id":"<a Download id from /downloads>"}'
```

`download_session_id` is required and must reference an existing
Download Session (`422 unknown_download_session` otherwise). `POST
/verifications` runs **synchronously**: it resolves the Download's
`local_storage_path`, computes a SHA-256 hash, and returns the
Verification already in its final state (`verified` or `failed`) --
mirroring `POST /downloads`. A missing, empty, or unreadable artifact is
recorded as `failed` with a descriptive `error_message`, not rejected as
invalid input (see "Implementation Decisions"). Re-verifying a Download
Session that already has a prior `verified` hash on record recomputes
the hash and compares it against that prior value, flagging a mismatch
as `failed` (corruption detected) -- see "Implementation Decisions" for
why this is how "Verify Existing Hashes"/"Detect Corrupt Files" map onto
the single creation route. All routes return `404` for an unknown
verification id.

### Engineering Metadata Extraction Engine API

```
POST /metadata                Extract metadata from a Verification's artifact (JSON body)
GET  /metadata                List metadata records; optional query filters:
                               status, verification_id
GET  /metadata/{id}           Fetch one metadata record
GET  /metadata/{id}/status    Status + timestamp + error only
```

```
curl -X POST http://127.0.0.1:8080/metadata \
  -H "Content-Type: application/json" \
  -d '{"verification_id":"<a Verification id from /verifications>"}'
```

`verification_id` is required and must reference an existing Verification
(`422 unknown_verification`) whose status is `verified` (`409
verification_not_successful` otherwise -- "Metadata extraction shall
operate only on successfully verified artifacts"). `POST /metadata` runs
**synchronously**: it resolves the underlying Download's artifact, copies
`sha256_hash`/`file_size_bytes` straight from the Verification record
(no re-hashing -- that's Integrity Verification's job, not this one's),
runs File Type Detection and Basic Document Inspection against the file,
and returns the ArtifactMetadata already in its final state (`extracted`
or `failed`) -- mirroring `POST /verifications`. A missing or unreadable
artifact is recorded as `failed` with a descriptive `error_message`; an
unrecognized file type is recorded as `extracted` with type `"Unknown"`/
MIME type `application/octet-stream`, not as a failure ("Unsupported file
types shall still produce metadata when possible" -- see "Implementation
Decisions"). Calling `POST /metadata` again for the same `verification_id`
creates a *new* record rather than overwriting the previous one, so
`GET /metadata?verification_id=...` returns the full extraction history
("Re-extract Metadata" / "Metadata history shall be preserved"). All
routes return `404` for an unknown metadata id.

### Engineering Reference Vault API

```
POST /vault                Publish a Metadata record's artifact into the Vault (JSON body)
GET  /vault                List Vault entries; optional query filters:
                            status, metadata_id
GET  /vault/{id}           Fetch one Vault entry
GET  /vault/{id}/status    Status + hash + timing only
```

```
curl -X POST http://127.0.0.1:8080/vault \
  -H "Content-Type: application/json" \
  -d '{"metadata_id":"<a Metadata id from /metadata>"}'
```

`metadata_id` is required and must reference an existing ArtifactMetadata
record (`422 unknown_metadata`) whose status is `extracted` (`409
metadata_not_successful` otherwise), must not already have a Vault entry
(`409 already_published` -- there is no "Re-publish"), must resolve to a
Verification that is `verified` (`409 verification_not_successful`), and
that Verification's Download artifact must still exist on disk (`422
artifact_not_found`) with a freshly-recomputed SHA-256 matching the
Verification record (`409 artifact_hash_mismatch`). `POST /vault` runs
**synchronously**: once every precondition passes, it copies the artifact
into `[storage] root_path`, addressed solely by its SHA-256 hash under a
sharded `<root>/<first-2-hex-chars>/<full-hash>` layout (skipping the
copy, but still creating a new Vault Entry row, if that exact content is
already stored), and returns the entry already `published` -- there is no
transient/failed state, unlike every prior stage (see "Implementation
Decisions"). All routes return `404` for an unknown Vault entry id. There
is no `PUT`/`PATCH`/`DELETE` route for `/vault` at all -- "Vault entries
shall be immutable after publication" is enforced by the absence of any
mutating route or repository method, not just by convention.

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
synchronous, instant `StubConnector`). WORK_PACKAGE-007 adds a dedicated
`hash_file_sha256` unit-test suite (a known SHA-256 test vector,
determinism across repeated reads, content larger than the streaming
read buffer, a missing file, and a path that is a directory rather than
a regular file -- entirely in-memory/local-disk, no database needed),
validation tests, Service-layer tests (against an in-memory fake
Verification repository and the existing fake Download repository,
covering the full Verified/Failed paths, missing-file and corrupt-file
detection, an empty-artifact rejection, and both re-verification
outcomes -- unchanged-artifact-stays-verified and
tampered-artifact-detected-as-failed), Repository-layer tests,
migration/schema-shape tests, and a REST API test seeding a real
Download Session (with a real file on disk) and exercising the full
`POST`/`GET` lifecycle plus every rejection case end to end.
WORK_PACKAGE-008 adds a dedicated `detect_file_type` unit-test suite
(magic-byte signatures for PDF/PNG/JPEG/ZIP/7Z/GZIP/TAR, content-prefix
detection for XML/SVG/HTML, extension fallback for JSON/YAML/CSV/TXT/
Markdown, and both an unrecognized type and a missing file each falling
back to `"Unknown"` -- entirely in-memory/local-disk, no database
needed), a dedicated `inspect_pdf` unit-test suite (version parsing,
page-count parsing via a `/Pages`/`/Count` fixture, and graceful empty
results for a non-PDF or missing file), validation tests, Service-layer
tests (against an in-memory fake Metadata repository plus the existing
fake Verification and Download repositories, covering the full
Extracted/Failed paths, the two Validation-Rules exceptions, missing-file
handling, an unsupported-file-type non-failure, PDF document inspection,
and re-extraction history), Repository-layer tests, migration/schema-shape
tests, and a REST API test seeding a real Verification (backed by a real
Download and a real file on disk) and exercising the full `POST`/`GET`
lifecycle, every rejection case, and history preservation across repeated
extraction end to end. WORK_PACKAGE-009 adds a dedicated
`compute_vault_path` unit-test suite (correct sharding by the first two
hex characters, rejecting a too-short/non-hex/uppercase hash, and
determinism -- pure, no filesystem access), validation tests,
Service-layer tests (against an in-memory fake Vault repository -- the
only fake in this suite that enforces a real invariant,
`metadata_id` uniqueness, since WORK_PACKAGE-009's immutability
requirement is central enough to need exercising without a live
database -- plus the existing fake Metadata/Verification/Download/Job
repositories, covering the full Published path, all seven Validation
Rules' exceptions, and the content-addressable dedup behavior across two
distinct chains with identical content), Repository-layer tests
(including the `metadata_id` `UNIQUE` constraint's own
`AlreadyPublishedError` mapping), migration/schema-shape tests, and a
REST API test seeding a real Metadata record (backed by a real
Verification, Download, and file on disk) and exercising the full
`POST`/`GET` lifecycle, every rejection case, and the dedup behavior end
to end -- including asserting the copied file actually exists on disk at
the returned `vault_path`.

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
through `migrations/V8__reference_vault.sql` verbatim from disk the
first time they run against a given database (so they exercise the
real, committed migration files) and `TRUNCATE ... CASCADE` the
affected tables between test runs -- `CASCADE` matters here: once
`acquisition_jobs` and its dependents exist, truncating
`official_sources` alone fails on its own foreign key unless the
dependent tables are truncated too (or `CASCADE` is used), which is
exactly what happened when WORK_PACKAGE_004's history table first made
the chain three tables deep -- see `tests/registry_test_support.cpp`,
`tests/jobs_test_support.cpp`, `tests/downloads_test_support.cpp`,
`tests/integrity_test_support.cpp`, `tests/metadata_test_support.cpp`,
and `tests/vault_test_support.cpp`. The latter three also seed a full
Source -> Job -> Download (-> Verification -> Metadata, as each stage
needs) chain with a real file written to the Download's
`local_storage_path`, since WORK_PACKAGE-007's, WORK_PACKAGE-008's, and
WORK_PACKAGE-009's Repository/API/migration tests each need an actual
artifact on disk to hash/inspect/publish.
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
  integrity/               Integrity Verification Engine: Verification
                           domain model, validation, SHA-256 hashing
                           utility (PicoSHA2), Repository interface +
                           PostgreSQL implementation (libpqxx), Service
  metadata/                Metadata Extraction Engine: ArtifactMetadata
                           domain model, validation, File Type Detection,
                           Basic Document Inspection (PDF), Repository
                           interface + PostgreSQL implementation (libpqxx),
                           Service
  vault/                   Engineering Reference Vault: VaultEntry domain
                           model (no update path -- see "Implementation
                           Decisions"), validation, content-addressable
                           path helper, Repository interface + PostgreSQL
                           implementation (libpqxx, no update method),
                           Service
  api/                     ApiServer (GET /health, /sources, /jobs,
                           /jobs/{id}/execute|cancel|status, /connectors,
                           /downloads, /verifications, /metadata, /vault
                           routes)
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
  integrity/               Integrity Verification Engine (WORK_PACKAGE_007)
                           -- reuses the directory WORK_PACKAGE_001
                           reserved under this exact name (see
                           "Implementation Decisions")
  metadata/                Metadata Extraction Engine (WORK_PACKAGE_008)
                           -- also reuses the directory WORK_PACKAGE_001
                           reserved under this exact name
  vault/                   Engineering Reference Vault (WORK_PACKAGE_009)
                           -- also reuses the directory WORK_PACKAGE_001
                           reserved under this exact name
  api/                     Embedded HTTP server: GET /health, /sources,
                           /jobs, /jobs/{id}/execute|cancel|status,
                           /connectors, /downloads, /verifications,
                           /metadata, /vault
  app/                     main() -- wires the above together
  browser/ licensing/
  workspace/               Reserved for future (Milestone 2) work packages
                           (empty -- see "Out of Scope" in
                           WORK_PACKAGE_001.md through WORK_PACKAGE_009.md).
                           Distinct from `[storage] workspace_path` below,
                           which is a runtime filesystem path, not a
                           source directory.
migrations/
  V1__initial_schema.sql          Flyway migration placeholder (WORK_PACKAGE_001)
  V2__official_sources.sql        official_sources table (WORK_PACKAGE_002)
  V3__acquisition_jobs.sql        acquisition_jobs table (WORK_PACKAGE_003)
  V4__job_execution_history.sql   acquisition_job_execution_history table (WORK_PACKAGE_004)
  V5__download_sessions.sql       download_sessions table (WORK_PACKAGE_006)
  V6__integrity_verifications.sql integrity_verifications table (WORK_PACKAGE_007)
  V7__artifact_metadata.sql       artifact_metadata table (WORK_PACKAGE_008)
  V8__reference_vault.sql         reference_vault table (WORK_PACKAGE_009)
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

**Hashing library: PicoSHA2, a single-header, dependency-free SHA-256
implementation, fetched and pinned like every other dependency.**
`PROJECT_CONTEXT.md` names "SHA-256 (Primary), BLAKE3 (Secondary)" in
the platform's technology stack but no specific library -- WORK_PACKAGE-007
is the first work package that actually needs to compute a cryptographic
hash. Hand-rolling SHA-256 was rejected (Engineering Principle 6,
Security by Design: don't reimplement cryptographic primitives when a
vetted library is readily available); pulling in all of OpenSSL was
rejected as disproportionate to "generate one hash algorithm" and
inconsistent with this project's existing lightweight-dependency pattern
(`cpp-httplib` itself is fetched with `HTTPLIB_REQUIRE_OPENSSL OFF` to
avoid exactly that dependency). PicoSHA2 has no version tags, so it is
pinned to a specific commit (`161cb3fc4170fa7a3eca9e582cebd27cc4d1fe29`,
the tip of its default branch at the time of this work package) rather
than a tag, the same way any other untagged dependency would be handled.
Its own `CMakeLists.txt` already defines a clean `picosha2` `INTERFACE`
target with tests/examples off by default, so no wrapper target was
needed.

**`src/integrity/` reuses the directory WORK_PACKAGE_001 reserved under
that exact name, rather than inventing a new one.** WORK_PACKAGE_001's
reserved-but-empty directories (`registry`, `acquisition`, `browser`,
`integrity`, `licensing`, `vault`, `workspace`) were named after items in
its own "Out of Scope"
list ("Official Source Registry, Reference Vault, Integrity, Metadata,
Browser, Licensing, Workspace, Engineering Objects"). Unlike
WORK_PACKAGE-003's `acquisition` reuse (which required inferring that
"acquisition" meant the Job Engine) or WORK_PACKAGE-005/006's `connectors`/
`downloads` (new directories, since nothing reserved fit), "Integrity" is
an exact, literal match for WORK_PACKAGE-007's "Integrity Verification
Engine" -- the strongest-possible case for directory reuse in this
codebase so far.

**A missing/empty/unreadable/hash-mismatched artifact is recorded as a
`Failed` Verification, not thrown as a validation error -- but a
nonexistent `download_session_id` is rejected outright.** WORK_PACKAGE-007's
"Validation Rules" list "Download session shall exist" alongside
"Downloaded artifact shall exist," "Artifact shall not be empty,"
"Missing files shall fail verification," and "Corrupt files shall fail
verification" as if they were all the same kind of rule, but they are
not: whether a *request* names a real Download Session is a property of
the request (mirroring WORK_PACKAGE-006's `UnknownJobError` -- a `422`),
while whether that session's *artifact* still exists, is non-empty, and
reads back cleanly are properties of the artifact's current condition on
disk, discovered only by trying to hash it -- exactly analogous to how
`downloads::DownloadService` records a connector fetch failure as a
terminal `Failed` `Download`, not an exception. Collapsing all five into
uniform `422`s would have made "Missing Files"/"Detect Corrupt Files"
(both explicitly listed Functional Requirements, each with its own named
test category) unobservable as Verification history -- there would be no
record of the attempt at all, only an HTTP error response.

**"Verify Existing Hashes" and "Detect Corrupt Files" are implemented as
re-verification against a download session's own prior verified hash,
not against a client-supplied "expected hash."** WORK_PACKAGE-007 lists
"Generate Cryptographic Hashes," "Verify Existing Hashes," and "Detect
Corrupt Files" as three distinct Functional Requirements, but defines
only one creation route (`POST /verifications`) and no "expected hash"
field anywhere in the Verification Model or REST API section. The
self-consistent reading used here: the first `POST /verifications` for a
Download Session computes and stores a hash (Generate); a later `POST
/verifications` for the *same* Download Session recomputes the hash and
compares it against that Download Session's own most recent `verified`
hash (Verify Existing Hashes), flagging a mismatch as `failed` with an
explanatory `error_message` (Detect Corrupt Files) -- self-referential
integrity monitoring over time, not comparison against an
externally-supplied value the spec never asks the client to provide.

**`POST /verifications` runs entirely synchronously -- no background
thread, no async execution model.** Same reasoning as WORK_PACKAGE-006's
`POST /downloads`: WORK_PACKAGE-007 has no second endpoint analogous to
`POST /jobs/{id}/execute`'s repeatable-step pattern, and building genuine
async hashing infrastructure for an artifact-hashing operation that
already completes in milliseconds against `StubConnector`-sized test
files would be speculative engineering. `Verification` still models
`Pending` as a real, distinct state (persisted briefly between `create`
and the finalizing `update`, mirroring `Download`'s `Pending` ->
`Downloading` step), but "Invalid transitions shall be rejected" is
enforced structurally rather than by an explicit guard: the REST API
exposes no route that can mutate an existing Verification, so
`IntegrityVerificationService::verify`'s own two internal transitions
(`Pending` -> `Verified`, `Pending` -> `Failed`) are the only ones that
can ever occur.

**"Corrupt Files" is tested via a path that is a directory rather than a
regular file, not via fabricated bit-level corruption.** WORK_PACKAGE-007's
Objective explicitly excludes document parsing and metadata extraction,
so this engine has no format-aware notion of a "corrupted PDF" or
similar -- "corrupt," for its purposes, can only mean "exists on disk but
cannot be read back as artifact content." `hash_file_sha256` rejects
anything that isn't `std::filesystem::is_regular_file` (a directory, in
the test suite) or that fails to open as a stream, which reproduces that
condition deterministically without inventing fake byte-level damage to
a format this engine doesn't parse anyway.

**`src/metadata/` reuses the directory WORK_PACKAGE_001 reserved under
that exact name.** Same reasoning as WORK_PACKAGE-007's `src/integrity/`
reuse -- "Metadata" is an exact, literal match for WORK_PACKAGE-008's
"Metadata Extraction Engine," the strongest directory-reuse case
available.

**"Verification shall exist" and "Verification shall be successful" are
both thrown (422/409); "Artifact shall exist" is recorded as `Failed`.**
WORK_PACKAGE-008's Validation Rules list all three together, but they are
not the same kind of rule: whether a request names a real, successfully
verified Verification is knowable immediately from the Verification
record itself (mirroring WORK_PACKAGE-006's `UnknownJobError`/
`JobNotExecutableError` pair -- both properties of the reference, thrown
as `422`/`409` respectively), while whether the underlying artifact still
exists on disk is only discoverable by trying to read it -- mirroring
WORK_PACKAGE-007's own "Downloaded artifact shall exist" (recorded as
`Failed`, not thrown). This is the same reasoning WORK_PACKAGE-007's
README applied to its own Validation Rules, now applied one stage further
down the pipeline.

**`file_size_bytes` and `sha256_hash` are copied from the Verification
record, never recomputed.** The artifact was already hashed by the
Integrity Verification Engine; recomputing that hash here would duplicate
work that engine already owns and would blur WORK_PACKAGE-008's own
Objective ("descriptive metadata," not re-verification) with
WORK_PACKAGE-007's responsibility. `MetadataExtractionService` only reads
the file to run File Type Detection, Basic Document Inspection, and
`std::filesystem::last_write_time` -- never to hash it again.

**File Type Detection is magic-byte signatures with an extension-based
fallback, implemented as a plain, appendable internal table -- not a
runtime plugin-loading system.** WORK_PACKAGE-008 requires "Architecture
shall support future file type plugins," but binary formats (PDF, PNG,
JPEG, ZIP, 7Z, GZIP) have reliable magic bytes while several required
text formats (JSON, YAML, CSV, TXT, Markdown) do not, so a signature-only
design could not satisfy the full "at minimum" list on its own. A future
file type is added by appending one entry to `file_type_detector.cpp`'s
internal table, without changing `detect_file_type`'s signature or any
caller -- the same bar WORK_PACKAGE-005 set for "Capabilities shall be
extensible" with a plain `std::set<std::string>` rather than a dynamic
plugin system, applied here to file type detection instead.

**Basic Document Inspection is implemented only for PDF (version + a
best-effort page count), not a generic extensible "document properties"
mechanism.** WORK_PACKAGE-008's own text gives exactly one example
("PDF version or page count") and its canonical Metadata Model field list
does not itself enumerate a document-properties field at all -- two
narrow, explicitly-typed optional columns (`pdf_version`, `pdf_page_count`)
fulfill the example literally without inventing a generic bag of
properties nothing has asked for yet. Page count is read via the same
low-level trick minimal PDF readers use (the `/Pages` object's `/Count`
entry) rather than a real PDF parsing library, since "Document parsing"
is explicitly out of scope; a malformed or unusual PDF simply yields a
missing `pdf_page_count` rather than an error, consistent with
"Unsupported file types shall still produce metadata when possible."
A future file type needing its own basic properties (e.g. image
dimensions, a ZIP entry count) is the natural point to generalize this
into a broader mechanism.

**Extraction States (`Pending`/`Extracted`/`Failed`) are inferred by
direct analogy with `DownloadStatus`/`VerificationStatus`, since
WORK_PACKAGE-008's text names "Extraction Status" as a Metadata Model
field but never enumerates its values the way WORK_PACKAGE-006/007 each
had a dedicated "States" section.** The three-state Pending/
terminal-success/terminal-failure shape is the one every prior stage in
this exact pipeline uses; inventing a different shape here (e.g. more
states, or a different terminal-state split) would have been a genuine
architectural deviation with no textual basis, whereas reusing the
established shape is filling a real but narrow gap. "Invalid transitions
shall be rejected" is satisfied the same structural way
WORK_PACKAGE-007's `VerificationStatus` is: the REST API has no route
that mutates an existing ArtifactMetadata record, so the only transitions
that occur are `MetadataExtractionService::extract`'s own two internal
ones.

**"Re-extract Metadata" / "Metadata history shall be preserved" is
satisfied by `POST /metadata` always inserting a new row, never updating
an existing one in place -- exactly mirroring WORK_PACKAGE-007's
"Verify Existing Hashes" re-verification pattern.** There is no separate
"re-extract" REST route; calling `POST /metadata` again for a
`verification_id` that already has metadata simply creates another,
independently queryable record (Engineering Principle 8: Engineering
Evidence Is Immutable), and `GET /metadata?verification_id=...` returns
every one of them in creation order.

**`src/vault/` reuses the directory WORK_PACKAGE_001 reserved under that
exact name -- the field WORK_PACKAGE_001 reserved specifically for this,
eight work packages ago, is used for the first time.** Same reasoning as
WORK_PACKAGE-007/008's `src/integrity/`/`src/metadata/` reuse; unlike
those two, this is also true at the *configuration* level: `[storage]
root_path` (`common::StorageConfig`) was added in WORK_PACKAGE_001 with
the comment "where acquired evidence will eventually be written
(Reference Vault, out of scope for WORK_PACKAGE_001)" and left unused by
every subsequent work package (WORK_PACKAGE-006 added a second,
sibling field, `workspace_path`, specifically because `root_path` was
already reserved for this and reusing it would have been semantically
wrong). WORK_PACKAGE-009 is the point that comment anticipated --
`root_path` needed no change at all to become the Vault's configured
location, directly satisfying "The Reference Vault location shall be
configurable independently of the acquisition workspace."

**A failed Validation Rule rejects the `POST /vault` request outright; no
`Failed` VaultEntry is ever persisted -- the opposite of how
WORK_PACKAGE-007/008 handle a missing/corrupt artifact.** WORK_PACKAGE-009's
seven Validation Rules ("Metadata record shall exist," "...extraction
shall be successful," "Verification shall be successful," "Published
artifact shall exist," "SHA-256 shall match...," "Vault path shall
validate," "Publication shall be immutable") are all phrased as flat,
undifferentiated preconditions -- unlike WORK_PACKAGE-007's explicit
"Missing files shall fail verification" or WORK_PACKAGE-008's explicit
"Metadata extraction failures shall be recorded," nothing in
WORK_PACKAGE-009's text says a failed publish attempt shall be recorded
as anything. Combined with "Publish Verified Artifact" being the only
creation-side Functional Requirement (no "Re-publish," unlike
WORK_PACKAGE-007/008's explicit re-verification/re-extraction support)
and "Publication shall be immutable" being listed as its own rule, the
most consistent reading is that publication is a single, all-or-nothing,
permanent event -- a `VaultEntry` is only ever created already
`Published`; `IVaultRepository` has no `update` method at all, and there
is no code path that persists a failed attempt.

**`VaultEntryStatus` has exactly one value, `Published`, unlike every
prior stage's multi-value status enum.** A direct consequence of the
decision above -- with no `Failed`/`Pending` counterpart ever persisted,
a second status value would be dead code. The enum (rather than a bare
boolean or no status field at all) is kept for schema-shape consistency
with every prior domain table and to leave room for a future,
`Lifecycle Management`-driven status (e.g. `"revoked"`) without an
additive migration redesigning the column -- `Lifecycle Management` is
explicitly out of scope for WORK_PACKAGE-009 ("Do NOT implement...
Lifecycle management").

**`metadata_id` is `UNIQUE` in `reference_vault` -- a given Metadata
record may be published at most once.** Direct consequence of "Publish
Verified Artifact" having no "Re-publish" Functional Requirement (see
above): re-`POST`ing the same `metadata_id` is rejected with
`AlreadyPublishedError`/`409 already_published` rather than silently
creating a second permanent record for input that hasn't changed.

**Content-addressable dedup happens at the filesystem layer only, never
at the database layer.** WORK_PACKAGE-009 explicitly asks for this: "If
the artifact already exists in the Reference Vault (identical SHA-256),
do not duplicate the stored file. Instead, create the appropriate Vault
record that references the existing immutable artifact." Two different
Metadata records (from two different Downloads that happen to have
byte-identical content) each still get their own `VaultEntry` row --
`metadata_id` uniqueness (above) and content-based file dedup are
independent constraints answering different questions ("was *this*
Metadata record published before?" vs. "is *this exact content* already
on disk?").

**`ReferenceVaultService` recomputes the artifact's SHA-256 immediately
before publication and compares it to the Verification record, rather
than trusting the Verification's stored hash or the Metadata's copy of
it.** "SHA-256 shall match the Verification record before publication" is
a literal, freshness-sensitive check: the artifact could in principle
have changed on disk in the (necessarily nonzero) time between
Verification and this Vault publish call, and the Vault -- as "the
authoritative, immutable repository" -- is the last point before that
artifact becomes a permanent, canonical fact, making it the right place
to re-assert data integrity one final time rather than propagate a
possibly-stale hash forward.

**"Original Source ID" is resolved through a fourth repository,
`acquisition::IAcquisitionJobRepository`, via the Download's `job_id` --
not stored redundantly anywhere upstream.** The Vault Model requires
"Original Source ID," but no prior stage's table stores it directly:
`Download` has `job_id`, and only `AcquisitionJob` has `source_id`. Since
both tables already exist and the relationship is a real foreign key
(WORK_PACKAGE-003's `acquisition_jobs.source_id -> official_sources`),
`ReferenceVaultService` resolves it by one extra lookup at publish time
rather than denormalizing `source_id` onto `Download` or `Verification`,
which neither WORK_PACKAGE-006 nor WORK_PACKAGE-007 needed for their own
purposes.

## TODOs

- Milestone 2 (the Engineering Knowledge Engine) onward: real connector
  types (HTTP, FTP, browser automation) implementing `IConnector`/`fetch`,
  wiring Connectors to Official Sources/Acquisition Jobs, Engineering
  Object creation, knowledge graph generation, search indexing, document
  interpretation, and semantic classification -- per
  `docs/architecture/SDD-R013` through `SDD-R019`. Milestone 1 (Engineering
  Acquisition MVP, WORK_PACKAGE_001 through WORK_PACKAGE_009) is complete.
- `migrations/flyway.toml` is still not invoked by any automated
  process (see Future Considerations below).

## Future Considerations

- `migrations/flyway.toml` is not yet invoked by any automated process
  -- a future work package should wire `flyway migrate` into the build
  or a deployment step. Repository/API/migration tests currently apply
  `V1__initial_schema.sql` through `V8__reference_vault.sql`
  verbatim themselves (see "Test" above) as a stand-in.
- The Reference Vault has no verification-at-rest / periodic
  fixity-checking mechanism -- once an artifact is copied in, nothing
  re-reads it later to confirm the file on disk still matches its
  recorded `sha256_hash` (e.g. against bit rot or an out-of-band
  filesystem change). WORK_PACKAGE-009 only requires the hash to match
  "before publication," not on an ongoing basis; a future work package
  concerned with long-term archival integrity should consider a
  periodic re-hash job.
- There is no Vault-side mechanism to reclaim storage for content that
  was deduplicated and later has zero remaining `VaultEntry` rows
  referencing it (`reference_vault` rows are never deleted, so this is
  purely theoretical today, but relevant if Lifecycle Management
  eventually introduces a way to remove entries).
- Milestone 2 (the Engineering Knowledge Engine) is the natural point to
  revisit "Duplicate detection" (explicitly out of scope for
  WORK_PACKAGE-009 beyond content-addressable storage's own incidental
  dedup) and "Version comparison" (also explicitly out of scope) at a
  semantic, cross-artifact level -- WORK_PACKAGE-009's dedup is a storage
  optimization keyed on byte-identical content, not a statement about
  two artifacts being "the same document."
- Basic Document Inspection only covers PDF (version + best-effort page
  count) -- see "Implementation Decisions." A future work package adding
  richer per-type inspection (image dimensions for PNG/JPEG, entry counts
  for ZIP/TAR/GZIP, etc.) should decide whether to keep adding narrow,
  explicitly-typed columns to `artifact_metadata` (this repository's
  existing precedent) or generalize into a broader properties mechanism
  once enough types need one.
- `inspect_pdf`'s page-count heuristic (locate `/Pages`, then the nearest
  following `/Count`) reads only the first 2 MiB of the file and does not
  walk cross-reference tables or object streams -- it will miss the page
  count for a large, non-linearized PDF whose `/Pages` object falls later
  in the file, or one using compressed object streams (common in newer
  PDF producers). This is accepted as "best-effort" per WORK_PACKAGE-008's
  own "Basic Document Inspection" framing; a future work package needing
  reliable page counts across arbitrary PDFs should adopt a real PDF
  parsing library instead (a larger dependency and a different scope than
  "basic" inspection).
- File Type Detection has no signature for DOCX/XLSX/PPTX (ZIP-based
  Office formats) -- they will currently detect as plain `"ZIP"`. Adding
  container-aware detection (checking for `[Content_Types].xml` inside
  the ZIP) is a natural extension of the signature table once those
  formats are actually expected to arrive as engineering artifacts.
- The Integrity Verification Engine only ever compares a re-verification
  against the *most recent* prior `verified` hash for a Download Session,
  not the full verification history -- if a Download Session is verified
  three times and the second verification was itself `failed` (e.g. a
  transient read error), the third verification still compares against
  the first (last-known-good) hash, since `Failed` verifications are
  excluded from `latest_verified_hash`'s filter. This matches WORK_PACKAGE-007's
  text (which never describes multi-hash reconciliation), but a future
  work package that needs finer-grained drift analysis across a longer
  history should revisit `IntegrityVerificationService`'s re-verification
  lookup.
- The Integrity Verification Engine only ever compares a re-verification
  against the *most recent* prior `verified` hash for a Download Session,
  not the full verification history -- if a Download Session is verified
  three times and the second verification was itself `failed` (e.g. a
  transient read error), the third verification still compares against
  the first (last-known-good) hash, since `Failed` verifications are
  excluded from `latest_verified_hash`'s filter. This matches WORK_PACKAGE-007's
  text (which never describes multi-hash reconciliation), but a future
  work package that needs finer-grained drift analysis across a longer
  history should revisit `IntegrityVerificationService`'s re-verification
  lookup.
- Only SHA-256 is implemented, though WORK_PACKAGE-007 requires
  "Architecture shall support additional algorithms in future revisions
  without redesign." `Verification` has no `algorithm` column -- adding a
  second algorithm (e.g. BLAKE3, per `PROJECT_CONTEXT.md`'s "Secondary"
  hash algorithm) would need an additive migration and a corresponding
  field/column, which the existing `CHECK`-constrained-`TEXT`-over-native-`ENUM`
  precedent (see WORK_PACKAGE-002's Implementation Decisions) already
  supports without redesigning `integrity_verifications`.
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
  `PostgresDownloadRepository`, `PostgresVerificationRepository`,
  `PostgresMetadataRepository`, and `PostgresVaultRepository` (each
  currently one `pqxx::connection` per repository instance, held for the
  process's lifetime) should be reassessed once concurrent request volume
  makes single-connection
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
