#pragma once

#include <memory>

#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/integrity/verification_repository.hpp"

namespace pqxx {
class connection;
}

namespace oep::acquisition::integrity {

/// `IVerificationRepository` backed by PostgreSQL via `libpqxx`
/// (WORK_PACKAGE-007), mirroring `downloads::PostgresDownloadRepository`.
class PostgresVerificationRepository : public IVerificationRepository {
 public:
  explicit PostgresVerificationRepository(const common::DatabaseConfig& config);
  ~PostgresVerificationRepository() override;

  PostgresVerificationRepository(const PostgresVerificationRepository&) = delete;
  PostgresVerificationRepository& operator=(const PostgresVerificationRepository&) = delete;

  Verification create(const Verification& verification) override;
  std::optional<Verification> find_by_id(const std::string& id) override;
  std::vector<Verification> list(const VerificationFilter& filter) override;
  std::optional<Verification> update(const std::string& id, const Verification& verification) override;

 private:
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::acquisition::integrity
