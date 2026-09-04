#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace oep::acquisition::vault {

/// WORK_PACKAGE-009's "Publication Status". Unlike every prior stage's
/// status enum (`downloads::DownloadStatus`, `integrity::VerificationStatus`,
/// `metadata::ExtractionStatus`), this has a single value today, by
/// design: WORK_PACKAGE-009's Validation Rules (unlike WORK_PACKAGE-007's
/// "Missing files shall fail verification" or WORK_PACKAGE-008's
/// "Metadata extraction failures shall be recorded") never say a failed
/// publication attempt shall be recorded -- every rule is phrased as a
/// bare precondition ("shall exist," "shall be successful," "shall
/// match"), and "Publish Verified Artifact" is the only creation-side
/// Functional Requirement (no "Re-publish", unlike WORK_PACKAGE-007/008's
/// explicit "Verify Existing Hashes"/"Re-extract Metadata"). So a failed
/// precondition rejects the `POST /vault` request outright (see
/// `vault_errors.hpp`) rather than persisting a `Failed` row -- a
/// `VaultEntry` is only ever created already `Published`. See README.md
/// "Implementation Decisions".
enum class VaultEntryStatus {
  Published,
};

[[nodiscard]] std::string to_string(VaultEntryStatus status);
[[nodiscard]] std::optional<VaultEntryStatus> vault_entry_status_from_string(const std::string& text);

/// WORK_PACKAGE-009's "Vault Model". `id` is the externally-visible UUID,
/// mirroring every prior domain model.
///
/// `sha256_hash`, `mime_type`, and `file_size_bytes` are copied from the
/// referenced Metadata/Verification records (already established by
/// earlier pipeline stages), never recomputed or accepted from a REST
/// client -- mirroring how `metadata::ArtifactMetadata` copies its own
/// hash/size from `integrity::Verification`. `vault_path` and
/// `published_at` are computed by `ReferenceVaultService`.
///
/// There is deliberately no mutation method anywhere in this module (see
/// `IVaultRepository`) -- "Vault entries shall be immutable after
/// publication" is enforced structurally, not just by convention.
struct VaultEntry {
  std::string id;
  std::string metadata_id;
  std::string verification_id;
  std::string download_session_id;
  std::string source_id;
  std::string vault_path;
  std::string sha256_hash;
  std::string mime_type;
  std::uint64_t file_size_bytes = 0;
  VaultEntryStatus status = VaultEntryStatus::Published;
  std::string published_at;
  std::string created_at;
  std::string updated_at;
};

}  // namespace oep::acquisition::vault
