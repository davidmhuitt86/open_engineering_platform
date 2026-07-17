#include <catch2/catch_test_macros.hpp>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/connectors/connector_factory.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/connectors/stub_connector.hpp"

using namespace oep::acquisition::connectors;
using oep::acquisition::api::ApiServer;

namespace {

ConnectorFactory make_factory() {
  ConnectorFactory factory;
  factory.register_type("stub", [](const ConnectorConfig& config) {
    return std::make_unique<StubConnector>(config);
  });
  return factory;
}

}  // namespace

// This is also WORK_PACKAGE-005's integration test: Factory, Registry, and
// the REST layer wired together exactly as main.cpp wires them.
TEST_CASE("Connector Framework REST API", "[api][connectors]") {
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  ConnectorConfig config;
  config.connector_id = "example-stub";
  config.type = "stub";
  config.name = "Example Stub Connector";
  config.description = "Demonstrates the framework.";
  config.settings = {{"capabilities", "download_files,search"}};
  registry.register_connector(config);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, nullptr, nullptr, nullptr, &registry);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  SECTION("GET /health still responds when only connectors is registered") {
    const auto response = client.Get("/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("GET /connectors lists every registered connector") {
    const auto response = client.Get("/connectors");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);

    const auto body = nlohmann::json::parse(response->body);
    REQUIRE(body.size() == 1);
    CHECK(body[0].at("id") == "example-stub");
    CHECK(body[0].at("type") == "stub");
  }

  SECTION("GET /connectors/{id} returns one connector") {
    const auto response = client.Get("/connectors/example-stub");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);

    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("name") == "Example Stub Connector");
    CHECK(body.at("description") == "Demonstrates the framework.");
  }

  SECTION("GET /connectors/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/connectors/does-not-exist");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /connectors/{id}/capabilities lists the connector's capabilities") {
    const auto response = client.Get("/connectors/example-stub/capabilities");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);

    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("id") == "example-stub");
    const auto capabilities = body.at("capabilities").get<std::vector<std::string>>();
    CHECK(capabilities.size() == 2);
  }

  SECTION("GET /connectors/{id}/capabilities returns 404 for an unknown id") {
    const auto response = client.Get("/connectors/does-not-exist/capabilities");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /connectors/{id}/health reports the connector's health") {
    const auto response = client.Get("/connectors/example-stub/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);

    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("id") == "example-stub");
    CHECK(body.at("status") == "healthy");
    CHECK_FALSE(body.at("checked_at").get<std::string>().empty());
  }

  SECTION("GET /connectors/{id}/health returns 404 for an unknown id") {
    const auto response = client.Get("/connectors/does-not-exist/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  server.stop();
}
