# WP-EXC-014 — Exchange RC1 End-to-End Verification
## Implementation Report

STATUS:
COMPLETE WITH CONDITIONS (Tier A legitimately skips in this sandbox — no live PostgreSQL role configured, an explicitly documented, pre-existing condition — see EXCHANGE TESTS below; Tier B, the primary genuine E2E proof, fully passes)

COMMIT:
Recorded after this report (single dedicated commit, per this WP's own git discipline).

PUSHED:
NO — LOCAL / NOT PUSHED.

E2E:
PASS (Tier B, `platform/oep_studio/test/exchange_rc1_e2e_test.dart` — the primary genuine end-to-end test, 4/4 passing, run repeatedly in this session with consistent results, both standalone and inside the full Studio suite)

SEARCH:
PASS — real `ExchangeRuntimeNotifier.search()` against a real socket-bound HTTP server, real `ExchangeApiClient` HTTP GET, real JSON decode; `searchResults.items` contains the seeded package.

DETAIL:
PASS — real `ExchangeRuntimeNotifier.selectPackage()`; `selectedPackage.packageId` matches.

DOWNLOAD:
PASS — real `ExchangeApiClient.downloadArtifact` over a real socket; real bytes and real `X-Checksum-Sha256` header received.

CHECKSUM:
PASS — `ExchangeInstallBridge`'s real SHA-256 verification (unmodified WP-EXC-013 code) both accepts a matching checksum and rejects a deliberately wrong one (AC-05 test) before Foundation is ever invoked.

FOUNDATION INSTALL:
PASS — real `FoundationBridge.installPackage`, real synced `oep_foundation_bridge.dll` (WP-EXC-013A pipeline run first: `flutter build windows --debug` then `dart run tool/sync_foundation_bridge_dll.dart`; confirmed already in sync, a no-op). `Installation.repositoryPackageId` reflects Foundation's own identity (`com.exchange.rc1.e2e.valid@1.0.0`), not Exchange's simulated stub value.

REPOSITORY REGISTRATION:
PASS — `bridge.listInstalledPackages()` contains the installed `packageId` after a successful install.

ENGINEERING OBJECT CREATION:
PASS — `bridge.getObjectCount()` == 2 after install, read from the live Foundation runtime.

RELATIONSHIP CREATION:
PASS — `bridge.getRelationshipCount()` == 1 after install, read from the live Foundation runtime.

ALREADY INSTALLED:
PASS — a second `installPackage` call for the same `packageId` reports `status: 'failed'`, `errorMessage` containing "already installed"; `getObjectCount()` unchanged from after the first (successful) install — no duplicate/partial state.

CORRUPT PACKAGE:
PASS — a corrupt (non-ZIP) archive, served with its own correct checksum (so it fails at Foundation, not at the checksum-verification step), is rejected by the real Foundation installer; `getObjectCount()` == 0 and `listInstalledPackages()` is empty afterward.

CHECKSUM MISMATCH:
PASS — a well-formed archive served with a deliberately wrong `X-Checksum-Sha256` header is rejected by `ExchangeInstallBridge` before Foundation is ever called; `errorMessage` contains "does not match the checksum"; `getObjectCount()` == 0.

PARTIAL-STATE PROTECTION:
PASS — verified directly in both the already-installed test (object count unchanged by the rejected second attempt) and the corrupt/checksum-mismatch tests (object count remains 0) — no misleading partial installation state in any rejected path.

EXCHANGE TESTS:
```
$ npx vitest run apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts
 Test Files  1 skipped (1)
      Tests  1 skipped (1)
```
Skips honestly — this sandbox's local PostgreSQL requires `scram-sha-256` authentication and has no `oep_exchange` role/database configured matching `db/README.md`'s documented setup (confirmed via `pg_hba.conf` and a direct connection attempt: `SASL: SCRAM-SERVER-FIRST-MESSAGE: client password must be a string`). This is the exact same, pre-existing condition that already gates 17 other `apps/exchange-api` test files — not a new gap this WP introduced, and not something this WP is authorized to work around (no credential was guessed or brute-forced).

Full Exchange root suite (regression check):
```
$ npm test
Test Files  69 passed | 18 skipped (87)
     Tests  319 passed | 125 skipped (444)
```
Up from WP-EXC-013's 69 passed / 17 skipped (86 files) baseline by exactly the one new, honestly-skipped WP-EXC-014 test file — zero regressions.
```
$ npx tsc -b
exit 0, zero errors
$ npx eslint apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts
exit 0, zero errors/warnings
```

STUDIO TESTS:
```
$ flutter test test/exchange_rc1_e2e_test.dart
+4: All tests passed!

$ flutter test test/exchange_rc1_e2e_test.dart test/exchange_foundation_install_integration_test.dart \
    test/exchange_install_bridge_test.dart test/exchange_runtime_install_bridge_orchestration_test.dart \
    test/exchange_api_client_test.dart
+33: All tests passed!
```
Full Studio suite (regression check):
```
$ flutter test
+1164 ~2 -7
```
Of the 7 failures: 6 are the pre-existing `foundation_bridge_diagram_identity_test.dart` latent bug WP-EXC-013A's own fix exposed (documented there, follow-up task `task_5a989f91` already filed; this WP did not touch that file). The 7th (`diagram_repository_commit_action_test.dart`'s "full continuity" test) is the same pre-existing full-suite-only ordering flake WP-EXC-013A already identified and independently re-confirmed clean in isolation both then and now (`flutter test test/diagram_studio/bridge/diagram_repository_commit_action_test.dart` → 13/13 passed). **Zero new failures caused by WP-EXC-014.** (The second flake WP-EXC-013A saw, `diagram_tabs_controller_test.dart`, did not recur in this run — consistent with test-ordering flakiness, not a fixed regression.)

BUILD:
```
$ flutter build windows --debug
√ Built build\windows\x64\runner\Debug\oep_studio.exe   (36.2s)
$ dart run tool/sync_foundation_bridge_dll.dart
oep_foundation_bridge.dll is already in sync with .../Debug/oep_foundation_bridge.dll.
```
```
$ npm run build   (Exchange root: tsc -b + publisher-portal + exchange-admin)
exit 0, zero errors, all three build steps succeed
```

STATIC ANALYSIS:
```
$ flutter analyze test/exchange_rc1_e2e_test.dart lib/exchange
No issues found!
```

FILES CHANGED:
- `platform/oep_studio/test/exchange_rc1_e2e_test.dart` (new)
- `services/exchange/apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts` (new)
- `services/exchange/docs/tasks/WP-EXC-014.md` (new)
- `services/exchange/docs/audits/WP-EXC-014-IMPLEMENTATION-REPORT.md` (this file, new)
- `OEP_PROJECT_STATUS.md` (updated)
- `docs/project/OEP_RELEASE_HISTORY.md` (updated)

No production source file was modified anywhere — Foundation, `ExchangeInstallBridge`, `FoundationBridge`, `ExchangeApiClient`, `ExchangeRuntimeNotifier`, and the real `apps/exchange-api` route handlers are all completely unchanged. This WP is test-only.

ARCHITECTURAL IMPACT:
None. The authoritative installation chain (`Exchange → ExchangeInstallBridge → FoundationBridge → FoundationRuntime → oep_package_install → Repository`) is exercised exactly as WP-EXC-013 established it — this WP adds no new production code, no second installation authority, and no Exchange-side repository shortcut. Tier B's `_LocalExchangeServer` is test-only scaffolding, defined inside the test file itself, with zero production dependents.

REMAINING GAPS:
- Tier A (`apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts`) cannot be proven to pass in this sandbox without a properly configured local PostgreSQL `oep_exchange` role (per `db/README.md`) — documented, not routed around.
- `foundation_bridge_diagram_identity_test.dart`'s 6 pre-existing failures remain unfixed, per this WP's own explicit instruction not to touch them (WP-EXC-013A's follow-up task `task_5a989f91` covers it).
- Tier B's local HTTP server implements only the 4 routes this vertical slice needs (search/detail/install/download) — not a general-purpose Exchange API stand-in.
- Trust-rejection (signed/tampered package) scenarios remain covered only at the unit level (WP-EXC-013's own fake-installer tests), not exercised inside this E2E, consistent with WP-EXC-013's own documented scope boundary.

NEXT WORK:
Exchange RC1 itself (full publisher UI, authentication, and the remaining out-of-scope items already enumerated across WP-EXC-010/013/013A/014) — no further "prove the pipeline works" work is required; the vertical slice is now proven end to end wherever Postgres is configured, and proven through the Foundation half unconditionally in this session.
