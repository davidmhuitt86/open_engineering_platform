#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/common/config.hpp"

using oep::acquisition::common::Config;
using oep::acquisition::common::ConfigError;

TEST_CASE("Config::load_from_string applies every declared section", "[config]") {
  const auto config = Config::load_from_string(R"toml(
    [database]
    host = "db.internal"
    port = 6543
    name = "acquisition_test"
    user = "tester"
    password = "secret"
    sslmode = "require"

    [logging]
    level = "debug"
    console = false
    file = "logs/test.log"

    [storage]
    root_path = "/mnt/vault"

    [server]
    host = "127.0.0.1"
    port = 9090
  )toml");

  CHECK(config.database.host == "db.internal");
  CHECK(config.database.port == 6543);
  CHECK(config.database.name == "acquisition_test");
  CHECK(config.database.user == "tester");
  CHECK(config.database.password == "secret");
  CHECK(config.database.sslmode == "require");

  CHECK(config.logging.level == "debug");
  CHECK(config.logging.console == false);
  CHECK(config.logging.file == "logs/test.log");

  CHECK(config.storage.root_path == "/mnt/vault");

  CHECK(config.server.host == "127.0.0.1");
  CHECK(config.server.port == 9090);
}

TEST_CASE("Config defaults apply when a section is entirely absent", "[config]") {
  const auto config = Config::load_from_string("");

  CHECK(config.database.host == "localhost");
  CHECK(config.database.port == 5432);
  CHECK(config.logging.level == "info");
  CHECK(config.logging.console == true);
  CHECK(config.storage.root_path == "./data/vault");
  CHECK(config.server.port == 8080);
}

TEST_CASE("Config defaults apply when only some fields in a section are set", "[config]") {
  const auto config = Config::load_from_string(R"toml(
    [server]
    port = 9999
  )toml");

  CHECK(config.server.port == 9999);
  CHECK(config.server.host == "0.0.0.0");  // default, untouched
}

TEST_CASE("Config::load_from_string throws ConfigError on malformed TOML", "[config]") {
  REQUIRE_THROWS_AS(Config::load_from_string("this is not [ valid toml"), ConfigError);
}

TEST_CASE("Config::load_from_file throws ConfigError for a missing file", "[config]") {
  REQUIRE_THROWS_AS(Config::load_from_file("/path/does/not/exist.toml"), ConfigError);
}

TEST_CASE("database_connection_string formats a libpq key/value string", "[config]") {
  Config config;
  config.database.host = "db.internal";
  config.database.port = 6543;
  config.database.name = "acquisition_test";
  config.database.user = "tester";
  config.database.sslmode = "require";

  CHECK(config.database_connection_string() ==
        "host=db.internal port=6543 dbname=acquisition_test user=tester sslmode=require");
}

TEST_CASE("database_connection_string includes password only when non-empty", "[config]") {
  Config config;
  config.database.password = "hunter2";

  CHECK(config.database_connection_string().find("password=hunter2") != std::string::npos);
}
