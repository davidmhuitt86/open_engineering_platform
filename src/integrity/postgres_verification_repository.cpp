#include "oep/acquisition/integrity/postgres_verification_repository.hpp"

#include <pqxx/pqxx>

#include "oep/acquisition/common/uuid.hpp"
#include "oep/acquisition/integrity/verification_errors.hpp"

namespace oep::acquisition::integrity {

namespace {

constexpr auto kSelectColumns =
    "uuid::text, download_session_id::text, status, sha256_hash, file_size_bytes, "
    "to_char(verified_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "error_message, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')";

std::optional<std::string> nullable_field(const pqxx::field& field) {
  if (field.is_null()) {
    return std::nullopt;
  }
  return field.as<std::string>();
}

Verification row_to_verification(const pqxx::row& row) {
  Verification verification;
  verification.id = row[0].as<std::string>();
  verification.download_session_id = row[1].as<std::string>();
  verification.status = verification_status_from_string(row[2].as<std::string>())
                             .value_or(VerificationStatus::Pending);
  verification.sha256_hash = row[3].as<std::string>();
  verification.file_size_bytes = row[4].as<std::uint64_t>();
  verification.verified_at = nullable_field(row[5]);
  verification.error_message = nullable_field(row[6]);
  verification.created_at = row[7].as<std::string>();
  verification.updated_at = row[8].as<std::string>();
  return verification;
}

}  // namespace

PostgresVerificationRepository::PostgresVerificationRepository(const common::DatabaseConfig& config)
    : connection_(std::make_unique<pqxx::connection>(
          common::Config{.database = config}.database_connection_string())) {}

PostgresVerificationRepository::~PostgresVerificationRepository() = default;

Verification PostgresVerificationRepository::create(const Verification& verification) {
  pqxx::work txn(*connection_);
  try {
    const pqxx::result result = txn.exec_params(
        std::string(
            "INSERT INTO integrity_verifications "
            "(download_session_id, status, sha256_hash, file_size_bytes, verified_at, error_message) "
            "VALUES ($1::uuid,$2,$3,$4,$5::timestamptz,$6) RETURNING ") +
            kSelectColumns,
        pqxx::params{verification.download_session_id, to_string(verification.status),
                     verification.sha256_hash, static_cast<std::int64_t>(verification.file_size_bytes),
                     verification.verified_at, verification.error_message});
    txn.commit();
    return row_to_verification(result[0]);
  } catch (const pqxx::foreign_key_violation&) {
    throw UnknownDownloadSessionError(verification.download_session_id);
  }
}

std::optional<Verification> PostgresVerificationRepository::find_by_id(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kSelectColumns + " FROM integrity_verifications WHERE uuid = $1::uuid",
      pqxx::params{id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_verification(result[0]);
}

std::vector<Verification> PostgresVerificationRepository::list(const VerificationFilter& filter) {
  pqxx::work txn(*connection_);

  std::string sql = std::string("SELECT ") + kSelectColumns + " FROM integrity_verifications WHERE TRUE";
  pqxx::params params;
  int index = 1;
  if (filter.status.has_value()) {
    sql += " AND status = $" + std::to_string(index++);
    params.append(to_string(*filter.status));
  }
  if (filter.download_session_id.has_value()) {
    sql += " AND download_session_id = $" + std::to_string(index++) + "::uuid";
    params.append(*filter.download_session_id);
  }
  sql += " ORDER BY created_at ASC";

  const pqxx::result result = txn.exec_params(sql, params);
  txn.commit();

  std::vector<Verification> verifications;
  verifications.reserve(result.size());
  for (const auto& row : result) {
    verifications.push_back(row_to_verification(row));
  }
  return verifications;
}

std::optional<Verification> PostgresVerificationRepository::update(const std::string& id,
                                                                      const Verification& verification) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string(
          "UPDATE integrity_verifications SET "
          "status=$1, sha256_hash=$2, file_size_bytes=$3, verified_at=$4::timestamptz, "
          "error_message=$5, updated_at=now() "
          "WHERE uuid=$6::uuid RETURNING ") +
          kSelectColumns,
      pqxx::params{to_string(verification.status), verification.sha256_hash,
                   static_cast<std::int64_t>(verification.file_size_bytes), verification.verified_at,
                   verification.error_message, id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_verification(result[0]);
}

}  // namespace oep::acquisition::integrity
