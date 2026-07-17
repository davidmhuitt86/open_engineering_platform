#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/vault/vault_entry.hpp"

namespace oep::acquisition::vault {

/// Optional filters for `GET /vault`. Every field is optional; unset
/// fields impose no constraint.
struct VaultFilter {
  std::optional<VaultEntryStatus> status;
  std::optional<std::string> metadata_id;
};

/// Abstracts persistence for `VaultEntry` so `ReferenceVaultService` can be
/// unit-tested against a fake without a live PostgreSQL instance,
/// mirroring `metadata::IMetadataRepository`.
///
/// Deliberately has no `update` method, unlike every prior repository
/// interface in this codebase -- "Vault entries shall be immutable after
/// publication" is enforced structurally: there is no code path anywhere
/// that can modify a `VaultEntry` once `create` has returned it.
class IVaultRepository {
 public:
  virtual ~IVaultRepository() = default;

  /// Inserts `entry` (already in its final, `Published` state -- see
  /// `ReferenceVaultService`) and returns the stored row (`id`/
  /// `created_at`/`updated_at` populated by the database). Throws if
  /// `entry.metadata_id` does not reference an existing ArtifactMetadata
  /// record, or if it has already been published (see `vault_errors.hpp`).
  virtual VaultEntry create(const VaultEntry& entry) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<VaultEntry> find_by_id(const std::string& id) = 0;

  virtual std::vector<VaultEntry> list(const VaultFilter& filter) = 0;
};

}  // namespace oep::acquisition::vault
