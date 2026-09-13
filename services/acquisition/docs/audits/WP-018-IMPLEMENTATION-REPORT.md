# WP-018 — Acquisition Record & Provenance Foundation
## Implementation Report

================================================================
EXECUTIVE SUMMARY
================================================================

WP-017's audit identified the single largest architecture-vs-implementation gap in the M1 EAM/Reference Vault pipeline: SDD-R015's "Acquisition Record" — the canonical, durable identity for one acquisition event — had no corresponding table or entity anywhere in the codebase. Provenance was fully reconstructable, but only as an implicit graph across four existing tables, never through one queryable identity.

WP-018 closes that gap with the smallest model SDD-R015 and the existing codebase actually support: one `acquisition_records` row per Download Session (not per Job — see rationale below), created automatically and advanced automatically as a best-effort side effect of the pre-existing `/downloads`, `/verifications`, `/metadata`, and `/vault` REST routes, with zero changes to any of the four underlying Services' constructors or contracts, and zero changes to `reference_vault`. A new `GET /acquisition-records/{id}/provenance` route reconstructs the full Vault Entry → Metadata → Verification → Download → Job → Source chain in one request.

All new and pre-existing tests pass: **235 test cases, 1090 assertions, 0 skipped, 0 failed**, confirmed identical across two independent, consecutive full-suite runs against a real PostgreSQL 18 instance.

================================================================
ARCHITECTURAL OBJECTIVE
================================================================

Establish a durable, queryable Acquisition Record providing the canonical identity and provenance anchor for an acquisition event, per SDD-R015, without redesigning EAM, without creating a second provenance/identity/hashing/repository system, and without moving any Reference Vault or Knowledge functionality.

================================================================
PRE-IMPLEMENTATION STATE
================================================================

- WP-001 through WP-009: complete, per WP-017's audit (still true — this WP touched none of their production code).
- No `AcquisitionRecord`, `acquisition_record`, or `provenance` symbol existed anywhere in the repository (confirmed by repository-wide search before this WP began).
- Provenance was reconstructable only via four sequential GETs (`reference_vault` → `artifact_metadata` → `integrity_verifications` → `download_sessions` → `acquisition_jobs` → `official_sources`), each already a real foreign key — WP-017's own §9 finding, re-confirmed.
- "Execution" is `acquisition_job_execution_history`, an append-only Job-status-transition log with no identifier of its own — not a distinct entity.
- No retry mechanism exists anywhere in this codebase (confirmed by `grep`) — a "retry" is, and always was, simply a new `AcquisitionJob`/`DownloadSession`.
- `ADR-0008`, cited by `WORK_PACKAGE_006.md`, `WORK_PACKAGE_009.md`, and `IConnector::fetch`'s own doc comment, does not exist anywhere in this repository (re-confirmed; unchanged from WP-017).

Full detail: `docs/audits/ACQUISITION_RECORD_IMPLEMENTATION_AUDIT.md` Sections 1-2.

================================================================
IMPLEMENTATION
================================================================

New module `oep::acquisition::provenance` (`include/oep/acquisition/provenance/`, `src/provenance/`):

- `acquisition_record.hpp/.cpp` — `AcquisitionRecordStatus` enum, `AcquisitionRecord` struct
- `acquisition_record_repository.hpp` — `IAcquisitionRecordRepository`, `AcquisitionRecordFilter`, `UnknownDownloadSessionError`, `DuplicateAcquisitionRecordError`
- `postgres_acquisition_record_repository.hpp/.cpp` — real PostgreSQL implementation via `libpqxx`
- `acquisition_record_json.hpp/.cpp` — REST JSON representation
- `acquisition_record_service.hpp/.cpp` — orchestration: `record_download_outcome`, `record_verification_outcome`, `record_metadata_outcome`, `record_vault_publication`, `get`, `list`, `get_provenance`

Integration: `src/api/server.cpp`'s `register_downloads_routes`/`register_verifications_routes`/`register_metadata_routes`/`register_vault_routes` each gained one optional `AcquisitionRecordService*` parameter and one best-effort, try/catch-wrapped call after their existing service call returns. A new `register_acquisition_records_routes` adds the three new GET routes. `ApiServer`'s constructor gained one new trailing optional parameter (`acquisition_record_service = nullptr`), preserving every existing call site unchanged. `main.cpp` wires the new repository/service following the exact same non-fatal-database precedent every other engine already uses.

**Zero lines changed** in `download_service.hpp/.cpp`, `integrity_verification_service.hpp/.cpp`, `metadata_extraction_service.hpp/.cpp`, `reference_vault_service.hpp/.cpp`, or any of their existing test files.

Full rationale for the route-layer (not service-layer) integration choice: audit document Section 8.

================================================================
DATABASE CHANGES
================================================================

One new, additive migration: `migrations/V10__acquisition_records.sql`.

```sql
CREATE TABLE acquisition_records (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    download_session_id UUID NOT NULL REFERENCES download_sessions (uuid),
    status TEXT NOT NULL
        CHECK (status IN ('pending', 'acquired', 'verified', 'published', 'failed', 'archived')),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT acquisition_records_uuid_key UNIQUE (uuid),
    CONSTRAINT acquisition_records_download_session_id_key UNIQUE (download_session_id)
);

CREATE INDEX idx_acquisition_records_status ON acquisition_records (status);
```

`V1`-`V9` are untouched. `reference_vault` (V8) is **not** altered by this migration — see Provenance Model below for why. Every foreign key (`download_session_id`) is covered by an index automatically created by its own `UNIQUE` constraint — no redundant explicit index was added, a deliberate departure from V5-V8's own minor redundancy, per this WP's explicit "no redundant indexes" instruction (documented in the migration file's own comment).

No historical backfill was performed for Download Sessions created before this migration — they simply have no Acquisition Record, which `AcquisitionRecordService`'s no-op-if-missing behavior handles safely (see Failure/Retry Semantics below). This is a disclosed, deliberate limitation, not an oversight: recomputing a historically-accurate status for pre-existing rows would require a nontrivial multi-table join inside the migration itself, for a dev/pre-M2 database with no production acquisition history to preserve.

================================================================
DOMAIN MODEL
================================================================

`AcquisitionRecord`: `id` (UUID), `download_session_id` (the record's one identity-defining relationship, UNIQUE), `status`, `error_message` (nullable), `created_at`, `updated_at`.

**Anchor decision**: one record per Download Session, not per Acquisition Job. SDD-R015 §8's own per-acquisition metadata list (Source URL, Referrer, Redirect Chain, ETag) describes facts specific to one fetch attempt, not to a (potentially multi-download) Job as a whole; and since a Job has no distinct retry concept in this codebase, a Job-anchored record could not answer "does retry create a new record" without inventing new bookkeeping. A Download-Session anchor answers it for free: a second `POST /downloads` is already, today, a second independent row. Full reasoning: audit document Section 3.

Every other SDD-R015 relationship (Source, Job, Execution History, Verification, Metadata, Vault) is intentionally **not** a stored column — each is reached by traversing an existing foreign key or repository filter, per this WP's explicit "traverse existing links instead of adding duplicate columns" instruction. Every SDD-R015 field this WP does *not* implement (Workstation, DNS, TLS, licensing, SHA-512/BLAKE3, Custody Events) is classified in the audit document's Gap Classification, each with a concrete reason it was not built now (no upstream producer, explicitly out of scope, or already covered by an existing mechanism).

================================================================
LIFECYCLE
================================================================

`Pending → Acquired → Verified → Published`, plus `Failed` (added alongside SDD-R015 §5's documented happy path, matching every other domain table's own established shape) and `Archived` (accepted by the schema, set by no code path yet — a disclosed, matching gap to WP-017's own Vault-side finding).

Transitions occur exactly at four points, each a best-effort call from the API route layer after the corresponding pre-existing service call returns: `POST /downloads` (creates, `Acquired`/`Failed`), `POST /verifications` (`Verified`/`Failed`), `POST /metadata` (`Failed` only — no distinct "metadata extracted" stage exists in SDD-R015's own lifecycle), `POST /vault` (`Published` — Vault publication has no persisted failure state to record, unchanged WORK_PACKAGE-009 design). Full table: audit document Section 8.

================================================================
PROVENANCE MODEL
================================================================

`GET /acquisition-records/{id}/provenance` reconstructs, in one request: the Acquisition Record itself; its Download Session; that Download's Acquisition Job, that Job's Official Source, and that Job's full execution history; every Integrity Verification for that Download Session; every Artifact Metadata record for those Verifications; and the Reference Vault Entry, if published. Every link is traversal-based (existing foreign keys or existing repository filters — `VerificationFilter::download_session_id`, `MetadataFilter::verification_id`, `VaultFilter::metadata_id`); no table gained a new relationship column, `reference_vault` included. Full diagram: audit document Section 7.

================================================================
VAULT INTEGRATION
================================================================

`reference_vault` (V8) is completely unmodified — no new column, no new constraint, no changed behavior. `ReferenceVaultService::publish`'s own orphan-file-race fix from WP-017 is untouched; WP-018 found no defect in it requiring correction. A Vault Entry's owning Acquisition Record is found via `reference_vault.download_session_id` (already present since V8) against `acquisition_records.download_session_id` — a lookup, not a stored relationship. Vault's own content-addressed storage mechanism, artifact hashing, and identity model are all unchanged.

================================================================
FAILURE / RETRY SEMANTICS
================================================================

Failure: a Download that completes as `Failed`, a Verification that completes as `Failed`, or a Metadata extraction that completes as `Failed` each advance the Acquisition Record to `Failed`, carrying that stage's own error message forward. A record that reaches `Failed` never subsequently reaches `Published` through any code path (Vault publication's own preconditions — Metadata must be `Extracted`, Verification must be `Verified` — already make this structurally impossible, unchanged from WORK_PACKAGE-009's own design).

Retry: unchanged, pre-existing behavior (a new `POST /downloads` call, whether against the same or a new Job) — automatically produces a new, independent Acquisition Record, with no new retry mechanism added. Verified in `test_acquisition_record_service.cpp`'s duplicate-record test and in the full-pipeline REST test's failed-verification section (`test_acquisition_record_api.cpp`).

A Download Session created before this WP shipped (or by an environment where the Acquisition Record repository was unavailable, e.g. a database outage — this WP follows the same non-fatal-database degradation precedent as every prior engine) has no Acquisition Record; every `record_*_outcome` call is a safe no-op (returns `nullopt`) rather than an error in that case — verified by a dedicated Service-layer test.

================================================================
IMMUTABILITY
================================================================

`id` and `download_session_id` never change after `create()` — no code path anywhere in this module can rewrite either. `status`/`error_message`/`updated_at` are the one deliberately-mutable field group, updated exactly once per stage transition, mirroring the exact pattern every prior domain table already uses. This resolves an apparent tension in SDD-R015 itself (§4.1's literal "never modified after creation" vs. §5's own multi-stage lifecycle) — documented explicitly, not silently reconciled. Full reasoning: audit document Section 5.

================================================================
REST/API
================================================================

`GET /acquisition-records` (filterable by `status`), `GET /acquisition-records/{id}`, `GET /acquisition-records/{id}/provenance`. No POST/PUT/DELETE route exists — every transition is a side effect of the four pre-existing routes listed under Lifecycle. Every existing route's JSON/error/status-code/UUID/timestamp conventions are reused verbatim (`respond_json`, `respond_error`, `guard_*` pattern) — no second API style was introduced.

Every pre-existing route (`/sources`, `/jobs`, `/connectors`, `/downloads`, `/verifications`, `/metadata`, `/vault`, `/health`) is unchanged in its request/response shape; the only observable *new* behavior on `/downloads`/`/verifications`/`/metadata`/`/vault` is that provenance bookkeeping now also occurs, which is invisible to a client unless it separately queries `/acquisition-records`.

================================================================
STUDIO IMPACT
================================================================

`platform/oep_studio/lib/acquisition` was inspected (not modified). Studio's acquisition wizard does not currently expose any acquisition-history or provenance UI that would require the new Acquisition Record to function correctly — its existing behavior is unaffected by, and does not depend on, anything this WP added. Per this WP's own instruction ("if no Studio behavior requires it, do NOT modify Studio merely for symmetry"), **no Studio changes were made.**

================================================================
KNOWLEDGE BOUNDARY
================================================================

No Engineering Knowledge Object was created. No OCR, AI interpretation, semantic classification, embeddings, or knowledge graph code was added. No Reference Library ingestion was implemented. The Acquisition Record describes acquisition provenance only — it has no field, method, or relationship that represents engineering meaning or interpretation. The EAM → Reference Vault → Universal Ingestion → Knowledge Candidate → Engineering Review → Reference Library boundary is unchanged; WP-018 operates entirely below the Reference Vault, extending provenance, not crossing into evidence interpretation.

================================================================
ADR-0003 STATUS
================================================================

Unresolved, exactly as WP-017 left it. WP-018 did not touch `HttpConnector`, did not add host allowlisting, did not add SSRF protection, did not add authentication, and did not expand or restrict its scope in any way. `HttpConnector` remains outside this WP's scope by explicit instruction; the M2 Readiness Impact section below repeats WP-017's own condition that ADR-0003 must be resolved before any M2 connector work — WP-018 is not connector work, so it does not itself trigger that condition, but it also does not discharge it.

================================================================
ADR-0008 TRACEABILITY
================================================================

Re-investigated per this WP's explicit instruction; unchanged conclusion. `ADR-0008` does not exist anywhere in this repository, under any path or name. `ADR-0002-PROPOSED-CONNECTOR-CONTENT-RETRIEVAL.md` (status: Proposed, not Ratified) closely matches what `IConnector::fetch` actually implements, but is numbered `0002`, not `0008`, and its own status does not claim ratification. No new ADR was fabricated to fill this gap — doing so would mean guessing at a decision apparently made outside this repository's own record. **Genuine, disclosed, unresolved traceability gap — BLOCKED, not fixed by this WP.**

================================================================
TEST RESULTS
================================================================

Full suite built (MSVC/CMake, Visual Studio 18 Build Tools, `CMAKE_PREFIX_PATH` pointed at the local PostgreSQL 18 install) and run via the compiled test binary directly against a real, reachable local PostgreSQL 18 instance (`OEP_TEST_DB_*` env vars set to the working `oep_acquisition`/`oep123` credentials already present in this environment).

**New test files this WP added**: `test_acquisition_record_service.cpp` (10 test cases, fakes only), `test_acquisition_record_repository.cpp` (1 test case, 9 sections, real Postgres), `test_acquisition_record_migration.cpp` (2 test cases, real Postgres), `test_acquisition_record_api.cpp` (1 test case, 4 sections, real Postgres + real HTTP server, exercising the complete Download → Verify → Metadata → Vault → Acquisition Record → provenance chain end to end, plus a genuine failed-verification path).

**Final, confirmed result — identical across two independent, consecutive full-suite runs** (different random seeds each time, `2756571952` and `1395653242`):

```
All tests passed (1090 assertions in 235 test cases)
```

- **235 / 235 test cases passed** (up from WP-017's confirmed baseline of 221 — 14 new test cases)
- **1090 / 1090 assertions passed** (up from 981 — 109 new assertions)
- **0 skipped, 0 failed**, exit code 0, both runs
- Build configuration: MSVC (Visual Studio 18 Build Tools), CMake, Debug configuration, C++23
- Database: PostgreSQL 18, local, real (not mocked) for every Repository/Migration/API test

One genuine test defect was found and fixed *during* this WP's own test-writing, before the numbers above: the failed-verification REST scenario initially corrupted the downloaded artifact's *content* to try to force a verification failure, but `IntegrityVerificationService::verify` has no prior hash to compare against on a first run (it establishes the hash, it does not check it against an expectation) — so corrupting content alone never fails verification. Fixed by removing the artifact file entirely instead ("Missing files shall fail verification" — an actual, documented Validation Rule), which is the correct way to exercise that path. This was caught by actually running the test, not by inspection — exactly the kind of thing this WP's own "do not report tests pass without execution" instruction is meant to catch.

================================================================
REGRESSION RESULTS
================================================================

Every one of WP-017's confirmed 221 test cases / 981 assertions still passes, unmodified, as part of the same 235/1090 total above. Specifically re-verified by direct inspection (not merely by the aggregate count): `test_download_service.cpp`, `test_verification_service.cpp`, `test_metadata_extraction_service.cpp`, and `test_reference_vault_service.cpp` — the four files most at risk of an accidental contract change — have **zero diff** from their WP-017 state. `test_download_api.cpp`, `test_verification_api.cpp`, `test_metadata_api.cpp`, `test_vault_api.cpp` likewise unmodified and passing, confirming the new optional `AcquisitionRecordService*` parameter on each route-registration function does not change behavior when `nullptr` (every existing test constructs `ApiServer` without passing WP-018's new trailing parameter at all, relying on its default).

================================================================
REMAINING GAPS
================================================================

See the audit document's Gap Classification table for the complete list with individual justifications. Summarized:

- Rich per-acquisition metadata (Workstation, DNS, TLS, Referrer/Redirect Chain, licensing) — **FUTURE**, no upstream producer exists yet; building the columns now would be empty, permanently-`NULL` speculative metadata.
- SHA-512 / BLAKE3 — **FUTURE**, not computed anywhere in this codebase.
- Full Custody Event log — **DEFERRED**, `acquisition_job_execution_history` already covers the Job-level portion of this need.
- `Archived` lifecycle state — **DEFERRED**, no archival capability exists anywhere yet (matches WP-017's own disclosed Vault-side gap).
- ADR-0008 traceability — **BLOCKED**, genuine pre-existing documentation gap.
- ADR-0003 (HttpConnector scope/SSRF) — **unresolved**, unchanged from WP-017, not this WP's to fix.

================================================================
M2 READINESS IMPACT
================================================================

WP-017 recommended treating the Acquisition Record gap as "an explicit early-M2 work package, not discovered mid-implementation." WP-018 discharges that recommendation. WP-017's three READY WITH CONDITIONS conditions are otherwise unaffected:

1. **ADR-0003 must be resolved** before any M2 connector work — still outstanding, unchanged, not addressed by this WP (by design — this WP explicitly does not touch `HttpConnector`).
2. **README.md's connector claims must be corrected** — still outstanding, unchanged.
3. **The Acquisition Record / SDD-R015 gap should be scoped as an explicit early-M2 work package** — **discharged by this WP.**

No new blocking condition is introduced by WP-018. The rich-metadata/licensing/custody-event/archival gaps identified above are all genuinely FUTURE-scoped, dependent on producers (better connectors, a licensing subsystem, an archival job) that do not exist yet — attempting them now would have meant building speculative infrastructure ahead of its own inputs, which this WP's own governing instructions explicitly prohibit.

================================================================
FINAL RECOMMENDATION
================================================================

**READY WITH CONDITIONS.**

Unchanged from WP-017 except that condition 3 is now discharged:

1. **ADR-0003 must be resolved** (ratify, gate off, or explicitly accept `HttpConnector` with its SSRF gap closed) before any Milestone-2 work package that touches connectors, downloading, or external network access begins. *(carried forward from WP-017, untouched by this WP)*
2. **`README.md`'s connector-related claims must be corrected** to match reality regardless of which option ADR-0003 resolves to. *(carried forward from WP-017, untouched by this WP)*
3. ~~The Acquisition Record / chain-of-custody gap should be scoped as an explicit early-M2 work package~~ — **discharged.** WP-018 implements this foundation. Follow-on work (rich per-acquisition metadata, licensing, custody events, archival) remains genuinely future-scoped and should be its own, separately-decided work package(s) once their respective upstream producers exist — not bundled into a repeat of this one.

Do not begin WP-019 or any other subsequent work package.
