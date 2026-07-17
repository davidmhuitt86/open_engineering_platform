#include <catch2/catch_test_macros.hpp>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/acquisition/api/server.hpp"

using oep::acquisition::api::ApiServer;
using oep::acquisition::common::ServerConfig;

TEST_CASE("GET /health responds with status ok", "[api]") {
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;  // OS-assigned ephemeral port -- avoids colliding with anything else.

  ApiServer server(config);
  REQUIRE(server.start());
  REQUIRE(server.bound_port() != 0);

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

TEST_CASE("An unregistered route does not resolve to the health handler", "[api]") {
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;

  ApiServer server(config);
  REQUIRE(server.start());

  httplib::Client client(config.host, server.bound_port());
  const auto response = client.Get("/does-not-exist");

  REQUIRE(response != nullptr);
  CHECK(response->status == 404);

  server.stop();
}
