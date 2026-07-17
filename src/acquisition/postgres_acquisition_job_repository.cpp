#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"

#include <pqxx/pqxx>

#include "oep/acquisition/common/uuid.hpp"

namespace oep::acquisition::acquisition {

namespace {

// Selected in a fixed order and read back by index -- see
// registry::PostgresOfficialSourceRepository for why.
constexpr auto kSelectColumns =
    "uuid::text, source_id::text, name, description, status, priority, requested_by, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(started_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(completed_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "error_message";

std::optional<std::string> nullable_field(const pqxx::field& field) {
  if (field.is_null()) {
    return std::nullopt;
  }
  return field.as<std::string>();
}

AcquisitionJob row_to_job(const pqxx::row& row) {
  AcquisitionJob job;
  job.id = row[0].as<std::string>();
  job.source_id = row[1].as<std::string>();
  job.name = row[2].as<std::string>();
  job.description = row[3].as<std::string>();
  job.status = job_status_from_string(row[4].as<std::string>()).value_or(JobStatus::Created);
  job.priority = job_priority_from_int(row[5].as<int>()).value_or(JobPriority::Normal);
  job.requested_by = row[6].as<std::string>();
  job.created_at = row[7].as<std::string>();
  job.updated_at = row[8].as<std::string>();
  job.started_at = nullable_field(row[9]);
  job.completed_at = nullable_field(row[10]);
  job.error_message = nullable_field(row[11]);
  return job;
}

}  // namespace

PostgresAcquisitionJobRepository::PostgresAcquisitionJobRepository(const common::DatabaseConfig& config)
    : connection_(std::make_unique<pqxx::connection>(
          common::Config{.database = config}.database_connection_string())) {}

PostgresAcquisitionJobRepository::~PostgresAcquisitionJobRepository() = default;

AcquisitionJob PostgresAcquisitionJobRepository::create(const AcquisitionJob& job) {
  pqxx::work txn(*connection_);
  try {
    const pqxx::result result = txn.exec_params(
        std::string(
            "INSERT INTO acquisition_jobs "
            "(source_id, name, description, status, priority, requested_by) "
            "VALUES ($1::uuid,$2,$3,$4,$5,$6) RETURNING ") +
            kSelectColumns,
        pqxx::params{job.source_id, job.name, job.description, to_string(job.status),
                     static_cast<int>(job.priority), job.requested_by});
    txn.commit();
    return row_to_job(result[0]);
  } catch (const pqxx::foreign_key_violation&) {
    throw UnknownSourceError(job.source_id);
  }
}

std::optional<AcquisitionJob> PostgresAcquisitionJobRepository::find_by_id(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result =
      txn.exec_params(std::string("SELECT ") + kSelectColumns +
                           " FROM acquisition_jobs WHERE uuid = $1::uuid AND deleted_at IS NULL",
                       pqxx::params{id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_job(result[0]);
}

std::vector<AcquisitionJob> PostgresAcquisitionJobRepository::list(const JobFilter& filter) {
  pqxx::work txn(*connection_);

  std::string sql = std::string("SELECT ") + kSelectColumns + " FROM acquisition_jobs WHERE deleted_at IS NULL";
  pqxx::params params;
  int index = 1;
  if (filter.status.has_value()) {
    sql += " AND status = $" + std::to_string(index++);
    params.append(to_string(*filter.status));
  }
  if (filter.priority.has_value()) {
    sql += " AND priority = $" + std::to_string(index++);
    params.append(static_cast<int>(*filter.priority));
  }
  if (filter.source_id.has_value()) {
    sql += " AND source_id = $" + std::to_string(index++) + "::uuid";
    params.append(*filter.source_id);
  }
  if (filter.requested_by.has_value()) {
    sql += " AND requested_by = $" + std::to_string(index++);
    params.append(*filter.requested_by);
  }
  sql += " ORDER BY created_at ASC";

  const pqxx::result result = txn.exec_params(sql, params);
  txn.commit();

  std::vector<AcquisitionJob> jobs;
  jobs.reserve(result.size());
  for (const auto& row : result) {
    jobs.push_back(row_to_job(row));
  }
  return jobs;
}

std::optional<AcquisitionJob> PostgresAcquisitionJobRepository::update(const std::string& id,
                                                                         const AcquisitionJob& job) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  try {
    const pqxx::result result = txn.exec_params(
        std::string(
            "UPDATE acquisition_jobs SET "
            "source_id=$1::uuid, name=$2, description=$3, status=$4, priority=$5, requested_by=$6, "
            "started_at=$7::timestamptz, completed_at=$8::timestamptz, error_message=$9, updated_at=now() "
            "WHERE uuid=$10::uuid AND deleted_at IS NULL RETURNING ") +
            kSelectColumns,
        pqxx::params{job.source_id, job.name, job.description, to_string(job.status),
                     static_cast<int>(job.priority), job.requested_by, job.started_at, job.completed_at,
                     job.error_message, id});
    txn.commit();
    if (result.empty()) {
      return std::nullopt;
    }
    return row_to_job(result[0]);
  } catch (const pqxx::foreign_key_violation&) {
    throw UnknownSourceError(job.source_id);
  }
}

bool PostgresAcquisitionJobRepository::soft_delete(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return false;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result =
      txn.exec_params("UPDATE acquisition_jobs SET deleted_at = now(), updated_at = now() "
                       "WHERE uuid = $1::uuid AND deleted_at IS NULL RETURNING uuid",
                       pqxx::params{id});
  txn.commit();
  return !result.empty();
}

}  // namespace oep::acquisition::acquisition
