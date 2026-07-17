# OEP Acquisition (Engineering Acquisition Manager)

The Trust Layer of the Open Engineering Platform (OEP): engineering
acquisition, provenance, integrity, licensing, and trusted evidence. See
`oep_architecture/docs/architecture/PLATFORM_SERVICES_ARCHITECTURE.md`
and this repository's own `docs/architecture/SDD-R013` through
`SDD-R019` for the full architecture.

## Status

**WORK_PACKAGE_001 (Repository Bootstrap) implemented.** This work
package establishes project infrastructure only -- no Engineering
Acquisition functionality (Official Source Registry, Browser, Vault,
Metadata, Integrity, Licensing, OCR, Engineering Objects) is
implemented yet. See `docs/tasks/WORK_PACKAGE_001.md`.

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
the process starts.

## Test

```
ctest --test-dir build --output-on-failure
```

12 tests across configuration parsing, the database connection
wrapper's failure path, and a real end-to-end `GET /health` request
against the embedded HTTP server (bound to an OS-assigned ephemeral
port, so tests never collide with a fixed port number or each other).

## Directory Layout

```
CMakeLists.txt          Root build: C++23, FetchContent dependencies, subdirectories
config/
  config.toml            Example/default process configuration
include/oep/acquisition/  Public headers, one subdirectory per module
  common/                 Config, Logger
  database/                DatabaseConnection
  api/                     ApiServer
src/
  common/                 Logging + TOML configuration loading
  database/                PostgreSQL connection management (libpq)
  api/                     Embedded HTTP server, GET /health
  app/                     main() -- wires the above together
  acquisition/ browser/ integrity/ licensing/ metadata/ registry/
  vault/ workspace/        Reserved for future work packages (empty --
                           see "Out of Scope" in WORK_PACKAGE_001.md)
migrations/
  V1__initial_schema.sql   Flyway migration placeholder (WORK_PACKAGE_001)
  flyway.toml              Flyway configuration (not yet invoked)
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

**Database client: raw `libpq`, not `libpqxx`.** WORK_PACKAGE_001 asks
for "PostgreSQL connection management. Connection only. No schema. No
repositories." `libpqxx` is a heavier, object-relational C++ wrapper
built for query execution with rich type conversions -- more than this
work package's scope needs. `DatabaseConnection`
(`src/database/database_connection.cpp`) is a small RAII wrapper
directly over the C API already installed alongside PostgreSQL 18. A
future work package introducing real repositories/queries may
reconsider this trade-off.

**Dependency management: CMake `FetchContent`, not vcpkg/Conan.** No
package manager was already set up in this environment or evidenced
elsewhere in the platform. `FetchContent` is built into CMake itself,
needs no additional tool install, and pins every dependency to an
explicit tagged version (never a floating branch) for reproducible
builds.

## TODOs

- Decide and ratify the platform's actual API framework (see
  "Implementation Decisions" above) in `oep_architecture`.
- WORK_PACKAGE_002 onward: Official Source Registry, Browser,
  Acquisition, Integrity, Licensing, Reference Vault, Metadata
  Extraction -- per `docs/architecture/SDD-R013` through `SDD-R019`.

## Future Considerations

- Once real schema/repositories exist, reassess whether `libpqxx`
  (or a connection pool) would serve better than the raw `libpq`
  wrapper this bootstrap uses.
- `migrations/flyway.toml` is not yet invoked by any automated process
  -- a future work package should wire `flyway migrate` into the build
  or a deployment step once a real schema exists to migrate.
