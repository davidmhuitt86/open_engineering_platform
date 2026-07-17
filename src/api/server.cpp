#include "oep/acquisition/api/server.hpp"

#include <httplib.h>
#include <nlohmann/json.hpp>

namespace oep::acquisition::api {

namespace {

void register_routes(httplib::Server& server) {
  server.Get("/health", [](const httplib::Request&, httplib::Response& response) {
    const nlohmann::json body{{"status", "ok"}};
    response.set_content(body.dump(), "application/json");
  });
}

}  // namespace

ApiServer::ApiServer(const common::ServerConfig& config)
    : config_(config), server_(std::make_unique<httplib::Server>()) {
  register_routes(*server_);
}

ApiServer::~ApiServer() {
  stop();
}

bool ApiServer::start() {
  if (running_) {
    return true;
  }

  // `bind_to_port` returns bool, not the bound port -- port 0 (an
  // OS-assigned ephemeral port, used by tests) needs `bind_to_any_port`,
  // which is the one overload that actually returns the resulting port
  // number.
  if (config_.port == 0) {
    const int bound = server_->bind_to_any_port(config_.host);
    if (bound <= 0) {
      return false;
    }
    bound_port_ = static_cast<std::uint16_t>(bound);
  } else {
    if (!server_->bind_to_port(config_.host, config_.port)) {
      return false;
    }
    bound_port_ = config_.port;
  }

  running_ = true;
  thread_ = std::thread([this]() { server_->listen_after_bind(); });
  server_->wait_until_ready();
  return true;
}

void ApiServer::stop() {
  if (!running_) {
    return;
  }
  server_->stop();
  if (thread_.joinable()) {
    thread_.join();
  }
  running_ = false;
  bound_port_ = 0;
}

bool ApiServer::is_running() const {
  return running_;
}

std::uint16_t ApiServer::bound_port() const {
  return bound_port_;
}

}  // namespace oep::acquisition::api
