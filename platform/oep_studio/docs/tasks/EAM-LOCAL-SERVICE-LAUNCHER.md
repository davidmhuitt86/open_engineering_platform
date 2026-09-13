# WP-EAM-LOCAL-SERVICE-001 — Local EAM Service Launcher

Status: Complete

## Why this exists

EAM (Engineering Acquisition Management) is an autonomous domain service, reached only through its own REST API (`docs/CONNECTION_MANAGER.md`'s boundary, mirrored for Acquisition). During local development, that backend (`services/acquisition`, a C++/`httplib` process) has to be started separately before Studio's "Test Connection" in Settings > Engineering Acquisition will succeed — otherwise the engineer sees "Network Error" and has to go find and run the executable from a terminal by hand. This work package adds a "Start Local Service" convenience to that same Settings page so a separate terminal is not required for local development. It does not change what the authoritative EAM backend is, how it is built, or how Studio talks to it.

## How the local EAM service is started

The launcher (`platform/oep_studio/lib/acquisition/services/acquisition_service_launcher.dart`) spawns the exact, unmodified, already-built binary a developer would otherwise run by hand:

```
executable: services/acquisition/build/src/app/Debug/oep_acquisition.exe
arguments:  config/config.toml
workingDirectory: services/acquisition
```

This mirrors `services/acquisition/run_server.bat`'s own command, corrected for this repository's actual checkout layout (that script's own `cd /d C:\dev\platform\oep_acquisition` predates a repository restructuring and points at a location that does not exist in this checkout) and for the CMake multi-config `Debug/` build output subdirectory the batch file omits.

`defaultAcquisitionLaunchPlanResolver()` locates `services/acquisition` by walking upward from both `Directory.current` and the running executable's own directory, looking for the marker file `services/acquisition/config/config.toml` — this avoids hardcoding an assumption about whether Studio is launched via `flutter run`/`flutter test` (CWD = the package root) or as a built `.exe` (CWD = wherever it happens to be launched from). If neither location leads to a real checkout of this repository (e.g. a packaged/installed Studio with no sibling source tree), the resolver returns `null` and the launcher reports "Unable to start EAM service." rather than guessing.

`oep_acquisition.exe` needs `libpq.dll` (PostgreSQL's client library) reachable on `PATH` at runtime — it is not copied next to the executable. The resolver scans `C:\Program Files\PostgreSQL\*\bin` for `libpq.dll` and prepends the highest-versioned match (plus `C:\Program Files\OpenSSL-Win64\bin` if present) to the spawned process's own `PATH`, mirroring `run_server.bat`'s own `set PATH=...` line — the parent Studio process's `PATH` is read but never itself modified.

### A note on draining the child process's output

The spawned process's stdout/stderr **must** be read continuously once it starts. Confirmed directly against the real `oep_acquisition.exe` during this work package's own testing: if nothing reads from the child's stdout pipe, its OS-level buffer eventually fills (this backend logs a line for every subsystem it connects during startup) and the write blocks the child process itself — not just the log — until something drains the pipe. The launcher keeps only the last 20 lines of combined output in memory for diagnostics; it never blocks on, or discards without reading, either stream.

## Service address behavior

The launcher never bypasses or duplicates the existing `Service Address` setting (`AcquisitionSettings.apiBaseUrl`, default `http://127.0.0.1:8080`). It reads that same setting to decide the host/port to spawn against and to poll for readiness, and defers to the existing `AcquisitionRuntimeNotifier.testConnection()` / `GET /health` path (no new endpoint) to confirm the process actually came up — the same check the workspace's own connection banner and Settings' "Test Connection" button already use.

`isLocalServiceAddress(String apiBaseUrl)` checks whether the configured address's host is `127.0.0.1`, `localhost`, or `::1`. The "Local EAM Service" section of Settings only renders when this is true; a remote address (e.g. `https://example.oep.com`) shows only the existing "Test Connection" control, treating that service as externally managed — the local launcher never attempts to start a process for it.

If something else is already listening on the configured port when "Start Local Service" is pressed, the launcher reports "Port {port} is already in use." and attempts `testConnection()` (in case that something else is in fact a healthy EAM instance started another way) — it never terminates the unrelated process.

## Local vs. remote deployment model

This is a **local development convenience only**. The architecture it sits inside remains:

```
OEP Studio
    │
    │ HTTP
    ▼
EAM Service
```

For local development, Settings additionally owns the convenience of *launching* that service — it does not become part of the service's own domain logic, and the EAM backend is not turned into a Flutter-owned subsystem. The exact same Studio build will, in production, communicate with a remote `https://<oep-service-domain>` (or any other configured address) where the "Local EAM Service" section simply does not appear, and the service is understood to be externally managed (deployed, started, and monitored by whatever owns that environment) rather than launched by Studio.

## Dependencies

- `services/acquisition/build/src/app/Debug/oep_acquisition.exe` must already be built (this work package does not build it).
- PostgreSQL must be installed at `C:\Program Files\PostgreSQL\<version>\bin` for `libpq.dll` resolution to work automatically; the backend itself treats a database connection failure as a non-fatal warning (per its own `main.cpp`), so the process still starts and its `/health` endpoint still responds even without a reachable database — only the DB-backed routes (`/sources`, `/jobs`, etc.) would then fail.
- The `oep_acquisition`/`oep_acquisition` PostgreSQL role and database, per `services/acquisition`'s own documented local setup, if DB-backed functionality is needed.

## Known limitations

- Windows-only, matching this repository's own current primary development workflow — no Linux/macOS/Android process-launch path was fabricated.
- The directory-walk-up resolver is a best-effort heuristic for a development checkout; it does not attempt to locate the service in a fully packaged/installed production deployment (which would not embed the C++ source tree at all).
- The launcher tracks and can stop only the process it itself started; a separately-started EAM instance is left alone entirely, including on Studio shutdown.
- No automatic re-detection of an already-running externally-started service beyond the existing "Test Connection" mechanism.

## Future production deployment expectations

In production, the EAM service is expected to be deployed and operated independently of Studio (its own release/monitoring/scaling lifecycle), reachable at a configured remote address. The `Service Address` abstraction this work package deliberately preserved is exactly what allows that: nothing about the local launcher assumes local process-spawning is the permanent or only way Studio ever reaches EAM.
