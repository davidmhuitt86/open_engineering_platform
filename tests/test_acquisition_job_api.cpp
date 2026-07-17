#include <catch2/catch_test_macros.hpp>

#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/acquisition_job_service.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/api/server.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::acquisition::AcquisitionJobService;
using oep::acquisition::acquisition::PostgresAcquisitionJobRepository;
using oep::acquisition::api::ApiServer;
using oep::acquisition::test_support::reset_acquisition_jobs_schema;
using oep::acquisition::test_support::seed_official_source;
using oep::acquisition::test_support::test_database_config;

namespace {

nlohmann::json valid_job_body(const std::string& source_id) {
  return nlohmann::json{
      {"source_id", source_id},
      {"name", "Acquire IEEE Standard 802.11"},
      {"description", "Pull the latest revision."},
      {"priority", 1},
      {"requested_by", "jdoe"},
  };
}

}  // namespace

TEST_CASE("Acquisition Job Engine REST API", "[api][jobs][database]") {
  const auto schema_error = reset_acquisition_jobs_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string source_id = seed_official_source();
  PostgresAcquisitionJobRepository repository(test_database_config());
  AcquisitionJobService service(repository);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, nullptr, &service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  SECTION("GET /health still responds when /jobs is registered without /sources") {
    const auto response = client.Get("/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("POST /jobs creates a job in the Created state and returns 201 with a Location header") {
    const auto response = client.Post("/jobs", valid_job_body(source_id).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    const auto body = nlohmann::json::parse(response->body);
    CHECK_FALSE(body.at("id").get<std::string>().empty());
    CHECK(body.at("status") == "created");
    CHECK(response->get_header_value("Location") == "/jobs/" + body.at("id").get<std::string>());
  }

  SECTION("POST /jobs ignores a client-supplied status") {
    auto job_body = valid_job_body(source_id);
    job_body["status"] = "running";
    const auto response = client.Post("/jobs", job_body.dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(nlohmann::json::parse(response->body).at("status") == "created");
  }

  SECTION("POST /jobs rejects an invalid body with 422") {
    const auto response =
        client.Post("/jobs", nlohmann::json{{"description", "missing required fields"}}.dump(),
                    "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("violations").size() == 3);
  }

  SECTION("POST /jobs rejects an unknown source_id with 422") {
    auto job_body = valid_job_body("00000000-0000-0000-0000-000000000000");
    const auto response = client.Post("/jobs", job_body.dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "unknown_source");
  }

  SECTION("POST /jobs rejects malformed JSON with 400") {
    const auto response = client.Post("/jobs", "not json", "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
  }

  SECTION("GET /jobs/{id} returns a created job") {
    const auto created =
        nlohmann::json::parse(client.Post("/jobs", valid_job_body(source_id).dump(), "application/json")->body);
    const auto response = client.Get("/jobs/" + created.at("id").get<std::string>());
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("GET /jobs/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/jobs/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /jobs lists created jobs and supports filtering by priority") {
    client.Post("/jobs", valid_job_body(source_id).dump(), "application/json");
    auto urgent = valid_job_body(source_id);
    urgent["priority"] = 3;
    client.Post("/jobs", urgent.dump(), "application/json");

    const auto all = client.Get("/jobs");
    REQUIRE(all != nullptr);
    CHECK(nlohmann::json::parse(all->body).size() == 2);

    const auto filtered = client.Get("/jobs?priority=3");
    REQUIRE(filtered != nullptr);
    CHECK(nlohmann::json::parse(filtered->body).size() == 1);
  }

  SECTION("PUT /jobs/{id} moves a job through its lifecycle") {
    const auto created =
        nlohmann::json::parse(client.Post("/jobs", valid_job_body(source_id).dump(), "application/json")->body);
    const std::string id = created.at("id").get<std::string>();

    auto running_body = valid_job_body(source_id);
    running_body["status"] = "running";
    running_body["started_at"] = "2026-01-01T00:00:00Z";
    const auto running_response = client.Put("/jobs/" + id, running_body.dump(), "application/json");
    REQUIRE(running_response != nullptr);
    CHECK(running_response->status == 200);
    const auto running_json = nlohmann::json::parse(running_response->body);
    CHECK(running_json.at("status") == "running");
    CHECK(running_json.at("started_at") == "2026-01-01T00:00:00Z");

    auto failed_body = valid_job_body(source_id);
    failed_body["status"] = "failed";
    failed_body["completed_at"] = "2026-01-01T01:00:00Z";
    failed_body["error_message"] = "Connection timed out.";
    const auto failed_response = client.Put("/jobs/" + id, failed_body.dump(), "application/json");
    REQUIRE(failed_response != nullptr);
    const auto failed_json = nlohmann::json::parse(failed_response->body);
    CHECK(failed_json.at("status") == "failed");
    CHECK(failed_json.at("error_message") == "Connection timed out.");
  }

  SECTION("PUT /jobs/{id} rejects an attempt to change the immutable id") {
    const auto created =
        nlohmann::json::parse(client.Post("/jobs", valid_job_body(source_id).dump(), "application/json")->body);
    auto updated_body = valid_job_body(source_id);
    updated_body["status"] = "queued";
    updated_body["id"] = "00000000-0000-0000-0000-000000000000";
    const auto response =
        client.Put("/jobs/" + created.at("id").get<std::string>(), updated_body.dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
  }

  SECTION("PUT /jobs/{id} returns 404 for an unknown id") {
    auto body = valid_job_body(source_id);
    body["status"] = "queued";
    const auto response = client.Put("/jobs/00000000-0000-0000-0000-000000000000", body.dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("DELETE /jobs/{id} soft-deletes and is not repeatable") {
    const auto created =
        nlohmann::json::parse(client.Post("/jobs", valid_job_body(source_id).dump(), "application/json")->body);
    const std::string id = created.at("id").get<std::string>();

    const auto first = client.Delete("/jobs/" + id);
    REQUIRE(first != nullptr);
    CHECK(first->status == 204);

    const auto second = client.Delete("/jobs/" + id);
    REQUIRE(second != nullptr);
    CHECK(second->status == 404);
  }

  server.stop();
}
