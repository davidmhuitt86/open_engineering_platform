#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/connectors/connector_errors.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/connectors/stub_connector.hpp"

using namespace oep::acquisition::connectors;

namespace {

ConnectorFactory make_factory() {
  ConnectorFactory factory;
  factory.register_type("stub", [](const ConnectorConfig& config) {
    return std::make_unique<StubConnector>(config);
  });
  return factory;
}

ConnectorConfig make_config(const std::string& id = "conn-1") {
  ConnectorConfig config;
  config.connector_id = id;
  config.type = "stub";
  config.name = "Test Connector";
  return config;
}

}  // namespace

TEST_CASE("ConnectorRegistry.register_connector registers and resolves a connector",
          "[connectors][registry]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  registry.register_connector(make_config());

  const auto* resolved = registry.resolve("conn-1");
  REQUIRE(resolved != nullptr);
  CHECK(resolved->config().name == "Test Connector");
}

TEST_CASE("ConnectorRegistry.resolve returns nullptr for an unknown id", "[connectors][registry]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  CHECK(registry.resolve("does-not-exist") == nullptr);
}

TEST_CASE("ConnectorRegistry.register_connector rejects a duplicate connector_id",
          "[connectors][registry]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  registry.register_connector(make_config());

  CHECK_THROWS_AS(registry.register_connector(make_config()), DuplicateConnectorIdError);
}

TEST_CASE("ConnectorRegistry.register_connector rejects an unknown connector type",
          "[connectors][registry]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  auto config = make_config();
  config.type = "does-not-exist";
  CHECK_THROWS_AS(registry.register_connector(config), UnknownConnectorTypeError);
}

TEST_CASE("ConnectorRegistry.register_connector rejects a connector that fails to validate",
          "[connectors][registry]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  auto config = make_config();
  config.connector_id.clear();  // StubConnector::validate_configuration requires a non-empty id
  CHECK_THROWS_AS(registry.register_connector(config), ConnectorValidationError);
}

TEST_CASE("ConnectorRegistry.list returns every registered connector", "[connectors][registry]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  registry.register_connector(make_config("conn-1"));
  registry.register_connector(make_config("conn-2"));

  CHECK(registry.list().size() == 2);
}

TEST_CASE("ConnectorRegistry.list is empty when nothing is registered", "[connectors][registry]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  CHECK(registry.list().empty());
}
