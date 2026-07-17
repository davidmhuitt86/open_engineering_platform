#include "oep/acquisition/acquisition/postgres_job_execution_history_repository.hpp"

#include <pqxx/pqxx>

namespace oep::acquisition::acquisition {

namespace {

constexpr auto kSelectColumns =
    "from_status, to_status, "
    "to_char(occurred_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "message";

JobExecutionHistoryEntry row_to_entry(const pqxx::row& row) {
  JobExecutionHistoryEntry entry;
  entry.from_status = row[0].as<std::string>();
  entry.to_status = row[1].as<std::string>();
  entry.occurred_at = row[2].as<std::string>();
  entry.message = row[3].as<std::string>();
  return entry;
}

}  // namespace

PostgresJobExecutionHistoryRepository::PostgresJobExecutionHistoryRepository(
    const common::DatabaseConfig& config)
    : connection_(std::make_unique<pqxx::connection>(
          common::Config{.database = config}.database_connection_string())) {}

PostgresJobExecutionHistoryRepository::~PostgresJobExecutionHistoryRepository() = default;

void PostgresJobExecutionHistoryRepository::record(const std::string& job_id, JobStatus from, JobStatus to,
                                                      const std::string& message) {
  pqxx::work txn(*connection_);
  txn.exec_params(
      "INSERT INTO acquisition_job_execution_history (job_id, from_status, to_status, message) "
      "VALUES ($1::uuid, $2, $3, $4)",
      pqxx::params{job_id, to_string(from), to_string(to), message});
  txn.commit();
}

std::vector<JobExecutionHistoryEntry> PostgresJobExecutionHistoryRepository::list_for_job(
    const std::string& job_id) {
  pqxx::work txn(*connection_);
  const pqxx::result result =
      txn.exec_params(std::string("SELECT ") + kSelectColumns +
                           " FROM acquisition_job_execution_history WHERE job_id = $1::uuid ORDER BY occurred_at ASC",
                       pqxx::params{job_id});
  txn.commit();

  std::vector<JobExecutionHistoryEntry> entries;
  entries.reserve(result.size());
  for (const auto& row : result) {
    entries.push_back(row_to_entry(row));
  }
  return entries;
}

}  // namespace oep::acquisition::acquisition
