#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/connectors/stub_connector.hpp"

using namespace oep::acquisition::connectors;

namespace {

ConnectorConfig make_config() {
  ConnectorConfig config;
  config.connector_id = "conn-1";
  config.type = "stub";
  config.name = "Test Connector";
  return config;
}

}  // namespace

TEST_CASE("StubConnector.connect/disconnect toggle is_connected", "[connectors][stub]") {
  StubConnector connector(make_config());
  CHECK_FALSE(connector.is_connected());

  connector.connect();
  CHECK(connector.is_connected());

  connector.disconnect();
  CHECK_FALSE(connector.is_connected());
}

TEST_CASE("StubConnector.capabilities parses the comma-separated 'capabilities' setting",
          "[connectors][stub]") {
  auto config = make_config();
  config.settings["capabilities"] = "download_files,search";
  StubConnector connector(config);

  const auto capabilities = connector.capabilities();
  CHECK(capabilities.size() == 2);
  CHECK(capabilities.contains("download_files"));
  CHECK(capabilities.contains("search"));
}

TEST_CASE("StubConnector.capabilities is empty when the setting is absent", "[connectors][stub]") {
  StubConnector connector(make_config());
  CHECK(connector.capabilities().empty());
}

TEST_CASE("StubConnector.health_check defaults to Healthy", "[connectors][stub]") {
  StubConnector connector(make_config());
  const auto result = connector.health_check();
  CHECK(result.status == HealthStatus::Healthy);
  CHECK_FALSE(result.message.empty());
  CHECK_FALSE(result.checked_at.empty());
}

TEST_CASE("StubConnector.health_check honors the 'health_status' setting", "[connectors][stub]") {
  auto unhealthy_config = make_config();
  unhealthy_config.settings["health_status"] = "unhealthy";
  CHECK(StubConnector(unhealthy_config).health_check().status == HealthStatus::Unhealthy);

  auto unknown_config = make_config();
  unknown_config.settings["health_status"] = "unknown";
  CHECK(StubConnector(unknown_config).health_check().status == HealthStatus::Unknown);
}

TEST_CASE("StubConnector.validate_configuration requires a non-empty id and type", "[connectors][stub]") {
  CHECK(StubConnector(make_config()).validate_configuration());

  auto missing_id = make_config();
  missing_id.connector_id.clear();
  CHECK_FALSE(StubConnector(missing_id).validate_configuration());

  auto missing_type = make_config();
  missing_type.type.clear();
  CHECK_FALSE(StubConnector(missing_type).validate_configuration());
}

TEST_CASE("StubConnector.capabilities is unaffected by connect/disconnect (immutable post-construction)",
          "[connectors][stub][validation]") {
  auto config = make_config();
  config.settings["capabilities"] = "download_files";
  StubConnector connector(config);

  const auto before = connector.capabilities();
  connector.connect();
  connector.disconnect();
  const auto after = connector.capabilities();

  // WORK_PACKAGE-005: "Capability definitions shall be immutable after
  // registration" -- IConnector exposes no setter for capabilities, so
  // this is satisfied by the interface's shape; this test only confirms
  // no other operation on the connector has a side effect on it.
  CHECK(before == after);
}
