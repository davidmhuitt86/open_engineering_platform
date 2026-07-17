#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <thread>

#include "oep/acquisition/common/config.hpp"

namespace httplib {
class Server;
}

namespace oep::acquisition::api {

/// The Engineering Acquisition Manager's minimal HTTP API (WORK_PACKAGE_001).
///
/// Embeds `cpp-httplib` directly in-process rather than fronting the
/// service with a separate Node/Fastify gateway -- see README.md
/// "Implementation Decisions" for why. Exposes exactly one endpoint,
/// `GET /health`, per this work package's explicit scope; no additional
/// routes are registered here.
class ApiServer {
 public:
  explicit ApiServer(const common::ServerConfig& config);
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
  std::unique_ptr<httplib::Server> server_;
  std::thread thread_;
  std::atomic<bool> running_{false};
  std::uint16_t bound_port_ = 0;
};

}  // namespace oep::acquisition::api
