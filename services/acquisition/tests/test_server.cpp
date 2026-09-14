#include <catch2/catch_test_macros.hpp>

#include <stdexcept>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/acquisition/api/server.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::api::ApiServer;
using oep::acquisition::common::ServerConfig;
using oep::acquisition::test_support::kTestApiToken;

TEST_CASE("GET /health responds with status ok without any Authorization header", "[api]") {
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;  // OS-assigned ephemeral port -- avoids colliding with anything else.

  ApiServer server(config, kTestApiToken);
  REQUIRE(server.start());
  REQUIRE(server.bound_port() != 0);

  // WP-SRV-003 / ADR-0002: /health is the one intentionally public route --
  // no Authorization header is sent here at all.
  httplib::Client client(config.host, server.bound_port());
  const auto response = client.Get("/health");

  REQUIRE(response != nullptr);
  CHECK(response->status == 200);
  CHECK(response->get_header_value("Content-Type") == "application/json");

  const auto body = nlohmann::json::parse(response->body);
  CHECK(body.at("status") == "ok");

  server.stop();
  CHECK_FALSE(server.is_running());
}

TEST_CASE("GET /health also succeeds with a valid Authorization header", "[api]") {
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;

  ApiServer server(config, kTestApiToken);
  REQUIRE(server.start());

  httplib::Client client(config.host, server.bound_port());
  client.set_bearer_token_auth(kTestApiToken);
  const auto response = client.Get("/health");

  REQUIRE(response != nullptr);
  CHECK(response->status == 200);

  server.stop();
}

TEST_CASE("An unregistered route with a valid token does not resolve to the health handler", "[api]") {
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;

  ApiServer server(config, kTestApiToken);
  REQUIRE(server.start());

  httplib::Client client(config.host, server.bound_port());
  client.set_bearer_token_auth(kTestApiToken);
  const auto response = client.Get("/does-not-exist");

  REQUIRE(response != nullptr);
  CHECK(response->status == 404);

  server.stop();
}

TEST_CASE("Constructing ApiServer with an empty api_token throws", "[api]") {
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;

  CHECK_THROWS_AS(ApiServer(config, ""), std::invalid_argument);
}
