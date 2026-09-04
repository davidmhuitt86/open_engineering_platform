#include "oep/acquisition/registry/postgres_official_source_repository.hpp"

#include <pqxx/pqxx>

#include "oep/acquisition/common/uuid.hpp"

namespace oep::acquisition::registry {

namespace {

// Selected in a fixed order and read back by index (rather than by column
// name) so field access below does not depend on a `pqxx::row` name-lookup
// API that varies across libpqxx versions.
constexpr auto kSelectColumns =
    "uuid::text, name, organization, base_url, description, country, language, category, "
    "trust_level, status, authentication_type, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')";

OfficialSource row_to_official_source(const pqxx::row& row) {
  OfficialSource source;
  source.id = row[0].as<std::string>();
  source.name = row[1].as<std::string>();
  source.organization = row[2].as<std::string>();
  source.base_url = row[3].as<std::string>();
  source.description = row[4].as<std::string>();
  source.country = row[5].as<std::string>();
  source.language = row[6].as<std::string>();
  source.category = row[7].as<std::string>();
  source.trust_level = trust_level_from_int(row[8].as<int>()).value_or(TrustLevel::Unknown);
  source.status = source_status_from_string(row[9].as<std::string>()).value_or(SourceStatus::Proposed);
  source.authentication_type =
      authentication_type_from_string(row[10].as<std::string>()).value_or(AuthenticationType::None);
  source.created_at = row[11].as<std::string>();
  source.updated_at = row[12].as<std::string>();
  return source;
}

}  // namespace

PostgresOfficialSourceRepository::PostgresOfficialSourceRepository(const common::DatabaseConfig& config)
    : connection_(std::make_unique<pqxx::connection>(
          common::Config{.database = config}.database_connection_string())) {}

PostgresOfficialSourceRepository::~PostgresOfficialSourceRepository() = default;

OfficialSource PostgresOfficialSourceRepository::create(const OfficialSource& source) {
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string(
          "INSERT INTO official_sources "
          "(name, organization, base_url, description, country, language, category, trust_level, status, "
          "authentication_type) "
          "VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING ") +
          kSelectColumns,
      pqxx::params{source.name, source.organization, source.base_url, source.description, source.country,
                   source.language, source.category, static_cast<int>(source.trust_level),
                   to_string(source.status), to_string(source.authentication_type)});
  txn.commit();
  return row_to_official_source(result[0]);
}

std::optional<OfficialSource> PostgresOfficialSourceRepository::find_by_id(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result =
      txn.exec_params(std::string("SELECT ") + kSelectColumns +
                           " FROM official_sources WHERE uuid = $1::uuid AND deleted_at IS NULL",
                       pqxx::params{id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_official_source(result[0]);
}

std::vector<OfficialSource> PostgresOfficialSourceRepository::list(const SourceFilter& filter) {
  pqxx::work txn(*connection_);

  std::string sql = std::string("SELECT ") + kSelectColumns + " FROM official_sources WHERE deleted_at IS NULL";
  pqxx::params params;
  int index = 1;
  if (filter.status.has_value()) {
    sql += " AND status = $" + std::to_string(index++);
    params.append(to_string(*filter.status));
  }
  if (filter.trust_level.has_value()) {
    sql += " AND trust_level = $" + std::to_string(index++);
    params.append(static_cast<int>(*filter.trust_level));
  }
  if (filter.category.has_value()) {
    sql += " AND category = $" + std::to_string(index++);
    params.append(*filter.category);
  }
  if (filter.country.has_value()) {
    sql += " AND country = $" + std::to_string(index++);
    params.append(*filter.country);
  }
  sql += " ORDER BY created_at ASC";

  const pqxx::result result = txn.exec_params(sql, params);
  txn.commit();

  std::vector<OfficialSource> sources;
  sources.reserve(result.size());
  for (const auto& row : result) {
    sources.push_back(row_to_official_source(row));
  }
  return sources;
}

std::optional<OfficialSource> PostgresOfficialSourceRepository::update(const std::string& id,
                                                                         const OfficialSource& source) {
  if (!common::is_uuid_like(id)) {
    return std::nullopt;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result = txn.exec_params(
      std::string(
          "UPDATE official_sources SET "
          "name=$1, organization=$2, base_url=$3, description=$4, country=$5, language=$6, category=$7, "
          "trust_level=$8, status=$9, authentication_type=$10, updated_at=now() "
          "WHERE uuid=$11::uuid AND deleted_at IS NULL RETURNING ") +
          kSelectColumns,
      pqxx::params{source.name, source.organization, source.base_url, source.description, source.country,
                   source.language, source.category, static_cast<int>(source.trust_level),
                   to_string(source.status), to_string(source.authentication_type), id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_official_source(result[0]);
}

bool PostgresOfficialSourceRepository::soft_delete(const std::string& id) {
  if (!common::is_uuid_like(id)) {
    return false;
  }
  pqxx::work txn(*connection_);
  const pqxx::result result =
      txn.exec_params("UPDATE official_sources SET deleted_at = now(), updated_at = now() "
                       "WHERE uuid = $1::uuid AND deleted_at IS NULL RETURNING uuid",
                       pqxx::params{id});
  txn.commit();
  return !result.empty();
}

}  // namespace oep::acquisition::registry
