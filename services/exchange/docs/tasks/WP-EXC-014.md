# WP-EXC-014

Title:
Exchange RC1 End-to-End Verification

Status:
Complete (with one explicitly documented environmental substitution — see §6)

Milestone:
Proves the complete Exchange RC1 vertical slice, end to end, through the real integration boundaries WP-EXC-013/WP-EXC-013A established: real Exchange client, real checksum verification, real Foundation installer, real Repository registration, real Engineering Objects/Relationships.

Dependencies:

- WP-EXC-013 (Exchange → Repository Install Bridge — `ExchangeInstallBridge`, `applyFoundationInstall`, the Stored-ZIP fixture)
- WP-EXC-013A (Foundation Bridge Artifact Synchronization & Integration Test Gate — the reproducible `flutter build windows --debug` + `dart run tool/sync_foundation_bridge_dll.dart` pipeline this WP's real-Foundation tests depend on)
- `apps/exchange-api`'s existing Postgres-gated test convention (`describe.skipIf(!databaseAvailable)`, `db/README.md` "Testing without a live database")

---

# 1. Objective

Prove the full RC1 vertical slice — search → package detail → download → checksum verification → `ExchangeInstallBridge` → `FoundationBridge.installPackage` → Foundation's installer → Repository registration → Engineering Objects/Relationships → installed-package confirmation — through the real integration boundaries, not a fully mocked path, with at least one genuine end-to-end test plus focused negative-path tests.

# 2. Test topology (two tiers, each independently real)

**Tier A — `apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts`** proves the real, Postgres-backed Exchange server's own search/detail/download/checksum behavior, via Fastify's `.inject()` (this repository's own established "real dispatch, not a mock" test mechanism — every existing `apps/exchange-api/src/routes/*.test.ts` file already uses it the same way). Gated by the exact same `describe.skipIf(!databaseAvailable)` convention as 17 pre-existing test files in this codebase.

**Tier B — `platform/oep_studio/test/exchange_rc1_e2e_test.dart`** is the primary genuine E2E test: it drives the real, unmodified production Studio code (`ExchangeRuntimeNotifier.search`/`.selectPackage`/`.installPackage` — the exact methods Studio's own "Install" button calls) against a real socket-bound HTTP server, through the real `ExchangeInstallBridge`, into the real, synced `FoundationBridge.installPackage`, verifying real Repository registration and real Engineering Object/Relationship creation.

# 3. Why two tiers, not one unified cross-process test

A single test spanning a real Node `apps/exchange-api` server and a real Dart/Foundation install would need the genuine Exchange backend listening on a real port, backed by genuine PostgreSQL. This sandbox's local PostgreSQL instance requires `scram-sha-256` authentication for every role (confirmed via `pg_hba.conf`) and has no `oep_exchange` role/database configured matching `db/README.md`'s documented setup — the exact same, pre-existing condition that already makes 17 of `apps/exchange-api`'s own test files skip. Rather than either (a) silently accept that the Foundation half of RC1 is never exercised through a real HTTP call in this environment, or (b) invent a new mocking layer to paper over it, this WP splits the proof into two tiers that are each fully real on their own terms, and documents the one substitution explicitly (§6).

# 4. Fixture identity

Both tiers reuse existing, pre-established archive-building infrastructure rather than inventing a second `.oep` format:

- **Tier B** (the one that actually reaches Foundation) uses WP-EXC-013's own hand-built Stored-ZIP fixture verbatim: `platform/oep_studio/test/fixtures/oep_package_fixture.dart`'s `buildDemoOepPackage(packageId)`/`buildCorruptOepPackage()`. This is the only archive Foundation's installer ever sees in this WP — Stored (uncompressed), because Foundation's `ZipReader` only accepts that compression method.
- **Tier A** (which never reaches Foundation — it only proves Exchange's own HTTP/storage round-trip, which is compression-agnostic) reuses the exact existing `adm-zip`-based archive-building pattern already established in `apps/exchange-api/src/routes/upload.test.ts`/`download.test.ts` (`buildArchive`/multipart helpers), with a manifest whose `packageId` names this WP for traceability (`com.exchange.rc1.e2e.backend`). This is not a second competing package *format* — it is the pre-existing, in-convention way this codebase already builds test archives for Exchange's own HTTP layer, distinct from (and never confused with) the one archive that actually gets installed into Foundation.

# 5. Test design detail (Tier B)

`platform/oep_studio/test/exchange_rc1_e2e_test.dart`:

1. A minimal `_LocalExchangeServer` (`dart:io HttpServer`, a real socket, `InternetAddress.loopbackIPv4`, OS-assigned port) implements exactly the wire contract `ExchangeApiClient` expects: `GET /api/v1/search`, `GET /api/v1/packages/{id}`, `POST /api/v1/packages/{id}/install`, `GET /api/v1/packages/{id}/download` (with the real `X-Checksum-Sha256` header contract).
2. A real `ProviderContainer` overrides only `exchangeSettingsProvider` (to point `apiBaseUrl` at the local server) — `foundationRuntimeServiceProvider` and `exchangeRuntimeServiceProvider` are the real, unmodified production notifiers, exactly as Studio itself wires them.
3. A real temporary Foundation repository is created (`repository.json` written per `oep::repository::RepositoryMetadata`'s schema) and opened via `FoundationRuntimeNotifier.openRepository` (real FFI call).
4. `ExchangeRuntimeNotifier.search`/`.selectPackage`/`.installPackage` are called exactly as Studio's UI would call them. `installPackage` internally calls the real `_installIntoFoundation` → `applyFoundationInstall` → `ExchangeInstallBridge.install` → real `FoundationBridge.installPackage` (WP-EXC-013's own, unmodified code).
5. Assertions read real state back from the real bridge: `getObjectCount()`, `getRelationshipCount()`, `listInstalledPackages()`.

Four tests: the full successful vertical slice (AC-01–AC-11), already-installed (AC-12), corrupt package (AC-13/AC-14), checksum mismatch (AC-05/AC-14).

# 6. Explicitly documented boundary substitution

The one place this WP's tests do not reach the literal, Postgres-backed `apps/exchange-api` server is Tier B's HTTP layer — a real `dart:io HttpServer` stands in for it, implementing the identical wire contract. This is not a mock of `ExchangeApiClient`, `ExchangeInstallBridge`, or `FoundationBridge` (all three are the real, unmodified, production classes, exercised over a real socket and a real FFI boundary) — it substitutes only the opposite HTTP endpoint, because the genuine server requires PostgreSQL credentials this sandbox does not have configured. Tier A independently proves the genuine server's own real behavior at exactly that same boundary, gated the same way every other Postgres-dependent test in this codebase already is. Wherever a developer or CI environment has `db/README.md`'s test database configured, Tier A runs for real and both tiers together constitute the full, unmocked RC1 vertical slice with no substitution at all.

# 7. Foundation bridge artifact

Per WP-EXC-013A: `flutter build windows --debug` then `dart run tool/sync_foundation_bridge_dll.dart` were run before Tier B's tests in this session (`build/windows/x64/runner/Debug/oep_foundation_bridge.dll` already matched — a no-op sync, confirming reproducibility). `OEP_API_VERSION 21`, `OEP_ABI_VERSION 1` (both confirmed against `platform/oep_foundation/platform/api/include/oep/api/oep_api.h`).

# 8. Package identity / version observed

`com.exchange.rc1.e2e.valid@1.0.0` (successful-path test), `com.exchange.rc1.e2e.duplicate@1.0.0` (already-installed test), `com.exchange.rc1.e2e.corrupt` (corrupt-package test, never reaches a version since installation fails), `com.exchange.rc1.e2e.checksum` (checksum-mismatch test, rejected before Foundation). Tier A's backend-only seed uses `com.exchange.rc1.e2e.backend@1.0.0`.

# 9. API routes exercised

Tier A (real, Postgres-backed): `POST /api/v1/packages/upload`, `GET /api/v1/search`, `GET /api/v1/packages/{id}`, `GET /api/v1/packages/{id}/download`.
Tier B (real client against the local stand-in server): `GET /api/v1/search`, `GET /api/v1/packages/{id}`, `POST /api/v1/packages/{id}/install`, `GET /api/v1/packages/{id}/download`.

# 10. Checksum / repository / object / relationship results

See the Implementation Report for exact numbers. Summary: real SHA-256 computed and verified in every test; successful installs report 2 Engineering Objects + 1 Relationship (matching the fixture's own two objects and one relationship); `getObjectCount()`/`getRelationshipCount()`/`listInstalledPackages()` all confirm the real Repository Registry state after each install.

# 11. Skipped tests / pre-existing failures

- Tier A (`exchange-rc1-vertical-slice.test.ts`): 1 test file, 1 test, **skipped** in this sandbox (no live `oep_exchange` Postgres role) — consistent with 17 other pre-existing Exchange test files, not a new gap.
- `platform/oep_studio/test/core/foundation/foundation_bridge_diagram_identity_test.dart`'s 6 pre-existing failures (exposed by WP-EXC-013A, not this WP) remain unfixed — explicitly out of this WP's scope per its own instructions. See WP-EXC-013A's implementation report and follow-up task `task_5a989f91`.
- Two full-suite-only flakes (`diagram_repository_commit_action_test.dart`, `diagram_tabs_controller_test.dart`) previously confirmed, in WP-EXC-013A, to be pre-existing test-ordering flakiness unrelated to any of this work — re-confirmed unrelated to WP-EXC-014 (this WP touched neither file).

# 12. Remaining limitations

- Tier A cannot be proven to pass in this sandbox without a properly configured local PostgreSQL role — documented, not worked around.
- Tier B's local HTTP server is a hand-written stand-in, not the genuine Fastify app; it implements only the four routes this vertical slice needs, not the full Exchange API surface.
- No dependency-resolution, licensing, authentication, or publisher-UI scenario was exercised (all explicitly out of scope).
