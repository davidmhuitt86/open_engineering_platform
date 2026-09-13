# Acquisition Record & Provenance Foundation — Implementation Audit (WP-018)

Companion to `docs/tasks/WP-018.md` and `docs/audits/WP-018-IMPLEMENTATION-REPORT.md`. This document explains what SDD-R015 requires, what existed before WP-018, what was implemented, why each implementation choice was made, and what remains deliberately out of scope.

---

## 1. What SDD-R015 requires

`docs/architecture/SDD-R015-ACQUISITION_RECORD_AND_CHAIN_OF_CUSTODY.md`, read in full. Its authoritative claims:

- The Acquisition Record is "the canonical representation of an engineering acquisition event" (Section 1) — immutable (Section 4.1), event-based (4.2), permanently traceable (4.4).
- A five-stage lifecycle: Pending → Acquired → Verified → Published to Vault → Archived (Section 5).
- A permanent, never-reused Acquisition Identifier (Section 6).
- References an "Engineering Artifact", which in turn maps to a "Vault Object" (Section 7) — terms not otherwise present anywhere in the M1 implementation (there is no `EngineeringArtifact` table; the closest concrete analogue is `reference_vault`).
- A rich per-acquisition metadata list (Section 8): Timestamp, Acquisition Method, User, Workstation, Organization, Source Registry Identifier, Endpoint Identifier, Source URL, Referrer, Redirect Chain, MIME Type, File Size, Original Filename, Content Encoding.
- Integrity metadata (Section 9): SHA-256, SHA-512, BLAKE3, File Length, Hash Timestamp.
- Source verification metadata (Section 10): DNS, resolved IP, TLS certificate/fingerprint, HTTP headers, server info, ETag, Last-Modified.
- Licensing metadata, explicitly independent from provenance (Section 11).
- A full Chain of Custody: an append-only log of Custody Events (Sections 12-13) — Downloaded, Imported, Verified, OCR Complete, Metadata Extracted, AI Indexed, Published to Vault, Archived.
- Duplicate acquisitions and revisions each get their own, independent Acquisition Record (Sections 15-16).
- A reference to the resulting Vault Object once verification succeeds (Section 18).
- Future extensions: digital signatures, blockchain timestamping, enterprise audit, regulatory compliance, multi-party verification, distributed acquisition (Section 19).

**This is a much richer model than WP-018 implements.** That is deliberate, not an oversight — see Section 6 ("Domain Model — what was implemented, and why less than the full text") below, and the Gap Classification at the end of this document. WP-017's own gap analysis already flagged the risk of over-building here; the governing WP-018 prompt independently reinforces it ("implement the smallest model supported by SDD-R015 and the existing system... avoid speculative metadata").

---

## 2. What existed before WP-018

Confirmed by direct code reading (not by trusting any README):

- **No table, entity, repository, or service anywhere in `services/acquisition` corresponded to "Acquisition Record."** A repository-wide search for `AcquisitionRecord`, `acquisition_record`, and `provenance` (case-insensitive) returned zero matches before this WP.
- **Provenance was fully reconstructable, but only as an implicit graph**, never through one queryable identity — `reference_vault.metadata_id` → `artifact_metadata.verification_id` → `integrity_verifications.download_session_id` → `download_sessions.job_id` → `acquisition_jobs.source_id` → `official_sources`. WP-017's Implementation Audit (§9) already confirmed this chain is intact and correct; its own stated gap was "no aggregating endpoint," which understated the real gap once SDD-R015 was read in full: there was no *entity*, only a *traversable path*.
- **"Execution" is not a distinct entity with its own identifier.** WORK_PACKAGE-004 explicitly reused `acquisition_jobs` unchanged and added only `acquisition_job_execution_history` — an append-only log of Job status transitions (`from_status`/`to_status`/`occurred_at`/`message`), keyed by `job_id`. There is no `execution_id` anywhere in the schema.
- **No retry mechanism exists anywhere in this codebase.** A `grep` for `retry`/`Retry` across `src/` returned zero matches. A Job, once in a terminal state (`Completed`/`Failed`/`Cancelled`), has no forward transition (`next_execution_status` returns `nullopt`) — the only way to "retry" an acquisition today is to create an entirely new `AcquisitionJob` (and, transitively, a new `DownloadSession`) pointing at the same source. This directly answers Domain Questions 12-13 (Section 4 below).
- **ADR-0008**, which `HttpConnector`'s own doc comment and WORK_PACKAGE-006 attribute the `IConnector::fetch` interface to, **does not exist anywhere in this repository**, under any path or name — confirmed by `Glob` for `**/ADR-0008*` (zero results) and by WP-017's own prior finding. See Section 9 below.

---

## 3. Domain Model — the anchor decision

The single most consequential design choice in this WP is **what one Acquisition Record is keyed to.** Two candidates were weighed:

**Option A — one record per Acquisition Job.** Simple, matches the "acquisition event = the thing a user requested" intuition. Rejected because: (1) nothing in this codebase prevents a Job from producing more than one Download Session (no uniqueness constraint on `download_sessions.job_id`), so a Job-keyed record could not unambiguously represent "this one fetch attempt's" Source URL/Referrer/Redirect Chain/ETag (SDD-R015 Section 8) if two different download attempts under the same Job ever had different values for those fields; (2) it does not cleanly answer Domain Question 13 ("does retry create a new Acquisition Record or another Execution?") without inventing new bookkeeping, since a Job has no retry concept at all today.

**Option B — one record per Download Session.** Adopted. Every field in SDD-R015 Section 8's own metadata list (Source URL, Referrer, Redirect Chain, ETag, Last-Modified, MIME Type, File Size, Original Filename) is a property of exactly one fetch attempt, not of the (potentially multi-attempt) Job as a whole. Since a "retry" in this codebase's *actual, demonstrated* behavior is simply a second `POST /downloads` producing a second, independent `download_sessions` row, keying the Acquisition Record the same way means retry semantics require **no new mechanism whatsoever** — each independent Download Session already is, and is treated as, an independent acquisition event, satisfying SDD-R015 Section 15 ("Duplicate Acquisitions shall not invalidate Acquisition Records... each acquisition event remains historically significant") for free.

This resolves Domain Questions 1-2, 5-6, 11-13 (Section 4 below) simultaneously, and is why `acquisition_records.download_session_id` is the schema's only foreign key (see Section 7).

---

## 4. Required Domain Questions — answered

1. **What constitutes one Acquisition Record?** One Download Session attempt (see Section 3).
2. **When is it created?** Synchronously, immediately after `DownloadService::start_download` returns — as a best-effort side effect performed by the API route handler (`POST /downloads`), not inside `DownloadService` itself (see Section 8).
3. **What is its permanent identifier?** `acquisition_records.uuid`, generated by the database (`gen_random_uuid()`), never reused, never rewritten.
4. **Which Official Source does it reference?** Not stored directly — reachable via `download_session_id → download_sessions.job_id → acquisition_jobs.source_id → official_sources`.
5. **Does it reference an Acquisition Job?** Not stored directly, for the same reason — reachable via `download_sessions.job_id`.
6. **Does it reference an Execution?** "Execution" is `acquisition_job_execution_history`, keyed by `job_id` (see Section 2) — reachable via the same one-hop traversal as the Job itself.
7. **How are Download Sessions related?** 1:1, by construction — `download_session_id` is `UNIQUE`.
8. **How are Verification results related?** By querying `integrity_verifications` filtered by `download_session_id` (an existing filter, `VerificationFilter::download_session_id`) — not a stored column.
9. **How is Metadata Extraction related?** By, for each Verification found above, querying `artifact_metadata` filtered by `verification_id` (an existing filter) — not a stored column.
10. **How is Reference Vault publication related?** By, for each Metadata record found above, querying `reference_vault` filtered by `metadata_id` (an existing filter) — not a stored column, and `reference_vault` itself is completely unmodified by this WP (see Section 7).
11. **Can one Acquisition Record produce multiple downloaded artifacts?** No — 1:1 with exactly one Download Session, by design (Section 3).
12. **Can an acquisition be retried?** Yes, exactly as it already could before this WP: by issuing a new `POST /downloads` (new Job or same Job, either already worked before WP-018) — nothing new was added or needed to be added.
13. **Does retry create a new Acquisition Record or another Execution?** A new Acquisition Record, automatically, as a direct consequence of the Download-Session anchor — the new Download Session gets its own record the moment it is created.
14. **What constitutes successful acquisition?** The record reaching `published` — Verification succeeded, Metadata extraction succeeded (implicitly, since Vault publication requires it), and Vault publication succeeded.
15. **What constitutes failed acquisition?** The record reaching `failed` — set on a failed Download, a failed Verification, or a failed Metadata extraction. (Vault publication has no distinct failure mode to record here — see Section 8.)
16. **What provenance must remain available after the acquisition completes?** Everything the traversal in Questions 4/5/6/8/9/10 reaches, all of it on rows that are themselves already immutable-after-write by every prior WP's own design (Job/Download/Verification/Metadata/Vault rows are never deleted, and only ever mutated in the narrow, already-tested ways each WP's own Service layer performs).
17. **What relationships are required to reconstruct Vault Artifact → Metadata → Verification → Download → Execution → Job → Source?** Exactly the traversal implemented by `AcquisitionRecordService::get_provenance` (Section 7) — no relationship needed here that was not already either a foreign key or an existing repository filter.
18. **Which relationships already exist and therefore must NOT be duplicated?** All of them except the one relationship that had no home anywhere: "this Download Session has a permanent, durable identity distinct from the Download Session row itself." That is the one gap this WP closes.

---

## 5. Immutability

SDD-R015 Section 4.1 states Acquisition Records "shall never be modified after creation." Taken completely literally, this is in tension with Section 5's own multi-stage lifecycle, which necessarily requires *some* field to change over the record's life. This tension is **documented here explicitly rather than silently resolved**, per this WP's own instruction not to let documentation and implementation silently diverge.

**The resolution adopted**: immutability applies to the record's *identity* — `id` (the permanent Acquisition Identifier) and `download_session_id` (which acquisition event this is) never change after `create()` returns, and no code path anywhere in this module can rewrite either. `status`/`error_message`/`updated_at` are the one deliberately-mutable summary field group, updated in place exactly once per stage transition via `IAcquisitionRecordRepository::update_status` — mirroring the exact pattern every other domain table in this codebase already uses (an `AcquisitionJob`'s own `status` mutates in place while `acquisition_job_execution_history` separately, and immutably, preserves every transition; a `Download`'s `status` mutates in place while its `error_message` is set once and never erased). The underlying facts that justify each transition (the Download's own outcome, the Verification's own outcome) are themselves recorded immutably on those other rows, which is what actually satisfies "permanent historical identity" in spirit.

A full append-only Custody Event log (SDD-R015 Sections 12-13) — which would let every transition be reconstructed independently of `acquisition_job_execution_history` and the other tables' own timestamps — was considered and explicitly **not** built: `acquisition_job_execution_history` already covers the Job-level portion of this need, and a second, more generic event log duplicating what the existing per-stage tables' own status/timestamp columns already capture is exactly the kind of speculative infrastructure this WP's own scope instructions prohibit absent a demonstrated requirement. Classified **DEFERRED** (see Gap Classification).

---

## 6. Domain Model — what was implemented, and why less than SDD-R015's full text

`AcquisitionRecord` (`include/oep/acquisition/provenance/acquisition_record.hpp`):

| Field | Justification |
|---|---|
| `id` (UUID) | SDD-R015 §6, mandatory |
| `download_session_id` | The record's anchor (Section 3) |
| `status` | SDD-R015 §5's lifecycle, plus `Failed` (Section 5 above) |
| `error_message` | Existing codebase convention (every other domain table has one), required by WP-018 §14's own failure-representation instruction |
| `created_at` / `updated_at` | Existing codebase convention on every domain table |

Every other SDD-R015 field (Section 8's Acquisition Method/User/Workstation/Organization/Endpoint Identifier/Referrer/Redirect Chain/Content Encoding; Section 9's SHA-512/BLAKE3/Hash Timestamp; Section 10's DNS/TLS/HTTP headers/server info; Section 11's licensing) is **not implemented**, because:

- None of it is captured anywhere upstream today — `HttpConnector` (the one real network connector) does not record Referrer, redirect chain, DNS, or TLS fingerprint information at all (confirmed by WP-017's audit of that connector), so adding these columns now would create empty, permanently-`NULL` fields with no writer — exactly the "speculative metadata" this WP's own instructions prohibit.
- SHA-512/BLAKE3 are not computed anywhere in this codebase; `integrity_verifications` stores SHA-256 only (WORK_PACKAGE-007's own explicit scope).
- Licensing is explicitly SDD-R015 Section 11's own "independent from provenance" concern — a distinct future work package, not part of establishing the missing identity/relationship this WP targets.

Classified **FUTURE** in the Gap Classification below, contingent on the connectors/verification layers that would need to produce this data first — building the columns before the producers exist would be scope creep, not foundation-laying.

---

## 7. Provenance Model

`AcquisitionRecordService::get_provenance` (`src/provenance/acquisition_record_service.cpp`) builds the full chain purely by traversal, with **zero new columns added to any pre-existing table**:

```text
Vault Entry (reference_vault, unmodified)
    ^ found via: vault_.list(VaultFilter{.metadata_id = <metadata.id>})
    |
Artifact Metadata (artifact_metadata, unmodified)
    ^ found via: metadata_repository_.list(MetadataFilter{.verification_id = <verification.id>})
    |
Integrity Verification (integrity_verifications, unmodified)
    ^ found via: verifications_.list(VerificationFilter{.download_session_id = record.download_session_id})
    |
Acquisition Record (acquisition_records, NEW -- the one table this WP adds)
    | .download_session_id
    v
Download Session (download_sessions, unmodified)
    | .job_id
    v
Acquisition Job (acquisition_jobs, unmodified)          Execution History (acquisition_job_execution_history,
    | .source_id                                         unmodified) -- job_history_.list_for_job(job.id)
    v
Official Source (official_sources, unmodified)
```

`reference_vault` is **not** given a new `acquisition_record_id` column, even though that would have made the top-down traversal (Vault Entry → Acquisition Record) a single indexed lookup instead of a two-hop one through `metadata_id`/`verification_id`. This was a deliberate choice: `reference_vault.download_session_id` already exists (from V8) and is exactly what `acquisition_records.download_session_id` is also keyed on, so `IAcquisitionRecordRepository::find_by_download_session_id(entry.download_session_id)` already answers "which Acquisition Record owns this Vault Entry" with no schema change at all — precisely the "traverse existing links instead of adding duplicate columns" instruction this WP was given. `GET /acquisition-records/{id}/provenance` is the REST-exposed form of this traversal, in the top-down (Acquisition Record → everything else) direction, which is the direction every caller who already has a record id will want; a Vault-Entry-first caller resolves the record id first via the same repository method (currently used internally only — no REST route currently exposes a raw `download_session_id → acquisition_record` lookup, since no known caller needs it yet; classified **FUTURE**, trivial to add if one materializes).

---

## 8. Lifecycle — where each transition is triggered, and why at the route layer

`AcquisitionRecordService` is deliberately **not** injected into `DownloadService`, `IntegrityVerificationService`, `MetadataExtractionService`, or `ReferenceVaultService`'s own constructors. Instead, `src/api/server.cpp`'s route handlers for `POST /downloads`, `POST /verifications`, `POST /metadata`, and `POST /vault` each make one additional, best-effort call immediately after their existing service call returns:

| Route | Call | Effect |
|---|---|---|
| `POST /downloads` | `record_download_outcome(download)` | Creates the record: `Acquired` if `Completed`, `Failed` (with the Download's own error) if `Failed` |
| `POST /verifications` | `record_verification_outcome(verification)` | Advances to `Verified` or `Failed` |
| `POST /metadata` | `record_metadata_outcome(metadata)` | Advances to `Failed` only on extraction failure — SDD-R015's lifecycle has no distinct "metadata extracted" stage, so success leaves the record `Verified` |
| `POST /vault` | `record_vault_publication(entry)` | Advances to `Published` — only ever called on success, since `ReferenceVaultService::publish` throws and persists nothing on any precondition failure (WORK_PACKAGE-009's own design, unchanged) |

**Why the route layer, not the service layer**: each of the four existing services is already independently unit-tested, already has an established public contract, and architecturally sits *below* the provenance concern this WP adds (Acquisition Record spans all four stages; none of the four stages should need to know a concept above them exists). Wiring provenance recording into all four constructors would have meant editing four already-correct, already-tested classes' public contracts, and every test file that constructs any of them (`test_download_service.cpp`, `test_verification_service.cpp`, `test_metadata_extraction_service.cpp`, `test_reference_vault_service.cpp`) — for a concern that is purely additive. `server.cpp` is the one place in this codebase that already assembles every stage together (see `register_routes`'s own existing signature, which already receives all eight prior service/registry pointers) — it is the correct, minimal seam, not a compromise.

**Why best-effort**: every one of the four calls above is wrapped in a try/catch (`record_provenance_best_effort`) that logs and swallows any exception. An Acquisition Record write failure (a transient database error, for instance) must never turn an otherwise-successful `/downloads`, `/verifications`, `/metadata`, or `/vault` request into a failure — that would be a new precondition WP-006/007/008/009 never had, in direct violation of this WP's own "preserve existing public contracts" instruction. Verified directly: **zero lines changed** in `download_service.hpp/.cpp`, `integrity_verification_service.hpp/.cpp`, `metadata_extraction_service.hpp/.cpp`, or `reference_vault_service.hpp/.cpp`; every one of their existing tests passes unmodified (see Test Results in the companion report).

---

## 9. ADR-0008 traceability

Re-investigated per this WP's explicit instruction. `ADR-0008` is cited by name in `WORK_PACKAGE_006.md`'s dependency list, `WORK_PACKAGE_009.md`'s dependency list, and `IConnector::fetch`'s own doc comment (`connector.hpp`) as "Connector Content Retrieval Interface" — but:

- `Glob("**/ADR-0008*")` across the entire monorepo: zero matches.
- `docs/decisions/` in `services/acquisition` contains `ADR-0001.md`, `ADR-0002-PROPOSED-CONNECTOR-CONTENT-RETRIEVAL.md`, and `ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md` — no ADR-0004 through ADR-0008 exist anywhere.
- `ADR-0002`'s own title ("PROPOSED Connector Content Retrieval") and content closely match what `IConnector::fetch` actually implements, strongly suggesting `ADR-0002`'s proposal is what was later implemented, but it is explicitly marked **PROPOSED**, not **RATIFIED**, and is numbered `0002`, not `0008` — the citations elsewhere in this codebase to "ADR-0008" do not resolve to it or to anything else.

**Conclusion, unchanged from WP-017's own finding**: this is a genuine, unresolved traceability gap in the repository's own documentation, not something fabricated by this audit, and not something this WP is authorized to resolve by inventing the missing document (this WP's own instructions explicitly forbid fabricating ADR-0008). No new ADR was created for this gap — creating one would mean *guessing* at a decision that was apparently made by a person, at some point, outside this repository's own record, which is a different and riskier act than documenting that the citation is broken. **Classified: unresolved traceability gap, OUT OF SCOPE for this WP to fix.**

---

## 10. Gap Classification

| Capability (SDD-R015) | Status |
|---|---|
| Permanent Acquisition Identifier | **IMPLEMENTED** |
| Pending → Acquired → Verified → Published lifecycle | **IMPLEMENTED** |
| Failure representation | **IMPLEMENTED** (added alongside the documented happy path — see Section 5) |
| Archived lifecycle state | **DEFERRED** — no archival capability exists anywhere in this service (matches WP-017's own disclosed Vault-side gap); the CHECK constraint accepts the value, no code path sets it |
| Reference to Official Source / Job / Execution / Download / Verification / Metadata / Vault | **IMPLEMENTED** (via traversal, not duplicated columns) |
| One provenance-chain-reconstruction endpoint | **IMPLEMENTED** (`GET /acquisition-records/{id}/provenance`) |
| Multiple Acquisition Records per artifact / revision detection | **IMPLEMENTED** (structural consequence of the Download-Session anchor — no new mechanism needed) |
| Retry semantics | **IMPLEMENTED** (unchanged pre-existing behavior; documented, not modified) |
| Acquisition Method / User / Workstation / Organization / Endpoint Identifier / Referrer / Redirect Chain / Content Encoding | **FUTURE** — no upstream producer exists yet (Section 6) |
| SHA-512 / BLAKE3 / Hash Timestamp | **FUTURE** — not computed anywhere in this codebase yet |
| DNS / resolved IP / TLS certificate / fingerprint / HTTP headers / server info | **FUTURE** — `HttpConnector` does not capture any of this today; capturing it is squarely ADR-0003's own territory (connector scope), not this WP's |
| Licensing metadata | **FUTURE** / **OUT OF SCOPE** — SDD-R015 §11 itself scopes this as independent of provenance; a distinct future work package |
| Chain of Custody / Custody Event log | **DEFERRED** — `acquisition_job_execution_history` already covers the Job-level portion of this need; a fully generic event log was assessed and not built (Section 5) |
| Digital signatures / blockchain timestamping / enterprise audit / regulatory compliance / multi-party verification / distributed acquisition | **OUT OF SCOPE** — SDD-R015 §19's own "Future Extensions," explicitly speculative |
| ADR-0008 traceability | **BLOCKED** — genuine, pre-existing, unresolved documentation gap; not fabricated, not resolved by this WP |
| Vault-Entry-first raw lookup REST route (no known caller yet) | **FUTURE** — trivial to add via the already-existing `find_by_download_session_id` if a caller materializes |
