#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/acquisition_job.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/acquisition/postgres_job_execution_history_repository.hpp"
#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/connectors/connector_factory.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/connectors/stub_connector.hpp"
#include "oep/acquisition/downloads/download_service.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "oep/acquisition/integrity/integrity_verification_service.hpp"
#include "oep/acquisition/integrity/postgres_verification_repository.hpp"
#include "oep/acquisition/metadata/metadata_extraction_service.hpp"
#include "oep/acquisition/metadata/postgres_metadata_repository.hpp"
#include "oep/acquisition/provenance/acquisition_record_service.hpp"
#include "oep/acquisition/provenance/postgres_acquisition_record_repository.hpp"
#include "oep/acquisition/registry/postgres_official_source_repository.hpp"
#include "oep/acquisition/vault/postgres_vault_repository.hpp"
#include "oep/acquisition/vault/reference_vault_service.hpp"
#include "provenance_test_support.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::provenance;
using oep::acquisition::acquisition::AcquisitionJob;
using oep::acquisition::acquisition::JobPriority;
using oep::acquisition::acquisition::JobStatus;
using oep::acquisition::acquisition::PostgresAcquisitionJobRepository;
using oep::acquisition::acquisition::PostgresJobExecutionHistoryRepository;
using oep::acquisition::api::ApiServer;
using oep::acquisition::connectors::ConnectorConfig;
using oep::acquisition::connectors::ConnectorFactory;
using oep::acquisition::connectors::ConnectorRegistry;
using oep::acquisition::connectors::StubConnector;
using oep::acquisition::downloads::DownloadService;
using oep::acquisition::downloads::PostgresDownloadRepository;
using oep::acquisition::integrity::IntegrityVerificationService;
using oep::acquisition::integrity::PostgresVerificationRepository;
using oep::acquisition::metadata::MetadataExtractionService;
using oep::acquisition::metadata::PostgresMetadataRepository;
using oep::acquisition::registry::PostgresOfficialSourceRepository;
using oep::acquisition::test_support::kTestApiToken;
using oep::acquisition::test_support::reset_provenance_schema;
using oep::acquisition::test_support::seed_official_source;
using oep::acquisition::test_support::test_database_config;
using oep::acquisition::vault::PostgresVaultRepository;
using oep::acquisition::vault::ReferenceVaultService;

namespace {

std::filesystem::path make_dir(const char* prefix) {
  static std::atomic<int> counter{0};
  const auto nonce = std::chrono::steady_clock::now().time_since_epoch().count();
  auto path = std::filesystem::temp_directory_path() /
              (std::string(prefix) + std::to_string(nonce) + "_" + std::to_string(++counter));
  std::filesystem::create_directories(path);
  return path;
}

}  // namespace

TEST_CASE("Acquisition Record & Provenance Foundation REST API and full-pipeline integration",
          "[api][provenance][database]") {
  const auto schema_error = reset_provenance_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string source_id = seed_official_source();
  PostgresOfficialSourceRepository source_repository(test_database_config());
  PostgresAcquisitionJobRepository job_repository(test_database_config());
  PostgresJobExecutionHistoryRepository job_history_repository(test_database_config());
  PostgresDownloadRepository download_repository(test_database_config());
  PostgresVerificationRepository verification_repository(test_database_config());
  PostgresMetadataRepository metadata_repository(test_database_config());
  PostgresVaultRepository vault_repository(test_database_config());
  PostgresAcquisitionRecordRepository record_repository(test_database_config());

  ConnectorFactory factory;
  factory.register_type("stub",
                         [](const ConnectorConfig& config) { return std::make_unique<StubConnector>(config); });
  ConnectorRegistry connector_registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  connector_config.name = "Test Connector";
  connector_registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_dir("oep_acquisition_record_api_workspace_").string();
  storage.root_path = make_dir("oep_acquisition_record_api_vault_").string();

  DownloadService download_service(download_repository, job_repository, connector_registry, storage);
  IntegrityVerificationService verification_service(verification_repository, download_repository);
  MetadataExtractionService metadata_service(metadata_repository, verification_repository, download_repository);
  ReferenceVaultService vault_service(vault_repository, metadata_repository, verification_repository,
                                       download_repository, job_repository, storage);
  AcquisitionRecordService record_service(record_repository, download_repository, job_repository,
                                           job_history_repository, verification_repository, metadata_repository,
                                           vault_repository, source_repository);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, kTestApiToken, nullptr, nullptr, nullptr, &connector_registry,
                   &download_service, &verification_service, &metadata_service, &vault_service, &record_service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());
  client.set_bearer_token_auth(kTestApiToken);

  const auto create_job = [&] {
    AcquisitionJob job;
    job.source_id = source_id;
    job.name = "Acquire 802.11";
    job.priority = JobPriority::Normal;
    job.status = JobStatus::Created;
    return job_repository.create(job).id;
  };

  SECTION("A full Download -> Verify -> Metadata -> Vault pipeline run produces one Published Acquisition Record"
          " reachable end to end via /acquisition-records") {
    const std::string job_id = create_job();

    const auto download_response = client.Post(
        "/downloads",
        nlohmann::json{{"job_id", job_id}, {"connector_id", "conn-1"}, {"source_uri", "stub://example/artifact.pdf"}}
            .dump(),
        "application/json");
    REQUIRE(download_response != nullptr);
    REQUIRE(download_response->status == 201);
    const auto download_body = nlohmann::json::parse(download_response->body);
    const std::string download_id = download_body.at("id").get<std::string>();

    // Immediately after /downloads returns, an Acquisition Record must
    // already exist for it -- created synchronously as a best-effort
    // side effect of the route handler, not requiring any separate call.
    const auto record_lookup = client.Get("/acquisition-records?status=acquired");
    REQUIRE(record_lookup != nullptr);
    REQUIRE(record_lookup->status == 200);
    const auto acquired_records = nlohmann::json::parse(record_lookup->body);
    REQUIRE(acquired_records.size() == 1);
    const std::string record_id = acquired_records.at(0).at("id").get<std::string>();
    CHECK(acquired_records.at(0).at("download_session_id") == download_id);

    const auto verify_response =
        client.Post("/verifications", nlohmann::json{{"download_session_id", download_id}}.dump(),
                    "application/json");
    REQUIRE(verify_response != nullptr);
    REQUIRE(verify_response->status == 201);
    const auto verification_body = nlohmann::json::parse(verify_response->body);
    const std::string verification_id = verification_body.at("id").get<std::string>();
    REQUIRE(verification_body.at("status") == "verified");

    const auto record_after_verify = client.Get("/acquisition-records/" + record_id);
    REQUIRE(record_after_verify != nullptr);
    CHECK(nlohmann::json::parse(record_after_verify->body).at("status") == "verified");

    const auto metadata_response =
        client.Post("/metadata", nlohmann::json{{"verification_id", verification_id}}.dump(),
                    "application/json");
    REQUIRE(metadata_response != nullptr);
    REQUIRE(metadata_response->status == 201);
    const auto metadata_body = nlohmann::json::parse(metadata_response->body);
    const std::string metadata_id = metadata_body.at("id").get<std::string>();
    REQUIRE(metadata_body.at("status") == "extracted");

    // A successful extraction leaves the record Verified -- SDD-R015's
    // lifecycle has no distinct metadata-extracted stage.
    const auto record_after_metadata = client.Get("/acquisition-records/" + record_id);
    REQUIRE(record_after_metadata != nullptr);
    CHECK(nlohmann::json::parse(record_after_metadata->body).at("status") == "verified");

    const auto vault_response =
        client.Post("/vault", nlohmann::json{{"metadata_id", metadata_id}}.dump(), "application/json");
    REQUIRE(vault_response != nullptr);
    REQUIRE(vault_response->status == 201);
    const auto vault_body = nlohmann::json::parse(vault_response->body);
    const std::string vault_entry_id = vault_body.at("id").get<std::string>();

    const auto record_after_publish = client.Get("/acquisition-records/" + record_id);
    REQUIRE(record_after_publish != nullptr);
    CHECK(nlohmann::json::parse(record_after_publish->body).at("status") == "published");

    const auto provenance_response = client.Get("/acquisition-records/" + record_id + "/provenance");
    REQUIRE(provenance_response != nullptr);
    REQUIRE(provenance_response->status == 200);
    const auto provenance = nlohmann::json::parse(provenance_response->body);
    CHECK(provenance.at("acquisition_record").at("id") == record_id);
    CHECK(provenance.at("download").at("id") == download_id);
    CHECK(provenance.at("job").at("id") == job_id);
    CHECK(provenance.at("source").at("id") == source_id);
    CHECK(provenance.at("verifications").at(0).at("id") == verification_id);
    CHECK(provenance.at("metadata").at(0).at("id") == metadata_id);
    CHECK(provenance.at("vault_entry").at("id") == vault_entry_id);
  }

  SECTION("A failed verification leaves the Acquisition Record Failed, never Published") {
    const std::string job_id = create_job();

    const auto download_response = client.Post(
        "/downloads",
        nlohmann::json{{"job_id", job_id}, {"connector_id", "conn-1"}, {"source_uri", "stub://example/artifact.pdf"}}
            .dump(),
        "application/json");
    const auto download_id = nlohmann::json::parse(download_response->body).at("id").get<std::string>();

    // Remove the artifact from disk so verification legitimately fails
    // ("Missing files shall fail verification") -- Verification has no
    // prior hash to compare against on this, its first run, so corrupting
    // the file's content would not itself cause a failure.
    const auto downloaded = download_repository.find_by_id(download_id);
    REQUIRE(downloaded.has_value());
    std::filesystem::remove(downloaded->local_storage_path);

    const auto verify_response =
        client.Post("/verifications", nlohmann::json{{"download_session_id", download_id}}.dump(),
                    "application/json");
    REQUIRE(verify_response != nullptr);
    REQUIRE(verify_response->status == 201);
    REQUIRE(nlohmann::json::parse(verify_response->body).at("status") == "failed");

    const auto record_lookup = client.Get("/acquisition-records?status=failed");
    REQUIRE(record_lookup != nullptr);
    const auto failed_records = nlohmann::json::parse(record_lookup->body);
    REQUIRE(failed_records.size() == 1);
    CHECK(failed_records.at(0).at("download_session_id") == download_id);
    CHECK_FALSE(failed_records.at(0).at("error_message").is_null());
  }

  SECTION("GET /acquisition-records/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/acquisition-records/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /acquisition-records/{id}/provenance returns 404 for an unknown id") {
    const auto response =
        client.Get("/acquisition-records/00000000-0000-0000-0000-000000000000/provenance");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  server.stop();
}
