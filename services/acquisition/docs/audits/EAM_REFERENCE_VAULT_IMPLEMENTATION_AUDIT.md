# EAM / Reference Vault — Implementation Audit (WP-017)

Audit date: 2026-09-12. Baseline commit at audit start: `84564de` (monorepo `main`). This document reports what was found by directly reading source, migrations, tests, and governing documents — not by trusting `services/acquisition/README.md`'s own self-description, which this audit independently verified and, in one major respect (§4), found to be **wrong**.

Status vocabulary used throughout: **COMPLETE / PARTIAL / MISSING / DEFERRED / BLOCKED / SUPERSEDED / FUTURE / OUT OF SCOPE**.

---

## 1. Current Architecture

The service (`services/acquisition`, "Engineering Acquisition Manager" / EAM) is a standalone C++23 backend (CMake, `cpp-httplib` embedded HTTP server, `libpqxx`/PostgreSQL persistence, Catch2 tests, Flyway-formatted migrations applied by the app itself). It implements a fixed, nine-stage pipeline mandated by `WORK_PACKAGE_001` through `WORK_PACKAGE_009`:

```
Official Source Registry (WP-002)
  -> Acquisition Job Engine (WP-003) -> Execution Engine (WP-004)
  -> Source Connector Framework (WP-005)
  -> Engineering Downloader (WP-006)
  -> Integrity Verification Engine (WP-007)
  -> Metadata Extraction Engine (WP-008)
  -> Reference Vault (WP-009)
```

Seven ratified SDDs (`SDD-R013` through `SDD-R019`) describe a considerably richer long-term architecture than this Milestone-1 slice implements — see `EAM_REFERENCE_VAULT_GAP_ANALYSIS.md` for the full comparison.

## 2. Actual Implementation Inventory

Verified directly (file listing + code reading, not README claims):

| Category | Finding |
|---|---|
| Services | 8 domain services: `OfficialSourceService`, `AcquisitionJobService`, `ExecutionService`, `ConnectorRegistry`/`ConnectorFactory`, `DownloadService`, `IntegrityVerificationService`, `MetadataExtractionService`, `ReferenceVaultService` |
| Repositories | One `Postgres*Repository` per domain table (7), each behind an `I*Repository` interface; each has an in-memory `Fake*Repository` test double |
| Domain models | `OfficialSource`, `AcquisitionJob`, `Download`, `Verification`, `ArtifactMetadata`, `VaultEntry`, plus `ConnectorConfig`/`AcquisitionRequest`/`AcquisitionResult` (connector framework, no DB backing) |
| REST endpoints | 33 routes across `/health`, `/sources`, `/jobs` (+`/execute`,`/cancel`,`/status`), `/connectors` (+`/capabilities`,`/health`), `/downloads` (+`/status`,`/cancel`), `/verifications` (+`/status`), `/metadata` (+`/status`), `/vault` (+`/status`) — enumerated directly from `src/api/server.cpp`, matches README's documented list exactly |
| Database tables | 7 tables, `V1`–`V8` migrations (`V1` is a placeholder; real schema starts at `V2`). **This audit adds `V9`** — see §11. |
| Filesystem storage | Two configured roots: `[storage] workspace_path` (Downloader's temp workspace) and `[storage] root_path` (Vault's permanent, content-addressed store) — genuinely distinct, confirmed in `common::StorageConfig` and both services' own code |
| Connectors | **Two**, not one — `StubConnector` (no network I/O) **and `HttpConnector`** (real HTTP/HTTPS client). See §4 — this contradicts the README. |
| Command-line applications | One: `oep_acquisition` (`src/app/main.cpp`), the server process itself. No separate CLI tools. |
| External dependencies | spdlog, nlohmann/json, tomlplusplus, cpp-httplib, Catch2, libpqxx, PicoSHA2 — all via CMake `FetchContent`, pinned versions, confirmed in `CMakeLists.txt` |
| Tests | 25 test source files under `tests/`, organized per work package (validation / service / repository / API / migration / support-fixture layers). Full suite actually built and executed (twice, consecutively) against a real local PostgreSQL 18 instance during this audit: **221/221 test cases passed, 981/981 assertions passed, 0 skipped, 0 failed**, both runs — see `EAM_REFERENCE_VAULT_M2_READINESS.md` §Test Results for the full account, including two test-fixture defects (non-idempotent scratch paths across process runs) found and fixed along the way. |
| Fixtures | `tests/*_test_support.{hpp,cpp}` — real Postgres schema bootstrap + real on-disk artifact seeding per pipeline stage, `Fake*Repository` in-memory doubles for pure service-layer tests |

## 3. WP-001 through WP-009 Status

| WP | Title | Status | Evidence |
|---|---|---|---|
| WP-001 | Repository Bootstrap | **COMPLETE** | CMake project, logging, TOML config, `DatabaseConnection` (connection-only), Catch2 harness, `GET /health`, README — all present and match the WP's own (infra-only, no domain model) scope exactly. |
| WP-002 | Official Source Registry | **COMPLETE** | `official_sources` table (V2), full CRUD + soft-delete + filtering REST API, Trust Level/Status/Auth Type constrained-value fields, validation. `enable`/`disable` exist at the Service layer only (no dedicated REST route) — a real, disclosed (in README) minor gap, not a defect. |
| WP-003 | Acquisition Job Engine | **COMPLETE** | `acquisition_jobs` table (V3, real FK to `official_sources`), full CRUD, Job Status enum, Priority. Note (§ Documentation Reconciliation): WP-003's own text never states whether `PUT /jobs/{id}` should enforce transition validity, and it doesn't — this is a genuine, disclosed, pre-existing gap (README's own "Future Considerations"), not something this audit's scope authorizes fixing (retrofitting validation onto `PUT` is a behavior change to an existing, working route with no demonstrated defect driving it). |
| WP-004 | Execution Engine | **COMPLETE** | `acquisition_job_execution_history` table (V4, append-only), `POST /jobs/{id}/execute|cancel`, `GET /jobs/{id}/status`, one-edge-per-call state machine, invalid-transition rejection (409), archived/deleted-source rejection (409). |
| WP-005 | Source Connector Framework | **PARTIAL** (see §4) | Framework itself (`IConnector`, `ConnectorFactory`, `ConnectorRegistry`, read-only REST API) is complete and correctly scoped. **However, the framework's own explicit constraint — "no implementation shall perform actual network communication" — is violated by a second connector type registered in the same running process.** Classifying the *framework* as complete but the *work package's stated invariant* as breached by `HttpConnector`'s presence. |
| WP-006 | Engineering Downloader | **PARTIAL** (see §4) | `download_sessions` table (V5), synchronous `POST /downloads`, full validation chain, progress tracking, cancellation model — all correctly implemented against `StubConnector`. Same caveat as WP-005: `POST /downloads` today can also drive `HttpConnector`, which is real network communication WP-006's own "Do NOT implement: HTTP client" excludes. |
| WP-007 | Integrity Verification Engine | **COMPLETE** | `integrity_verifications` table (V6), synchronous SHA-256 hashing (PicoSHA2), missing/empty/corrupt-file handling recorded as `Failed` (not rejected), re-verification-against-prior-hash semantics, full REST API. |
| WP-008 | Metadata Extraction Engine | **COMPLETE** | `artifact_metadata` table (V7), magic-byte + extension-fallback file type detection (verified list below), PDF version/page-count inspection, unsupported-type-still-succeeds semantics, re-extraction history (new row per call, never overwritten). |
| WP-009 | Reference Vault | **COMPLETE, with one demonstrated defect now fixed** (see §7/§8) | `reference_vault` table (V8), all 7 Validation Rules enforced, content-addressable sharded storage, dedup, immutability (no update/delete route or repository method). The file/DB-insert race identified in §8 has been corrected as part of this audit (see `src/vault/reference_vault_service.cpp`). |

**WP-005/WP-006 PARTIAL disposition**: this is not a claim that the *implemented* functional requirements are incomplete — every functional requirement WP-005/006 actually list is implemented and tested. It is a claim that an explicit **exclusion** ("no real network communication") is not honored by the current state of the codebase, because of a second connector this audit found already present. See ADR-0003.

## 4. Connector Audit

- **Registration**: `ConnectorRegistry`, populated once at process startup from `main.cpp` (no `POST /connectors` — matches WP-005's read-only REST API exactly).
- **Identity**: `connector_id` (string, e.g. `"example-stub"`, `"http-source"`), unique-enforced by `ConnectorRegistry::register_connector` (throws on duplicate id — verified in `connector_registry.cpp`/tests).
- **Capabilities**: `std::set<std::string>`, extensible per WP-005's own requirement; `capability::` namespace provides named constants for convenience only.
- **Health**: `IConnector::health_check()` — for both connectors today, this is **configuration-driven, not a live probe** (`StubConnector` and `HttpConnector` both read a `"health_status"` setting rather than actually testing connectivity). `GET /connectors/{id}/health` surfaces whatever that returns.
- **Fetch contract**: `IConnector::fetch(const AcquisitionRequest&) -> AcquisitionResult` (ADR-0008, per the service's own docs — see the important caveat in §19/Documentation Reconciliation about ADR-0008 itself).
- **Lifecycle**: `connect()`/`disconnect()` toggle an in-memory flag only, for both connector types; neither performs real connection setup/teardown (for `HttpConnector`, `httplib::Client` is actually constructed fresh per `fetch()` call, not held open across `connect()`/`disconnect()`).
- **Real external content acquisition**: **IMPLEMENTED** — `HttpConnector` (see below), not merely `StubConnector`. **This is the single most significant finding of this audit.**

### 4.1 `StubConnector`

Exactly as documented: writes a small deterministic placeholder file locally, no network I/O, fully configurable failure/health/MIME-type behavior for tests. Correctly scoped to WP-005's own constraint.

### 4.2 `HttpConnector` — real, registered, live (contradicts README)

`include/oep/acquisition/connectors/http_connector.hpp` / `src/connectors/http_connector.cpp`: a genuine HTTP/HTTPS client (`cpp-httplib` client mode) that performs real `GET` requests, streams the response to disk, follows redirects, honors `std::stop_token` cancellation, and reports real HTTP status/MIME type/ETag. Registered at startup in `main.cpp` as connector id `http-source`, type `"http"`, **alongside** `example-stub`. Has its own dedicated, real-network test suite (`tests/test_http_connector.cpp`) including a real fetch, a real redirect follow, and a real 404.

This directly contradicts:
- `README.md`'s repeated claim that `StubConnector` is the only connector type and that "no real network communication" occurs.
- WP-005's explicit "No implementation shall perform actual network communication."
- WP-006's explicit "Do NOT implement: HTTP client."

Confirmed via `git log` that this predates WP-017 (introduced by the single squashed monorepo-import commit, `af5c6ec`, 2026-09-04) — **this audit did not introduce it, and did not remove it** (removing already-working, tested functionality is itself an unauthorized architectural action this audit's own scope does not clearly grant — see ADR-0003 for the full disposition and options left for a human decision-maker).

**Required architectural interface for future real connectors**: already satisfied by the existing `IConnector`/`fetch` contract — no new interface is needed for a *third* real connector type (e.g. FTP); `HttpConnector` itself is the proof this interface is sufficient.

## 5. Integrity Verification Audit

- SHA-256 generation: `hash_file_sha256` (PicoSHA2), streaming read, verified via a dedicated unit-test suite including a known test vector and content larger than the streaming buffer.
- File existence/empty/corruption handling: a missing, empty, or unreadable artifact is recorded as a `Failed` Verification (not rejected as invalid input) — confirmed against WP-007's own "Missing files shall fail verification" wording, which is the one WP in the whole corpus that most clearly supports this reading (see the cross-WP analysis in `EAM_REFERENCE_VAULT_GAP_ANALYSIS.md`).
- Repeated verification / history: every `POST /verifications` inserts a row; re-verification compares against the Download Session's own most-recently-`verified` hash (not the full history — a disclosed, WP-007-text-consistent limitation, not a defect).
- Immutable records: no update/delete route exists for `/verifications`; the only two transitions (`Pending`→`Verified`, `Pending`→`Failed`) occur entirely inside `IntegrityVerificationService::verify`, never exposed for external mutation.
- **The verification hash is confirmed to be the authoritative hash used by later stages**: `MetadataExtractionService` copies `sha256_hash`/`file_size_bytes` directly from the Verification record (never re-hashes); `ReferenceVaultService::publish` recomputes the hash fresh immediately before publication and compares it against the Verification record's stored hash (`ArtifactHashMismatchError` on mismatch) — this is the strongest integrity check in the whole pipeline, deliberately placed at the last possible moment before a fact becomes permanent.
- **Race window, Download → Verification**: none found — Verification always reads the artifact fresh from `local_storage_path` at verification time; there is no cached/stale hash consulted here.
- **Race window, Verification → Vault Publication**: none found — `ReferenceVaultService::publish` re-hashes the artifact itself rather than trusting the Verification record's stored hash, closing exactly this window by design (confirmed by direct code reading of `reference_vault_service.cpp`, not merely the README's claim).

## 6. Metadata Extraction Audit

- Supported file types (magic-byte + prefix detection, confirmed against `file_type_detector.cpp`'s own test suite): PDF, ZIP, 7Z, TAR, GZIP, PNG, JPEG (magic bytes); XML, SVG, HTML (content-prefix); JSON, YAML, CSV, TXT, Markdown (extension fallback) — matches WP-008's "at minimum" list exactly, no gaps found.
- Unsupported types: recorded as `Extracted` with type `"Unknown"` / MIME `application/octet-stream` — **not** a failure, matching WP-008's "Unsupported file types shall still produce metadata when possible" and this audit's own instruction not to let unsupported formats block Vault publication. Confirmed: `ReferenceVaultService` gates on `ExtractionStatus::Extracted` (which "Unknown" type still satisfies), not on file-type recognition — so an unrecognized-type artifact **can** still reach the Vault. This is correct per governing text.
- Basic Document Inspection: PDF only (version + best-effort page count via a raw `/Pages`/`/Count` scan of the first 2MB) — matches WP-008's one given example literally; a real limitation for large/non-linearized/compressed-object-stream PDFs, already disclosed in README, not newly found here.
- History: `POST /metadata` always inserts a new row; `GET /metadata?verification_id=...` returns the full history — confirmed by direct code reading (`MetadataExtractionService::extract`, no update path exists).
- Failure semantics: "Verification shall exist"/"shall be successful" → thrown (422/409, request-level); "Artifact shall exist" → recorded as `Failed` (artifact-condition-level) — this bifurcation is a documented *implementation decision* filling a genuine textual gap in WP-008 (see cross-WP analysis), not a defect, and is internally consistent with WP-007's own precedent.

## 7. Reference Vault Audit

All fields from WP-009's Vault Model are present in `reference_vault` (V8) and surfaced by `GET /vault`/`GET /vault/{id}` (`vault_entry_json.cpp`, confirmed to serialize every column). All 7 Validation Rules are enforced, in order, by `ReferenceVaultService::publish` (confirmed by direct code reading, `reference_vault_service.cpp`):

1. `metadata_id` shall exist → `UnknownMetadataError` (422)
2. Metadata extraction shall be successful → `MetadataNotSuccessfulError` (409)
3. Not already published → `AlreadyPublishedError` (409) — checked at the Service layer AND enforced again at the database layer via `reference_vault.metadata_id UNIQUE` (defense in depth, confirmed in `postgres_vault_repository.cpp`'s `unique_violation` handling)
4. Verification shall be successful → `VerificationNotSuccessfulError` (409)
5. Artifact shall exist on disk → `ArtifactNotFoundError` (422)
6. SHA-256 shall match the Verification record, **recomputed fresh** → `ArtifactHashMismatchError` (409)
7. Vault path shall validate (sharding must produce a valid path) → `InvalidVaultPathError` (422)

Every one of the seven was individually verified either by direct code reading of the guard clause or by locating its corresponding Service-layer test in `tests/test_reference_vault_service.cpp` (each rule has its own `TEST_CASE`).

**Publication immutability**: no `PUT`/`PATCH`/`DELETE` route exists for `/vault` at all (confirmed via `grep` against `src/api/server.cpp`); `IVaultRepository` has no `update`/`delete` method in its interface. Immutability is structural, not conventional.

**A defect was found and fixed**: see §8.

## 8. Content-Addressable Storage Audit

- Path generation: `compute_vault_path(root, sha256_hex)` — sharded `<root>/<first-2-hex>/<full-hash>`, deterministic, rejects a too-short/non-hex/uppercase hash (own dedicated unit-test suite, `test_vault_path.cpp`).
- Dedup: confirmed at the filesystem layer only (existence check before copy) — two different Metadata records with byte-identical content each get their own `VaultEntry` row referencing the same physical file, verified by a direct Service-layer test (`ReferenceVaultService.publish deduplicates identical content across two different chains`) and now a second one added by this audit (below) proving the dedup path also survives a subsequent failure.
- Original acquisition workspace: never touched — the Vault only ever *copies* `download.local_storage_path` (`std::filesystem::copy_file`, source untouched), confirmed by reading `reference_vault_service.cpp`.

**Defect found: publication could leave an orphaned file with zero referencing `VaultEntry` rows.** The file copy (when this call is the one that materializes new content) and the database `INSERT` are not one atomic operation — nothing spans a filesystem write and a PostgreSQL commit. If `IVaultRepository::create` throws *after* a fresh copy already succeeded (a concurrent publish racing the same `metadata_id` past the Service-layer `already_published` check and losing the database's own `UNIQUE` constraint at commit time, or a transient connection failure), the copy was not rolled back. `PostgresVaultRepository::create` itself is correctly transactional (a single `pqxx::work`, committed once, with `unique_violation`/`foreign_key_violation` mapped to domain errors) — the gap is strictly in the ordering across the two systems in `ReferenceVaultService::publish`, not inside the repository.

**Fixed** (`src/vault/reference_vault_service.cpp`): the copy-vs-dedup decision is now tracked (`copied_by_this_call`); if `vault_.create(entry)` throws, and this call is the one that performed a fresh copy, that file is removed before the exception propagates. A dedup hit (reusing a file a different, already-committed `VaultEntry` owns) is never touched by this cleanup. Two new regression tests added (`test_reference_vault_service.cpp`): one proving the orphan is now cleaned up and a subsequent retry still succeeds; one proving the cleanup never deletes a file a concurrent, successful dedup publish still needs.

No corresponding "dangling database row pointing at a missing file" direction was found possible — the code order is copy-then-insert, so a successful `INSERT` (the only way a `VaultEntry` becomes visible via the API) is only ever reached after the file already exists at the recorded path.

## 9. Provenance Audit

`reference_vault` stores `metadata_id`, `verification_id`, `download_session_id`, and `source_id` directly as real foreign keys (all four confirmed present in V8's `CREATE TABLE`, all four confirmed serialized by `GET /vault/{id}`). The chain is reconstructable exactly as this audit's own diagram describes:

```
Vault Entry --(metadata_id)--> Metadata --(verification_id)--> Verification
  --(download_session_id)--> Download --(job_id)--> Acquisition Job --(source_id)--> Official Source
```

`source_id` is additionally denormalized directly onto `reference_vault` (resolved once, at publish time, via `Download.job_id -> AcquisitionJob.source_id`) rather than requiring a client to walk through Job — a convenience, not a redundant/competing provenance system (there is exactly one place, `ReferenceVaultService::publish`, that resolves it, and exactly one place it's stored).

**Reconstructable today**: every relationship is a real, indexed (after this audit's V9 fix — see §11) foreign key. A client can walk the full chain via 4 sequential `GET` calls (`/vault/{id}` → `/metadata/{id}` → `/verifications/{id}` → `/downloads/{id}` → `/sources/{id}`, with `/jobs/{id}` reachable via `download.job_id` if the intermediate Job record itself is needed). **Not implemented**: a single aggregating "full provenance" convenience endpoint — this is a UX/ergonomics gap, not a data-integrity one (nothing is unrecoverable, it just requires multiple round-trips), and is not required by any WP-002 through WP-009 text. Classified **FUTURE**, not a gap blocking M2.

Nothing in SDD-R016's provenance requirements is unrepresented at the *relationship* level; SDD-R016 additionally describes Licensing relationships, Related Vault Objects, Previous/Later Revisions, and Engineering Knowledge Object references that are explicitly out of Milestone-1 scope (see gap analysis document) — this audit did not invent a second provenance system to cover them.

## 10. Database Audit

See migrations `V1`–`V8` (pre-existing) and `V9` (added by this audit). Findings:

- **Primary keys**: every table has a `BIGSERIAL` internal PK plus a `UUID` external identifier — consistent, confirmed across all 7 domain tables.
- **Foreign keys**: `acquisition_jobs.source_id`, `download_sessions.job_id`, `integrity_verifications.download_session_id`, `artifact_metadata.verification_id`, `reference_vault.{metadata_id,verification_id,download_session_id,source_id}` — all real `REFERENCES` constraints, no application-level-only checks masquerading as relational integrity.
- **Uniqueness**: `uuid` on every table; `reference_vault.metadata_id` additionally `UNIQUE` (enforces "no re-publish" at the database layer, not just the Service layer).
- **Missing foreign-key indexes — FOUND AND FIXED**: `V8__reference_vault.sql` indexed `metadata_id` (via its `UNIQUE` constraint) and `sha256_hash`/`status`, but left `verification_id`, `download_session_id`, and `source_id` — three of its four foreign keys — without their own index, breaking the pattern every other migration (V3, V4, V5, V6, V7) established of indexing every FK column. **Fixed**: `migrations/V9__reference_vault_fk_indexes.sql` (additive only, V1–V8 untouched), with a new regression test (`test_vault_migration.cpp`) asserting all three indexes exist.
- **Missing uniqueness/check constraints**: none found beyond the above.
- **Nullability**: spot-checked against each WP's own Domain Model "(nullable)" annotations (e.g. `acquisition_jobs.started_at`/`completed_at`/`error_message`) — matches.
- **Accidental mutable identity**: none found — every `id`/`uuid` pair is write-once by construction (no repository exposes an update to either column).
- **Orphanable records**: the one genuine case found (§8) has been fixed. No others identified — every table's foreign keys are `NOT NULL` (no optional, dangling-by-design references).
- **Inconsistent status values**: `reference_vault.status` has exactly one legal value (`'published'`) by `CHECK` constraint — intentional per WP-009's own "no re-publish, no failed-state persistence" design (see §7), not an oversight.
- **Cascade behavior**: no `ON DELETE CASCADE` anywhere — consistent with an evidence-immutability posture (nothing here is ever hard-deleted; soft-delete via `deleted_at` exists only on `official_sources`/`acquisition_jobs`, which have real `DELETE` routes backed by soft-delete, not hard delete).

## 11. REST API Audit

All 33 routes (§2) were enumerated directly from `src/api/server.cpp` and cross-checked against `README.md`'s documented list — **exact match**, no undocumented routes found and no documented-but-missing routes found (the connector/vault immutability claims — no mutating routes — were independently confirmed by the same `grep`, not merely read from prose).

- Request validation: every `POST` validates required fields before touching a repository (`parse_and_validate_*` per module); malformed JSON bodies produce a `400`/`422` (module-specific, consistent with each WP's own Validation Rules).
- Response shape: consistent per-resource JSON shape (a `to_json`/`status_to_json` pair per domain type), confirmed for Vault in §7; the same pattern was spot-checked for Verification and Metadata.
- Not-found behavior: every single-resource route (`GET /x/{id}`, etc.) returns `404` for an unknown id, confirmed via `grep` pattern consistency across all seven resource families.
- Invalid-state behavior: `409` with a machine-readable `"error"` string (`invalid_transition`, `already_published`, `verification_not_successful`, `connector_unhealthy`, `source_unavailable`, etc.) — consistent error-model shape across every module.
- Idempotency: `POST /jobs/{id}/execute`/`cancel` are correctly non-idempotent by design (each call advances exactly one state); `POST /vault` is correctly non-idempotent the other direction (a second call for the same `metadata_id` is rejected, never silently repeated).
- No implementation details leak across the boundary that this audit could find: internal `BIGSERIAL id` never appears in any JSON response (confirmed for Vault in §7; the same internal/external key split is architecture-wide per every migration's own header comment).

## 12. Studio Integration Audit

`platform/oep_studio/lib/acquisition` (1,125 lines across `services/`, `panels/`, `workspaces/`, `wizard/`, `settings/`, `inspector/`, `models/`) reaches EAM **exclusively** through `AcquisitionApiClient`, a plain REST client hitting the exact same endpoints documented in §2/§11 (confirmed by direct code reading of `acquisition_api_client.dart`) — no direct database access, no bypass of the backend's own validation.

- Navigation: `AcquisitionStudioPage` (a Workspace surface, per the existing Surface/Studio architecture — no new router introduced, confirmed by grep for router/route-table changes: none found in this directory).
- Panels present: Sources, Jobs, Pipeline (download/verify/metadata/vault progression), Vault — matching the backend's own resource families one-for-one.
- Error display: `AcquisitionApiException` (network vs. service-status distinction), surfaced to the panels — confirmed present, not merely assumed.
- Knowledge-boundary discipline (§13 below) is honestly reflected here too: `WizardStepCandidatePreview` (Wizard Step 7) explicitly shows an **empty** candidate-knowledge preview with a visible "not yet available" banner rather than fabricating example Engineering Objects, with its own doc comment stating exactly why (Milestone 2's Knowledge Engine doesn't exist yet) — a genuine, verified instance of "do not fabricate" discipline, not an assumption.
- `wizard/acquisition_wizard_controller.dart` hardcodes `connectorId = 'http-source'` — **this Studio wizard already targets the real `HttpConnector` found in §4**, not `example-stub`. This strengthens §4's finding: the real HTTP connector is not merely present in the backend, it is already the one the Studio's own primary acquisition workflow is wired to use.

## 13. Knowledge Boundary Audit

Searched `platform/oep_studio/lib/acquisition` for any reference to `KnowledgeObject`/`EngineeringObject`/knowledge-runtime types: **none found**. The one place the wizard *discusses* Engineering Objects (`WizardStepCandidatePreview`) explicitly renders them as a not-yet-implemented, honestly-empty preview rather than creating any. No code in the audited acquisition surface creates, persists, or fabricates an Engineering Knowledge Object. The EAM backend itself (C++) has no dependency on `knowledge/reference_library` at all (confirmed: `services/acquisition`'s `CMakeLists.txt`/includes reference no Python/knowledge-library path, and the two are entirely separate runtimes/languages with no shared process or database). The boundary described in this task (`EAM -> Reference Vault -> Knowledge Ingestion -> Knowledge Candidate -> Engineering Review -> Reference Library`) is **respected** by everything this audit could find; the stages after Reference Vault are simply **not yet built** (Milestone 2), which is the correct, disclosed state, not a boundary violation.
