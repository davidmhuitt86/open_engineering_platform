#include <catch2/catch_test_macros.hpp>

#include <string>
#include <vector>

#include <pqxx/pqxx>

#include "downloads_test_support.hpp"
#include "oep/acquisition/common/config.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::common::Config;
using oep::acquisition::test_support::reset_downloads_schema;
using oep::acquisition::test_support::test_database_config;

TEST_CASE("V5 migration applies cleanly and produces the expected download_sessions schema",
          "[downloads][database][migration]") {
  const auto schema_error = reset_downloads_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  pqxx::connection connection(Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);

  const auto columns =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'download_sessions' ORDER BY ordinal_position");

  std::vector<std::string> column_names;
  for (const auto& row : columns) {
    column_names.push_back(row[0].as<std::string>());
  }

  const std::vector<std::string> expected = {
      "id",       "uuid",      "job_id",        "connector_id", "source_uri",
      "local_storage_path", "file_name", "mime_type",     "file_size_bytes", "status",
      "progress_percentage", "started_at", "completed_at", "error_message",
      "created_at", "updated_at"};
  CHECK(column_names == expected);

  const auto started_at_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'download_sessions' AND column_name = 'started_at'");
  REQUIRE(started_at_nullable.size() == 1);
  CHECK(started_at_nullable[0][0].as<std::string>() == "YES");

  const auto status_not_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'download_sessions' AND column_name = 'status'");
  REQUIRE(status_not_nullable.size() == 1);
  CHECK(status_not_nullable[0][0].as<std::string>() == "NO");

  const auto foreign_key =
      txn.exec("SELECT constraint_name FROM information_schema.table_constraints "
               "WHERE table_name = 'download_sessions' AND constraint_type = 'FOREIGN KEY'");
  CHECK(foreign_key.size() == 1);

  // No deleted_at column -- WORK_PACKAGE-006 has no DELETE route.
  const auto deleted_at =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'download_sessions' AND column_name = 'deleted_at'");
  CHECK(deleted_at.empty());
}
