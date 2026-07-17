#pragma once

#include <filesystem>
#include <string>

namespace oep::acquisition::vault {

/// Builds the content-addressable path for an artifact with the given
/// lowercase hex `sha256_hash`, sharded by its first two hex characters
/// (WORK_PACKAGE-009: "Use a deterministic directory structure to prevent
/// oversized directories" -- e.g. `reference_vault/3f/3f8b0d8e7c4e6...`).
/// Returns an empty path if `sha256_hash` is not a well-formed 64-character
/// hex string -- `ReferenceVaultService` treats that as an invalid Vault
/// path (WORK_PACKAGE-009 Validation Rules: "Vault path shall validate").
[[nodiscard]] std::filesystem::path compute_vault_path(const std::filesystem::path& vault_root,
                                                          const std::string& sha256_hash);

}  // namespace oep::acquisition::vault
