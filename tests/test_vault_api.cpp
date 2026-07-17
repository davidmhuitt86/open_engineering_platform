#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <string>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "oep/acquisition/integrity/postgres_verification_repository.hpp"
#include "oep/acquisition/metadata/postgres_metadata_repository.hpp"
#include "oep/acquisition/vault/postgres_vault_repository.hpp"
#include "oep/acquisition/vault/reference_vault_service.hpp"
#include "registry_test_support.hpp"
#include "vault_test_support.hpp"

using namespace oep::acquisition::vault;
using oep::acquisition::acquisition::PostgresAcquisitionJobRepository;
using oep::acquisition::api::ApiServer;
using oep::acquisition::downloads::PostgresDownloadRepository;
using oep::acquisition::integrity::PostgresVerificationRepository;
using oep::acquisition::metadata::PostgresMetadataRepository;
using oep::acquisition::test_support::reset_vault_schema;
using oep::acquisition::test_support::seed_extracted_metadata;
using oep::acquisition::test_support::test_database_config;

namespace {

nlohmann::json publish_body(const std::string& metadata_id) {
  return nlohmann::json{{"metadata_id", metadata_id}};
}

std::filesystem::path make_vault_root() {
  static std::atomic<int> counter{0};
  return std::filesystem::temp_directory_path() / ("oep_vault_api_test_" + std::to_string(++counter));
}

}  // namespace

TEST_CASE("Engineering Reference Vault REST API", "[api][vault][database]") {
  const auto schema_error = reset_vault_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = seed_extracted_metadata("some plain text content", "notes.txt");
  PostgresAcquisitionJobRepository job_repository(test_database_config());
  PostgresDownloadRepository download_repository(test_database_config());
  PostgresVerificationRepository verification_repository(test_database_config());
  PostgresMetadataRepository metadata_repository(test_database_config());
  PostgresVaultRepository vault_repository(test_database_config());

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = make_vault_root().string();

  ReferenceVaultService service(vault_repository, metadata_repository, verification_repository,
                                  download_repository, job_repository, storage);

  oep::acquisition::common::ServerConfig server_config;
  server_config.host = "127.0.0.1";
  server_config.port = 0;

  ApiServer server(server_config, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, &service);
  REQUIRE(server.start());
  httplib::Client client(server_config.host, server.bound_port());

  SECTION("GET /health still responds when only vault is registered") {
    const auto response = client.Get("/health");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("POST /vault publishes a real artifact end to end and returns 201") {
    const auto response = client.Post("/vault", publish_body(seeded.id).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 201);

    const auto body = nlohmann::json::parse(response->body);
    CHECK_FALSE(body.at("id").get<std::string>().empty());
    CHECK(body.at("status") == "published");
    CHECK(body.at("sha256_hash") == seeded.sha256_hash);
    CHECK(body.at("source_id") == seeded.source_id);
    CHECK(std::filesystem::exists(body.at("vault_path").get<std::string>()));
    CHECK(response->get_header_value("Location") == "/vault/" + body.at("id").get<std::string>());
  }

  SECTION("POST /vault rejects an invalid body with 422") {
    const auto response = client.Post("/vault", nlohmann::json::object().dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("violations").size() == 1);
  }

  SECTION("POST /vault rejects malformed JSON with 400") {
    const auto response = client.Post("/vault", "not json", "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 400);
  }

  SECTION("POST /vault returns 422 unknown_metadata for a nonexistent metadata_id") {
    const auto response =
        client.Post("/vault", publish_body("00000000-0000-0000-0000-000000000000").dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 422);
    CHECK(nlohmann::json::parse(response->body).at("error") == "unknown_metadata");
  }

  SECTION("POST /vault returns 409 already_published for a second publish attempt") {
    client.Post("/vault", publish_body(seeded.id).dump(), "application/json");
    const auto response = client.Post("/vault", publish_body(seeded.id).dump(), "application/json");
    REQUIRE(response != nullptr);
    CHECK(response->status == 409);
    CHECK(nlohmann::json::parse(response->body).at("error") == "already_published");
  }

  SECTION("GET /vault/{id} returns a created entry") {
    const auto create_response = client.Post("/vault", publish_body(seeded.id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/vault/" + created.at("id").get<std::string>());
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
  }

  SECTION("GET /vault/{id} returns 404 for an unknown id") {
    const auto response = client.Get("/vault/00000000-0000-0000-0000-000000000000");
    REQUIRE(response != nullptr);
    CHECK(response->status == 404);
  }

  SECTION("GET /vault/{id}/status reports status and hash") {
    const auto create_response = client.Post("/vault", publish_body(seeded.id).dump(), "application/json");
    const auto created = nlohmann::json::parse(create_response->body);

    const auto response = client.Get("/vault/" + created.at("id").get<std::string>() + "/status");
    REQUIRE(response != nullptr);
    CHECK(response->status == 200);
    const auto body = nlohmann::json::parse(response->body);
    CHECK(body.at("status") == "published");
    CHECK_FALSE(body.at("sha256_hash").get<std::string>().empty());
  }

  SECTION("GET /vault lists published entries and supports filtering by metadata_id") {
    const auto other_seeded = seed_extracted_metadata("a different artifact", "other.txt");
    client.Post("/vault", publish_body(seeded.id).dump(), "application/json");
    client.Post("/vault", publish_body(other_seeded.id).dump(), "application/json");

    const auto all = client.Get("/vault");
    REQUIRE(all != nullptr);
    CHECK(nlohmann::json::parse(all->body).size() == 2);

    const auto filtered = client.Get("/vault?metadata_id=" + seeded.id);
    REQUIRE(filtered != nullptr);
    CHECK(nlohmann::json::parse(filtered->body).size() == 1);
  }

  server.stop();
}
