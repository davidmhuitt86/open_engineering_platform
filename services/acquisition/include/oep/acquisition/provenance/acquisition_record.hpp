#pragma once

#include <optional>
#include <string>

namespace oep::acquisition::provenance {

/// WP-018's Acquisition Record lifecycle (SDD-R015 Section 5: "Pending ->
/// Acquired -> Verified -> Published to Vault -> Archived"). `Failed` is
/// added alongside that documented happy path -- SDD-R015 Section 5's own
/// diagram shows only the success path, but Section 14 of WP-018 explicitly
/// requires failure to be representable, and every other domain table in
/// this codebase (AcquisitionJob, Download, Verification, ArtifactMetadata)
/// already pairs its happy-path states with exactly one `Failed` terminal --
/// this follows that same established, established precedent rather than
/// inventing a new shape.
///
/// `Archived` has no code path that sets it today (no archival capability
/// exists anywhere in this service yet -- WP-017's audit already flagged
/// this as a disclosed M1 gap for the Reference Vault, and the same gap
/// applies here). It is included in the enum/CHECK constraint because it is
/// part of SDD-R015's authoritative lifecycle text, not because this WP
/// implements it -- see the WP-018 audit's Gap Classification for its
/// explicit FUTURE status.
enum class AcquisitionRecordStatus {
  Pending,
  Acquired,
  Verified,
  Published,
  Failed,
  Archived,
};

[[nodiscard]] std::string to_string(AcquisitionRecordStatus status);
[[nodiscard]] std::optional<AcquisitionRecordStatus> acquisition_record_status_from_string(
    const std::string& text);

/// The durable acquisition-level provenance anchor WP-018 introduces
/// (SDD-R015's "Acquisition Record"). `id` is the externally-visible UUID
/// (SDD-R015 Section 6's "Acquisition Identifier"), mirroring every prior
/// domain model.
///
/// `download_session_id` is the record's one identity-defining
/// relationship: exactly one Acquisition Record exists per Download Session
/// (enforced by a UNIQUE constraint at the database layer -- see
/// migrations/V10__acquisition_records.sql), created at the moment a
/// download attempt begins (`DownloadService::start_download`, see
/// `AcquisitionRecordService::record_download_outcome`). This is a
/// deliberate design choice, not an assumption: SDD-R015 Section 8's own
/// per-acquisition metadata list (Source URL, Referrer, Redirect Chain,
/// MIME Type, ETag, Last-Modified) describes facts specific to one fetch
/// attempt, not to the (potentially retried, potentially multi-download)
/// Acquisition Job as a whole -- so one Acquisition Record per Download
/// Session, not per Job, is what makes retry semantics (WP-018 Section 14)
/// unambiguous: a second `POST /downloads` for the same job_id is a second,
/// independent acquisition event, exactly as SDD-R015 Section 15 ("Duplicate
/// Acquisitions shall not invalidate Acquisition Records... each acquisition
/// event remains historically significant") requires.
///
/// Every other relationship in the target provenance chain (Official
/// Source, Acquisition Job, Execution history, Integrity Verification,
/// Metadata Extraction, Reference Vault) is deliberately NOT duplicated as
/// a column here -- each is already reachable by traversing existing
/// foreign keys starting from `download_session_id` (see
/// `AcquisitionRecordService::get_provenance`), per this WP's own
/// instruction to traverse existing links rather than add duplicate
/// columns.
///
/// `status` is the one field this record mutates after creation --
/// SDD-R015 Section 4.1's "never modified after creation" is interpreted
/// here (see docs/audits/ACQUISITION_RECORD_IMPLEMENTATION_AUDIT.md's
/// Immutability section for the full reasoning) as applying to the
/// record's *identity* (`id`, `download_session_id`, `created_at`), which
/// truly never change once written -- not to the single current-status
/// summary field every other domain table in this codebase also mutates in
/// place while keeping the underlying facts that justified each transition
/// (the Download's own outcome, the Verification's own outcome, etc.)
/// immutably recorded on those other, already-immutable-after-write rows.
struct AcquisitionRecord {
  std::string id;
  std::string download_session_id;
  AcquisitionRecordStatus status = AcquisitionRecordStatus::Pending;
  std::optional<std::string> error_message;
  std::string created_at;
  std::string updated_at;
};

}  // namespace oep::acquisition::provenance
