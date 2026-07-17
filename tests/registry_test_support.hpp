#pragma once

#include <optional>
#include <string>

#include "oep/acquisition/common/config.hpp"

namespace oep::acquisition::test_support {

/// Reads `OEP_TEST_DB_{HOST,PORT,NAME,USER,PASSWORD}` environment variables,
/// falling back to `common::DatabaseConfig`'s own defaults (which match
/// `config/config.toml`) for anything unset. Lets Repository/API/migration
/// tests run against a differently-configured PostgreSQL instance without
/// editing test code -- see README.md "Test".
[[nodiscard]] common::DatabaseConfig test_database_config();

/// Ensures the `official_sources` table exists -- applying
/// `migrations/V1__initial_schema.sql` and `migrations/V2__official_sources.sql`
/// verbatim from disk the first time this is called against a given
/// database -- and truncates it so every test starts from an empty table.
///
/// Returns an error message if the database is unreachable (or the
/// migrations could not be applied), in which case the caller should
/// `SKIP` the test rather than fail it: a missing local PostgreSQL
/// instance is an environment gap, not a defect (continuing
/// WORK_PACKAGE_001's precedent that a database-dependent test suite
/// remains runnable, if not fully exercised, without one).
[[nodiscard]] std::optional<std::string> reset_official_sources_table();

}  // namespace oep::acquisition::test_support
