#pragma once

#include <memory>

#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/vault/vault_repository.hpp"

namespace pqxx {
class connection;
}

namespace oep::acquisition::vault {

/// `IVaultRepository` backed by PostgreSQL via `libpqxx`
/// (WORK_PACKAGE-009), mirroring `metadata::PostgresMetadataRepository` --
/// except there is no `update` method (see `IVaultRepository`).
class PostgresVaultRepository : public IVaultRepository {
 public:
  explicit PostgresVaultRepository(const common::DatabaseConfig& config);
  ~PostgresVaultRepository() override;

  PostgresVaultRepository(const PostgresVaultRepository&) = delete;
  PostgresVaultRepository& operator=(const PostgresVaultRepository&) = delete;

  VaultEntry create(const VaultEntry& entry) override;
  std::optional<VaultEntry> find_by_id(const std::string& id) override;
  std::vector<VaultEntry> list(const VaultFilter& filter) override;

 private:
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::acquisition::vault
