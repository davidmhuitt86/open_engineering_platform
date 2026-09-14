#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <memory>
#include <string>
#include <thread>

#include "oep/server_repository/api/server.hpp"
#include "oep/server_repository/common/config.hpp"
#include "oep/server_repository/common/logger.hpp"
#include "oep/server_repository/persistence/store.hpp"

namespace {

std::atomic<bool> g_shutdown_requested{false};

void handle_shutdown_signal(int /*signal*/) {
  g_shutdown_requested = true;
}

oep::server_repository::common::Config load_configuration(int argc, char** argv) {
  using oep::server_repository::common::Config;

  const std::filesystem::path config_path =
      argc > 1 ? std::filesystem::path(argv[1]) : std::filesystem::path("config/config.toml");

  if (!std::filesystem::exists(config_path)) {
    std::fprintf(stderr, "[oep_server_repository] no config file at %s -- using defaults\n",
                 config_path.string().c_str());
    return Config{};
  }
  return Config::load_from_file(config_path);
}

}  // namespace

int main(int argc, char** argv) {
  using oep::server_repository::api::ApiServer;
  using oep::server_repository::common::Logger;
  using oep::server_repository::persistence::ServerRepositoryStore;

  // ADR-0006 SS12/SS16: the same OEP_API_TOKEN convention EAM already
  // established (WP-SRV-003) -- reused, not reinvented, per ADR-0002 SS3.
  const char* api_token_env = std::getenv("OEP_API_TOKEN");
  if (api_token_env == nullptr || *api_token_env == '\0') {
    std::fprintf(stderr,
                 "[oep_server_repository] OEP_API_TOKEN environment variable is not set (or is empty) -- "
                 "refusing to start without an explicit API authentication token.\n");
    return 1;
  }
  const std::string api_token(api_token_env);

  const auto config = load_configuration(argc, argv);
  Logger::initialize(config.logging);
  auto& log = Logger::get();

  log.info("OEP Server Repository starting up");
  log.info("API authentication token configured (length {})", api_token.size());

  std::unique_ptr<ServerRepositoryStore> store;
  try {
    store = std::make_unique<ServerRepositoryStore>(config.database);
  } catch (const std::exception&) {
    // Never log the raw driver exception (it can include the connection
    // string) -- a generic, actionable message is sufficient here.
    log.error("database connection failed at startup ({}:{}/{}) -- refusing to start", config.database.host,
               config.database.port, config.database.name);
    return 1;
  }
  log.info("database connection established ({}:{}/{})", config.database.host, config.database.port,
            config.database.name);

  ApiServer server(config.server, api_token, *store);
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
