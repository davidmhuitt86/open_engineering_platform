#include <catch2/catch_test_macros.hpp>

#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "downloads_test_support.hpp"
#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/connectors/connector_factory.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/connectors/stub_connector.hpp"
#include "oep/acquisition/downloads/download_service.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::downloads;
using oep::acquisition::acquisition::AcquisitionJob;
using oep::acquisition::acquisition::JobPriority;
using oep::acquisition::acquisition::JobStatus;
using oep::acquisition::acquisition::PostgresAcquisitionJobRepository;
using oep::acquisition::api::ApiServer;
using oep::acquisition::connectors::ConnectorConfig;
using oep::acquisition::connectors::ConnectorFactory;
using oep::acquisition::connectors::ConnectorRegistry;
using oep::acquisition::connectors::StubConnector;
using oep::acquisition::test_support::reset_downloads_schema;
using oep::acquisition::test_support::seed_official_source;
using oep::acquisition::test_support::test_database_config;

namespace {

nlohmann::json start_body(const std::string& job_id, const std::string& connector_id = "conn-1") {
  return nlohmann::json{
      {"job_id", job_id},
      {"connector_id", connector_id},
      {"source_uri", "stub://example/artifact.pdf"},
  };
}

}  // namespace

TEST_CASE("Engineering Downloader REST API", "[api][downloads][database]") {
  const auto schema_error = reset_downloads_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string source_id = seed_official_source();
  PostgresAcquisitionJobRepository jobs(test_database_config());
  PostgresDownloadRepository download_repository(test_database_config());

  ConnectorFactory factory;
  factory.register_type("stub",
                          [](const ConnectorConfig& config) { return std::make_unique<StubConnector>(config); });
  ConnectorRegistry registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  connector_config.name = "Test Connector";
  registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path =
      (std::filesystem::temp_directory_path() / "oep_download_api_test").string();
  std::filesystem::create_directories(storage.workspace_path);

  DownloadService service(download_repository, jobs, registry, storage);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, nullptr, nullptr, nullptr, nullptr, &service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  const auto create_job = [&](JobStatus status) {
    AcquisitionJob job;
    job.source_id = source_id;
    job.name = "Acquire 802.11";
    job.priority = JobPriority::Normal;
    job.status = JobStatus::Created;
    const auto created = jobs.create(job);
    if (status != JobStatus::Created) {
      auto updated = created;
      updated.status = status;
      jobs.update(created.id, updated);
    }
    return created.id;
  };

  SECTION("GET /health still responds when only downloads is registered") {
    const auto response = client.Get("/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("POST /downloads completes a download and returns 201 with a Location header") {
    const std::string job_id = create_job(JobStatus::Created);
    const auto response = client.Post("/downloads", start_body(job_id).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    const auto body = nlohmann::json::parse(response->body);
    CHECK_FALSE(body.at("id").get<std::string>().empty());
    CHECK(body.at("status") == "completed");
    CHECK(body.at("progress_percentage") == 100);
    CHECK(response->get_header_value("Location") == "/downloads/" + body.at("id").get<std::string>());
  }

  SECTION("POST /downloads rejects an invalid body with 422") {
    const auto response =
        client.Post("/downloads", nlohmann::json::object().dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("violations").size() == 3);
  }

  SECTION("POST /downloads rejects malformed JSON with 400") {
    const auto response = client.Post("/downloads", "not json", "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
  }

  SECTION("POST /downloads returns 422 unknown_job for a nonexistent job") {
    const auto response =
        client.Post("/downloads", start_body("00000000-0000-0000-0000-000000000000").dump(),
                    "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "unknown_job");
  }

  SECTION("POST /downloads returns 409 job_not_executable for a terminal job") {
    const std::string job_id = create_job(JobStatus::Completed);
    const auto response = client.Post("/downloads", start_body(job_id).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "job_not_executable");
  }

  SECTION("POST /downloads returns 422 unknown_connector for an unregistered connector") {
    const std::string job_id = create_job(JobStatus::Created);
    const auto response =
        client.Post("/downloads", start_body(job_id, "does-not-exist").dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "unknown_connector");
  }

  SECTION("GET /downloads/{id} returns a created download") {
    const std::string job_id = create_job(JobStatus::Created);
    const auto create_response = client.Post("/downloads", start_body(job_id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/downloads/" + created.at("id").get<std::string>());
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("GET /downloads/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/downloads/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /downloads/{id}/status reports status and progress") {
    const std::string job_id = create_job(JobStatus::Created);
    const auto create_response = client.Post("/downloads", start_body(job_id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/downloads/" + created.at("id").get<std::string>() + "/status");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("status") == "completed");
    CHECK(body.at("progress_percentage") == 100);
  }

  SECTION("GET /downloads lists created downloads and supports filtering by job_id") {
    const std::string first_job = create_job(JobStatus::Created);
    const std::string second_job = create_job(JobStatus::Created);
    client.Post("/downloads", start_body(first_job).dump(), "application/json");
    client.Post("/downloads", start_body(second_job).dump(), "application/json");

    const auto all = client.Get("/downloads");
    REQUIRE(all != nullptr);
    CHECK(nlohmann::json::parse(all->body).size() == 2);

    const auto filtered = client.Get("/downloads?job_id=" + first_job);
    REQUIRE(filtered != nullptr);
    CHECK(nlohmann::json::parse(filtered->body).size() == 1);
  }

  SECTION("POST /downloads/{id}/cancel returns 409 for an already-completed download") {
    const std::string job_id = create_job(JobStatus::Created);
    const auto create_response = client.Post("/downloads", start_body(job_id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Post("/downloads/" + created.at("id").get<std::string>() + "/cancel");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "invalid_transition");
  }

  SECTION("POST /downloads/{id}/cancel returns 404 for an unknown id") {
    const auto response = client.Post("/downloads/00000000-0000-0000-0000-000000000000/cancel");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  server.stop();
}
