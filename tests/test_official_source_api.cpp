#include <catch2/catch_test_macros.hpp>

#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/registry/official_source_service.hpp"
#include "oep/acquisition/registry/postgres_official_source_repository.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::api::ApiServer;
using oep::acquisition::registry::OfficialSourceService;
using oep::acquisition::registry::PostgresOfficialSourceRepository;
using oep::acquisition::test_support::reset_official_sources_table;
using oep::acquisition::test_support::test_database_config;

namespace {

nlohmann::json valid_source_body() {
  return nlohmann::json{
      {"name", "Example Standards Body"},   {"organization", "Example Org"},
      {"base_url", "https://example.org"},  {"description", "A test source."},
      {"country", "US"},                    {"language", "en"},
      {"category", "standards"},            {"trust_level", 5},
      {"status", "active"},                 {"authentication_type", "none"},
  };
}

}  // namespace

TEST_CASE("Official Source Registry REST API", "[api][registry][database]") {
  const auto schema_error = reset_official_sources_table();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  PostgresOfficialSourceRepository repository(test_database_config());
  OfficialSourceService service(repository);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, &service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  SECTION("GET /health still responds when /sources is also registered") {
    const auto response = client.Get("/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("POST /sources creates a source and returns 201 with a Location header") {
    const auto response = client.Post("/sources", valid_source_body().dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    const auto body = nlohmann::json::parse(response->body);
    CHECK_FALSE(body.at("id").get<std::string>().empty());
    CHECK(body.at("name") == "Example Standards Body");
    CHECK(response->get_header_value("Location") == "/sources/" + body.at("id").get<std::string>());
  }

  SECTION("POST /sources rejects an invalid body with 422 and lists violations") {
    const auto response =
        client.Post("/sources", nlohmann::json{{"description", "missing required fields"}}.dump(),
                    "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);

    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("error") == "validation_failed");
    CHECK(body.at("violations").size() >= 4);
  }

  SECTION("POST /sources rejects malformed JSON with 400") {
    const auto response = client.Post("/sources", "not json", "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
  }

  SECTION("GET /sources/{id} returns a created source") {
    const auto create_response = client.Post("/sources", valid_source_body().dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/sources/" + created.at("id").get<std::string>());
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
    CHECK(nlohmann::json::parse(response->body).at("base_url") == "https://example.org");
  }

  SECTION("GET /sources/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/sources/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /sources lists created sources and supports filtering") {
    client.Post("/sources", valid_source_body().dump(), "application/json");
    auto second = valid_source_body();
    second["status"] = "suspended";
    client.Post("/sources", second.dump(), "application/json");

    const auto all = client.Get("/sources");
    REQUIRE(all != nullptr);
    CHECK(nlohmann::json::parse(all->body).size() == 2);

    const auto filtered = client.Get("/sources?status=suspended");
    REQUIRE(filtered != nullptr);
    CHECK(nlohmann::json::parse(filtered->body).size() == 1);
  }

  SECTION("GET /sources rejects an unrecognized status filter with 400") {
    const auto response = client.Get("/sources?status=not-a-status");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
  }

  SECTION("PUT /sources/{id} updates a source") {
    const auto create_response = client.Post("/sources", valid_source_body().dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    auto updated_body = valid_source_body();
    updated_body["name"] = "Renamed Source";
    const auto response =
        client.Put("/sources/" + created.at("id").get<std::string>(), updated_body.dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
    CHECK(nlohmann::json::parse(response->body).at("name") == "Renamed Source");
  }

  SECTION("PUT /sources/{id} rejects an attempt to change the immutable id") {
    const auto create_response = client.Post("/sources", valid_source_body().dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    auto updated_body = valid_source_body();
    updated_body["id"] = "00000000-0000-0000-0000-000000000000";
    const auto response =
        client.Put("/sources/" + created.at("id").get<std::string>(), updated_body.dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
  }

  SECTION("PUT /sources/{id} returns 404 for an unknown id") {
    const auto response = client.Put("/sources/00000000-0000-0000-0000-000000000000",
                                      valid_source_body().dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("DELETE /sources/{id} soft-deletes and is not repeatable") {
    const auto create_response = client.Post("/sources", valid_source_body().dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);
    const std::string id = created.at("id").get<std::string>();

    const auto first = client.Delete("/sources/" + id);
    REQUIRE(first != nullptr);
    CHECK(first->status == 204);

    const auto second = client.Delete("/sources/" + id);
    REQUIRE(second != nullptr);
    CHECK(second->status == 404);

    const auto get_after_delete = client.Get("/sources/" + id);
    REQUIRE(get_after_delete != nullptr);
    CHECK(get_after_delete->status == 404);
  }

  server.stop();
}
