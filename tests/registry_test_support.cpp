#include "registry_test_support.hpp"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>

#include <pqxx/pqxx>

namespace oep::acquisition::test_support {

namespace {

std::string read_file(const std::filesystem::path& path) {
  std::ifstream stream(path);
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

}  // namespace

common::DatabaseConfig test_database_config() {
  common::DatabaseConfig config;
  if (const char* host = std::getenv("OEP_TEST_DB_HOST"); host != nullptr) {
    config.host = host;
  }
  if (const char* port = std::getenv("OEP_TEST_DB_PORT"); port != nullptr) {
    config.port = static_cast<std::uint16_t>(std::stoi(port));
  }
  if (const char* name = std::getenv("OEP_TEST_DB_NAME"); name != nullptr) {
    config.name = name;
  }
  if (const char* user = std::getenv("OEP_TEST_DB_USER"); user != nullptr) {
    config.user = user;
  }
  if (const char* password = std::getenv("OEP_TEST_DB_PASSWORD"); password != nullptr) {
    config.password = password;
  }
  return config;
}

std::optional<std::string> reset_official_sources_table() {
  try {
    pqxx::connection connection(
        common::Config{.database = test_database_config()}.database_connection_string());
    pqxx::work txn(connection);

    const auto exists = txn.exec("SELECT to_regclass('official_sources')");
    if (exists[0][0].is_null()) {
      const std::filesystem::path migrations_dir = OEP_ACQUISITION_MIGRATIONS_DIR;
      txn.exec(read_file(migrations_dir / "V1__initial_schema.sql"));
      txn.exec(read_file(migrations_dir / "V2__official_sources.sql"));
    } else {
      txn.exec("TRUNCATE TABLE official_sources RESTART IDENTITY");
    }

    txn.commit();
    return std::nullopt;
  } catch (const std::exception& ex) {
    return std::string(ex.what());
  }
}

}  // namespace oep::acquisition::test_support
