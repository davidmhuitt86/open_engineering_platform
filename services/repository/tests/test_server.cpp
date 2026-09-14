#include <catch2/catch_test_macros.hpp>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/server_repository/api/server.hpp"
#include "oep/server_repository/persistence/store.hpp"
#include "test_support.hpp"

using oep::server_repository::api::ApiServer;
using oep::server_repository::common::ServerConfig;
using oep::server_repository::persistence::ServerRepositoryStore;
using oep::server_repository::test_support::kTestApiToken;
using oep::server_repository::test_support::reset_schema;
using oep::server_repository::test_support::test_database_config;

TEST_CASE("GET /health responds without any Authorization header", "[api]") {
  const auto schema_error = reset_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  ServerRepositoryStore store(test_database_config());
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;
  ApiServer server(config, kTestApiToken, store);
  REQUIRE(server.start());

  httplib::Client client(config.host, server.bound_port());
  const auto response = client.Get("/health");
  REQUIRE(response != nullptr);
  CHECK(response->status == 200);
  CHECK(nlohmann::json::parse(response->body).at("status") == "ok");

  server.stop();
}

TEST_CASE("Requests without a token are rejected, requests with the wrong token are rejected identically",
          "[api]") {
  const auto schema_error = reset_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  ServerRepositoryStore store(test_database_config());
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;
  ApiServer server(config, kTestApiToken, store);
  REQUIRE(server.start());

  SECTION("no Authorization header") {
    httplib::Client client(config.host, server.bound_port());
    const auto response = client.Get("/repositories/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 401);
    CHECK(nlohmann::json::parse(response->body).at("error") == "AUTHENTICATION_REQUIRED");
    CHECK(response->get_header_value("WWW-Authenticate") == "Bearer");
  }

  SECTION("malformed Authorization header") {
    httplib::Client client(config.host, server.bound_port());
    client.set_default_headers({{"Authorization", "not-a-bearer-token"}});
    const auto response = client.Get("/repositories/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 401);
  }

  SECTION("wrong token vs. missing token produce byte-identical responses") {
    httplib::Client wrong(config.host, server.bound_port());
    wrong.set_bearer_token_auth("definitely-the-wrong-token");
    const auto wrong_response = wrong.Get("/repositories/00000000-0000-0000-0000-000000000000");

    httplib::Client missing(config.host, server.bound_port());
    const auto missing_response = missing.Get("/repositories/00000000-0000-0000-0000-000000000000");

    REQUIRE(wrong_response != nullptr);
    REQUIRE(missing_response != nullptr);
    CHECK(wrong_response->status == missing_response->status);
    CHECK(wrong_response->body == missing_response->body);
  }

  SECTION("correct token succeeds") {
    httplib::Client client(config.host, server.bound_port());
    client.set_bearer_token_auth(kTestApiToken);
    const auto response = client.Get("/repositories/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);  // authenticated, just doesn't exist -- proves auth passed.
  }

  server.stop();
}

TEST_CASE("Error responses never leak filesystem paths, credentials, or raw driver text", "[api]") {
  const auto schema_error = reset_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  ServerRepositoryStore store(test_database_config());
  ServerConfig config;
  config.host = "127.0.0.1";
  config.port = 0;
  ApiServer server(config, kTestApiToken, store);
  REQUIRE(server.start());

  httplib::Client client(config.host, server.bound_port());
  client.set_bearer_token_auth(kTestApiToken);

  SECTION("not found") {
    const auto response = client.Get("/repositories/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->body.find(":\\") == std::string::npos);
    CHECK(response->body.find("/home/") == std::string::npos);
    CHECK(response->body.find("password") == std::string::npos);
    CHECK(response->body.find("host=") == std::string::npos);
  }

  SECTION("malformed JSON body") {
    const auto response = client.Post("/repositories", "not json", "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
    CHECK(nlohmann::json::parse(response->body).at("error") == "VALIDATION_FAILED");
    CHECK(response->body.find(":\\") == std::string::npos);
  }

  server.stop();
}
