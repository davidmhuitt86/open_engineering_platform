# WP-EXC-013 — Exchange → Repository Install Bridge
## Implementation Report

STATUS:
COMPLETE

COMMIT:
`e1211c4799ce16a17a7ebb0b69c2661d674c9196` — "WP-EXC-013: connect Exchange to Foundation installer" (single dedicated commit, per §28 of the task).

PUSHED:
NO — LOCAL / NOT PUSHED.

FOUNDATION SOURCE CHANGED:
NO. Zero files under `platform/oep_foundation/` were modified. The existing, frozen `oep_package_install` C API and `FoundationRuntime::install_package` C++ implementation were reused entirely as-is.

EXCHANGE SOURCE CHANGED:
Studio (Dart) only. No file under `services/exchange/` (TypeScript) was modified — the checksum header this bridge relies on already existed in `apps/exchange-api`'s download route and required no backend change.

FILES CREATED:
- `platform/oep_studio/lib/exchange/services/exchange_install_bridge.dart`
- `platform/oep_studio/test/exchange_install_bridge_test.dart`
- `platform/oep_studio/test/exchange_runtime_install_bridge_orchestration_test.dart`
- `platform/oep_studio/test/exchange_foundation_install_integration_test.dart`
- `platform/oep_studio/test/fixtures/oep_package_fixture.dart`
- `services/exchange/docs/tasks/WP-EXC-013.md`
- `services/exchange/docs/audits/WP-EXC-013-IMPLEMENTATION-REPORT.md` (this file)

FILES MODIFIED:
- `platform/oep_studio/lib/exchange/models/installation.dart` (added `copyWith`)
- `platform/oep_studio/lib/exchange/services/exchange_api_client.dart` (added `DownloadedArtifact` + `downloadArtifact()`; existing `downloadBytes()` left unchanged for its existing caller)
- `platform/oep_studio/lib/exchange/services/exchange_runtime_service.dart` (`installPackage` now calls the new `_installIntoFoundation` step; no signature change)
- `platform/oep_studio/test/exchange_api_client_test.dart` (3 new tests for `downloadArtifact`)
- `OEP_PROJECT_STATUS.md` (see below)
- `docs/project/OEP_RELEASE_HISTORY.md` (new entry — see below)

CHECKSUM RESULT:
Exchange's existing `X-Checksum-Sha256` download-response header (already sent by `apps/exchange-api`'s `sendArtifact`, never previously read by Studio) is now read by `ExchangeApiClient.downloadArtifact` and verified by `ExchangeInstallBridge` via SHA-256 (`package:crypto`, already a dependency) before any Foundation call. A mismatch is rejected with category `checksumMismatch` and the installer is never invoked — proven both with a fake installer (`exchange_install_bridge_test.dart`) and against the real Foundation runtime (`exchange_foundation_install_integration_test.dart`).

TRUST RESULT:
Foundation's real Ed25519 trust verification runs unmodified inside `install_package`. The WP-EXC-013 fixture is unsigned and accepted under the default (non-signature-required) trust policy — proven by the real-runtime integration test's successful install. Rejection paths (`Tampered`, `InvalidSignature`, unknown publisher, signature-required policy) are proven against a fake installer using Foundation's own exact error-message substrings (read from `foundation_runtime.cpp`), since provoking those specific rejections against the real runtime would require a signed/tampered fixture and a configured trust store beyond this bridge's own scope to construct.

INSTALL RESULT:
`PackageInstallResult` (existing type) is returned on success: `packageId`, `version`, `objectsCreated`, `relationshipsCreated` — all Foundation's own values, not fabricated. `Installation.repositoryPackageId` is set to `'${result.packageId}@${result.version}'`, i.e. Foundation's identity, not Exchange's catalog identity and not the old stub's `stub-{packageId}@{version}`.

ERROR TESTS:
All required categories (`CHECKSUM_MISMATCH`, `TRUST_FAILURE`, `INSTALL_FAILURE`, `ALREADY_INSTALLED`) are distinguished and tested — see `exchange_install_bridge_test.dart`'s classification group (6 tests) and the real-runtime already-installed/corrupt/checksum tests in `exchange_foundation_install_integration_test.dart`.

STUDIO RESULT:
No new Studio surface, no SurfaceRegistry/StudioRegistry/WorkspaceTabsController change. `ExchangeRuntimeNotifier.installPackage`'s outward contract (parameters, `Installation` shape, `PlatformEventBus` operation events) is unchanged; only what determines the final `Installation.status`/`.errorMessage`/`.repositoryPackageId` changed, from Exchange's simulated value to Foundation's real one. `exchange_package_detail_panel.dart` required zero changes — it already read those same fields.

TEST RESULTS:

Bridge unit tests (fake installer):
```
$ flutter test test/exchange_install_bridge_test.dart
00:00 +10: All tests passed!
```

Orchestration tests (fake download + fake installer):
```
$ flutter test test/exchange_runtime_install_bridge_orchestration_test.dart
00:00 +5: All tests passed!
```

Real-Foundation integration tests (`oep_foundation_bridge.dll`):
```
$ flutter test test/exchange_foundation_install_integration_test.dart
00:00 +4: All tests skipped.   # against the checked-in (stale) DLL — see REMAINING GAPS
```
Verified once locally by temporarily swapping in the current build (`build/windows/x64/runner/Debug/oep_foundation_bridge.dll`) in place of the stale checked-in copy, then reverting (working tree confirmed clean afterward, `git status` shows no diff on that binary):
```
00:00 +4: All tests passed!
```
All 4 tests — valid install (with real object/relationship counts read back via `getObjectCount()`/`getRelationshipCount()`), checksum-mismatch rejection, corrupt-archive rejection, duplicate-install detection — passed against the genuine, unmodified Foundation runtime. This is the proof the task required: the package did not merely get marked "installed" by Exchange — it reached Foundation's real installer, and Foundation's own object/relationship counts and Repository Registry confirm it.

`exchange_api_client_test.dart` (includes 3 new `downloadArtifact` tests):
```
00:00 +11: All tests passed!
```

Full Studio suite (regression check):
```
$ flutter test
+1157 ~12: All tests passed!
```
0 failures. 12 skipped: the 4 real-Foundation tests above (stale checked-in DLL) plus 8 pre-existing, unrelated skips.

BUILD RESULTS:

Studio analyzer (WP-EXC-013 files):
```
$ flutter analyze lib/exchange test/exchange_install_bridge_test.dart test/exchange_runtime_install_bridge_orchestration_test.dart test/exchange_foundation_install_integration_test.dart test/fixtures test/exchange_api_client_test.dart
No issues found!
```

Exchange root build (no Exchange TS source touched, verified for regressions):
```
$ npm run build
tsc -b                                                              -> exit 0
@oep-exchange/publisher-portal build (tsc --noEmit && vite build)   -> exit 0
@oep-exchange/exchange-admin build (tsc --noEmit && vite build)     -> exit 0
```

Exchange root test suite (regression check):
```
$ npm test
Test Files  69 passed | 17 skipped (86)
     Tests  319 passed | 124 skipped (443)
```
Identical to WP-EXC-012's own baseline — zero regressions from this WP (no Exchange TS file was touched).

SECURITY RESULT:
No TLS/signature-verification bypass; no accepted checksum mismatch (rejected before the installer is ever called); no credential/private-key logging (the bridge never touches credentials); no path traversal (the temp archive's file name is sanitized to `[A-Za-z0-9._-]`, and Foundation's own extractor — unmodified — governs where package contents land); extraction happens only inside Foundation's existing, already-reviewed installer, never re-implemented here. The one identified pre-existing weakness (§14 of the task doc: `apps/exchange-api`'s `HttpRepositoryClient` targets a nonexistent endpoint) was documented, not touched or "fixed" by weakening anything.

ARCHITECTURAL IMPACT:
None beyond the one intended addition. `ExchangeInstallBridge` is a new Studio-side class with a single responsibility (checksum + installer invocation + error classification); it introduces no new persistence, no new repository semantics, no new database entity, and no new Exchange API endpoint. The dependency chain matches WP-EXC-013 §22 exactly (Studio Exchange Surface → Exchange Client/Install Service → Exchange Download/Verification → Foundation Installer → OEP Repository → Engineering Object), with no custom Exchange repository/installer layer inserted before Foundation.

REMAINING GAPS:
- The `oep_foundation_bridge.dll` checked into `platform/oep_studio/` (root) is stale relative to the current build under `build/windows/x64/runner/Debug/` (missing symbols the current `oep_api.h` declares, confirmed by a `Failed to lookup symbol 'oep_runtime_get_state'` FFI error). Refreshing that checked-in binary artifact is out of this WP's scope — it is a pre-existing, unrelated tracked file, and this WP's git discipline (§28) requires excluding unrelated working-tree changes, not adding new ones. `exchange_foundation_install_integration_test.dart` therefore skips (does not fail) against that stale copy, and this report documents — rather than fabricates — that its genuine pass was verified through a temporary, reverted local swap.
- Foundation's own granular trust-rejection states (`Tampered`, `InvalidSignature`, `UnknownPublisher`, `ExpiredCertificate`, `RevokedCertificate`) are proven via a fake installer using Foundation's exact message substrings, not via a real signed/tampered fixture against a configured trust store — constructing valid and invalid Ed25519-signed test fixtures was judged out of this WP's minimal-bridge scope; Foundation's own (unmodified) trust-verification test suite already covers that logic directly.
- No dependency-resolution scenario was exercised (the fixture declares no dependencies) — out of scope per §23.

WP-EXC-014 READINESS:
READY WITH CONDITIONS. The bridge itself is proven against the real Foundation runtime (once the checked-in DLL artifact is refreshed by whatever process owns that build step). WP-EXC-014's own full end-to-end scenario test can build directly on `ExchangeInstallBridge`/`applyFoundationInstall` and the fixture in `test/fixtures/oep_package_fixture.dart` without needing to re-derive any of this WP's checksum/trust/error-classification work. WP-EXC-014 should refresh (or arrange CI to refresh) the checked-in `oep_foundation_bridge.dll` before relying on `exchange_foundation_install_integration_test.dart` passing rather than skipping.
