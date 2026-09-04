#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/downloads/download_repository.hpp"
#include "oep/acquisition/integrity/verification_repository.hpp"
#include "oep/acquisition/metadata/metadata_repository.hpp"

namespace oep::acquisition::metadata {

/// Orchestrates WORK_PACKAGE-008's Metadata Extraction Engine: resolves a
/// `verification_id` against the Integrity Verification Engine, resolves
/// the underlying artifact via the Engineering Downloader, runs File Type
/// Detection and Basic Document Inspection against it, and records the
/// outcome as an ArtifactMetadata row -- entirely synchronously, mirroring
/// `integrity::IntegrityVerificationService::verify` (see README.md
/// "Implementation Decisions" for why no background thread is used).
///
/// Depends on `IMetadataRepository`, `integrity::IVerificationRepository`,
/// and `downloads::IDownloadRepository` (interfaces, not concrete Postgres
/// classes) so it can be unit-tested against fakes without a live
/// database, mirroring `integrity::IntegrityVerificationService`.
class MetadataExtractionService {
 public:
  MetadataExtractionService(IMetadataRepository& metadata, integrity::IVerificationRepository& verifications,
                              downloads::IDownloadRepository& downloads);

  /// Throws (WORK_PACKAGE-008 "Validation Rules", checked in this order):
  /// - ValidationError if `verification_id` is missing.
  /// - UnknownVerificationError if `verification_id` does not reference an
  ///   existing Verification.
  /// - VerificationNotSuccessfulError if that Verification's status is not
  ///   `Verified`.
  ///
  /// On success, synchronously detects the artifact's file type, runs
  /// Basic Document Inspection, and returns the ArtifactMetadata in its
  /// final state (Extracted or Failed) -- a missing or unreadable artifact
  /// is recorded as Failed rather than thrown, and an unrecognized file
  /// type is recorded as Extracted with type "Unknown" rather than Failed
  /// (WORK_PACKAGE-008: "Unsupported file types shall still produce
  /// metadata when possible").
  ArtifactMetadata extract(const nlohmann::json& body);

  std::optional<ArtifactMetadata> get(const std::string& id);

  std::vector<ArtifactMetadata> list(const MetadataFilter& filter);

 private:
  IMetadataRepository& metadata_;
  integrity::IVerificationRepository& verifications_;
  downloads::IDownloadRepository& downloads_;
};

}  // namespace oep::acquisition::metadata
