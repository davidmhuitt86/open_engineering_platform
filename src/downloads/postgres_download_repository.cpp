#include "oep/acquisition/downloads/postgres_download_repository.hpp"

#include <pqxx/pqxx>

#include "oep/acquisition/common/uuid.hpp"

namespace oep::acquisition::downloads {

namespace {

constexpr auto kSelectColumns =
    "uuid::text, job_id::text, connector_id, source_uri, local_storage_path, file_name, mime_type, "
    "file_size_bytes, status, progress_percentage, "
    "to_char(started_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(completed_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "error_message, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')";

std::optional<std::string> nullable_field(const pqxx::field& field) {
  if (field.is_null()) {
    return std::nullopt;
  }
  return field.as<std::string>();
}

Download row_to_download(const pqxx::row& row) {
  Download download;
  download.id = row[0].as<std::string>();
  download.job_id = row[1].as<std::string>();
  download.connector_id = row[2].as<std::string>();
  download.source_uri = row[3].as<std::string>();
  download.local_storage_path = row[4].as<std::string>();
  download.file_name = row[5].as<std::string>();
  download.mime_type = row[6].as<std::string>();
  download.file_size_bytes = row[7].as<std::uint64_t>();
  download.status = download_status_from_string(row[8].as<std::string>()).value_or(DownloadStatus::Pending);
  download.progress_percentage = row[9].as<int>();
  download.started_at = nullable_field(row[10]);
  download.completed_at = nullable_field(row[11]);
  download.error_message = nullable_field(row[12]);
  download.created_at = row[13].as<std::string>();
  download.updated_at = row[14].as<std::string>();
  return download;
}

}  // namespace

PostgresDownloadRepository::PostgresDownloadRepository(const common::DatabaseConfig& config)
    : connection_(std::make_unique<pqxx::connection>(
          common::Config{.database = config}.database_connection_string())) {}

PostgresDownloadRepository::~PostgresDownloadRepository() = default;

Download PostgresDownloadRepository::create(const Download& download) {
  pqxx::work txn(*connection_);
  try {
    const pqxx::result result = txn.exec_params(
        std::string(
            "INSERT INTO download_sessions "
            "(job_id, connector_id, source_uri, local_storage_path, file_name, mime_type, "
            "file_size_bytes, status, progress_percentage, started_at, completed_at, error_message) "
            "VALUES ($1::uuid,$2,$3,$4,$5,$6,$7,$8,$9,$10::timestamptz,$11::timestamptz,$12) RETURNING ") +
            kSelectColumns,
        pqxx::params{download.job_id, download.connector_id, download.source_uri,
                     download.local_storage_path, download.file_name, download.mime_type,
                     static_cast<std::int64_t>(download.file_size_bytes), to_string(download.status),
                     download.progress_percentage, download.started_at, download.completed_at,
                     download.error_message});
    txn.commit();
    return row_to_download(result[0]);
  } catch (const pqxx::foreign_key_violation&) {
    throw UnknownJobError(download.job_id);
  }
}

std::optional<Download> PostgresDownloadRepository::find_by_id(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kSelectColumns + " FROM download_sessions WHERE uuid = $1::uuid",
      pqxx::params{id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_download(result[0]);
}

std::vector<Download> PostgresDownloadRepository::list(const DownloadFilter& filter) {
  pqxx::work txn(*connection_);

  std::string sql = std::string("SELECT ") + kSelectColumns + " FROM download_sessions WHERE TRUE";
  pqxx::params params;
  int index = 1;
  if (filter.status.has_value()) {
    sql += " AND status = $" + std::to_string(index++);
    params.append(to_string(*filter.status));
  }
  if (filter.job_id.has_value()) {
    sql += " AND job_id = $" + std::to_string(index++) + "::uuid";
    params.append(*filter.job_id);
  }
  if (filter.connector_id.has_value()) {
    sql += " AND connector_id = $" + std::to_string(index++);
    params.append(*filter.connector_id);
  }
  sql += " ORDER BY created_at ASC";

  const pqxx::result result = txn.exec_params(sql, params);
  txn.commit();

  std::vector<Download> downloads;
  downloads.reserve(result.size());
  for (const auto& row : result) {
    downloads.push_back(row_to_download(row));
  }
  return downloads;
}

std::optional<Download> PostgresDownloadRepository::update(const std::string& id, const Download& download) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string(
          "UPDATE download_sessions SET "
          "connector_id=$1, source_uri=$2, local_storage_path=$3, file_name=$4, mime_type=$5, "
          "file_size_bytes=$6, status=$7, progress_percentage=$8, started_at=$9::timestamptz, "
          "completed_at=$10::timestamptz, error_message=$11, updated_at=now() "
          "WHERE uuid=$12::uuid RETURNING ") +
          kSelectColumns,
      pqxx::params{download.connector_id, download.source_uri, download.local_storage_path,
                   download.file_name, download.mime_type,
                   static_cast<std::int64_t>(download.file_size_bytes), to_string(download.status),
                   download.progress_percentage, download.started_at, download.completed_at,
                   download.error_message, id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_download(result[0]);
}

}  // namespace oep::acquisition::downloads
