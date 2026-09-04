#pragma once

#include <memory>

#include "oep/acquisition/acquisition/acquisition_job_repository.hpp"
#include "oep/acquisition/common/config.hpp"

namespace pqxx {
class connection;
}

namespace oep::acquisition::acquisition {

/// `IAcquisitionJobRepository` backed by PostgreSQL via `libpqxx`
/// (WORK_PACKAGE-003), mirroring
/// `registry::PostgresOfficialSourceRepository`'s pattern.
///
/// The constructor connects immediately and throws if the connection
/// fails -- see `registry::PostgresOfficialSourceRepository` for why.
class PostgresAcquisitionJobRepository : public IAcquisitionJobRepository {
 public:
  explicit PostgresAcquisitionJobRepository(const common::DatabaseConfig& config);
  ~PostgresAcquisitionJobRepository() override;

  PostgresAcquisitionJobRepository(const PostgresAcquisitionJobRepository&) = delete;
  PostgresAcquisitionJobRepository& operator=(const PostgresAcquisitionJobRepository&) = delete;

  AcquisitionJob create(const AcquisitionJob& job) override;
  std::optional<AcquisitionJob> find_by_id(const std::string& id) override;
  std::vector<AcquisitionJob> list(const JobFilter& filter) override;
  std::optional<AcquisitionJob> update(const std::string& id, const AcquisitionJob& job) override;
  bool soft_delete(const std::string& id) override;

 private:
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::acquisition::acquisition
