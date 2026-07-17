#include "oep/acquisition/connectors/stub_connector.hpp"

#include <sstream>

#include "oep/acquisition/common/time.hpp"

namespace oep::acquisition::connectors {

namespace {

std::set<std::string> parse_capabilities(const ConnectorConfig& config) {
  std::set<std::string> result;
  const auto it = config.settings.find("capabilities");
  if (it == config.settings.end() || it->second.empty()) {
    return result;
  }
  std::istringstream stream(it->second);
  std::string capability;
  while (std::getline(stream, capability, ',')) {
    if (!capability.empty()) {
      result.insert(capability);
    }
  }
  return result;
}

HealthStatus parse_health_status(const ConnectorConfig& config) {
  const auto it = config.settings.find("health_status");
  if (it == config.settings.end()) {
    return HealthStatus::Healthy;
  }
  if (it->second == "unhealthy") {
    return HealthStatus::Unhealthy;
  }
  if (it->second == "unknown") {
    return HealthStatus::Unknown;
  }
  return HealthStatus::Healthy;
}

}  // namespace

StubConnector::StubConnector(ConnectorConfig config) : config_(std::move(config)) {}

void StubConnector::connect() {
  connected_ = true;
}

void StubConnector::disconnect() {
  connected_ = false;
}

bool StubConnector::is_connected() const {
  return connected_;
}

HealthCheckResult StubConnector::health_check() const {
  const HealthStatus status = parse_health_status(config_);
  std::string message;
  switch (status) {
    case HealthStatus::Healthy:
      message = "Stub connector reports healthy (no real check performed).";
      break;
    case HealthStatus::Unhealthy:
      message = "Stub connector configured to report unhealthy.";
      break;
    case HealthStatus::Unknown:
      message = "Stub connector configured to report unknown.";
      break;
  }
  return HealthCheckResult{status, message, common::current_timestamp_utc()};
}

std::set<std::string> StubConnector::capabilities() const {
  return parse_capabilities(config_);
}

bool StubConnector::validate_configuration() const {
  return !config_.connector_id.empty() && !config_.type.empty();
}

const ConnectorConfig& StubConnector::config() const {
  return config_;
}

}  // namespace oep::acquisition::connectors
