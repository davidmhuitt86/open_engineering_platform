#include "oep/acquisition/connectors/stub_connector.hpp"

#include <filesystem>
#include <fstream>
#include <functional>
#include <sstream>
#include <string_view>

#include "oep/acquisition/common/time.hpp"

namespace oep::acquisition::connectors {

namespace {

constexpr std::string_view kPlaceholderContent = "stub-connector-fetch-placeholder\n";

// A transfer-level checksum of what this stub actually wrote -- not a
// cryptographic hash (SHA-256/BLAKE3 are a future Integrity Verification
// concern, out of scope for ADR-0008), just enough to prove
// AcquisitionResult::checksum is populated deterministically.
std::string fake_checksum(std::string_view content) {
  std::ostringstream stream;
  stream << std::hex << std::hash<std::string_view>{}(content);
  return stream.str();
}

bool fetch_configured_to_fail(const ConnectorConfig& config) {
  const auto it = config.settings.find("fetch_outcome");
  return it != config.settings.end() && it->second == "failure";
}

std::string fetch_mime_type(const ConnectorConfig& config) {
  const auto it = config.settings.find("fetch_mime_type");
  return it != config.settings.end() ? it->second : "text/plain";
}

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

AcquisitionResult StubConnector::fetch(const AcquisitionRequest& request) {
  AcquisitionResult result;

  if (request.cancellation.stop_requested()) {
    result.error_message = "Fetch cancelled before it started.";
    return result;
  }

  if (fetch_configured_to_fail(config_)) {
    result.error_message = "Stub connector configured to report fetch failure.";
    return result;
  }

  if (!request.overwrite && !request.resume && std::filesystem::exists(request.destination)) {
    result.error_message = "Destination already exists (overwrite=false).";
    return result;
  }

  const std::uint64_t total_bytes = kPlaceholderContent.size();
  if (request.progress) {
    request.progress(0, total_bytes);
  }

  try {
    if (request.destination.has_parent_path()) {
      std::filesystem::create_directories(request.destination.parent_path());
    }
    std::ofstream stream(request.destination, std::ios::binary | std::ios::trunc);
    stream << kPlaceholderContent;
    stream.flush();
    if (!stream) {
      result.error_message = "Failed to write to destination path: " + request.destination.string();
      return result;
    }
  } catch (const std::filesystem::filesystem_error& ex) {
    result.error_message = std::string("Failed to write to destination path: ") + ex.what();
    return result;
  }

  if (request.progress) {
    request.progress(total_bytes, total_bytes);
  }

  result.success = true;
  result.downloaded_file = request.destination;
  result.bytes_transferred = total_bytes;
  result.mime_type = fetch_mime_type(config_);
  result.checksum = fake_checksum(kPlaceholderContent);
  return result;
}

}  // namespace oep::acquisition::connectors
