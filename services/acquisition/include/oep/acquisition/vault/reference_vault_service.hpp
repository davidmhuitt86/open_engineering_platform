#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_job_repository.hpp"
#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/downloads/download_repository.hpp"
#include "oep/acquisition/integrity/verification_repository.hpp"
#include "oep/acquisition/metadata/metadata_repository.hpp"
#include "oep/acquisition/vault/vault_repository.hpp"

namespace oep::acquisition::vault {

/// Orchestrates WORK_PACKAGE-009's Engineering Reference Vault: resolves a
/// `metadata_id` through the full Metadata -> Verification -> Download ->
/// Acquisition Job chain, re-validates every precondition, copies the
/// artifact into a content-addressable permanent store, and records a
/// single, immutable VaultEntry -- entirely synchronously, mirroring
/// `metadata::MetadataExtractionService::extract` (see README.md
/// "Implementation Decisions" for why no background thread is used, and
/// for why -- unlike every prior stage -- a failed precondition rejects
/// the request instead of persisting a `Failed` row).
///
/// Depends on `IVaultRepository`, `metadata::IMetadataRepository`,
/// `integrity::IVerificationRepository`, `downloads::IDownloadRepository`,
/// and `acquisition::IAcquisitionJobRepository` (interfaces, not concrete
/// Postgres classes) so it can be unit-tested against fakes without a live
/// database, mirroring `metadata::MetadataExtractionService`.
class ReferenceVaultService {
 public:
  ReferenceVaultService(IVaultRepository& vault, metadata::IMetadataRepository& metadata_repository,
                          integrity::IVerificationRepository& verifications,
                          downloads::IDownloadRepository& downloads,
                          acquisition::IAcquisitionJobRepository& jobs, common::StorageConfig storage_config);

  /// Throws (WORK_PACKAGE-009 "Validation Rules", checked in this order):
  /// - ValidationError if `metadata_id` is missing.
  /// - UnknownMetadataError if `metadata_id` does not reference an
  ///   existing ArtifactMetadata record.
  /// - MetadataNotSuccessfulError if that record's status is not
  ///   `Extracted`.
  /// - AlreadyPublishedError if `metadata_id` has already been published.
  /// - VerificationNotSuccessfulError if the Metadata's Verification does
  ///   not exist or is not `Verified`.
  /// - ArtifactNotFoundError if the Download's artifact cannot be located
  ///   or read.
  /// - ArtifactHashMismatchError if the artifact's recomputed SHA-256
  ///   does not match the Verification record.
  /// - InvalidVaultPathError if the computed content-addressable path
  ///   cannot be created/written.
  ///
  /// On success, synchronously copies the artifact into the Reference
  /// Vault (skipping the copy, but still creating a new VaultEntry row,
  /// if that content hash is already stored -- WORK_PACKAGE-009's
  /// content-addressable dedup) and returns the created, already-
  /// `Published` VaultEntry.
  VaultEntry publish(const nlohmann::json& body);

  std::optional<VaultEntry> get(const std::string& id);

  std::vector<VaultEntry> list(const VaultFilter& filter);

 private:
  IVaultRepository& vault_;
  metadata::IMetadataRepository& metadata_repository_;
  integrity::IVerificationRepository& verifications_;
  downloads::IDownloadRepository& downloads_;
  acquisition::IAcquisitionJobRepository& jobs_;
  common::StorageConfig storage_config_;
};

}  // namespace oep::acquisition::vault
