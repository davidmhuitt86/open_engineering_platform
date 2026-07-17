#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/connectors/connector_errors.hpp"
#include "oep/acquisition/connectors/connector_factory.hpp"
#include "oep/acquisition/connectors/stub_connector.hpp"

using namespace oep::acquisition::connectors;

namespace {

ConnectorConfig make_config(const std::string& type = "stub") {
  ConnectorConfig config;
  config.connector_id = "conn-1";
  config.type = type;
  config.name = "Test Connector";
  return config;
}

}  // namespace

TEST_CASE("ConnectorFactory constructs a connector using its registered type's creator",
          "[connectors][factory]") {
  ConnectorFactory factory;
  factory.register_type("stub", [](const ConnectorConfig& config) {
    return std::make_unique<StubConnector>(config);
  });

  const auto connector = factory.create(make_config());
  REQUIRE(connector != nullptr);
  CHECK(connector->config().connector_id == "conn-1");
}

TEST_CASE("ConnectorFactory.has_type reflects registered types", "[connectors][factory]") {
  ConnectorFactory factory;
  CHECK_FALSE(factory.has_type("stub"));

  factory.register_type("stub", [](const ConnectorConfig& config) {
    return std::make_unique<StubConnector>(config);
  });
  CHECK(factory.has_type("stub"));
}

TEST_CASE("ConnectorFactory.create throws UnknownConnectorTypeError for an unregistered type",
          "[connectors][factory]") {
  ConnectorFactory factory;
  CHECK_THROWS_AS(factory.create(make_config("does-not-exist")), UnknownConnectorTypeError);
}

TEST_CASE("ConnectorFactory.register_type replaces a previously-registered creator for the same type",
          "[connectors][factory]") {
  ConnectorFactory factory;
  int first_calls = 0;
  int second_calls = 0;

  factory.register_type("stub", [&first_calls](const ConnectorConfig& config) {
    ++first_calls;
    return std::make_unique<StubConnector>(config);
  });
  factory.register_type("stub", [&second_calls](const ConnectorConfig& config) {
    ++second_calls;
    return std::make_unique<StubConnector>(config);
  });

  [[maybe_unused]] const auto connector = factory.create(make_config());
  CHECK(first_calls == 0);
  CHECK(second_calls == 1);
}
