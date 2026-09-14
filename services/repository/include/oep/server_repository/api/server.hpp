#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <string>
#include <thread>

#include "oep/server_repository/common/config.hpp"

namespace httplib {
class Server;
}

namespace oep::server_repository::persistence {
class ServerRepositoryStore;
}

namespace oep::server_repository::api {

/// The Server Repository's HTTP API (WP-SRV-011 / ADR-0006 SS7).
///
/// Exactly the 8 routes ADR-0006 SS7/SS29 authorize -- no undocumented
/// mutation route exists; every object/relationship mutation goes
/// through `POST /repositories/{repository_id}/commits`. Every route
/// except this instance's own equivalent of `GET /health` requires the
/// same bearer-token pre-routing check EAM already uses (ADR-0002 SS3,
/// ADR-0006 SS12), installed once, the same way `ApiServer`
/// (services/acquisition) already does -- see this class's own `.cpp`.
class ApiServer {
 public:
  ApiServer(const common::ServerConfig& config, std::string api_token, persistence::ServerRepositoryStore& store);
  ~ApiServer();

  ApiServer(const ApiServer&) = delete;
  ApiServer& operator=(const ApiServer&) = delete;

  bool start();
  void stop();
  [[nodiscard]] bool is_running() const;
  [[nodiscard]] std::uint16_t bound_port() const;

 private:
  common::ServerConfig config_;
  std::string api_token_;
  persistence::ServerRepositoryStore& store_;
  std::unique_ptr<httplib::Server> server_;
  std::thread thread_;
  std::atomic<bool> running_{false};
  std::uint16_t bound_port_ = 0;
};

}  // namespace oep::server_repository::api
