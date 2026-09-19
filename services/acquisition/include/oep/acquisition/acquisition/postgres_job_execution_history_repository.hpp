#pragma once

#include "oep/acquisition/acquisition/job_execution_history_repository.hpp"
#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/database/resilient_connection.hpp"

namespace oep::acquisition::acquisition {

/// `IJobExecutionHistoryRepository` backed by PostgreSQL via `libpqxx`
/// (WORK_PACKAGE-004), mirroring `PostgresAcquisitionJobRepository`.
class PostgresJobExecutionHistoryRepository : public IJobExecutionHistoryRepository {
 public:
  explicit PostgresJobExecutionHistoryRepository(const common::DatabaseConfig& config);
  ~PostgresJobExecutionHistoryRepository() override;

  PostgresJobExecutionHistoryRepository(const PostgresJobExecutionHistoryRepository&) = delete;
  PostgresJobExecutionHistoryRepository& operator=(const PostgresJobExecutionHistoryRepository&) = delete;

  void record(const std::string& job_id, JobStatus from, JobStatus to, const std::string& message) override;
  std::vector<JobExecutionHistoryEntry> list_for_job(const std::string& job_id) override;

 private:
  database::ResilientConnection connection_;
};

}  // namespace oep::acquisition::acquisition
