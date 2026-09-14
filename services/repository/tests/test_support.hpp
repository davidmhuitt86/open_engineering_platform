#pragma once

#include <optional>
#include <string>

#include "oep/server_repository/common/config.hpp"

namespace oep::server_repository::test_support {

/// A fixed, obviously-fake bearer token used only to construct
/// `ApiServer` instances in tests -- mirrors EAM's own
/// `kTestApiToken` convention exactly (services/acquisition/tests/
/// registry_test_support.hpp).
inline const std::string kTestApiToken = "test-only-wp-srv-011-fake-token";

/// Reads `OEP_TEST_DB_{HOST,PORT,NAME,USER,PASSWORD}` environment
/// variables, falling back to `common::DatabaseConfig`'s own defaults.
/// Mirrors services/acquisition's own `test_database_config` exactly,
/// so the same environment-variable convention works for both services
/// (pointed at two different databases via `OEP_TEST_DB_NAME`).
[[nodiscard]] common::DatabaseConfig test_database_config();

/// Ensures the schema exists (applying `migrations/V1__initial_schema.sql`
/// verbatim from disk the first time) and truncates every table
/// (`TRUNCATE repositories CASCADE` -- every other table's foreign keys
/// trace back to `repositories`, directly or transitively, so this one
/// statement clears the whole schema) so every test starts from an
/// empty database. Returns an error message if the database is
/// unreachable, in which case the caller should `SKIP` the test rather
/// than fail it -- mirroring EAM's own established convention exactly
/// (a missing local PostgreSQL instance is an environment gap, not a
/// defect).
[[nodiscard]] std::optional<std::string> reset_schema();

}  // namespace oep::server_repository::test_support
