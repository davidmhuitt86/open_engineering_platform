#include "oep/acquisition/vault/reference_vault_service.hpp"

#include <filesystem>
#include <system_error>

#include "oep/acquisition/common/time.hpp"
#include "oep/acquisition/integrity/hashing.hpp"
#include "oep/acquisition/metadata/artifact_metadata.hpp"
#include "oep/acquisition/vault/validation.hpp"
#include "oep/acquisition/vault/vault_errors.hpp"
#include "oep/acquisition/vault/vault_path.hpp"

namespace oep::acquisition::vault {

ReferenceVaultService::ReferenceVaultService(IVaultRepository& vault,
                                                metadata::IMetadataRepository& metadata_repository,
                                                integrity::IVerificationRepository& verifications,
                                                downloads::IDownloadRepository& downloads,
                                                acquisition::IAcquisitionJobRepository& jobs,
                                                common::StorageConfig storage_config)
    : vault_(vault),
      metadata_repository_(metadata_repository),
      verifications_(verifications),
      downloads_(downloads),
      jobs_(jobs),
      storage_config_(std::move(storage_config)) {}

VaultEntry ReferenceVaultService::publish(const nlohmann::json& body) {
  const PublishArtifactRequest request = parse_and_validate_publish(body);

  const auto artifact_metadata = metadata_repository_.find_by_id(request.metadata_id);
  if (!artifact_metadata.has_value()) {
    throw UnknownMetadataError(request.metadata_id);
  }
  if (artifact_metadata->status != metadata::ExtractionStatus::Extracted) {
    throw MetadataNotSuccessfulError(request.metadata_id, metadata::to_string(artifact_metadata->status));
  }

  const auto already_published = vault_.list(VaultFilter{.metadata_id = request.metadata_id});
  if (!already_published.empty()) {
    throw AlreadyPublishedError(request.metadata_id);
  }

  const auto verification = verifications_.find_by_id(artifact_metadata->verification_id);
  if (!verification.has_value() || verification->status != integrity::VerificationStatus::Verified) {
    throw VerificationNotSuccessfulError(artifact_metadata->verification_id);
  }

  const auto download = downloads_.find_by_id(verification->download_session_id);
  const std::filesystem::path artifact_path =
      download.has_value() ? std::filesystem::path(download->local_storage_path) : std::filesystem::path();

  if (artifact_path.empty() || !std::filesystem::exists(artifact_path)) {
    throw ArtifactNotFoundError(artifact_path.string());
  }

  const auto computed_hash = integrity::hash_file_sha256(artifact_path);
  if (!computed_hash.has_value()) {
    throw ArtifactNotFoundError(artifact_path.string());
  }
  if (computed_hash->sha256_hex != verification->sha256_hash) {
    throw ArtifactHashMismatchError(verification->sha256_hash, computed_hash->sha256_hex);
  }

  const std::filesystem::path vault_path =
      compute_vault_path(storage_config_.root_path, computed_hash->sha256_hex);
  if (vault_path.empty()) {
    throw InvalidVaultPathError(computed_hash->sha256_hex);
  }

  std::error_code error;
  // AUDIT WP-017 Section 8 -- tracked separately from "did the file already
  // exist" so the catch block below can tell whether *this* call is the one
  // that materialized the file (and must therefore clean it up on failure)
  // versus a dedup hit against content another Vault Entry already owns.
  const bool copied_by_this_call = !std::filesystem::exists(vault_path);
  if (copied_by_this_call) {
    std::filesystem::create_directories(vault_path.parent_path(), error);
    if (error) {
      throw InvalidVaultPathError(vault_path.string());
    }
    // Content-addressable dedup (WORK_PACKAGE-009): if this exact content
    // hash is already stored, the copy is skipped entirely -- only a new
    // VaultEntry row is created, referencing the existing immutable file.
    std::filesystem::copy_file(artifact_path, vault_path, error);
    if (error) {
      throw InvalidVaultPathError(vault_path.string());
    }
  }

  std::string source_id;
  if (download.has_value()) {
    const auto job = jobs_.find_by_id(download->job_id);
    if (job.has_value()) {
      source_id = job->source_id;
    }
  }

  VaultEntry entry;
  entry.metadata_id = request.metadata_id;
  entry.verification_id = artifact_metadata->verification_id;
  entry.download_session_id = verification->download_session_id;
  entry.source_id = source_id;
  entry.vault_path = vault_path.string();
  entry.sha256_hash = computed_hash->sha256_hex;
  entry.mime_type = artifact_metadata->mime_type;
  entry.file_size_bytes = computed_hash->file_size_bytes;
  entry.status = VaultEntryStatus::Published;
  entry.published_at = common::current_timestamp_utc();

  // AUDIT WP-017 Section 8 -- the file copy above and this database insert
  // are not one atomic operation (no distributed transaction spans a
  // filesystem write and a PostgreSQL commit). If the insert throws after a
  // fresh copy (e.g. a concurrent publish of the same metadata_id racing
  // past the earlier `already_published` check and winning the database's
  // own UNIQUE constraint, or a transient connection failure), the copy
  // that already happened must not be left behind as a file with zero
  // Vault Entry rows referencing it. Only the copy *this call* performed is
  // removed -- a dedup hit reuses a file another, already-committed Vault
  // Entry legitimately owns, and must never be deleted out from under it.
  try {
    return vault_.create(entry);
  } catch (...) {
    if (copied_by_this_call) {
      std::error_code cleanup_error;
      std::filesystem::remove(vault_path, cleanup_error);
    }
    throw;
  }
}

std::optional<VaultEntry> ReferenceVaultService::get(const std::string& id) {
  return vault_.find_by_id(id);
}

std::vector<VaultEntry> ReferenceVaultService::list(const VaultFilter& filter) {
  return vault_.list(filter);
}

}  // namespace oep::acquisition::vault
