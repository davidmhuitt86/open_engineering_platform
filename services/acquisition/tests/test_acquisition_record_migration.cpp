#include <catch2/catch_test_macros.hpp>

#include <algorithm>
#include <string>
#include <vector>

#include <pqxx/pqxx>

#include "oep/acquisition/common/config.hpp"
#include "provenance_test_support.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::common::Config;
using oep::acquisition::test_support::reset_provenance_schema;
using oep::acquisition::test_support::test_database_config;

TEST_CASE("V10 migration applies cleanly and produces the expected acquisition_records schema",
          "[provenance][database][migration]") {
  const auto schema_error = reset_provenance_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  pqxx::connection connection(Config{.database = test_database_config()}.database_connection_string());
  pqxx::work txn(connection);

  const auto columns =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'acquisition_records' ORDER BY ordinal_position");

  std::vector<std::string> column_names;
  for (const auto& row : columns) {
    column_names.push_back(row[0].as<std::string>());
  }

  const std::vector<std::string> expected = {"id",       "uuid",       "download_session_id", "status",
                                              "error_message", "created_at", "updated_at"};
  CHECK(column_names == expected);

  // WP-018: reference_vault is deliberately left completely unmodified by
  // this migration -- a Vault Entry's owning Acquisition Record is found
  // by traversing download_session_id, not by a new column on either
  // table (see V10's own migration comment).
  const auto vault_columns =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'reference_vault' AND column_name = 'acquisition_record_id'");
  CHECK(vault_columns.empty());

  const auto foreign_keys =
      txn.exec("SELECT constraint_name FROM information_schema.table_constraints "
               "WHERE table_name = 'acquisition_records' AND constraint_type = 'FOREIGN KEY'");
  CHECK(foreign_keys.size() == 1);  // download_session_id -> download_sessions(uuid)

  const auto unique_constraints =
      txn.exec("SELECT constraint_name FROM information_schema.table_constraints "
               "WHERE table_name = 'acquisition_records' AND constraint_type = 'UNIQUE'");
  CHECK(unique_constraints.size() == 2);  // uuid, download_session_id

  // Exactly one Acquisition Record per Download Session (WP-018 Section 6).
  const auto indexes = txn.exec("SELECT indexname FROM pg_indexes WHERE tablename = 'acquisition_records'");
  std::vector<std::string> index_names;
  for (const auto& row : indexes) {
    index_names.push_back(row[0].as<std::string>());
  }
  CHECK(std::find(index_names.begin(), index_names.end(), "idx_acquisition_records_status") != index_names.end());

  // No deleted_at column -- this WP's REST API has no DELETE route.
  const auto deleted_at =
      txn.exec("SELECT column_name FROM information_schema.columns "
               "WHERE table_name = 'acquisition_records' AND column_name = 'deleted_at'");
  CHECK(deleted_at.empty());
}

TEST_CASE("acquisition_records rejects a second row for the same download_session_id",
          "[provenance][database][migration]") {
  const auto schema_error = reset_provenance_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = oep::acquisition::test_support::seed_completed_download();
  pqxx::connection connection(Config{.database = test_database_config()}.database_connection_string());

  {
    pqxx::work txn(connection);
    txn.exec_params("INSERT INTO acquisition_records (download_session_id, status) VALUES ($1::uuid, 'acquired')",
                     pqxx::params{seeded.id});
    txn.commit();
  }

  pqxx::work txn(connection);
  CHECK_THROWS_AS(
      txn.exec_params("INSERT INTO acquisition_records (download_session_id, status) VALUES ($1::uuid, 'acquired')",
                       pqxx::params{seeded.id}),
      pqxx::unique_violation);
}
