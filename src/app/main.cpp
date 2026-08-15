#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <filesystem>
#include <memory>
#include <thread>

#include "oep/acquisition/acquisition/acquisition_execution_service.hpp"
#include "oep/acquisition/acquisition/acquisition_job_service.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/acquisition/postgres_job_execution_history_repository.hpp"
#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/common/logger.hpp"
#include "oep/acquisition/connectors/connector_factory.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/connectors/http_connector.hpp"
#include "oep/acquisition/connectors/stub_connector.hpp"
#include "oep/acquisition/database/database_connection.hpp"
#include "oep/acquisition/downloads/download_service.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "oep/acquisition/integrity/integrity_verification_service.hpp"
#include "oep/acquisition/integrity/postgres_verification_repository.hpp"
#include "oep/acquisition/metadata/metadata_extraction_service.hpp"
#include "oep/acquisition/metadata/postgres_metadata_repository.hpp"
#include "oep/acquisition/registry/official_source_service.hpp"
#include "oep/acquisition/registry/postgres_official_source_repository.hpp"
#include "oep/acquisition/vault/postgres_vault_repository.hpp"
#include "oep/acquisition/vault/reference_vault_service.hpp"

namespace {

std::atomic<bool> g_shutdown_requested{false};

void handle_shutdown_signal(int /*signal*/) {
  g_shutdown_requested = true;
}

oep::acquisition::common::Config load_configuration(int argc, char** argv) {
  using oep::acquisition::common::Config;

  const std::filesystem::path config_path =
      argc > 1 ? std::filesystem::path(argv[1]) : std::filesystem::path("config/config.toml");

  if (!std::filesystem::exists(config_path)) {
    // A missing config file is not fatal for this bootstrap -- every
    // Config field has a documented default (config.hpp). Logging isn't
    // initialized yet at this point, so this goes straight to stderr.
    std::fprintf(stderr, "[oep_acquisition] no config file at %s -- using defaults\n",
                 config_path.string().c_str());
    return Config{};
  }
  return Config::load_from_file(config_path);
}

}  // namespace

int main(int argc, char** argv) {
  using oep::acquisition::api::ApiServer;
  using oep::acquisition::common::Logger;
  using oep::acquisition::database::DatabaseConnection;

  const auto config = load_configuration(argc, argv);
  Logger::initialize(config.logging);
  auto& log = Logger::get();

  log.info("OEP Acquisition Manager starting up");

  // Connection only, per WORK_PACKAGE_001 -- a failed connection is
  // logged, never fatal, since no schema or repositories exist yet for
  // anything to actually depend on the database being reachable.
  const DatabaseConnection database(config.database);
  if (database.is_connected()) {
    log.info("database connection established ({}:{}/{})", config.database.host, config.database.port,
              config.database.name);
  } else {
    log.warn("database connection unavailable: {}", database.last_error());
  }

  // The Official Source Registry (WORK-PACKAGE-002) needs a working
  // PostgreSQL connection to do anything useful, unlike the connection-only
  // check above. Continuing WORK_PACKAGE_001's non-fatal-database
  // precedent: if it can't be constructed, the process still starts with
  // `/health` only -- `/sources` becomes available again on the next
  // restart once the database is reachable.
  std::unique_ptr<oep::acquisition::registry::PostgresOfficialSourceRepository> source_repository;
  std::unique_ptr<oep::acquisition::registry::OfficialSourceService> source_service;
  try {
    source_repository =
        std::make_unique<oep::acquisition::registry::PostgresOfficialSourceRepository>(config.database);
    source_service = std::make_unique<oep::acquisition::registry::OfficialSourceService>(*source_repository);
    log.info("official source registry repository connected");
  } catch (const std::exception& ex) {
    log.warn("official source registry repository unavailable: {} -- /sources routes disabled this run",
              ex.what());
  }

  // The Acquisition Job Engine (WORK_PACKAGE-003) follows the same
  // non-fatal-database precedent as the Official Source Registry above.
  std::unique_ptr<oep::acquisition::acquisition::PostgresAcquisitionJobRepository> job_repository;
  std::unique_ptr<oep::acquisition::acquisition::AcquisitionJobService> job_service;
  try {
    job_repository =
        std::make_unique<oep::acquisition::acquisition::PostgresAcquisitionJobRepository>(config.database);
    job_service = std::make_unique<oep::acquisition::acquisition::AcquisitionJobService>(*job_repository);
    log.info("acquisition job engine repository connected");
  } catch (const std::exception& ex) {
    log.warn("acquisition job engine repository unavailable: {} -- /jobs routes disabled this run", ex.what());
  }

  // The Execution Engine (WORK_PACKAGE_004) needs both the Job repository
  // and the Source repository (to check for an archived/unavailable
  // source on execute) plus its own execution-history repository, so it
  // is only constructed when both of the above already connected
  // successfully -- same non-fatal-database precedent as above.
  std::unique_ptr<oep::acquisition::acquisition::PostgresJobExecutionHistoryRepository> execution_history_repository;
  std::unique_ptr<oep::acquisition::acquisition::AcquisitionExecutionService> execution_service;
  if (source_repository && job_repository) {
    try {
      execution_history_repository =
          std::make_unique<oep::acquisition::acquisition::PostgresJobExecutionHistoryRepository>(
              config.database);
      execution_service = std::make_unique<oep::acquisition::acquisition::AcquisitionExecutionService>(
          *job_repository, *source_repository, *execution_history_repository);
      log.info("acquisition execution engine repository connected");
    } catch (const std::exception& ex) {
      log.warn(
          "acquisition execution engine repository unavailable: {} -- /jobs/{{id}}/execute, /cancel, "
          "/status routes disabled this run",
          ex.what());
    }
  } else {
    log.warn("acquisition execution engine disabled this run: source and/or job repository unavailable");
  }

  // The Source Connector Framework (WORK_PACKAGE-005) has no PostgreSQL
  // dependency -- connectors are registered in-memory at startup, not
  // through the (read-only) REST API -- so it does not follow the
  // non-fatal-database pattern above and is always available.
  oep::acquisition::connectors::ConnectorFactory connector_factory;
  connector_factory.register_type(
      "stub", [](const oep::acquisition::connectors::ConnectorConfig& connector_config) {
        return std::make_unique<oep::acquisition::connectors::StubConnector>(connector_config);
      });
  connector_factory.register_type(
      "http", [](const oep::acquisition::connectors::ConnectorConfig& connector_config) {
        return std::make_unique<oep::acquisition::connectors::HttpConnector>(connector_config);
      });
  oep::acquisition::connectors::ConnectorRegistry connector_registry(connector_factory);
  connector_registry.register_connector(oep::acquisition::connectors::ConnectorConfig{
      .connector_id = "example-stub",
      .type = "stub",
      .name = "Example Stub Connector",
      .description = "Demonstrates the Connector Framework; performs no real network communication.",
      .settings = {{"capabilities", "download_files,search"}},
  });
  // A real connector: genuine HTTP(S) GET requests via cpp-httplib's
  // client mode (`HttpConnector`) -- distinct from `example-stub` above,
  // which performs no network I/O at all.
  connector_registry.register_connector(oep::acquisition::connectors::ConnectorConfig{
      .connector_id = "http-source",
      .type = "http",
      .name = "HTTP Source Connector",
      .description = "Retrieves engineering artifacts over real HTTP/HTTPS.",
      .settings = {{"capabilities", "download_files"}},
  });
  log.info("connector framework initialized ({} connector(s) registered)", connector_registry.list().size());

  // The Engineering Downloader (WORK_PACKAGE_006) needs the Job
  // repository (to validate "Job shall exist"/"Job shall be executable")
  // plus its own download-session repository, so it is only constructed
  // when the Job Engine already connected successfully -- same
  // non-fatal-database precedent as the Execution Engine above. It uses
  // the live `connector_registry` directly (no database dependency there).
  std::unique_ptr<oep::acquisition::downloads::PostgresDownloadRepository> download_repository;
  std::unique_ptr<oep::acquisition::downloads::DownloadService> download_service;
  if (job_repository) {
    try {
      download_repository =
          std::make_unique<oep::acquisition::downloads::PostgresDownloadRepository>(config.database);
      download_service = std::make_unique<oep::acquisition::downloads::DownloadService>(
          *download_repository, *job_repository, connector_registry, config.storage);
      log.info("engineering downloader repository connected");
    } catch (const std::exception& ex) {
      log.warn("engineering downloader repository unavailable: {} -- /downloads routes disabled this run",
                ex.what());
    }
  } else {
    log.warn("engineering downloader disabled this run: job repository unavailable");
  }

  // The Integrity Verification Engine (WORK_PACKAGE_007) needs the
  // Download repository (to resolve "Download session shall exist" and
  // locate the artifact to hash) plus its own verification-history
  // repository, so it is only constructed when the Engineering Downloader
  // already connected successfully -- same non-fatal-database precedent as
  // the Execution Engine and Engineering Downloader above.
  std::unique_ptr<oep::acquisition::integrity::PostgresVerificationRepository> verification_repository;
  std::unique_ptr<oep::acquisition::integrity::IntegrityVerificationService> verification_service;
  if (download_repository) {
    try {
      verification_repository =
          std::make_unique<oep::acquisition::integrity::PostgresVerificationRepository>(config.database);
      verification_service = std::make_unique<oep::acquisition::integrity::IntegrityVerificationService>(
          *verification_repository, *download_repository);
      log.info("integrity verification engine repository connected");
    } catch (const std::exception& ex) {
      log.warn(
          "integrity verification engine repository unavailable: {} -- /verifications routes disabled "
          "this run",
          ex.what());
    }
  } else {
    log.warn("integrity verification engine disabled this run: download repository unavailable");
  }

  // The Metadata Extraction Engine (WORK_PACKAGE_008) needs both the
  // Verification repository (to resolve "Verification shall exist"/"shall
  // be successful") and the Download repository (to locate the artifact
  // to inspect) plus its own metadata-history repository, so it is only
  // constructed when the Integrity Verification Engine already connected
  // successfully -- same non-fatal-database precedent as every engine
  // above.
  std::unique_ptr<oep::acquisition::metadata::PostgresMetadataRepository> metadata_repository;
  std::unique_ptr<oep::acquisition::metadata::MetadataExtractionService> metadata_service;
  if (verification_repository && download_repository) {
    try {
      metadata_repository =
          std::make_unique<oep::acquisition::metadata::PostgresMetadataRepository>(config.database);
      metadata_service = std::make_unique<oep::acquisition::metadata::MetadataExtractionService>(
          *metadata_repository, *verification_repository, *download_repository);
      log.info("metadata extraction engine repository connected");
    } catch (const std::exception& ex) {
      log.warn(
          "metadata extraction engine repository unavailable: {} -- /metadata routes disabled this run",
          ex.what());
    }
  } else {
    log.warn("metadata extraction engine disabled this run: verification and/or download repository unavailable");
  }

  // The Engineering Reference Vault (WORK_PACKAGE_009) needs the Metadata,
  // Verification, and Download repositories (to resolve and re-validate
  // the full Metadata -> Verification -> Download chain) plus the Job
  // repository (to resolve the Download's Original Source ID) and its own
  // vault repository, so it is only constructed when the Metadata
  // Extraction Engine and Job Engine already connected successfully --
  // same non-fatal-database precedent as every engine above. It uses
  // `config.storage` (`root_path`) for the permanent vault location,
  // distinct from `workspace_path` used by the Downloader.
  std::unique_ptr<oep::acquisition::vault::PostgresVaultRepository> vault_repository;
  std::unique_ptr<oep::acquisition::vault::ReferenceVaultService> vault_service;
  if (metadata_repository && verification_repository && download_repository && job_repository) {
    try {
      vault_repository = std::make_unique<oep::acquisition::vault::PostgresVaultRepository>(config.database);
      vault_service = std::make_unique<oep::acquisition::vault::ReferenceVaultService>(
          *vault_repository, *metadata_repository, *verification_repository, *download_repository,
          *job_repository, config.storage);
      log.info("engineering reference vault repository connected");
    } catch (const std::exception& ex) {
      log.warn("engineering reference vault repository unavailable: {} -- /vault routes disabled this run",
                ex.what());
    }
  } else {
    log.warn(
        "engineering reference vault disabled this run: metadata, verification, download, and/or job "
        "repository unavailable");
  }

  ApiServer server(config.server, source_service.get(), job_service.get(), execution_service.get(),
                    &connector_registry, download_service.get(), verification_service.get(),
                    metadata_service.get(), vault_service.get());
  if (!server.start()) {
    log.error("failed to start API server on {}:{}", config.server.host, config.server.port);
    return 1;
  }
  log.info("API server listening on {}:{}", config.server.host, server.bound_port());

  std::signal(SIGINT, handle_shutdown_signal);
  std::signal(SIGTERM, handle_shutdown_signal);

  while (!g_shutdown_requested && server.is_running()) {
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
  }

  log.info("shutting down");
  server.stop();
  return 0;
}
