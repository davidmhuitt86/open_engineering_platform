#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/metadata/artifact_metadata.hpp"

namespace oep::acquisition::metadata {

/// Optional filters for `GET /metadata`. Every field is optional; unset
/// fields impose no constraint.
struct MetadataFilter {
  std::optional<ExtractionStatus> status;
  std::optional<std::string> verification_id;
};

/// Abstracts persistence for `ArtifactMetadata` so
/// `MetadataExtractionService` can be unit-tested against a fake without a
/// live PostgreSQL instance, mirroring `integrity::IVerificationRepository`.
class IMetadataRepository {
 public:
  virtual ~IMetadataRepository() = default;

  /// Inserts `metadata` and returns the stored row (`id`/`created_at`/
  /// `updated_at` populated by the database). Throws
  /// UnknownVerificationError if `metadata.verification_id` does not
  /// reference an existing Verification.
  virtual ArtifactMetadata create(const ArtifactMetadata& metadata) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<ArtifactMetadata> find_by_id(const std::string& id) = 0;

  virtual std::vector<ArtifactMetadata> list(const MetadataFilter& filter) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<ArtifactMetadata> update(const std::string& id, const ArtifactMetadata& metadata) = 0;
};

}  // namespace oep::acquisition::metadata
