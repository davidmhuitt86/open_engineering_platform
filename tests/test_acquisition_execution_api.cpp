#include <catch2/catch_test_macros.hpp>

#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "execution_test_support.hpp"
#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/acquisition_execution_service.hpp"
#include "oep/acquisition/acquisition/acquisition_job_service.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/acquisition/postgres_job_execution_history_repository.hpp"
#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/registry/postgres_official_source_repository.hpp"
#include "registry_test_support.hpp"

using oep::acquisition::acquisition::AcquisitionExecutionService;
using oep::acquisition::acquisition::AcquisitionJobService;
using oep::acquisition::acquisition::PostgresAcquisitionJobRepository;
using oep::acquisition::acquisition::PostgresJobExecutionHistoryRepository;
using oep::acquisition::api::ApiServer;
using oep::acquisition::registry::PostgresOfficialSourceRepository;
using oep::acquisition::test_support::reset_execution_schema;
using oep::acquisition::test_support::seed_official_source;
using oep::acquisition::test_support::test_database_config;

namespace {

nlohmann::json valid_job_body(const std::string& source_id) {
  return nlohmann::json{
      {"source_id", source_id},
      {"name", "Acquire IEEE Standard 802.11"},
      {"priority", 1},
  };
}

}  // namespace

TEST_CASE("Acquisition Execution Engine REST API", "[api][execution][database]") {
  const auto schema_error = reset_execution_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string source_id = seed_official_source();
  PostgresOfficialSourceRepository sources(test_database_config());
  PostgresAcquisitionJobRepository jobs(test_database_config());
  PostgresJobExecutionHistoryRepository history(test_database_config());
  AcquisitionJobService job_service(jobs);
  AcquisitionExecutionService execution_service(jobs, sources, history);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, nullptr, &job_service, &execution_service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  const auto create_job = [&] {
    const auto response = client.Post("/jobs", valid_job_body(source_id).dump(), "application/json");
    return nlohmann::json::parse(response->body).at("id").get<std::string>();
  };

  SECTION("POST /jobs/{id}/execute advances Created -> Queued -> Running -> Completed") {
    const std::string id = create_job();

    const auto queued = client.Post("/jobs/" + id + "/execute");
    REQUIRE(queued != nullptr);
    CHECK(queued->status == 200);
    CHECK(nlohmann::json::parse(queued->body).at("status") == "queued");

    const auto running = client.Post("/jobs/" + id + "/execute");
    REQUIRE(running != nullptr);
    const auto running_json = nlohmann::json::parse(running->body);
    CHECK(running_json.at("status") == "running");
    CHECK_FALSE(running_json.at("started_at").is_null());

    const auto completed = client.Post("/jobs/" + id + "/execute");
    REQUIRE(completed != nullptr);
    const auto completed_json = nlohmann::json::parse(completed->body);
    CHECK(completed_json.at("status") == "completed");
    CHECK_FALSE(completed_json.at("completed_at").is_null());
  }

  SECTION("POST /jobs/{id}/execute returns 409 for a terminal job") {
    const std::string id = create_job();
    client.Post("/jobs/" + id + "/execute");  // Queued
    client.Post("/jobs/" + id + "/execute");  // Running
    client.Post("/jobs/" + id + "/execute");  // Completed

    const auto response = client.Post("/jobs/" + id + "/execute");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "invalid_transition");
  }

  SECTION("POST /jobs/{id}/execute returns 404 for an unknown job") {
    const auto response = client.Post("/jobs/00000000-0000-0000-0000-000000000000/execute");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("POST /jobs/{id}/execute returns 404 after the job is soft-deleted") {
    const std::string id = create_job();
    client.Delete("/jobs/" + id);

    const auto response = client.Post("/jobs/" + id + "/execute");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("POST /jobs/{id}/cancel transitions Queued to Cancelled") {
    const std::string id = create_job();
    client.Post("/jobs/" + id + "/execute");  // Queued

    const auto response = client.Post("/jobs/" + id + "/cancel");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
    CHECK(nlohmann::json::parse(response->body).at("status") == "cancelled");
  }

  SECTION("POST /jobs/{id}/cancel returns 409 for a job in the Created state") {
    const std::string id = create_job();

    const auto response = client.Post("/jobs/" + id + "/cancel");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "invalid_transition");
  }

  SECTION("GET /jobs/{id}/status reports current status and history") {
    const std::string id = create_job();
    client.Post("/jobs/" + id + "/execute");  // Queued
    client.Post("/jobs/" + id + "/execute");  // Running

    const auto response = client.Get("/jobs/" + id + "/status");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);

    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("status") == "running");
    REQUIRE(body.at("history").size() == 2);
    CHECK(body.at("history")[0].at("to_status") == "queued");
    CHECK(body.at("history")[1].at("to_status") == "running");
  }

  SECTION("GET /jobs/{id}/status returns 404 for an unknown job") {
    const auto response = client.Get("/jobs/00000000-0000-0000-0000-000000000000/status");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  server.stop();
}
