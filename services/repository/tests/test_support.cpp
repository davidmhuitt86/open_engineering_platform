#include "test_support.hpp"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>

#include <pqxx/pqxx>

namespace oep::server_repository::test_support {

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

std::optional<std::string> reset_schema() {
  try {
    pqxx::connection connection(common::Config{.database = test_database_config()}.database_connection_string());
    pqxx::work txn(connection);

    const std::filesystem::path migrations_dir = OEP_SERVER_REPOSITORY_MIGRATIONS_DIR;

    const auto exists = txn.exec("SELECT to_regclass('repositories')");
    if (exists[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V1__initial_schema.sql"));
    } else {
      txn.exec("TRUNCATE repositories CASCADE");
    }

    // WP-SRV-012: applied verbatim, exactly like V1 above, the first time
    // this test database doesn't yet have it (an already-migrated V1-only
    // database from before this WP, or a brand new one that just got V1
    // applied above) -- mirrors how the real Flyway migration path picks
    // up V2 automatically, without duplicating Flyway itself here.
    const auto has_tombstone_column = txn.exec(
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_name = 'object_heads' AND column_name = 'is_tombstoned'");
    if (has_tombstone_column.empty()) {
      txn.exec(read_file(migrations_dir / "V2__tombstone_semantics.sql"));
    }

    txn.commit();
    return std::nullopt;
  } catch (const std::exception& ex) {
    return std::string(ex.what());
  }
}

}  // namespace oep::server_repository::test_support
