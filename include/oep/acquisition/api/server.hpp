#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <thread>

#include "oep/acquisition/common/config.hpp"

namespace httplib {
class Server;
}

namespace oep::acquisition::registry {
class OfficialSourceService;
}

namespace oep::acquisition::api {

/// The Engineering Acquisition Manager's HTTP API.
///
/// Embeds `cpp-httplib` directly in-process rather than fronting the
/// service with a separate Node/Fastify gateway -- see README.md
/// "Implementation Decisions" and ADR-0007 (Platform API Strategy) for why.
///
/// `GET /health` (WORK_PACKAGE_001) is always registered. The `/sources`
/// routes (WORK-PACKAGE-002) are registered only when `source_service` is
/// non-null -- `main.cpp` passes `nullptr` if the PostgreSQL repository
/// could not be constructed at startup, so a database outage degrades
/// the process to "health checks only" rather than preventing it from
/// starting at all (continuing WORK_PACKAGE_001's non-fatal-database
/// precedent).
class ApiServer {
 public:
  explicit ApiServer(const common::ServerConfig& config,
                      registry::OfficialSourceService* source_service = nullptr);
  ~ApiServer();

  ApiServer(const ApiServer&) = delete;
  ApiServer& operator=(const ApiServer&) = delete;

  /// Binds the configured host/port and starts accepting connections on a
  /// background thread. Returns false if the bind failed (e.g. the port
  /// is already in use). Passing `config.port == 0` binds an OS-assigned
  /// ephemeral port -- `bound_port()` reports which one, which is how
  /// tests avoid colliding with a fixed port number.
  bool start();

  /// Stops accepting connections and joins the background thread. Safe
  /// to call even if `start()` was never called or already failed.
  void stop();

  [[nodiscard]] bool is_running() const;

  /// The actual bound port once `start()` has succeeded (0 beforehand).
  [[nodiscard]] std::uint16_t bound_port() const;

 private:
  common::ServerConfig config_;
  registry::OfficialSourceService* source_service_;
  std::unique_ptr<httplib::Server> server_;
  std::thread thread_;
  std::atomic<bool> running_{false};
  std::uint16_t bound_port_ = 0;
};

}  // namespace oep::acquisition::api
