#include <catch2/catch_test_macros.hpp>

#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "integrity_test_support.hpp"
#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "oep/acquisition/integrity/integrity_verification_service.hpp"
#include "oep/acquisition/integrity/postgres_verification_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::integrity;
using oep::acquisition::api::ApiServer;
using oep::acquisition::downloads::PostgresDownloadRepository;
using oep::acquisition::test_support::reset_integrity_schema;
using oep::acquisition::test_support::seed_completed_download;
using oep::acquisition::test_support::test_database_config;

namespace {

nlohmann::json verify_body(const std::string& download_session_id) {
  return nlohmann::json{{"download_session_id", download_session_id}};
}

}  // namespace

TEST_CASE("Engineering Integrity Verification Engine REST API", "[api][integrity][database]") {
  const auto schema_error = reset_integrity_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = seed_completed_download();
  PostgresDownloadRepository download_repository(test_database_config());
  PostgresVerificationRepository verification_repository(test_database_config());
  IntegrityVerificationService service(verification_repository, download_repository);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, nullptr, nullptr, nullptr, nullptr, nullptr, &service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  SECTION("GET /health still responds when only verifications is registered") {
    const auto response = client.Get("/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("POST /verifications verifies a real artifact end to end and returns 201") {
    const auto response =
        client.Post("/verifications", verify_body(seeded.id).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    const auto body = nlohmann::json::parse(response->body);
    CHECK_FALSE(body.at("id").get<std::string>().empty());
    CHECK(body.at("status") == "verified");
    CHECK_FALSE(body.at("sha256_hash").get<std::string>().empty());
    CHECK(response->get_header_value("Location") == "/verifications/" + body.at("id").get<std::string>());
  }

  SECTION("POST /verifications rejects an invalid body with 422") {
    const auto response =
        client.Post("/verifications", nlohmann::json::object().dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("violations").size() == 1);
  }

  SECTION("POST /verifications rejects malformed JSON with 400") {
    const auto response = client.Post("/verifications", "not json", "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
  }

  SECTION("POST /verifications returns 422 unknown_download_session for a nonexistent session") {
    const auto response = client.Post(
        "/verifications", verify_body("00000000-0000-0000-0000-000000000000").dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "unknown_download_session");
  }

  SECTION("GET /verifications/{id} returns a created verification") {
    const auto create_response =
        client.Post("/verifications", verify_body(seeded.id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/verifications/" + created.at("id").get<std::string>());
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("GET /verifications/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/verifications/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /verifications/{id}/status reports status and hash") {
    const auto create_response =
        client.Post("/verifications", verify_body(seeded.id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/verifications/" + created.at("id").get<std::string>() + "/status");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("status") == "verified");
    CHECK_FALSE(body.at("sha256_hash").get<std::string>().empty());
  }

  SECTION("GET /verifications lists created verifications and supports filtering by download_session_id") {
    const auto other_seeded = seed_completed_download("a different artifact");
    client.Post("/verifications", verify_body(seeded.id).dump(), "application/json");
    client.Post("/verifications", verify_body(other_seeded.id).dump(), "application/json");

    const auto all = client.Get("/verifications");
    REQUIRE(all != nullptr);
    CHECK(nlohmann::json::parse(all->body).size() == 2);

    const auto filtered = client.Get("/verifications?download_session_id=" + seeded.id);
    REQUIRE(filtered != nullptr);
    CHECK(nlohmann::json::parse(filtered->body).size() == 1);
  }

  server.stop();
}
