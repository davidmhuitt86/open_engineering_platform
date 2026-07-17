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
#include "oep/acquisition/connectors/stub_connector.hpp"
#include "oep/acquisition/database/database_connection.hpp"
#include "oep/acquisition/registry/official_source_service.hpp"
#include "oep/acquisition/registry/postgres_official_source_repository.hpp"

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
  oep::acquisition::connectors::ConnectorRegistry connector_registry(connector_factory);
  connector_registry.register_connector(oep::acquisition::connectors::ConnectorConfig{
      .connector_id = "example-stub",
      .type = "stub",
      .name = "Example Stub Connector",
      .description = "Demonstrates the Connector Framework; performs no real network communication.",
      .settings = {{"capabilities", "download_files,search"}},
  });
  log.info("connector framework initialized ({} connector(s) registered)", connector_registry.list().size());

  ApiServer server(config.server, source_service.get(), job_service.get(), execution_service.get(),
                    &connector_registry);
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
