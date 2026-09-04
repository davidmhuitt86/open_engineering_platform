#include <catch2/catch_test_macros.hpp>

#include <string>
#include <vector>

#include <pqxx/pqxx>

#include "integrity_test_support.hpp"
#include "oep/acquisition/common/config.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::common::Config;
using oep::acquisition::test_support::reset_integrity_schema;
using oep::acquisition::test_support::test_database_config;

TEST_CASE(
    "V6 migration applies cleanly and produces the expected integrity_verifications schema",
    "[integrity][database][migration]") {
  const auto schema_error = reset_integrity_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  pqxx::connection connection(Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);

  const auto columns =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'integrity_verifications' ORDER BY ordinal_position");

  std::vector<std::string> column_names;
  for (const auto& row : columns) {
    column_names.push_back(row[0].as<std::string>());
  }

  const std::vector<std::string> expected = {
      "id",         "uuid",       "download_session_id", "status",     "sha256_hash",
      "file_size_bytes", "verified_at", "error_message", "created_at", "updated_at"};
  CHECK(column_names == expected);

  const auto verified_at_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'integrity_verifications' AND column_name = 'verified_at'");
  REQUIRE(verified_at_nullable.size() == 1);
  CHECK(verified_at_nullable[0][0].as<std::string>() == "YES");

  const auto status_not_nullable =
      txn.exec("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name = 'integrity_verifications' AND column_name = 'status'");
  REQUIRE(status_not_nullable.size() == 1);
  CHECK(status_not_nullable[0][0].as<std::string>() == "NO");

  const auto foreign_key =
      txn.exec("SELECT constraint_name FROM information_schema.table_constraints "
               "WHERE table_name = 'integrity_verifications' AND constraint_type = 'FOREIGN KEY'");
  CHECK(foreign_key.size() == 1);

  // No metadata columns, per WORK_PACKAGE-007's Objective: "No metadata
  // extraction or engineering object creation shall be performed" / "No
  // metadata shall be stored."
  const auto metadata_column =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'integrity_verifications' AND column_name = 'metadata'");
  CHECK(metadata_column.empty());

  // No deleted_at column -- WORK_PACKAGE-007 has no DELETE route.
  const auto deleted_at =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'integrity_verifications' AND column_name = 'deleted_at'");
  CHECK(deleted_at.empty());
}
