#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>

#include "fake_acquisition_job_repository.hpp"
#include "fake_download_repository.hpp"
#include "oep/acquisition/connectors/connector_factory.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/connectors/stub_connector.hpp"
#include "oep/acquisition/downloads/download_errors.hpp"
#include "oep/acquisition/downloads/download_service.hpp"
#include "oep/acquisition/downloads/validation.hpp"

using namespace oep::acquisition::downloads;
using oep::acquisition::acquisition::AcquisitionJob;
using oep::acquisition::acquisition::JobPriority;
using oep::acquisition::acquisition::JobStatus;
using oep::acquisition::connectors::ConnectorConfig;
using oep::acquisition::connectors::ConnectorFactory;
using oep::acquisition::connectors::ConnectorRegistry;
using oep::acquisition::connectors::StubConnector;
using oep::acquisition::test_support::FakeAcquisitionJobRepository;
using oep::acquisition::test_support::FakeDownloadRepository;

namespace {

ConnectorFactory make_factory() {
  ConnectorFactory factory;
  factory.register_type("stub",
                          [](const ConnectorConfig& config) { return std::make_unique<StubConnector>(config); });
  return factory;
}

AcquisitionJob make_job(JobStatus status = JobStatus::Created) {
  AcquisitionJob job;
  job.source_id = "source-1";
  job.name = "Acquire 802.11";
  job.priority = JobPriority::Normal;
  job.status = status;
  return job;
}

std::filesystem::path make_workspace() {
  static std::atomic<int> counter{0};
  auto path = std::filesystem::temp_directory_path() /
              ("oep_download_service_test_" + std::to_string(counter++));
  std::filesystem::create_directories(path);
  return path;
}

nlohmann::json start_body(const std::string& job_id, const std::string& connector_id = "conn-1") {
  return nlohmann::json{
      {"job_id", job_id},
      {"connector_id", connector_id},
      {"source_uri", "stub://example/artifact.pdf"},
  };
}

}  // namespace

TEST_CASE("DownloadService.start_download completes successfully end to end", "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  connector_config.name = "Test Connector";
  registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();

  DownloadService service(downloads, jobs, registry, storage);

  const auto job = jobs.create(make_job());
  const auto result = service.start_download(start_body(job.id));

  CHECK(result.status == DownloadStatus::Completed);
  CHECK(result.progress_percentage == 100);
  CHECK_FALSE(result.local_storage_path.empty());
  CHECK(std::filesystem::exists(result.local_storage_path));
  CHECK_FALSE(result.mime_type.empty());
  CHECK(result.started_at.has_value());
  CHECK(result.completed_at.has_value());
}

TEST_CASE("DownloadService.start_download throws ValidationError for a malformed body",
          "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  CHECK_THROWS_AS(service.start_download(nlohmann::json::object()), ValidationError);
}

TEST_CASE("DownloadService.start_download throws UnknownJobError for a nonexistent job",
          "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  CHECK_THROWS_AS(service.start_download(start_body("does-not-exist")), UnknownJobError);
}

TEST_CASE("DownloadService.start_download throws JobNotExecutableError for a terminal job",
          "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  const auto job = jobs.create(make_job(JobStatus::Completed));

  CHECK_THROWS_AS(service.start_download(start_body(job.id)), JobNotExecutableError);
}

TEST_CASE("DownloadService.start_download throws UnknownConnectorError for an unregistered connector",
          "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  const auto job = jobs.create(make_job());

  CHECK_THROWS_AS(service.start_download(start_body(job.id, "does-not-exist")), UnknownConnectorError);
}

TEST_CASE("DownloadService.start_download throws ConnectorUnhealthyError for an unhealthy connector",
          "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  connector_config.settings["health_status"] = "unhealthy";
  registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  const auto job = jobs.create(make_job());

  CHECK_THROWS_AS(service.start_download(start_body(job.id)), ConnectorUnhealthyError);
}

TEST_CASE("DownloadService.start_download records a Failed download when the connector reports failure",
          "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  connector_config.settings["fetch_outcome"] = "failure";
  registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  const auto job = jobs.create(make_job());
  const auto result = service.start_download(start_body(job.id));

  CHECK(result.status == DownloadStatus::Failed);
  CHECK(result.error_message.has_value());
  CHECK(result.completed_at.has_value());
}

TEST_CASE("DownloadService.get/list/cancel", "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);
  ConnectorConfig connector_config;
  connector_config.connector_id = "conn-1";
  connector_config.type = "stub";
  registry.register_connector(connector_config);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  const auto job = jobs.create(make_job());
  const auto created = service.start_download(start_body(job.id));

  SECTION("get returns the download") {
    const auto found = service.get(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
  }

  SECTION("get returns nullopt for an unknown id") {
    CHECK_FALSE(service.get("does-not-exist").has_value());
  }

  SECTION("list returns the download") {
    CHECK(service.list(DownloadFilter{}).size() == 1);
  }

  SECTION("cancel rejects an already-completed download") {
    CHECK_THROWS_AS(service.cancel(created.id), InvalidTransitionError);
  }

  SECTION("cancel returns nullopt for an unknown id") {
    CHECK_FALSE(service.cancel("does-not-exist").has_value());
  }
}

TEST_CASE("DownloadService.cancel transitions a Pending download to Cancelled",
          "[downloads][service]") {
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  const auto factory = make_factory();
  ConnectorRegistry registry(factory);

  oep::acquisition::common::StorageConfig storage;
  storage.workspace_path = make_workspace().string();
  DownloadService service(downloads, jobs, registry, storage);

  // Seed a Pending download directly via the repository -- with a
  // synchronous DownloadService, a download reaches a terminal state
  // before start_download even returns, so this is the deterministic way
  // to exercise cancelling an in-flight download (see README.md
  // "Implementation Decisions").
  Download pending;
  pending.job_id = "job-1";
  pending.connector_id = "conn-1";
  pending.source_uri = "stub://example/artifact.pdf";
  pending.status = DownloadStatus::Pending;
  const auto created = downloads.create(pending);

  const auto cancelled = service.cancel(created.id);
  REQUIRE(cancelled.has_value());
  CHECK(cancelled->status == DownloadStatus::Cancelled);
  CHECK(cancelled->completed_at.has_value());
}
