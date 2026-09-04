#include <catch2/catch_test_macros.hpp>

#include <string>
#include <vector>

#include <pqxx/pqxx>

#include "oep/acquisition/common/config.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::common::Config;
using oep::acquisition::test_support::reset_official_sources_table;
using oep::acquisition::test_support::test_database_config;

TEST_CASE("V1 and V2 migrations apply cleanly and produce the expected official_sources schema",
          "[registry][database][migration]") {
  const auto schema_error = reset_official_sources_table();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  pqxx::connection connection(Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);

  const auto columns =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'official_sources' ORDER BY ordinal_position");

  std::vector<std::string> column_names;
  for (const auto& row : columns) {
    column_names.push_back(row[0].as<std::string>());
  }

  const std::vector<std::string> expected = {"id",       "uuid",      "name",     "organization",
                                              "base_url", "description", "country",  "language",
                                              "category", "trust_level", "status",   "authentication_type",
                                              "created_at", "updated_at", "deleted_at"};
  CHECK(column_names == expected);

  const auto deleted_at_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'official_sources' AND column_name = 'deleted_at'");
  REQUIRE(deleted_at_nullable.size() == 1);
  CHECK(deleted_at_nullable[0][0].as<std::string>() == "YES");

  const auto name_not_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'official_sources' AND column_name = 'name'");
  REQUIRE(name_not_nullable.size() == 1);
  CHECK(name_not_nullable[0][0].as<std::string>() == "NO");

  const auto uuid_unique_index =
      txn.exec("SELECT indexname FROM pg_indexes WHERE tablename = 'official_sources' "
               "AND indexname = 'idx_official_sources_uuid_active'");
  CHECK(uuid_unique_index.size() == 1);
}
