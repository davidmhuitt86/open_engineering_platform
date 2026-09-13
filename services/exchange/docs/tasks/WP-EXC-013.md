# WP-EXC-013

Title:
Exchange → Repository Install Bridge

Status:
Complete (bridge scope only — see §13 for what is deliberately not included)

Milestone:
The single connection point identified by the WP-EXC-010 Scope & Architecture Readiness Audit as the smallest complete step toward Exchange RC1: `Exchange package → download → checksum verification → Foundation package installation → Repository registration → Engineering Object creation → verified installed package`.

Dependencies:

- WP-EXC-010 (Scope & Architecture Readiness Audit — identified this exact gap: Exchange's install action never reached Foundation)
- Foundation's Public C API package-install surface (`oep_package_install`, frozen by WP-REP-001) and Trust & Signing subsystem (WP-REP-004)
- The pre-existing Dart FFI path `OepApiBindings` → `FoundationBridge`, already used by `platform/oep_studio/lib/features/packages/package_manager_page.dart` for manual local-file installs
- `apps/exchange-api`'s existing download route (`X-Checksum-Sha256` response header, already sent, previously unread by Studio)

---

# 1. Objective

Connect Exchange's existing Studio install action to Foundation's existing, authoritative `oep_package_install` installer — nothing more. Not Exchange RC1, not WP-EXC-014 (end-to-end scenario test), not WP-EXC-015, not publisher UI, not dependency resolution, not uninstall, not authentication.

# 2. Architecture

Foundation remains authoritative for installation: trust verification, extraction, transactional Engineering Object/Relationship creation, and Repository Registry registration all happen inside `FoundationRuntime::install_package` (C++, unmodified). Exchange's own responsibility stops at discovery, metadata, download, and checksum verification. The dependency chain this WP establishes:

```
Studio Exchange Surface (ExchangeStudioPage, unchanged)
  -> ExchangeRuntimeNotifier.installPackage (existing method, corrected)
    -> ExchangeApiClient.downloadArtifact (new method, existing client class)
    -> ExchangeInstallBridge (new, Studio-side, no new architecture)
      -> FoundationBridge.installPackage (existing FFI method, unchanged)
        -> oep_package_install (existing C API, unchanged)
          -> FoundationRuntime::install_package (existing C++, unchanged)
            -> Repository Registry + ObjectStore/RelationshipStore (existing, unchanged)
```

No new Exchange-side repository implementation, no new Foundation source, no new FFI binding.

# 3. Existing Foundation installer authority

`oep_package_install(OEP_Runtime, archive_path, out_result)` (declared `platform/oep_foundation/platform/api/include/oep/api/oep_api.h`, implemented `platform/oep_foundation/platform/api/src/oep_api.cpp:2344`) delegates directly to `FoundationRuntime::install_package`, which (in order): extracts the archive, checks the Repository Registry for an existing record of the same `packageId` (already-installed short-circuit), runs Ed25519 trust verification (`package_verifier`), resolves manifest-declared dependencies against the already-installed set, then transactionally creates Engineering Objects and Relationships and writes a Repository Registry entry. This surface is frozen (WP-REP-001) and was not modified.

Only reads uncompressed ("Stored") ZIP entries — DEFLATE-compressed archives fail with `OEP_ERROR_OPERATION_FAILED`. This governs §9's fixture format.

# 4. Existing Exchange install flow (before this WP)

`ExchangeRuntimeNotifier.installPackage` (`platform/oep_studio/lib/exchange/services/exchange_runtime_service.dart`) called Exchange's own `POST /installations` (`ExchangeApiClient.install`) and trusted whatever `Installation.status` that endpoint returned. That endpoint's own backend (`apps/exchange-api`) defaulted to a `StubRepositoryClient` that fabricates `stub-{packageId}@{version}` and never touches a real repository; its alternative, `HttpRepositoryClient`, targets `${baseUrl}/api/v1/packages/install`, an endpoint that has never existed (Foundation has no HTTP server). Either way, "installed" was never proven — only recorded.

# 5. Bridge design

`ExchangeInstallBridge` (`platform/oep_studio/lib/exchange/services/exchange_install_bridge.dart`) is the one new class. It takes an injected `PackageInstaller` (`PackageInstallResult Function(String archivePath)` — production code passes `FoundationBridge.installPackage`) and:

1. Verifies the downloaded bytes' SHA-256 against the checksum Exchange's download response reported.
2. Writes the verified bytes to a temporary `.oep` file (Foundation's installer takes a filesystem path).
3. Calls the injected installer and classifies whatever it reports.
4. Always deletes the temporary file/directory afterward, regardless of outcome.

`applyFoundationInstall` (same file) is the standalone orchestration function `ExchangeRuntimeNotifier._installIntoFoundation` delegates to — it is what is unit-tested with fakes, not the notifier itself, since the notifier's real dependency (`FoundationRuntimeNotifier.bridge`) is a concrete FFI-backed class with no existing test seam.

# 6. Checksum model

Exchange's download route (`apps/exchange-api/src/routes/download.ts`'s `sendArtifact`) already sends an `X-Checksum-Sha256` header on every download response — this was never read by Studio. `ExchangeApiClient.downloadArtifact` (new method) reads it and throws if absent, so a missing checksum is a hard failure rather than a silently skipped check. No new Exchange API endpoint or contract change was needed. `ExchangeInstallBridge` computes SHA-256 over the downloaded bytes using `package:crypto` (already a dependency) and rejects a mismatch before ever calling the installer.

# 7. Trust model

Foundation's Ed25519 trust verification is invoked exactly as-is, inside `install_package`, before any transaction begins. The fixture built for this WP (§9) is unsigned (`"signatures":{}`), which Foundation's default trust policy accepts (`TrustState.Unsigned`); a repository with `oep_trust_set_policy(require_signatures=true)` would reject it — this WP does not change or duplicate that policy decision. Nothing simulates or bypasses trust verification at the Exchange layer.

# 8. Error model

Foundation's C API reports only 6 generic `oep_error_code_t` values and 4 categories — no granular per-condition codes exist for "already installed" vs. "trust rejected" vs. "corrupt". `ExchangeInstallBridge._classify` pattern-matches the exact literal substrings `FoundationRuntime::install_package` produces (read directly from `foundation_runtime.cpp`, not guessed) against `FoundationBridgeException.technicalDetail`:

| Substring matched | Category |
|---|---|
| `"is already installed"` | `alreadyInstalled` |
| `"could not verify package trust"`, `"package trust verification failed"`, `"trust policy requires signed packages"` | `trustFailure` |
| (checksum computed by the bridge itself, before any Foundation call) | `checksumMismatch` |
| anything else Foundation reports | `installFailure` |

`diagnosticMessage` always preserves Foundation's own specific text (`technicalDetail`, never the generic curated `.message`), so a caller never loses information the categorization collapses.

# 9. Package fixture

One hand-built Stored-ZIP `.oep` fixture, built as Dart source (not a checked-in binary) at `platform/oep_studio/test/fixtures/oep_package_fixture.dart`, ported field-for-field from Foundation's own test fixture builder (`platform/oep_foundation/tests/runtime/package_installation_tests.cpp`'s `build_stored_zip`/`manifest_for`/`build_demo_archive`) — not invented. Contains `manifest/package.json` (all 16 required fields), two Engineering Objects, and one Relationship between them. `buildCorruptOepPackage()` produces a deliberately non-ZIP byte sequence for the corrupt-archive test. Being source rather than a binary blob makes "how it was produced" self-evident and keeps no binary in git history.

# 10. Studio integration

`ExchangeRuntimeNotifier.installPackage` (existing method) is unchanged in its outward shape: it still calls Exchange's own `POST /installations` first (for Exchange-side bookkeeping the Library page's "Refresh status" relies on), then — unless that record already failed outright — calls the new `_installIntoFoundation` step, which downloads the real artifact, verifies it, and installs it through `ExchangeInstallBridge`. The `Installation` object written into My Library and `state.selectedPackageInstallation` now reflects Foundation's real outcome (its own `packageId@version` identity on success, or its own diagnostic text on failure) rather than Exchange's simulated one. No widget changed: `exchange_package_detail_panel.dart`'s "Open Installed Package" gating already read `installation.isCompleted`/`.errorMessage`/`.repositoryPackageId` directly. No new UX framework, no new Studio surface, no SurfaceRegistry/StudioRegistry change.

# 11. Tests

- `test/exchange_install_bridge_test.dart` (10 tests): checksum verification (mismatch rejected before installer call, case-insensitive comparison), temp-file lifecycle (written then removed on success and on throw), and all 6 error-classification substrings.
- `test/exchange_runtime_install_bridge_orchestration_test.dart` (5 tests): `applyFoundationInstall` directly — no-repository-open, genuine success (Foundation's identity, not Exchange's stub), checksum mismatch, already-installed, trust rejection — all with plain fakes, no Riverpod container, no native runtime.
- `test/exchange_foundation_install_integration_test.dart` (4 tests): the real, unmodified Foundation runtime, loaded through the real `oep_foundation_bridge.dll`, exercised through `ExchangeInstallBridge` with the real fixture from §9 — valid install (asserting real object/relationship counts read back from Foundation), checksum-mismatch rejection, corrupt-archive rejection, and duplicate-install detection. See §16/the implementation report for this environment's DLL-freshness caveat: these tests skip (not fail) rather than fabricate a pass when the checked-in `oep_foundation_bridge.dll` is stale.
- `test/exchange_api_client_test.dart`: 3 new tests for `downloadArtifact` (bytes + checksum header returned; versioned route; missing-header failure).

Foundation's own `tests/runtime/package_installation_tests.cpp` suite (unmodified) is the authority for the installer's own correctness; this WP's tests prove only that the bridge invokes that real path correctly, per §15 of the task specification.

# 12. Package identity

Exchange's own catalog `packageId`/`version` (from `/packages/{id}`, `/search`) are distinct from Foundation's Repository Registry identity (`PackageInstallResult.packageId`/`.version`, read from the installed manifest) — they are expected to carry equal values for a well-formed package, but the bridge never assumes this: on success, `Installation.repositoryPackageId` is built from Foundation's own returned identity, not from Exchange's request parameters. No new database entity was created to track this relationship; none was needed, since `Installation.repositoryPackageId` (an existing field) already provides the mapping point.

# 13. Out of scope

WP-EXC-014 (full end-to-end scenario test), WP-EXC-015, RC1 publisher UI, exchange-admin, authentication, licensing/payments, reviews/ratings, dependency resolution UX, update/uninstall flows, monetization, recommendation/ranking, any new Repository semantics, any new Foundation installer or trust architecture, any new package format, any new OEP application shell, Diagram Studio redesign.

# 14. Known limitations / exit criteria

- The `oep_foundation_bridge.dll` checked into `platform/oep_studio/` (root) is a stale build (missing symbols current `oep_api.h` declares) relative to the fresh build under `build/windows/x64/runner/Debug/`. This WP did not refresh that checked-in binary artifact — it is unrelated, pre-existing, and out of this WP's scope to touch — so `test/exchange_foundation_install_integration_test.dart` skips honestly rather than failing in an environment where only the stale copy is present. It was verified once, locally, by temporarily swapping in the fresh build (then reverting), and all 4 tests passed genuinely against the real Foundation runtime — see the implementation report.
- Exit criteria met: real installer reused (no duplicate), real artifact downloaded, checksum verified before install, real trust verification invoked (not bypassed), successful install reaches Foundation's Repository Registry and ObjectStore/RelationshipStore, corrupt/checksum-mismatch/trust-failure/already-installed behaviors distinguished and tested, one valid fixture, all new/changed tests passing, Exchange root build/typecheck passing, publisher-portal build/tests passing, zero Foundation source changes, zero new repository implementations, one dedicated commit, nothing pushed.
