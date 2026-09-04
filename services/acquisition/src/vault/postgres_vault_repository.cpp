#include "oep/acquisition/vault/postgres_vault_repository.hpp"

#include <pqxx/pqxx>

#include "oep/acquisition/common/uuid.hpp"
#include "oep/acquisition/vault/vault_errors.hpp"

namespace oep::acquisition::vault {

namespace {

constexpr auto kSelectColumns =
    "uuid::text, metadata_id::text, verification_id::text, download_session_id::text, source_id::text, "
    "vault_path, sha256_hash, mime_type, file_size_bytes, status, "
    "to_char(published_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')";

VaultEntry row_to_entry(const pqxx::row& row) {
  VaultEntry entry;
  entry.id = row[0].as<std::string>();
  entry.metadata_id = row[1].as<std::string>();
  entry.verification_id = row[2].as<std::string>();
  entry.download_session_id = row[3].as<std::string>();
  entry.source_id = row[4].as<std::string>();
  entry.vault_path = row[5].as<std::string>();
  entry.sha256_hash = row[6].as<std::string>();
  entry.mime_type = row[7].as<std::string>();
  entry.file_size_bytes = row[8].as<std::uint64_t>();
  entry.status = vault_entry_status_from_string(row[9].as<std::string>()).value_or(VaultEntryStatus::Published);
  entry.published_at = row[10].as<std::string>();
  entry.created_at = row[11].as<std::string>();
  entry.updated_at = row[12].as<std::string>();
  return entry;
}

}  // namespace

PostgresVaultRepository::PostgresVaultRepository(const common::DatabaseConfig& config)
    : connection_(std::make_unique<pqxx::connection>(
          common::Config{.database = config}.database_connection_string())) {}

PostgresVaultRepository::~PostgresVaultRepository() = default;

VaultEntry PostgresVaultRepository::create(const VaultEntry& entry) {
  pqxx::work txn(*connection_);
  try {
    const pqxx::result result = txn.exec_params(
        std::string(
            "INSERT INTO reference_vault "
            "(metadata_id, verification_id, download_session_id, source_id, vault_path, sha256_hash, "
            "mime_type, file_size_bytes, status, published_at) "
            "VALUES ($1::uuid,$2::uuid,$3::uuid,$4::uuid,$5,$6,$7,$8,$9,$10::timestamptz) RETURNING ") +
            kSelectColumns,
        pqxx::params{entry.metadata_id, entry.verification_id, entry.download_session_id, entry.source_id,
                     entry.vault_path, entry.sha256_hash, entry.mime_type,
                     static_cast<std::int64_t>(entry.file_size_bytes), to_string(entry.status),
                     entry.published_at});
    txn.commit();
    return row_to_entry(result[0]);
  } catch (const pqxx::unique_violation&) {
    throw AlreadyPublishedError(entry.metadata_id);
  } catch (const pqxx::foreign_key_violation&) {
    throw UnknownMetadataError(entry.metadata_id);
  }
}

std::optional<VaultEntry> PostgresVaultRepository::find_by_id(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kSelectColumns + " FROM reference_vault WHERE uuid = $1::uuid",
      pqxx::params{id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_entry(result[0]);
}

std::vector<VaultEntry> PostgresVaultRepository::list(const VaultFilter& filter) {
  pqxx::work txn(*connection_);

  std::string sql = std::string("SELECT ") + kSelectColumns + " FROM reference_vault WHERE TRUE";
  pqxx::params params;
  int index = 1;
  if (filter.status.has_value()) {
    sql += " AND status = $" + std::to_string(index++);
    params.append(to_string(*filter.status));
  }
  if (filter.metadata_id.has_value()) {
    sql += " AND metadata_id = $" + std::to_string(index++) + "::uuid";
    params.append(*filter.metadata_id);
  }
  sql += " ORDER BY created_at ASC";

  const pqxx::result result = txn.exec_params(sql, params);
  txn.commit();

  std::vector<VaultEntry> entries;
  entries.reserve(result.size());
  for (const auto& row : result) {
    entries.push_back(row_to_entry(row));
  }
  return entries;
}

}  // namespace oep::acquisition::vault
