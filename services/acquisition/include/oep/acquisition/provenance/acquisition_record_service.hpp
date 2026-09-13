#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_job_repository.hpp"
#include "oep/acquisition/acquisition/job_execution_history_repository.hpp"
#include "oep/acquisition/downloads/download.hpp"
#include "oep/acquisition/downloads/download_repository.hpp"
#include "oep/acquisition/integrity/verification.hpp"
#include "oep/acquisition/integrity/verification_repository.hpp"
#include "oep/acquisition/metadata/artifact_metadata.hpp"
#include "oep/acquisition/metadata/metadata_repository.hpp"
#include "oep/acquisition/provenance/acquisition_record_repository.hpp"
#include "oep/acquisition/registry/official_source_repository.hpp"
#include "oep/acquisition/vault/vault_entry.hpp"
#include "oep/acquisition/vault/vault_repository.hpp"

namespace oep::acquisition::provenance {

/// Orchestrates WP-018's Acquisition Record & Provenance Foundation.
///
/// Deliberately NOT wired into the constructors of `DownloadService`,
/// `IntegrityVerificationService`, `MetadataExtractionService`, or
/// `ReferenceVaultService` -- doing so would change four existing, already
/// independently-tested services' public contracts for a concern (durable
/// cross-stage provenance) that architecturally sits above all four, not
/// inside any one of them. Instead, the API layer (`server.cpp`, the one
/// place that already assembles every pipeline stage together) calls this
/// service's `record_*_outcome` methods immediately after each existing
/// service call returns, and every call is best-effort: an exception raised
/// while recording provenance is caught and logged at the route layer, and
/// never surfaces as a failure of the underlying (pre-existing,
/// WP-006/007/008/009-owned) request. See
/// docs/audits/ACQUISITION_RECORD_IMPLEMENTATION_AUDIT.md's "Lifecycle"
/// section for the full rationale.
///
/// Depends on every repository interface needed to create/update
/// Acquisition Records and to traverse the provenance chain outward from
/// one (interfaces, not concrete Postgres classes, so it can be
/// unit-tested against fakes without a live database, mirroring every
/// other Service in this codebase).
class AcquisitionRecordService {
 public:
  AcquisitionRecordService(IAcquisitionRecordRepository& records, downloads::IDownloadRepository& downloads,
                            acquisition::IAcquisitionJobRepository& jobs,
                            acquisition::IJobExecutionHistoryRepository& job_history,
                            integrity::IVerificationRepository& verifications,
                            metadata::IMetadataRepository& metadata_repository, vault::IVaultRepository& vault,
                            registry::IOfficialSourceRepository& sources);

  /// Called once, immediately after `DownloadService::start_download`
  /// returns (regardless of outcome) -- creates the one Acquisition Record
  /// for `download.id` (SDD-R015 Section 6: a fresh, permanent Acquisition
  /// Identifier), already resolved to `Acquired` or `Failed` depending on
  /// `download.status`. Any other `download.status` value (unreachable via
  /// the synchronous `start_download` today -- see its own header comment)
  /// is recorded as `Pending`.
  AcquisitionRecord record_download_outcome(const downloads::Download& download);

  /// Called after `IntegrityVerificationService::verify` returns. Finds the
  /// Acquisition Record for `verification.download_session_id` and advances
  /// it to `Verified` or `Failed`. A no-op (returns nullopt) if no
  /// Acquisition Record exists for that Download Session -- true for every
  /// Download Session created before WP-018 shipped, which have no
  /// Acquisition Record to advance and must not cause this call to fail.
  std::optional<AcquisitionRecord> record_verification_outcome(const integrity::Verification& verification);

  /// Called after `MetadataExtractionService::extract` returns. SDD-R015's
  /// lifecycle has no distinct "metadata extracted" stage, so a successful
  /// extraction leaves the Acquisition Record's status untouched (still
  /// `Verified`) -- only a Failed extraction advances it, to `Failed`, since
  /// a failed extraction means the chain can never reach `POST /vault`
  /// (WORK_PACKAGE-009's own "Metadata extraction shall be successful"
  /// precondition). Same no-op-if-missing behavior as
  /// `record_verification_outcome`.
  std::optional<AcquisitionRecord> record_metadata_outcome(const metadata::ArtifactMetadata& item);

  /// Called after `ReferenceVaultService::publish` succeeds (it is never
  /// called on failure -- `publish` throws and persists nothing on any
  /// precondition failure, so there is no Vault-stage "Failed" outcome to
  /// record here; see `vault::ReferenceVaultService`'s own header comment).
  /// Advances the Acquisition Record for `entry.download_session_id` to
  /// `Published`. Same no-op-if-missing behavior as the above.
  std::optional<AcquisitionRecord> record_vault_publication(const vault::VaultEntry& entry);

  std::optional<AcquisitionRecord> get(const std::string& id);

  std::vector<AcquisitionRecord> list(const AcquisitionRecordFilter& filter);

  /// Builds the full provenance chain for `id` (WP-018 Section 10): the
  /// Acquisition Record itself, plus its Download Session, Acquisition Job
  /// (and that Job's Official Source and execution history), every
  /// Integrity Verification for that Download Session, every Artifact
  /// Metadata record for those Verifications, and the Reference Vault Entry
  /// (if published) -- each resolved by traversing existing foreign
  /// keys/filters, never by a duplicated column. Empty optional if `id`
  /// does not exist.
  std::optional<nlohmann::json> get_provenance(const std::string& id);

 private:
  IAcquisitionRecordRepository& records_;
  downloads::IDownloadRepository& downloads_;
  acquisition::IAcquisitionJobRepository& jobs_;
  acquisition::IJobExecutionHistoryRepository& job_history_;
  integrity::IVerificationRepository& verifications_;
  metadata::IMetadataRepository& metadata_repository_;
  vault::IVaultRepository& vault_;
  registry::IOfficialSourceRepository& sources_;
};

}  // namespace oep::acquisition::provenance
