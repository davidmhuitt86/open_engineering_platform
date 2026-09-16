# OEP Release History

Canonical chronological release/implementation history for the Open Engineering Platform (OEP). See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) for current status and [`OEP_MILESTONE_ROADMAP.md`](OEP_MILESTONE_ROADMAP.md) for what comes next.

Last audited: 2026-09-16 (WP-CTRL-002 reconciliation).

**This document distinguishes, at every entry, exactly which of these four categories it falls into**:

1. **GITHUB MAIN** — verified present on `origin/main`, the shared/pushed state.
2. **LOCAL / NOT PUSHED** — a real commit exists on this machine's local `main` branch, verified via `git log`, but has not been pushed to `origin/main`.
3. **LOCAL WORKING TREE** — uncommitted changes present in the working directory, not yet a commit at all.
4. **PROPOSED / FUTURE WORK** — not yet implemented in any form.

No entry in this document should be read as implying a commit is on GitHub main unless explicitly labeled GITHUB MAIN.

---

## Current GitHub main

Verified via `git log origin/main -1 --oneline` on 2026-09-16 (WP-CTRL-002 reconciliation):

```
a36f69e  Merge remote-tracking branch 'origin/main'
```

**This is the current, verified state of the shared repository.** The entries in the new "Commits landed on GitHub main since the WP-CTRL-001 baseline" section below (covering `889cec2` through `a36f69e`) are confirmed present on `origin/main` at this commit. All entries in the "Commits landed on GitHub main this session" section further below (PR-014 through the ADR-0003 follow-up, ending at the prior baseline `4798912`) remain confirmed present as they were at the WP-CTRL-001 reconciliation.

Prior documented baselines (both superseded by the current baseline above):
```
4798912  ADR-0003: record final commit hash in release history          (WP-CTRL-001 baseline, 2026-09-13)
78ee8b0  Boot the Workspace to a real Home/Dashboard surface instead of empty
```

---

## Commits landed on GitHub main this session (originally recorded as "local commits ahead of GitHub main"; all 24 pushed 2026-09-13 — see WP-CTRL-001 below)

Listed oldest to newest (the order they'd be pushed in):

### PR-014 — Stabilize Diagram Studio WebView lifetime

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `1a97358`
**Message:** "PR-014: stabilize Diagram Studio WebView lifetime"

**Root cause found**: `DiagramWithComparePane` reconstructed/repositioned the primary `LegacyV2WebViewPage` through different conditional widget branches, causing the WebView to be recreated (and its expensive load/seed state lost) merely because a side panel's visibility changed.

**Fix**: the primary Legacy V2 WebView is now permanently mounted in one unconditional location in the widget tree, independent of Compare-pane visibility.

**Verified**: a Windows debug launch showed one CREATE / INIT / LOAD / SEED and no DISPOSE during the tested startup sequence (lifecycle instrumentation logging).

**Remaining**: human interactive validation is still required — this was verified via a single instrumented debug launch sequence, not via any automated lifecycle regression test. No automated lifecycle regression test suite exists for this behavior.

### PR-015 — Diagram Studio human UX/UI acceptance test system

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `8634276`
**Message:** "PR-015: add Diagram Studio human UX/UI acceptance test system"

Created:
- `platform/oep_studio/docs/testing/DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md`
- `platform/oep_studio/docs/testing/DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md`
- `platform/oep_studio/docs/testing/PRODUCT-READINESS-015-HUMAN-UX-UI-TEST-REPORT.md`

The human acceptance test itself has **not** been executed. Status is READY FOR HUMAN TEST, not PASSED.

### PR-016 — Prepare Diagram Studio human acceptance testing

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `5c231b5`
**Message:** "PR-016: prepare Diagram Studio human acceptance testing"

Created `platform/oep_studio/docs/testing/DIAGRAM-STUDIO-HUMAN-UX-UI-TESTER-START-GUIDE.md`.

### PR-016A — Interactive Diagram Studio human acceptance tester

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `84564de`
**Message:** "PR-016A: add interactive Diagram Studio human acceptance tester"

Created a standalone, interactive HTML acceptance-test tool (`diagram-studio-human-acceptance-test.html`) as a lighter-weight alternative to the markdown test form.

### Sidebar nav-order fix

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `bead021`
**Message:** "Fix HTML acceptance tester sidebar nav order (N between M and O)"

Small bugfix to the PR-016A HTML tool.

### WP-017 — EAM / Reference Vault Completion & M2 Readiness audit

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `8c6185c`
**Message:** "WP-017: EAM/Reference Vault implementation audit and hardening"

**Description**: a complete engineering audit and hardening pass of the Engineering Acquisition Manager (EAM) and Reference Vault implementation.

**Result: READY WITH CONDITIONS.**

**Findings**:
- HttpConnector performs real outbound HTTP, contradicting the documented WP-005/WP-006 "no real network communication" exclusion and README's own claims — SSRF-shaped gap, no host-allowlisting against the Official Source Registry. Documented in `services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md`, presenting three options; **not resolved at the time of this audit** (2026-09-12) — **subsequently resolved 2026-09-13, see the ADR-0003 entry below**.
- Reference Vault publish orphan-file race (filesystem copy + DB insert not atomic) — **fixed**, with regression tests.
- `reference_vault`'s foreign keys were missing indexes — **fixed** via additive migration V9, with a regression test.
- Two test-fixture defects (non-idempotent scratch paths across process runs) — **fixed**, discovered by actually executing the suite twice.

**Test results, verified twice consecutively against real PostgreSQL 18**: 221/221 test cases, 981/981 assertions, 0 skipped, 0 failed.

### WP-018 — Acquisition Record & Provenance Foundation

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `0494e25`
**Message:** "WP-018: implement Acquisition Record and provenance foundation"

**Description**: implements the Acquisition Record entity WP-017 identified as the largest architecture-vs-implementation gap in EAM — a durable, queryable identity anchoring one acquisition event (keyed 1:1 on Download Session ID) across Source/Job/Execution/Download/Verification/Metadata/Vault, with a new `acquisition_records` table (additive migration V10) and a new `GET /acquisition-records/{id}/provenance` route reconstructing the full chain by traversal — zero changes to `DownloadService`, `IntegrityVerificationService`, `MetadataExtractionService`, `ReferenceVaultService`, or `reference_vault` itself.

**Test results, verified twice consecutively against real PostgreSQL 18**: 235/235 test cases, 1090/1090 assertions, 0 skipped, 0 failed (up from WP-017's 221/981 — 14 new test cases, 109 new assertions, all added by WP-018).

**Not implemented** (explicitly deferred): rich per-acquisition metadata (Workstation, DNS, TLS, Referrer/Redirect Chain, licensing), SHA-512/BLAKE3, a full chain-of-custody event log, the `Archived` lifecycle state. Full detail: `services/acquisition/docs/audits/ACQUISITION_RECORD_IMPLEMENTATION_AUDIT.md` and `WP-018-IMPLEMENTATION-REPORT.md`.

### Project-control documentation system

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `1474c0e`
**Message:** "Establish canonical OEP project-control, versioning & master status system"

Created this documentation hierarchy (`OEP_PROJECT_STATUS.md` and everything under `docs/project/`). No source code changed.

### OEP Release Boundary & Repository Integrity Audit

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `b44f860`
**Message:** "Add OEP release boundary & repository integrity audit"

Audited whether the 8 preceding local commits are ready to become the next baseline (yes, at the Git level — pure fast-forward, zero conflicts) and independently re-confirmed (by fetching the original `oep_exchange` upstream repository directly) that its `packages/*` workspace was deleted in that repository's own final commit before the monorepo migration ever touched it. Recommended a dedicated Exchange workspace-reconstruction work package. See `docs/project/audits/2026-09-13-OEP-RELEASE-BOUNDARY-AUDIT.md`. No source code changed.

### WP-EXC-011 — Exchange Workspace Reconstruction

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `d110ddf`
**Message:** "WP-EXC-011: reconstruct Exchange workspace"

**Description**: restored all 14 documented `services/exchange/packages/*` workspace packages byte-for-byte from the last known good upstream commit (`18484e3`, before their undocumented deletion in that repository's own final commit `c6dbb75`). Removed one dangling workspace reference (`package_cli`, which never had any implementation in either repository's history). Result: `npm install`/`tsc -b`/lint all pass with zero errors; `apps/exchange-api` and `apps/exchange-admin` build and typecheck cleanly; 83 test files now execute (up from 19 before restoration). One confirmed, historically-unrecoverable gap remains: `apps/publisher-portal` depends on a real `@oep-exchange/exchange-client` implementation that was never committed anywhere (TASK-EXC-0007's own scope, never completed upstream) — 7 test files / 12 tests fail for this one diagnosed reason. This is Exchange RC1's workspace *foundation*, not Exchange RC1 itself, which remains not started.

### WP-EXC-012 — Exchange Client API Foundation

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `986bf8d`
**Message:** "WP-EXC-012: implement Exchange client API foundation"

**Description**: implemented the real `@oep-exchange/exchange-client` (`ExchangeApiClient`, `ExchangeApiError`) WP-EXC-011 found genuinely unrecoverable from git history — new code, not a restoration, established entirely from `apps/exchange-api`'s existing routes and `apps/publisher-portal`'s own existing, unmodified consumer code/tests (e.g. `use-async.test.ts`'s pinned `ExchangeApiError(status, code, message)` constructor, `PublishersPage.test.tsx`'s pinned flat-array `publishers.list()` return). Uses the platform's native `fetch`; no new HTTP dependency. Every implemented client method maps to an existing backend route — no speculative endpoint. No file under `apps/publisher-portal/` was modified.

**Result**: full Exchange workspace build/typecheck/lint/test now all pass with zero failures — 86 test files (69 passed, 17 pre-existing Postgres-gated skips), 443 tests (319 passed, 124 skipped, **0 failed**), up from WP-EXC-011's 7 failing files / 12 failing tests. Exchange RC1 (WP-EXC-010) remains not started; its foundation (workspace + client) is now complete.

### WP-EXC-010 Scope & Readiness Audit

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).** Audit/documentation only — no source code changed.
**Commit:** `9b2cb13`
**Message:** "WP-EXC-010: scope and readiness audit for Exchange RC1 + Studio integration"

**Description**: a scope/architecture readiness audit (not an implementation) for WP-EXC-010, now that WP-EXC-011/012 are complete. Its central finding: **OEP Studio already has a substantial, working Exchange integration** (`platform/oep_studio/lib/exchange/` — a full workspace, panels, a real Dart API client, persistent storage, Settings, already registered in `StudioRegistry`/`SurfaceRegistry`) — far more mature than the original `docs/tasks/WP-EXC-010.md` ("Status: Planned") describes. The one genuine, well-evidenced gap: Studio's Exchange "Install" action calls only Exchange's own REST API, which defaults to a `StubRepositoryClient` that fabricates a fake result — it never reaches Foundation's real, already-working, already-trust-verifying `oep_package_install`/`FoundationBridge.installPackage` (already used by an unrelated manual "Package Manager" Studio page). Closing that one connection — not new architecture — is identified as the crux of a genuine RC1 vertical slice. Proposes a revised, evidence-based WP-EXC-010 scope (`docs/tasks/WP-EXC-010-SCOPE.md`) and a small work-package breakdown (WP-EXC-013 install bridge, WP-EXC-014 end-to-end verification, WP-EXC-015 Studio test depth). See `services/exchange/docs/audits/WP-EXC-010-SCOPE-AND-READINESS-AUDIT.md` for the full evidence.

### WP-EXC-013 — Exchange → Repository Install Bridge

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `e1211c4`
**Message:** "WP-EXC-013: connect Exchange to Foundation installer"

**Description**: closed the one gap the WP-EXC-010 scope audit identified — Studio's Exchange "Install" action never reached a real OEP Repository. Added `ExchangeInstallBridge` (`platform/oep_studio/lib/exchange/services/exchange_install_bridge.dart`), which downloads the real package artifact (`ExchangeApiClient.downloadArtifact`, new — reads the `X-Checksum-Sha256` header `apps/exchange-api`'s download route already sent but Studio never read), verifies its SHA-256 checksum, and installs it through Foundation's real, unmodified `oep_package_install` via the same `FoundationBridge.installPackage` FFI path the manual Package Manager page already used. `ExchangeRuntimeNotifier.installPackage`'s outward contract is unchanged; only the source of truth for the resulting `Installation.status`/`.errorMessage`/`.repositoryPackageId` changed, from Exchange's simulated `StubRepositoryClient` result to Foundation's genuine outcome. Zero Foundation source changed; zero new Exchange API endpoints; zero new repository implementation.

**Result**: verified against the real, unmodified Foundation runtime (the actual `oep_foundation_bridge.dll`, not a fake) — a valid Stored-ZIP fixture (hand-built as Dart source, ported field-for-field from Foundation's own C++ test fixture builder) installs successfully with its object/relationship counts read back from Foundation itself; a checksum mismatch is rejected before Foundation is ever called; a corrupt archive and a duplicate install both produce Foundation's own real failure outcomes. 19 new/changed Dart tests across bridge unit tests, orchestration tests, and the real-Foundation integration test, all passing (the 4 real-Foundation tests are honestly skipped rather than falsely passed in an environment where the checked-in `oep_foundation_bridge.dll` build artifact is stale — verified once via a temporary, reverted local swap; see the implementation report). Full Studio suite: 1157 passed, 0 failed, 12 skipped (no regressions). Exchange root build/typecheck/test suite unaffected (no Exchange TS source touched): 69 test files / 319 tests passing, identical to WP-EXC-012's own baseline. Exchange RC1 itself remains not implemented; WP-EXC-014 (full end-to-end scenario test) is the next, now well-founded step. See `services/exchange/docs/tasks/WP-EXC-013.md` and `services/exchange/docs/audits/WP-EXC-013-IMPLEMENTATION-REPORT.md`.

### WP-EXC-013A — Foundation Bridge Artifact Synchronization & Integration Test Gate

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `26ab396`
**Message:** "WP-EXC-013A: synchronize Foundation bridge integration artifact"

**Description**: eliminates the manual-DLL-swap limitation WP-EXC-013 documented. Root cause: the tracked `platform/oep_studio/oep_foundation_bridge.dll` (committed 2026-08-15) was never part of any build pipeline — the canonical `flutter build windows` pipeline produces its own copy under the git-ignored `build/windows/x64/runner/` tree — and had gone stale after `OEP_API_VERSION` moved to 21 (commit `1ef6fd6`, 2026-08-27, whose own message records the CMake module list had been broken and this DLL "had not been successfully rebuilt in some time"). Added `platform/oep_studio/tool/sync_foundation_bridge_dll.dart`, which copies the canonical build output over the tracked root copy. Also hardened `test/exchange_foundation_install_integration_test.dart`'s own environment handling to distinguish a genuinely absent DLL (legitimate skip) from a loaded-but-stale/incompatible one (now FAILS clearly instead of silently skipping). No Foundation source, no CMake file, and no `ExchangeInstallBridge` logic were modified.

**Result**: ran the real pipeline (`flutter build windows --debug` then the sync script) this session and confirmed the real Foundation integration test now passes with zero manual file manipulation — verified three ways: passes after sync, FAILs clearly when the old stale DLL is restored, SKIPs when the DLL is removed entirely. Exchange root build/test unaffected (69 files / 319 tests, identical to WP-EXC-013's baseline). Full Studio suite: 1159 passed, 8 failed, 2 skipped (was 1157/0/12) — of the 8 failures, 6 are a pre-existing, unrelated latent bug in `test/core/foundation/foundation_bridge_diagram_identity_test.dart` (AP-OEP-FOUNDATION-BRIDGE-002) that this fix exposed for the first time (that file never wrote a `repository.json` before calling `openRepository`; its tests always silently skipped before because the stale DLL made `FoundationBridge.create()` fail first) — flagged as a follow-up task, not fixed here (out of scope, a different work package's test file); the other 2 were confirmed, by isolated re-run, to be pre-existing full-suite ordering flakiness unrelated to this WP. Classified COMPLETE WITH CONDITIONS rather than unconditionally COMPLETE for this reason. See `services/exchange/docs/tasks/WP-EXC-013A.md` and `services/exchange/docs/audits/WP-EXC-013A-IMPLEMENTATION-REPORT.md`.

### WP-EXC-014 — Exchange RC1 End-to-End Verification

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `30e4a1f`
**Message:** "WP-EXC-014: verify Exchange RC1 end-to-end installation"

**Description**: proves the full RC1 vertical slice (search → package detail → download → checksum verification → `ExchangeInstallBridge` → `FoundationBridge.installPackage` → Foundation's installer → Repository registration → Engineering Objects/Relationships → installed-package confirmation) through the real integration boundaries WP-EXC-013/WP-EXC-013A established, not a fully mocked path. Two tiers: `platform/oep_studio/test/exchange_rc1_e2e_test.dart` drives the real, unmodified production `ExchangeRuntimeNotifier`/`ExchangeInstallBridge`/`FoundationBridge` chain against a real socket-bound local HTTP server standing in for the genuine Postgres-backed Exchange server (explicitly documented substitution — this sandbox's local PostgreSQL has no `oep_exchange` role configured, the same pre-existing condition already gating 17 other Exchange test files); `apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts` independently proves the genuine server's own real search/detail/download/checksum behavior via Fastify's `.inject()`, gated by the same pre-existing `describe.skipIf(!databaseAvailable)` convention. Reuses WP-EXC-013's own Stored-ZIP fixture verbatim — no second package format. No production source touched anywhere.

**Result**: Tier B (Dart, the primary genuine E2E) — 4/4 tests pass: successful install (real object/relationship counts, real installed-package query), already-installed detection, corrupt-package rejection, checksum-mismatch rejection, all with no partial repository state on any rejected path. Tier A (TypeScript, real Postgres-backed) skips honestly in this sandbox (no live database role), exactly like 17 pre-existing files — not a new gap. Exchange root: 69 files / 319 tests passed, 18 skipped (was 17; +1 for this WP's own honestly-skipped test), zero regressions; `tsc -b`/`eslint`/`npm run build` all clean. Full Studio suite: 1164 passed, 7 failed, 2 skipped — all 7 failures are WP-EXC-013A's own already-documented pre-existing gaps (the 6-test `foundation_bridge_diagram_identity_test.dart` latent bug plus one already-identified full-suite ordering flake, re-confirmed clean in isolation); **zero new failures from WP-EXC-014**. See `services/exchange/docs/tasks/WP-EXC-014.md` and `services/exchange/docs/audits/WP-EXC-014-IMPLEMENTATION-REPORT.md`.

### WP-EAM-LOCAL-SERVICE-001 — Local EAM Service Launcher

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `be34235`
**Message:** "EAM: add local service launcher to Settings"

**Description**: adds a "Local EAM Service" section to Studio's Settings > Engineering Acquisition page with Start/Stop/Restart controls, so a developer no longer needs a separate terminal to run the local EAM backend during development. `AcquisitionServiceLauncherNotifier` spawns the exact, unmodified, already-built `oep_acquisition.exe` (mirroring `services/acquisition/run_server.bat`'s own command, corrected for this checkout's real layout), never a second backend or API; it defers entirely to the existing `AcquisitionRuntimeNotifier.testConnection`/`GET /health` path to confirm the process came up, and never touches a process it did not itself spawn — an already-occupied port is reported, not seized. The controls only appear for a local Service Address; a remote address only shows the existing Test Connection button. Along the way, a real startup hang was found and fixed: the spawned process's stdout/stderr must be drained continuously or its OS pipe buffer fills and blocks the child process itself once it logs enough at startup — confirmed directly against the real backend.

**Result**: 11 fake-based unit tests cover every status transition; a separate, honestly-skippable test drives the real `oep_acquisition.exe` end to end and passes in this environment (real PostgreSQL role for `oep_acquisition` already configured here). Existing Acquisition test suite (8 tests) unaffected. Full Studio suite: 1175 passed, 8 failed, 2 skipped — all 8 failures are the same, already-documented WP-EXC-013A gaps (6-test `foundation_bridge_diagram_identity_test.dart` latent bug + a known flaky test, reconfirmed intermittent by isolated reruns); zero new failures from this work. `flutter build windows --debug` succeeds; `flutter analyze` clean. See `platform/oep_studio/docs/tasks/EAM-LOCAL-SERVICE-LAUNCHER.md`.

### ADR-0003 — HttpConnector Security, Scope, and SSRF Resolution

**Status: PUSHED (verified on origin/main by WP-CTRL-001, 2026-09-13).**
**Commit:** `d7df760`
**Message:** "ADR-0003: resolve HttpConnector security and scope"

**Description**: resolves the previously-Proposed `ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md` (raised by WP-017's implementation audit, 2026-09-12): `HttpConnector` — a real, live, unauthenticated-API-reachable HTTP client registered as `"http-source"` in `main.cpp` since this repository's own import commit — was confirmed to have a genuine, reproducible SSRF vulnerability (zero destination validation anywhere; `source_uri` flows unchecked from the request body straight into a real outbound fetch, with no cross-check against the Official Source Registry's own `base_url`/`trust_level` trust anchor, which exists in the schema but was never wired into the download path). Ratified as an approved capability (Option A) with the SSRF gap closed structurally rather than documented-only: every destination — the initial URL and every redirect hop — is resolved via `getaddrinfo` and validated against loopback/RFC1918/link-local/multicast/unspecified ranges (IPv4 and IPv6, including IPv4-mapped IPv6 and the 169.254.169.254 cloud-metadata address, which needed no special case since it is simply link-local), with the validated address pinned via `httplib::Client::set_hostname_addr_map` to close the DNS-rebinding TOCTOU window, redirects followed manually with per-hop re-validation up to a configurable cap, and a response-size cap enforced during streaming. TLS certificate verification, timeouts, and proxy behavior were already safe by default and needed no change. Deliberately deferred: cross-checking `source_uri` against a Job's registered Source `base_url` — no ratified specification ever constrained it that way, and imposing it now would be a product decision, not a security patch; left as an explicitly open question for a future work package with product authority, not silently decided either way. Four stale "StubConnector is the only connector type" claims in `README.md` corrected.

**Result**: 13 new deterministic tests (no internet dependency — `getaddrinfo` resolves literal IPs without a network query) covering every disallowed destination class, userinfo rejection, invalid/looping/unresolvable redirects, and oversized responses, plus a test that reads `main.cpp`'s own source to guarantee the live connector registration never opts into the test-only `allow_private_destinations` escape hatch. Full existing suite: 247 test cases, 568 assertions, 0 failed, 25 skipped (all pre-existing PostgreSQL-auth environment gaps, unrelated to connectors). Live verification against the real running server: a genuine external HTTPS fetch (`https://example.com/`) still succeeds end to end; an identical self-referential SSRF attempt (`http://127.0.0.1:8080/health`) is now correctly rejected with a clear error and leaves no partial file on disk. See `services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md` and `docs/project/audits/2026-09-13-OEP-ADR-0003-HTTPCONNECTOR-RESOLUTION-AUDIT.md`.

---

## Commits landed on GitHub main since the WP-CTRL-001 baseline (`4798912` → `a36f69e`, reconciled by WP-CTRL-002, 2026-09-16)

Listed oldest to newest.

### WP-SRV-002 — Vault artifact retrieval / filesystem-path removal

**Status: PUSHED.**
**Commit:** `e6018d1`
**Message:** "WP-SRV-002: implement GET /vault/{id}/artifact and remove filesystem paths from public API"

**Description**: adds `GET /vault/{id}/artifact` (raw-bytes retrieval, `Content-Type`/`Content-Length`/`X-Checksum-Sha256`, modeled on Exchange's package-download contract) to the Reference Vault API, and removes `vault_path`/`local_storage_path` from public Vault/Download JSON responses (both remain available internally where still needed).

**Verification**: no dedicated audit document exists for this WP specifically; `services/acquisition/tests/test_download_api.cpp` was extended in the same commit. Its own test additions are folded into WP-SRV-003's subsequent full-suite baseline (256/256 test cases) below — this document does not have an isolated, WP-SRV-002-only assertion count on record. **Classification: IMPLEMENTED, VERIFIED (as part of the WP-SRV-003 full-suite run), not independently re-verified in isolation.**

### WP-SRV-003 — EAM API Authentication

**Status: PUSHED.**
**Commit:** `0421ca2`
**Message:** "feat(server): add EAM API authentication boundary"

**Description**: adds the EAM REST API's first authentication boundary — a single, server-wide bearer-token gate (`Authorization: Bearer <OEP_API_TOKEN>`, constant-time comparison) in front of every route except `GET /health`, installed once via `httplib::Server::set_pre_routing_handler`. No default/implicit token exists; both `main.cpp` and `ApiServer`'s constructor independently refuse to start with an empty token.

**Test results**: 256/256 test cases, 1188/1188 assertions, 0 failed, 0 skipped, against real PostgreSQL. See `docs/project/audits/2026-09-13-WP-SRV-003-EAM-API-AUTHENTICATION-AUDIT.md` and `docs/architecture/decisions/ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md`. **Classification: IMPLEMENTED, VERIFIED.**

### WP-SRV-004 — EAM API TLS Boundary

**Status: PUSHED.**
**Commit:** `ce2fbf9`
**Message:** "feat(server): add EAM API TLS boundary"

**Description**: adds a TLS termination boundary in front of the (now-authenticated) EAM API — nginx reverse proxy, TLS 1.2+/1.3 only, self-signed development certificate (never committed to this repository), EAM rebound from `0.0.0.0:8080` to loopback-only `127.0.0.1:8080`. ADR-0002's authentication mechanism/response shape is unchanged and verified working identically through the new boundary.

**Test results**: Windows/MSVC — 256/256 test cases, 1188/1188 assertions, 0 failed, 0 skipped. Linux/GCC (VM) — 231 test cases, 0 failed, 25 skipped (pre-existing, environment-only DB-credential skip pattern, unrelated). See `docs/project/audits/2026-09-14-WP-SRV-004-EAM-API-TLS-BOUNDARY-AUDIT.md` and `docs/architecture/decisions/ADR-0003-OEP-REFERENCE-SERVER-TLS-BOUNDARY.md`. **Classification: IMPLEMENTED, VERIFIED.**

### WP-SRV-005 — OEP Server Data Infrastructure (narrowed scope)

**Status: PUSHED.**
**Commit:** `889cec2`
**Message:** "feat(server): establish EAM PostgreSQL data infrastructure (WP-SRV-005)"

**Description**: WP-SRV-005 as originally specified assumed a PostgreSQL-backed "OEP Repository" persistence layer for Engineering Objects/Relationships/State. The audit found this would contradict ADR-0001 §4.6 (Foundation has no server-side existence yet — a separate, not-yet-made architectural decision) and reported this to the user directly before implementing anything. The user selected the recommended narrowed path: proceed with EAM's own PostgreSQL persistence/Reference Vault documentation (already substantially implemented), and leave "OEP Repository" persistence for its own, separate architectural decision — which subsequently became the Server Repository Service (ADR-0004 through ADR-0006, WP-SRV-011 onward, see below).

**Verification**: full existing suite re-run after this WP's documentation/config changes, 256/256 test cases, 1188/1188 assertions, 0 failed, 0 skipped (twice consecutively per the audit). See `docs/project/audits/2026-09-14-WP-SRV-005-OEP-SERVER-DATA-INFRASTRUCTURE-AUDIT.md`. **Classification: DOCUMENTATION ONLY for the "OEP Repository" persistence question (explicitly deferred, not attempted); IMPLEMENTED/VERIFIED for EAM's own data-infrastructure documentation scope.**

### Server Repository Service architecture — ADR-0001 through ADR-0006

**Status: PUSHED (documentation only — no source code in any of these commits).**
**Commits:** `220d542`, `a93192d`, `0ecded6`, `e8e43e0`, `c48596d`, `a21c1c9`, `57eafeb`, `a1c8fc3`
**Messages:** "docs(server): audit reference server infrastructure bring-up"; "docs/server: define OEP Reference Server boundary and artifact contract"; "docs(server): define Server Repository service contract"; "docs(server): define repository semantics and state model"; "docs(server): define repository API and persistence boundary"; "docs(server): finalize repository implementation readiness"; "docs(server): correct repository idempotency atomicity contract"; "docs(server): require atomic, durable repository-creation idempotency"

**Description**: the architecture-only decision chain that authorized the Server Repository Service's first implementation slice — service contract, semantics/state model, API/persistence boundary, implementation readiness/wire contract (ADR-0006), and two later corrections to ADR-0006 (operation-identity scope; atomic idempotency persistence, both required before implementation began per their own "STOP and report" instructions). **Classification: DOCUMENTATION ONLY.** See `docs/architecture/decisions/` and `docs/architecture/contracts/SERVER-REPOSITORY-SERVICE-CONTRACT.md`.

### WP-SRV-011 — Server Repository First Vertical Slice

**Status: PUSHED.**
**Commit:** `9bde275`
**Message:** "WP-SRV-011: Server Repository first vertical slice (persistence & domain core)"

**Description**: the first actual implementation of the Server Repository Service, authorized by ADR-0006 §29. Repositories, repository-creation identity/idempotency (server-scoped), objects/relationships with append-only revision history plus "head" current-state pointers, commits with repository-scoped idempotency, minimal audit association. Repository-creation and commit atomicity (mutation + revisions + commit record + idempotency + audit in one PostgreSQL transaction). Optimistic concurrency via `SELECT ... FOR UPDATE`. 8 of the ADR-0006-authorized HTTP routes.

**Test results**: 159/159 assertions, 8 test cases, against real PostgreSQL (VM-hosted, dedicated `oep_server_repository`/`oep_server_repository_test` databases, least-privilege role, separate from EAM's own). **Classification: IMPLEMENTED, VERIFIED.**

### WP-SRV-011A — Real PostgreSQL Concurrency Validation Correction

**Status: PUSHED.**
**Commit:** `4618729`
**Message:** "WP-SRV-011A: correct PostgreSQL concurrency validation"

**Description**: an independent audit found WP-SRV-011's original single-connection-plus-mutex persistence design serialized every concurrent commit in the application layer before PostgreSQL ever saw a second transaction — the concurrency test proved HTTP-response-level behavior only, not real database row-lock contention. Replaced with a small (16-connection) internal connection pool so concurrent HTTP requests run on genuinely independent connections/transactions; re-verified with 8 real OS threads racing a real PostgreSQL row lock (`SELECT ... FOR UPDATE`) for the same object.

**Test results**: 166/166 assertions, 8 test cases. **Classification: IMPLEMENTED, VERIFIED — corrects a real, confirmed gap in WP-SRV-011's own original verification claim.**

### WP-SRV-011B — Server Repository API Wire Version

**Status: PUSHED.**
**Commit:** `31cb11b`
**Message:** "WP-SRV-011B: add Server Repository API wire version"

**Description**: adds the `/api/v1/` wire-version prefix ADR-0006 requires ("API version MUST appear at the wire boundary"), following the same precedent Exchange already established. `GET /health` deliberately stays unversioned/unauthenticated. Also closes a related gap found during the same audit: "list objects"/"list relationships" were required for this slice by ADR-0006 §7/§18 but had never been wired up (only "list repositories" had been a documented, deliberate omission).

**Test results**: 200/200 assertions, 9 test cases. **Classification: IMPLEMENTED, VERIFIED.**

### WP-SRV-011C — Enforce UUIDv4 Identity Contract

**Status: PUSHED.**
**Commit:** `fd8d630`
**Message:** "WP-SRV-011C: enforce UUIDv4 identity contract"

**Description**: ADR-0004/ADR-0006 establish UUIDv4 as the identity format for every Server Repository identity, but validation only checked canonical UUID *structure* (length, hyphens, hex digits) — a UUIDv1/v3/v5 identity, or a structurally valid UUID with a non-standard variant, was accepted. Strengthened the shared validation function to also check the version nibble (must be `4`) and the variant nibble (RFC 4122/9562 standard variant), applied uniformly to every client-supplied identity field via the single shared function every call site already used.

**Test results**: 307/307 assertions, 12 test cases. **Classification: IMPLEMENTED, VERIFIED.**

### WP-SRV-012 — Repository Tombstone/Delete Semantics

**Status: PUSHED.**
**Commit:** `0d5be8a`
**Message:** "WP-SRV-012: implement repository tombstone semantics"

**Description**: implements the delete/tombstone semantics ADR-0006 §10 already authorized (delete-as-tombstone only, never a hard delete, never a removed history row; deletion creates a new revision; historical revisions remain retrievable; object deletion blocked while a live relationship still references it unless that relationship is deleted atomically in the same commit). Tombstoned current-state GET reuses the existing `NOT_FOUND`/404 category rather than inventing a new one (ADR-0006's error-category list is closed; `NOT_FOUND` already covers "no live current state exists").

**Classification: IMPLEMENTED — see WP-SRV-012A immediately below, which corrected this WP's own restoration mechanism before final verification; the 514/514-assertion figure reported for WP-SRV-012A is the verified state of both WPs' combined work.**

### WP-SRV-012A — Correct Create-Shaped Tombstone Restoration

**Status: PUSHED.**
**Commit:** `66af1f5`
**Message:** "WP-SRV-012A: correct create-shaped tombstone restoration"

**Description**: corrects a mismatch an independent review found in WP-SRV-012: ADR-0006 §10 specifies restoration of a tombstoned identity exclusively as "a subsequent create-shaped mutation," but WP-SRV-012's original implementation restored via an ordinary *update* mutation instead. Corrected so `object_create`/`relationship_create` against an existing identity restores it only when that identity is currently tombstoned (producing a new LIVE revision N+1); an `update` mutation against a tombstoned identity is now correctly rejected instead of silently restoring it. The initial INSERT-uniqueness attempt is wrapped in a SAVEPOINT-backed `pqxx::subtransaction` so a collision (an existing, tombstoned row) rolls back only that attempt, not the whole commit transaction — the same commit can then inspect and restore the row. `expected_revision` became an accepted, optional field on create mutations, required and validated against the tombstone revision when restoring, so restoration participates in the same optimistic-concurrency/idempotency/atomic-transaction machinery as every other mutation (no second concurrency mechanism invented).

**Test results**: **514/514 assertions, 16 test cases, all passing**, against real PostgreSQL (VM-hosted). Includes explicit re-verification that the WP-SRV-011A concurrency tests and WP-SRV-011C UUIDv4 tests were not weakened. No ADR modified; no hard-delete SQL (`DELETE FROM`) exists anywhere in the service's source (verified by direct search). **Classification: IMPLEMENTED, VERIFIED.**

### UX-001 / docs(ux) — OEP UX architecture, EAM workspace specs, sectional UI implementation kit

**Status: PUSHED (documentation/specification only — no source code in any of these commits).**
**Commits:** `fc0fa5f`, `4a38d22`, `6d6fb62`, `004a1f0`, `25bf7b5`, `00997a4`, `f0c5ba9`, `9ad1e20`, `80487a9`, `60cbc55`, `d856e3f`, `fa57e0e`, `7861146`
**Description**: establishes `docs/architecture/ux/` (OEP UX architecture index, EAM acquisition workspace/interaction-state specs, marks a legacy dashboard model superseded), the OEP UI implementation kit, a Diagram Studio implementation work-package definition, a live-Flutter-hot-reload requirement during UI work, and a sectional UI implementation workflow plus its packaged skill (`.claude/skills/oep-ui/SKILL.md`). **Classification: DOCUMENTATION ONLY.** No implementation work has been verified or claimed against any of these specifications by this reconciliation — they describe planned/target UI architecture, not yet-built Studio surfaces.

---

## Uncommitted local working-tree changes (as of 2026-09-16, WP-CTRL-002 reconciliation — pre-existing, unrelated to this WP, left untouched)

**Status: LOCAL WORKING TREE, not even a commit.**

- `platform/oep_studio/lib/acquisition/services/acquisition_api_client.dart`, `platform/oep_studio/lib/acquisition/settings/acquisition_settings_page.dart`, `services/acquisition/config/config.toml` — EAM client-side auth-token wiring and local-dev VM database connection settings from a prior session; not committed, not part of this reconciliation's scope, left untouched.
- `docs/architecture/ux/` (multiple untracked `.md` files plus a `renders/` directory) — local-only UX design material distinct from the already-committed `UX-001`/`docs(ux)` series above (different filenames/content); not committed, not part of this reconciliation's scope, left untouched.
- `services/acquisition/data/vault/f0/`, `services/acquisition/data/workspace/75d7031a-5d88-454a-bc54-6d6145429a15/` — local EAM runtime data directories generated by manual testing; not committed, not part of this reconciliation's scope, left untouched.

---

## Proposed / future work (PROPOSED — not yet implemented in any form)

- **WP-EXC-010** — Exchange RC1 plus OEP Studio integration. Priority: CRITICAL, per Exchange's own program planning. See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) Section 12.
- **Diagram Studio human UX/UI acceptance test execution** — infrastructure exists (PR-015/016/016A), the test itself has not been run.
- **Broader EAM M2** — rich per-acquisition provenance metadata, connector security policy beyond ADR-0003's own resolved scope, custody events (all classified FUTURE/DEFERRED in the WP-018 audit, pending upstream producers that do not exist yet; connector destination-security itself, and now API authentication/TLS, are both resolved — see above).
- **WP-SRV-013** — the next Server Repository Service work package. **NOT STARTED**: no commit, source file, test, migration, or document anywhere in this repository references it (verified by direct search, WP-CTRL-002, 2026-09-16). Not selected or scoped by this reconciliation.

---

## Superseded / historical status documents

The following documents predate this canonical documentation system and are retained for historical/subsystem context. Each has been annotated with a supersession notice pointing back to [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md):

- `platform/oep_foundation/PROJECT_STATUS.md`
- `platform/oep_foundation/CURRENT_SPRINT.md`
- `platform/oep_foundation/docs/review/FINAL_RECOMMENDATION.md`
- `platform/oep_foundation/docs/review/PLATFORM_SNAPSHOT.md`
- `platform/oep_foundation/docs/review/TECHNICAL_DEBT.md`

See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) Section 16 for why the credential-exposure claim in the three `docs/review/` documents above is treated as documentation drift rather than a corroborated current finding.
