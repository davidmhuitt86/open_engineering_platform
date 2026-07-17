#include <catch2/catch_test_macros.hpp>

#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "metadata_test_support.hpp"
#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "oep/acquisition/integrity/postgres_verification_repository.hpp"
#include "oep/acquisition/metadata/metadata_extraction_service.hpp"
#include "oep/acquisition/metadata/postgres_metadata_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::metadata;
using oep::acquisition::api::ApiServer;
using oep::acquisition::downloads::PostgresDownloadRepository;
using oep::acquisition::integrity::PostgresVerificationRepository;
using oep::acquisition::test_support::reset_metadata_schema;
using oep::acquisition::test_support::seed_verified_download;
using oep::acquisition::test_support::test_database_config;

namespace {

nlohmann::json extract_body(const std::string& verification_id) {
  return nlohmann::json{{"verification_id", verification_id}};
}

}  // namespace

TEST_CASE("Engineering Metadata Extraction Engine REST API", "[api][metadata][database]") {
  const auto schema_error = reset_metadata_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = seed_verified_download("some plain text content", "notes.txt");
  PostgresDownloadRepository download_repository(test_database_config());
  PostgresVerificationRepository verification_repository(test_database_config());
  PostgresMetadataRepository metadata_repository(test_database_config());
  MetadataExtractionService service(metadata_repository, verification_repository, download_repository);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, &service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  SECTION("GET /health still responds when only metadata is registered") {
    const auto response = client.Get("/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("POST /metadata extracts metadata from a real artifact end to end and returns 201") {
    const auto response =
        client.Post("/metadata", extract_body(seeded.id).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    const auto body = nlohmann::json::parse(response->body);
    CHECK_FALSE(body.at("id").get<std::string>().empty());
    CHECK(body.at("status") == "extracted");
    CHECK(body.at("mime_type") == "text/plain");
    CHECK(body.at("file_name") == "notes.txt");
    CHECK(body.at("sha256_hash") == seeded.sha256_hash);
    CHECK(response->get_header_value("Location") == "/metadata/" + body.at("id").get<std::string>());
  }

  SECTION("POST /metadata rejects an invalid body with 422") {
    const auto response = client.Post("/metadata", nlohmann::json::object().dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("violations").size() == 1);
  }

  SECTION("POST /metadata rejects malformed JSON with 400") {
    const auto response = client.Post("/metadata", "not json", "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
  }

  SECTION("POST /metadata returns 422 unknown_verification for a nonexistent verification") {
    const auto response = client.Post(
        "/metadata", extract_body("00000000-0000-0000-0000-000000000000").dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "unknown_verification");
  }

  SECTION("GET /metadata/{id} returns a created record") {
    const auto create_response = client.Post("/metadata", extract_body(seeded.id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/metadata/" + created.at("id").get<std::string>());
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("GET /metadata/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/metadata/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /metadata/{id}/status reports status only") {
    const auto create_response = client.Post("/metadata", extract_body(seeded.id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/metadata/" + created.at("id").get<std::string>() + "/status");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("status") == "extracted");
  }

  SECTION("GET /metadata lists records and supports filtering by verification_id, preserving history") {
    client.Post("/metadata", extract_body(seeded.id).dump(), "application/json");
    client.Post("/metadata", extract_body(seeded.id).dump(), "application/json");

    const auto all = client.Get("/metadata");
    REQUIRE(all != nullptr);
    CHECK(nlohmann::json::parse(all->body).size() == 2);

    const auto filtered = client.Get("/metadata?verification_id=" + seeded.id);
    REQUIRE(filtered != nullptr);
    CHECK(nlohmann::json::parse(filtered->body).size() == 2);
  }

  server.stop();
}
