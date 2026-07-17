#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <filesystem>
#include <thread>

#include "oep/acquisition/api/server.hpp"
#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/common/logger.hpp"
#include "oep/acquisition/database/database_connection.hpp"

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

  ApiServer server(config.server);
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
