#pragma once

#include <memory>

#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/downloads/download_repository.hpp"

namespace pqxx {
class connection;
}

namespace oep::acquisition::downloads {

/// `IDownloadRepository` backed by PostgreSQL via `libpqxx`
/// (WORK_PACKAGE-006), mirroring `acquisition::PostgresAcquisitionJobRepository`.
class PostgresDownloadRepository : public IDownloadRepository {
 public:
  explicit PostgresDownloadRepository(const common::DatabaseConfig& config);
  ~PostgresDownloadRepository() override;

  PostgresDownloadRepository(const PostgresDownloadRepository&) = delete;
  PostgresDownloadRepository& operator=(const PostgresDownloadRepository&) = delete;

  Download create(const Download& download) override;
  std::optional<Download> find_by_id(const std::string& id) override;
  std::vector<Download> list(const DownloadFilter& filter) override;
  std::optional<Download> update(const std::string& id, const Download& download) override;

 private:
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::acquisition::downloads
