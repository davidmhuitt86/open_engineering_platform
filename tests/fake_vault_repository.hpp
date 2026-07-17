#pragma once

#include <unordered_map>

#include "oep/acquisition/vault/vault_errors.hpp"
#include "oep/acquisition/vault/vault_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IVaultRepository` so `ReferenceVaultService` tests exercise
/// validation and orchestration without a live PostgreSQL instance,
/// mirroring `FakeMetadataRepository`. Unlike every other fake repository
/// in this test suite, `create` DOES enforce the `metadata_id` uniqueness
/// constraint (throwing `AlreadyPublishedError`) -- that invariant is
/// central enough to WORK_PACKAGE-009 ("Publication shall be immutable",
/// no "Re-publish" Functional Requirement) that Service-layer tests need
/// to exercise it without a live database.
class FakeVaultRepository : public vault::IVaultRepository {
 public:
  vault::VaultEntry create(const vault::VaultEntry& entry) override {
    for (const auto& [id, existing] : rows_) {
      if (existing.metadata_id == entry.metadata_id) {
        throw vault::AlreadyPublishedError(entry.metadata_id);
      }
    }
    vault::VaultEntry stored = entry;
    stored.id = "fake-vault-" + std::to_string(++next_id_);
    stored.created_at = "2026-01-01T00:00:00Z";
    stored.updated_at = stored.created_at;
    rows_[stored.id] = stored;
    order_.push_back(stored.id);
    return stored;
  }

  std::optional<vault::VaultEntry> find_by_id(const std::string& id) override {
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    return it->second;
  }

  std::vector<vault::VaultEntry> list(const vault::VaultFilter& filter) override {
    std::vector<vault::VaultEntry> result;
    for (const auto& id : order_) {
      const auto& entry = rows_.at(id);
      if (filter.status.has_value() && entry.status != *filter.status) {
        continue;
      }
      if (filter.metadata_id.has_value() && entry.metadata_id != *filter.metadata_id) {
        continue;
      }
      result.push_back(entry);
    }
    return result;
  }

 private:
  std::unordered_map<std::string, vault::VaultEntry> rows_;
  std::vector<std::string> order_;
  int next_id_ = 0;
};

}  // namespace oep::acquisition::test_support
