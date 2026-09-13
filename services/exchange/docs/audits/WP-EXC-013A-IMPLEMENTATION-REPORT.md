# WP-EXC-013A — Foundation Bridge Artifact Synchronization & Integration Test Gate
## Implementation Report

STATUS:
COMPLETE WITH CONDITIONS (see §"Remaining gaps" — a pre-existing, unrelated test-file bug was exposed, not caused, by this WP's fix; documented rather than silently left unmentioned or fixed out of scope)

COMMIT:
`26ab396b16663d3ae51591bbe9b78823fad22747` — "WP-EXC-013A: synchronize Foundation bridge integration artifact" (single dedicated commit, per the task's own git discipline).

PUSHED:
NO — LOCAL / NOT PUSHED.

ROOT CAUSE:
Two compounding facts. (1) The tracked `platform/oep_studio/oep_foundation_bridge.dll` (committed 2026-08-15, the single "Import oep_studio history" commit) was never part of any build pipeline — the canonical `flutter build windows` pipeline produces and copies its own DLL to the git-ignored `build/windows/x64/runner/{Debug,Release}/` tree, a completely different file. Nothing ever kept the two in sync. (2) Commit `1ef6fd6` (2026-08-27, `OEP_API_VERSION` 20→21) fixed `native/foundation_bridge/CMakeLists.txt`'s Foundation module list, whose own commit message records that this DLL "had not been successfully rebuilt in some time" before that fix (a stale `exchange` module reference broke `add_subdirectory` outright). The Aug-15 root copy predates all of this, so by the time WP-EXC-013 tried to use it, `dart:ffi`'s `DynamicLibrary.open` could load the file but `oep_runtime_get_state` and other current symbols were missing (Windows error 127, "Failed to lookup symbol").

BRIDGE ARTIFACT:
`platform/oep_studio/oep_foundation_bridge.dll` (tracked). Refreshed this session from 1,748,480 bytes (stale, Aug 15) to 5,554,688 bytes (current, produced by `flutter build windows --debug` in this session and copied over via the new sync script).

TRACKING DECISION:
A — remains tracked; kept in sync going forward by an explicit script (`tool/sync_foundation_bridge_dll.dart`), not by deletion or a `.gitignore` change. Rationale in `docs/tasks/WP-EXC-013A.md` §4: the repository already established this exact tracking precedent; a prebuilt, working copy lets `flutter test` exercise the real native Foundation surface without every contributor/CI runner needing a full C++ toolchain; the actual defect was "nothing regenerates it," not "it's tracked." A future WP may revisit this policy with a broader mandate — not forced here.

CANONICAL BUILD PATH:
```
flutter build windows --debug
dart run tool/sync_foundation_bridge_dll.dart
```
(`--release` accepted by the sync script for a Release build; the script checks Debug first by default, falling back to Release if Debug is absent.)

API:
`OEP_API_VERSION 21` (confirmed directly in `platform/oep_foundation/platform/api/include/oep/api/oep_api.h`, matches the expected value).

ABI:
`OEP_ABI_VERSION 1` (confirmed, matches the expected value).

REAL FOUNDATION INTEGRATION:
Reproducible and PASSING. `flutter build windows --debug` (fresh, canonical build performed this session; content-identical to a same-day prior build since Foundation source hasn't changed, confirming determinism) → `dart run tool/sync_foundation_bridge_dll.dart` → `flutter test test/exchange_foundation_install_integration_test.dart` → all 4 tests pass, with zero manual binary manipulation between the sync step and the test run.

MANUAL DLL SWAP REQUIRED:
NO. (Verified this is genuinely eliminated — see TEST RESULTS below for the three-way confirmation: pass after sync, FAIL when the old stale DLL is restored, SKIP when the DLL is removed entirely.)

INSTALL TEST:
PASS — real install, Foundation's own object/relationship counts (2/1) read back via `getObjectCount()`/`getRelationshipCount()`.

CHECKSUM TEST:
PASS — mismatch rejected before Foundation is ever called; `getObjectCount()` confirms nothing was created.

CORRUPT PACKAGE TEST:
PASS — real Foundation installer rejects the non-ZIP fixture.

ALREADY INSTALLED TEST:
PASS — second install of the same fixture returns Foundation's genuine already-installed outcome.

REPOSITORY REGISTRATION:
PASS — confirmed via the real Repository Registry (`getObjectCount`/`getRelationshipCount` read back through the live bridge, not asserted from the install result alone).

ENGINEERING OBJECT CREATION:
PASS — 2 real Engineering Objects + 1 real Relationship, counts read from the live runtime.

EXCHANGE TESTS:
```
$ npm run build   (root tsc -b + publisher-portal + exchange-admin)
exit 0, zero errors

$ npm test
Test Files  69 passed | 17 skipped (86)
     Tests  319 passed | 124 skipped (443)
```
Identical to WP-EXC-013's own baseline — no Exchange TS source was touched by this WP, confirmed no regression.

STUDIO TESTS:
```
$ flutter test test/exchange_foundation_install_integration_test.dart
+4: All tests passed!               (reproducible, no manual swap)

$ flutter test test/exchange_install_bridge_test.dart
                test/exchange_runtime_install_bridge_orchestration_test.dart
                test/exchange_api_client_test.dart
+26: All tests passed!              (WP-EXC-013's other bridge tests, unaffected)

$ flutter test   (full suite, captured complete output)
+1159 ~2 -8
```
Of the 8 failures: **6 are a pre-existing, unrelated latent bug this WP's own fix exposed for the first time** — `test/core/foundation/foundation_bridge_diagram_identity_test.dart`'s 6 tests have always called `bridge.openRepository(tempDir.path)` on an empty temp directory with no `repository.json` ever written into it, which Foundation's `open_repository` requires. Before this WP, `FoundationBridge.create()` itself always failed first (the stale DLL), so every test in that file degraded to `markTestSkipped` and the bug never ran. Now that the DLL genuinely loads, all 6 reach the real `openRepository` call and fail with `FoundationBridgeException(FoundationErrorCode.notFound, ...)` — a real defect in that test file's own setup, not in Foundation, not in the Exchange bridge, and not something this WP introduced or is in scope to fix (it belongs to a different work package's test surface, AP-OEP-FOUNDATION-BRIDGE-002). Flagged as a follow-up task (`task_5a989f91`) rather than fixed here. The remaining 2 failures (`diagram_repository_commit_action_test.dart`'s "full continuity" test, `diagram_tabs_controller_test.dart`'s "recentlyClosed is bounded" test) were independently re-run in isolation and **passed cleanly both times** — pre-existing full-suite test-ordering/isolation flakiness unrelated to anything this WP touched, not a regression.

Net accounting matches exactly: WP-EXC-013's baseline was 1157 passed / 0 failed / 12 skipped (1169 total). This run is 1159 passed / 8 failed / 2 skipped (1169 total) — the same 10 tests that stopped skipping (4 Exchange integration tests + 6 diagram-identity tests) split into 4 genuine new passes and 6 genuine newly-exposed failures, while 2 unrelated tests flaked this run only (confirmed passing in isolation both times).

PUBLISHER PORTAL:
```
$ npm run build -w @oep-exchange/publisher-portal
tsc --noEmit && vite build -> exit 0
```
Unaffected — no Exchange TS file was touched by this WP.

BUILD:
```
$ flutter build windows --debug
Building Windows application...  63.8s
√ Built build\windows\x64\runner\Debug\oep_studio.exe
```
```
$ flutter analyze test/exchange_foundation_install_integration_test.dart tool/sync_foundation_bridge_dll.dart
No issues found!
```

SOURCE CODE CHANGED:
YES — Studio (Dart) test/tooling only:
- `platform/oep_studio/tool/sync_foundation_bridge_dll.dart` (new)
- `platform/oep_studio/test/exchange_foundation_install_integration_test.dart` (failure-classification hardening: FAIL on stale/incompatible bridge, SKIP only on a genuinely absent DLL)
- `platform/oep_studio/oep_foundation_bridge.dll` (refreshed binary content, not architecture)

FOUNDATION SOURCE CHANGED:
NO. No file under `platform/oep_foundation/` was modified. No CMake file (`windows/CMakeLists.txt`, `windows/runner/CMakeLists.txt`, `native/foundation_bridge/CMakeLists.txt`) was modified — all three were inspected, and the existing `POST_BUILD copy_if_different` step already does exactly what it should for its own target directory; this WP added a separate, standalone sync step rather than altering that pipeline.

FILES CHANGED:
- `platform/oep_studio/tool/sync_foundation_bridge_dll.dart` (new)
- `platform/oep_studio/test/exchange_foundation_install_integration_test.dart` (modified)
- `platform/oep_studio/oep_foundation_bridge.dll` (binary content refreshed)
- `services/exchange/docs/tasks/WP-EXC-013A.md` (new)
- `services/exchange/docs/audits/WP-EXC-013A-IMPLEMENTATION-REPORT.md` (this file, new)
- `OEP_PROJECT_STATUS.md` (Exchange section — see below)
- `docs/project/OEP_RELEASE_HISTORY.md` (new entry — see below)

ARCHITECTURAL IMPACT:
None. No Foundation installer, trust, package-format, or FFI-binding architecture changed. `ExchangeInstallBridge`/`applyFoundationInstall` (WP-EXC-013) are untouched. The one new file (`tool/sync_foundation_bridge_dll.dart`) is a standalone build/test-support script with no runtime dependency from any production code path.

REMAINING GAPS:
- **A pre-existing, unrelated test-file bug was exposed, not fixed, by this WP**: `test/core/foundation/foundation_bridge_diagram_identity_test.dart` (AP-OEP-FOUNDATION-BRIDGE-002, 6 tests) never writes `repository.json` before calling `openRepository`, so all 6 now fail against the genuinely-working DLL this WP produced, instead of silently skipping against the previously-broken one. This is why STATUS is COMPLETE WITH CONDITIONS rather than unconditionally COMPLETE — literally, "existing Studio tests remain passing" is not 100% true after this WP, though the cause is a latent defect this WP's own correctness improvement surfaced, not introduced. Flagged as follow-up task `task_5a989f91`; fixing it (adding the same `repository.json`-writing helper WP-EXC-013's own integration test already uses) is a small, mechanical, out-of-scope change for a different work package's test file.
- The DLL sync step (`tool/sync_foundation_bridge_dll.dart`) is manual — a developer or CI job must run it after `flutter build windows`. It is not wired into `flutter test` itself; this repository's Dart test tooling has no pre-test-run hook, and adding one would exceed this WP's scope.
- No CI pipeline exists in this repository to run any of this automatically (confirmed: no `.github/workflows/` at the repository root; only vendored third-party workflow files inside dependency source trees). Building one is explicitly out of scope; documented in `docs/tasks/WP-EXC-013A.md` §9 for whoever adds one.
- The DLL-tracking policy (§"Tracking decision") is resolved pragmatically for this WP, not declared a permanent repository-wide policy.

WP-EXC-014:
READY WITH CONDITIONS. The bridge (WP-EXC-013) and its now-reproducible real-Foundation test gate (WP-EXC-013A) are both solid foundations for WP-EXC-014's full end-to-end scenario test. The one condition: whoever picks up WP-EXC-014 should be aware of, and ideally see resolved first, the `foundation_bridge_diagram_identity_test.dart` gap above if their own end-to-end scenario touches diagram-identity functionality — it does not affect the install-bridge path itself.

NEXT WORK:
WP-EXC-014 — Exchange RC1 End-to-End Verification

PUSHED:
NO
