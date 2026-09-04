#pragma once

#include <stdexcept>
#include <string>

namespace oep::acquisition::vault {

/// Thrown by `ReferenceVaultService::publish` when `metadata_id` does not
/// reference an existing ArtifactMetadata record (WORK_PACKAGE-009
/// Validation Rules: "Metadata record shall exist").
class UnknownMetadataError : public std::runtime_error {
 public:
  explicit UnknownMetadataError(const std::string& metadata_id)
      : std::runtime_error("metadata_id does not reference an existing ArtifactMetadata record: " +
                            metadata_id) {}
};

/// Thrown when the referenced ArtifactMetadata's status is not `Extracted`
/// (WORK_PACKAGE-009 Validation Rules: "Metadata extraction shall be
/// successful").
class MetadataNotSuccessfulError : public std::runtime_error {
 public:
  MetadataNotSuccessfulError(const std::string& metadata_id, const std::string& metadata_status)
      : std::runtime_error("Metadata extraction is not successful (status '" + metadata_status +
                            "'): " + metadata_id) {}
};

/// Thrown when `metadata_id` has already been published (WORK_PACKAGE-009
/// has no "Re-publish" Functional Requirement, unlike WORK_PACKAGE-007/008's
/// explicit re-verification/re-extraction support -- see README.md
/// "Implementation Decisions"). A state conflict on an otherwise-valid,
/// otherwise-successful reference.
class AlreadyPublishedError : public std::runtime_error {
 public:
  explicit AlreadyPublishedError(const std::string& metadata_id)
      : std::runtime_error("metadata_id has already been published to the Reference Vault: " + metadata_id) {}
};

/// Thrown when the Metadata's referenced Verification does not exist or is
/// not `Verified` (WORK_PACKAGE-009 Validation Rules: "Verification shall
/// be successful"). Both cases collapse to one error: a missing
/// Verification can only happen if the database's own foreign keys have
/// been violated (an invariant this service does not otherwise need to
/// distinguish a reason for).
class VerificationNotSuccessfulError : public std::runtime_error {
 public:
  explicit VerificationNotSuccessfulError(const std::string& verification_id)
      : std::runtime_error("Verification is not successful or does not exist: " + verification_id) {}
};

/// Thrown when the Download's artifact cannot be located or read
/// (WORK_PACKAGE-009 Validation Rules: "Published artifact shall exist").
/// Unlike WORK_PACKAGE-007/008's equivalent checks, this rejects the
/// publish request rather than recording a Failed VaultEntry -- see
/// `vault_entry.hpp` and README.md "Implementation Decisions".
class ArtifactNotFoundError : public std::runtime_error {
 public:
  explicit ArtifactNotFoundError(const std::string& path)
      : std::runtime_error("Published artifact does not exist or could not be read: " + path) {}
};

/// Thrown when the artifact's freshly-recomputed SHA-256 does not match
/// the Verification record's stored hash (WORK_PACKAGE-009 Validation
/// Rules: "SHA-256 shall match the Verification record before
/// publication") -- the artifact may have changed since it was verified.
class ArtifactHashMismatchError : public std::runtime_error {
 public:
  ArtifactHashMismatchError(const std::string& expected_hash, const std::string& actual_hash)
      : std::runtime_error("Artifact SHA-256 does not match the Verification record: expected " +
                            expected_hash + ", got " + actual_hash) {}
};

/// Thrown when the computed content-addressable Vault path cannot be
/// created/written (WORK_PACKAGE-009 Validation Rules: "Vault path shall
/// validate"), mirroring `downloads::InvalidDestinationError`.
class InvalidVaultPathError : public std::runtime_error {
 public:
  explicit InvalidVaultPathError(const std::string& vault_path)
      : std::runtime_error("Vault path did not validate: " + vault_path) {}
};

}  // namespace oep::acquisition::vault
