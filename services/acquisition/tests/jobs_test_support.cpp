#include "jobs_test_support.hpp"

#include <fstream>
#include <sstream>

#include <pqxx/pqxx>

#include "oep/acquisition/common/config.hpp"
#include "registry_test_support.hpp"

namespace oep::acquisition::test_support {

namespace {

std::string read_file(const std::filesystem::path& path) {
  std::ifstream stream(path);
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

}  // namespace

std::optional<std::string> reset_acquisition_jobs_schema() {
  try {
    pqxx::connection connection(
        common::Config{.database = test_database_config()}.database_connection_string());
    pqxx::work txn(connection);

    const std::filesystem::path migrations_dir = OEP_ACQUISITION_MIGRATIONS_DIR;

    if (txn.exec("SELECT to_regclass('official_sources')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V1__initial_schema.sql"));
      txn.exec(read_file(migrations_dir / "V2__official_sources.sql"));
    }
    if (txn.exec("SELECT to_regclass('acquisition_jobs')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V3__acquisition_jobs.sql"));
    }

    // CASCADE: WORK_PACKAGE-004 added acquisition_job_execution_history,
    // which references acquisition_jobs -- see the matching comment in
    // registry_test_support.cpp's reset_official_sources_table.
    txn.exec("TRUNCATE TABLE acquisition_jobs, official_sources RESTART IDENTITY CASCADE");
    txn.commit();
    return std::nullopt;
  } catch (const std::exception& ex) {
    return std::string(ex.what());
  }
}

std::string seed_official_source() {
  pqxx::connection connection(common::Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);
  const auto result = txn.exec_params(
      "INSERT INTO official_sources (name, base_url, trust_level, status, authentication_type) "
      "VALUES ($1, $2, $3, $4, $5) RETURNING uuid::text",
      pqxx::params{"Seed Source", "https://example.org", 5, "active", "none"});
  txn.commit();
  return result[0][0].as<std::string>();
}

}  // namespace oep::acquisition::test_support
