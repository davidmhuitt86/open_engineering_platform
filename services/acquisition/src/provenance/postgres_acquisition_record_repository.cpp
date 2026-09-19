#include "oep/acquisition/provenance/postgres_acquisition_record_repository.hpp"

#include <pqxx/pqxx>

#include "oep/acquisition/common/uuid.hpp"

namespace oep::acquisition::provenance {

namespace {

constexpr auto kSelectColumns =
    "uuid::text, download_session_id::text, status, error_message, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')";

std::optional<std::string> nullable_field(const pqxx::field& field) {
  if (field.is_null()) {
    return std::nullopt;
  }
  return field.as<std::string>();
}

AcquisitionRecord row_to_record(const pqxx::row& row) {
  AcquisitionRecord record;
  record.id = row[0].as<std::string>();
  record.download_session_id = row[1].as<std::string>();
  record.status = acquisition_record_status_from_string(row[2].as<std::string>())
                       .value_or(AcquisitionRecordStatus::Pending);
  record.error_message = nullable_field(row[3]);
  record.created_at = row[4].as<std::string>();
  record.updated_at = row[5].as<std::string>();
  return record;
}

}  // namespace

PostgresAcquisitionRecordRepository::PostgresAcquisitionRecordRepository(const common::DatabaseConfig& config)
    : connection_(common::Config{.database = config}.database_connection_string()) {}

PostgresAcquisitionRecordRepository::~PostgresAcquisitionRecordRepository() = default;

AcquisitionRecord PostgresAcquisitionRecordRepository::create(const AcquisitionRecord& record) {
  pqxx::work txn(connection_.get());
  try {
    const pqxx::result result = txn.exec_params(
        std::string(
            "INSERT INTO acquisition_records (download_session_id, status, error_message) "
            "VALUES ($1::uuid,$2,$3) RETURNING ") +
            kSelectColumns,
        pqxx::params{record.download_session_id, to_string(record.status), record.error_message});
    txn.commit();
    return row_to_record(result[0]);
  } catch (const pqxx::unique_violation&) {
    throw DuplicateAcquisitionRecordError(record.download_session_id);
  } catch (const pqxx::foreign_key_violation&) {
    throw UnknownDownloadSessionError(record.download_session_id);
  }
}

std::optional<AcquisitionRecord> PostgresAcquisitionRecordRepository::find_by_id(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(connection_.get());
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kSelectColumns + " FROM acquisition_records WHERE uuid = $1::uuid",
      pqxx::params{id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_record(result[0]);
}

std::optional<AcquisitionRecord> PostgresAcquisitionRecordRepository::find_by_download_session_id(
    const std::string& download_session_id) {
  if (!common::is_uuid_like(download_session_id)) {
    return std::nullopt;
  }
  pqxx::work txn(connection_.get());
  const pqxx::result result =
      txn.exec_params(std::string("SELECT ") + kSelectColumns +
                           " FROM acquisition_records WHERE download_session_id = $1::uuid",
                       pqxx::params{download_session_id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_record(result[0]);
}

std::vector<AcquisitionRecord> PostgresAcquisitionRecordRepository::list(const AcquisitionRecordFilter& filter) {
  pqxx::work txn(connection_.get());

  std::string sql = std::string("SELECT ") + kSelectColumns + " FROM acquisition_records WHERE TRUE";
  pqxx::params params;
  int index = 1;
  if (filter.status.has_value()) {
    sql += " AND status = $" + std::to_string(index++);
    params.append(to_string(*filter.status));
  }
  sql += " ORDER BY created_at ASC";

  const pqxx::result result = txn.exec_params(sql, params);
  txn.commit();

  std::vector<AcquisitionRecord> records;
  records.reserve(result.size());
  for (const auto& row : result) {
    records.push_back(row_to_record(row));
  }
  return records;
}

std::optional<AcquisitionRecord> PostgresAcquisitionRecordRepository::update_status(
    const std::string& id, AcquisitionRecordStatus status, const std::optional<std::string>& error_message) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(connection_.get());
  const pqxx::result result = txn.exec_params(
      std::string(
          "UPDATE acquisition_records SET status = $1, error_message = $2, updated_at = now() "
          "WHERE uuid = $3::uuid RETURNING ") +
          kSelectColumns,
      pqxx::params{to_string(status), error_message, id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_record(result[0]);
}

}  // namespace oep::acquisition::provenance
