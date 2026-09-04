#include <catch2/catch_test_macros.hpp>

#include <string>
#include <vector>

#include <pqxx/pqxx>

#include "oep/acquisition/common/config.hpp"
#include "registry_test_support.hpp"
#include "vault_test_support.hpp"

using oep::acquisition::common::Config;
using oep::acquisition::test_support::reset_vault_schema;
using oep::acquisition::test_support::test_database_config;

TEST_CASE("V8 migration applies cleanly and produces the expected reference_vault schema",
          "[vault][database][migration]") {
  const auto schema_error = reset_vault_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  pqxx::connection connection(Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);

  const auto columns =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'reference_vault' ORDER BY ordinal_position");

  std::vector<std::string> column_names;
  for (const auto& row : columns) {
    column_names.push_back(row[0].as<std::string>());
  }

  const std::vector<std::string> expected = {
      "id",       "uuid",         "metadata_id", "verification_id", "download_session_id",
      "source_id", "vault_path", "sha256_hash", "mime_type",       "file_size_bytes",
      "status",   "published_at", "created_at",  "updated_at"};
  CHECK(column_names == expected);

  const auto status_not_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'reference_vault' AND column_name = 'status'");
  REQUIRE(status_not_nullable.size() == 1);
  CHECK(status_not_nullable[0][0].as<std::string>() == "NO");

  const auto published_at_not_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'reference_vault' AND column_name = 'published_at'");
  REQUIRE(published_at_not_nullable.size() == 1);
  CHECK(published_at_not_nullable[0][0].as<std::string>() == "NO");

  const auto foreign_keys =
      txn.exec("SELECT constraint_name FROM information_schema.table_constraints "
               "WHERE table_name = 'reference_vault' AND constraint_type = 'FOREIGN KEY'");
  CHECK(foreign_keys.size() == 4);

  // "Publish Verified Artifact" has no "Re-publish" counterpart -- a given
  // metadata_id may be published at most once (see README.md
  // "Implementation Decisions").
  const auto unique_constraints =
      txn.exec("SELECT constraint_name FROM information_schema.table_constraints "
               "WHERE table_name = 'reference_vault' AND constraint_type = 'UNIQUE'");
  CHECK(unique_constraints.size() == 2);  // uuid, metadata_id

  // No deleted_at column -- WORK_PACKAGE-009's REST API has no DELETE
  // route, and vault entries are immutable.
  const auto deleted_at =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'reference_vault' AND column_name = 'deleted_at'");
  CHECK(deleted_at.empty());
}
