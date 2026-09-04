#include <catch2/catch_test_macros.hpp>

#include <string>
#include <vector>

#include <pqxx/pqxx>

#include "jobs_test_support.hpp"
#include "oep/acquisition/common/config.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::common::Config;
using oep::acquisition::test_support::reset_acquisition_jobs_schema;
using oep::acquisition::test_support::test_database_config;

TEST_CASE("V3 migration applies cleanly and produces the expected acquisition_jobs schema",
          "[jobs][database][migration]") {
  const auto schema_error = reset_acquisition_jobs_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  pqxx::connection connection(Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);

  const auto columns =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'acquisition_jobs' ORDER BY ordinal_position");

  std::vector<std::string> column_names;
  for (const auto& row : columns) {
    column_names.push_back(row[0].as<std::string>());
  }

  const std::vector<std::string> expected = {"id",           "uuid",        "source_id",  "name",
                                              "description",  "status",      "priority",   "requested_by",
                                              "created_at",   "updated_at",  "started_at", "completed_at",
                                              "error_message", "deleted_at"};
  CHECK(column_names == expected);

  const auto nullable_started_at =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'acquisition_jobs' AND column_name = 'started_at'");
  REQUIRE(nullable_started_at.size() == 1);
  CHECK(nullable_started_at[0][0].as<std::string>() == "YES");

  const auto not_nullable_name =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'acquisition_jobs' AND column_name = 'name'");
  REQUIRE(not_nullable_name.size() == 1);
  CHECK(not_nullable_name[0][0].as<std::string>() == "NO");

  const auto foreign_key = txn.exec(
      "SELECT constraint_name FROM information_schema.table_constraints "
      "WHERE table_name = 'acquisition_jobs' AND constraint_type = 'FOREIGN KEY'");
  CHECK(foreign_key.size() == 1);
}
