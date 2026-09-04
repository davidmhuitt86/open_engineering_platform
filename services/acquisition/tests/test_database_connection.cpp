#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/database/database_connection.hpp"

using oep::acquisition::common::DatabaseConfig;
using oep::acquisition::database::DatabaseConnection;

// Deliberately does not assert a *successful* connection anywhere in this
// suite -- WORK_PACKAGE_001 requires the connection object to exist and
// behave correctly, not that a live PostgreSQL 18 instance with matching
// credentials is reachable wherever these tests run. The failure path
// below is fully deterministic and needs no external service.
TEST_CASE("DatabaseConnection reports failure for an unreachable host without throwing", "[database]") {
  DatabaseConfig config;
  config.host = "127.0.0.1";
  config.port = 1;  // Reserved port; nothing binds a PostgreSQL server there.

  const DatabaseConnection connection(config);

  CHECK_FALSE(connection.is_connected());
  CHECK_FALSE(connection.last_error().empty());
}

TEST_CASE("DatabaseConnection is move-constructible", "[database]") {
  DatabaseConfig config;
  config.host = "127.0.0.1";
  config.port = 1;

  DatabaseConnection original(config);
  DatabaseConnection moved(std::move(original));

  CHECK_FALSE(moved.is_connected());
}
