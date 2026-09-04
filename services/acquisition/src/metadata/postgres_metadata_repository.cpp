#include "oep/acquisition/metadata/postgres_metadata_repository.hpp"

#include <pqxx/pqxx>

#include "oep/acquisition/common/uuid.hpp"
#include "oep/acquisition/metadata/artifact_metadata_errors.hpp"

namespace oep::acquisition::metadata {

namespace {

constexpr auto kSelectColumns =
    "uuid::text, verification_id::text, file_name, file_extension, mime_type, file_size_bytes, "
    "sha256_hash, "
    "to_char(file_created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(file_modified_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "pdf_version, pdf_page_count, status, "
    "to_char(extracted_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "error_message, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')";

std::optional<std::string> nullable_field(const pqxx::field& field) {
  if (field.is_null()) {
    return std::nullopt;
  }
  return field.as<std::string>();
}

std::optional<int> nullable_int_field(const pqxx::field& field) {
  if (field.is_null()) {
    return std::nullopt;
  }
  return field.as<int>();
}

ArtifactMetadata row_to_metadata(const pqxx::row& row) {
  ArtifactMetadata metadata;
  metadata.id = row[0].as<std::string>();
  metadata.verification_id = row[1].as<std::string>();
  metadata.file_name = row[2].as<std::string>();
  metadata.file_extension = row[3].as<std::string>();
  metadata.mime_type = row[4].as<std::string>();
  metadata.file_size_bytes = row[5].as<std::uint64_t>();
  metadata.sha256_hash = row[6].as<std::string>();
  metadata.file_created_at = nullable_field(row[7]);
  metadata.file_modified_at = nullable_field(row[8]);
  metadata.pdf_version = nullable_field(row[9]);
  metadata.pdf_page_count = nullable_int_field(row[10]);
  metadata.status = extraction_status_from_string(row[11].as<std::string>()).value_or(ExtractionStatus::Pending);
  metadata.extracted_at = nullable_field(row[12]);
  metadata.error_message = nullable_field(row[13]);
  metadata.created_at = row[14].as<std::string>();
  metadata.updated_at = row[15].as<std::string>();
  return metadata;
}

}  // namespace

PostgresMetadataRepository::PostgresMetadataRepository(const common::DatabaseConfig& config)
    : connection_(std::make_unique<pqxx::connection>(
          common::Config{.database = config}.database_connection_string())) {}

PostgresMetadataRepository::~PostgresMetadataRepository() = default;

ArtifactMetadata PostgresMetadataRepository::create(const ArtifactMetadata& metadata) {
  pqxx::work txn(*connection_);
  try {
    const pqxx::result result = txn.exec_params(
        std::string(
            "INSERT INTO artifact_metadata "
            "(verification_id, file_name, file_extension, mime_type, file_size_bytes, sha256_hash, "
            "file_created_at, file_modified_at, pdf_version, pdf_page_count, status, extracted_at, "
            "error_message) "
            "VALUES ($1::uuid,$2,$3,$4,$5,$6,$7::timestamptz,$8::timestamptz,$9,$10,$11,$12::timestamptz,"
            "$13) RETURNING ") +
            kSelectColumns,
        pqxx::params{metadata.verification_id, metadata.file_name, metadata.file_extension,
                     metadata.mime_type, static_cast<std::int64_t>(metadata.file_size_bytes),
                     metadata.sha256_hash, metadata.file_created_at, metadata.file_modified_at,
                     metadata.pdf_version, metadata.pdf_page_count, to_string(metadata.status),
                     metadata.extracted_at, metadata.error_message});
    txn.commit();
    return row_to_metadata(result[0]);
  } catch (const pqxx::foreign_key_violation&) {
    throw UnknownVerificationError(metadata.verification_id);
  }
}

std::optional<ArtifactMetadata> PostgresMetadataRepository::find_by_id(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kSelectColumns + " FROM artifact_metadata WHERE uuid = $1::uuid",
      pqxx::params{id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_metadata(result[0]);
}

std::vector<ArtifactMetadata> PostgresMetadataRepository::list(const MetadataFilter& filter) {
  pqxx::work txn(*connection_);

  std::string sql = std::string("SELECT ") + kSelectColumns + " FROM artifact_metadata WHERE TRUE";
  pqxx::params params;
  int index = 1;
  if (filter.status.has_value()) {
    sql += " AND status = $" + std::to_string(index++);
    params.append(to_string(*filter.status));
  }
  if (filter.verification_id.has_value()) {
    sql += " AND verification_id = $" + std::to_string(index++) + "::uuid";
    params.append(*filter.verification_id);
  }
  sql += " ORDER BY created_at ASC";

  const pqxx::result result = txn.exec_params(sql, params);
  txn.commit();

  std::vector<ArtifactMetadata> records;
  records.reserve(result.size());
  for (const auto& row : result) {
    records.push_back(row_to_metadata(row));
  }
  return records;
}

std::optional<ArtifactMetadata> PostgresMetadataRepository::update(const std::string& id,
                                                                      const ArtifactMetadata& metadata) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string(
          "UPDATE artifact_metadata SET "
          "file_name=$1, file_extension=$2, mime_type=$3, file_size_bytes=$4, sha256_hash=$5, "
          "file_created_at=$6::timestamptz, file_modified_at=$7::timestamptz, pdf_version=$8, "
          "pdf_page_count=$9, status=$10, extracted_at=$11::timestamptz, error_message=$12, "
          "updated_at=now() "
          "WHERE uuid=$13::uuid RETURNING ") +
          kSelectColumns,
      pqxx::params{metadata.file_name, metadata.file_extension, metadata.mime_type,
                   static_cast<std::int64_t>(metadata.file_size_bytes), metadata.sha256_hash,
                   metadata.file_created_at, metadata.file_modified_at, metadata.pdf_version,
                   metadata.pdf_page_count, to_string(metadata.status), metadata.extracted_at,
                   metadata.error_message, id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_metadata(result[0]);
}

}  // namespace oep::acquisition::metadata
