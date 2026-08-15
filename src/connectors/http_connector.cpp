#include "oep/acquisition/connectors/http_connector.hpp"

#include <cstdint>
#include <fstream>
#include <optional>
#include <sstream>
#include <string_view>

#include <httplib.h>

#include "oep/acquisition/common/time.hpp"

namespace oep::acquisition::connectors {

namespace {

struct ParsedUrl {
  std::string origin;  // e.g. "https://example.com" or "https://example.com:8443"
  std::string path;    // e.g. "/data/file.csv?x=1" -- always starts with '/'
};

std::optional<ParsedUrl> parse_url(const std::string& uri) {
  const auto scheme_end = uri.find("://");
  if (scheme_end == std::string::npos) return std::nullopt;
  const std::string scheme = uri.substr(0, scheme_end);
  if (scheme != "http" && scheme != "https") return std::nullopt;

  const auto authority_start = scheme_end + 3;
  if (authority_start >= uri.size()) return std::nullopt;
  const auto path_start = uri.find('/', authority_start);
  if (path_start == std::string::npos) {
    return ParsedUrl{uri, "/"};
  }
  return ParsedUrl{uri.substr(0, path_start), uri.substr(path_start)};
}

bool fetch_configured_to_fail(const ConnectorConfig& config) {
  const auto it = config.settings.find("fetch_outcome");
  return it != config.settings.end() && it->second == "failure";
}

std::set<std::string> parse_capabilities(const ConnectorConfig& config) {
  std::set<std::string> result;
  const auto it = config.settings.find("capabilities");
  if (it == config.settings.end() || it->second.empty()) return result;
  std::istringstream stream(it->second);
  std::string capability;
  while (std::getline(stream, capability, ',')) {
    if (!capability.empty()) result.insert(capability);
  }
  return result;
}

HealthStatus parse_health_status(const ConnectorConfig& config) {
  const auto it = config.settings.find("health_status");
  if (it == config.settings.end()) return HealthStatus::Healthy;
  if (it->second == "unhealthy") return HealthStatus::Unhealthy;
  if (it->second == "unknown") return HealthStatus::Unknown;
  return HealthStatus::Healthy;
}

int setting_int(const ConnectorConfig& config, std::string_view key, int fallback) {
  const auto it = config.settings.find(std::string(key));
  if (it == config.settings.end()) return fallback;
  try {
    return std::stoi(it->second);
  } catch (const std::exception&) {
    return fallback;
  }
}

std::string setting_string(const ConnectorConfig& config, std::string_view key, std::string fallback) {
  const auto it = config.settings.find(std::string(key));
  return it != config.settings.end() ? it->second : std::move(fallback);
}

}  // namespace

HttpConnector::HttpConnector(ConnectorConfig config) : config_(std::move(config)) {}

void HttpConnector::connect() { connected_ = true; }
void HttpConnector::disconnect() { connected_ = false; }
bool HttpConnector::is_connected() const { return connected_; }

HealthCheckResult HttpConnector::health_check() const {
  const HealthStatus status = parse_health_status(config_);
  std::string message;
  switch (status) {
    case HealthStatus::Healthy:
      message = "HTTP connector reports healthy (no live probe performed).";
      break;
    case HealthStatus::Unhealthy:
      message = "HTTP connector configured to report unhealthy.";
      break;
    case HealthStatus::Unknown:
      message = "HTTP connector configured to report unknown.";
      break;
  }
  return HealthCheckResult{status, message, common::current_timestamp_utc()};
}

std::set<std::string> HttpConnector::capabilities() const { return parse_capabilities(config_); }

bool HttpConnector::validate_configuration() const {
  return !config_.connector_id.empty() && !config_.type.empty();
}

const ConnectorConfig& HttpConnector::config() const { return config_; }

AcquisitionResult HttpConnector::fetch(const AcquisitionRequest& request) {
  AcquisitionResult result;

  if (request.cancellation.stop_requested()) {
    result.error_message = "Fetch cancelled before it started.";
    return result;
  }

  if (fetch_configured_to_fail(config_)) {
    result.error_message = "HTTP connector configured to report fetch failure.";
    return result;
  }

  if (!request.overwrite && !request.resume && std::filesystem::exists(request.destination)) {
    result.error_message = "Destination already exists (overwrite=false).";
    return result;
  }

  const auto parsed = parse_url(request.source_uri);
  if (!parsed) {
    result.error_message = "source_uri is not an absolute http:// or https:// URL: " + request.source_uri;
    return result;
  }

#ifndef CPPHTTPLIB_OPENSSL_SUPPORT
  if (parsed->origin.rfind("https://", 0) == 0) {
    result.error_message =
        "https:// requested but this build of cpp-httplib has no OpenSSL support "
        "(CPPHTTPLIB_OPENSSL_SUPPORT not defined) -- configure OpenSSL and rebuild.";
    return result;
  }
#endif

  httplib::Client client(parsed->origin);
  client.set_connection_timeout(setting_int(config_, "connect_timeout_seconds", 10));
  client.set_read_timeout(setting_int(config_, "read_timeout_seconds", 30));
  client.set_follow_location(true);

  const httplib::Headers headers = {
      {"User-Agent", setting_string(config_, "user_agent", "oep-acquisition-http-connector/1.0")},
  };

  if (request.destination.has_parent_path()) {
    std::filesystem::create_directories(request.destination.parent_path());
  }

  std::ofstream out(request.destination, std::ios::binary | std::ios::trunc);
  if (!out) {
    result.error_message = "Failed to open destination path for writing: " + request.destination.string();
    return result;
  }

  std::uint64_t bytes_written = 0;
  bool write_failed = false;
  const auto cancellation = request.cancellation;
  const auto progress = request.progress;

  auto content_receiver = [&](const char* data, size_t data_length) -> bool {
    if (cancellation.stop_requested()) return false;
    out.write(data, static_cast<std::streamsize>(data_length));
    if (!out) {
      write_failed = true;
      return false;
    }
    bytes_written += data_length;
    return true;
  };

  auto progress_callback = [&](std::uint64_t current, std::uint64_t total) -> bool {
    if (progress) progress(current, total);
    return !cancellation.stop_requested();
  };

  const auto response = client.Get(parsed->path, headers, content_receiver, progress_callback);
  out.flush();
  out.close();

  if (!response) {
    std::filesystem::remove(request.destination);
    result.error_message = "HTTP request failed: " + httplib::to_string(response.error());
    return result;
  }
  if (write_failed) {
    std::filesystem::remove(request.destination);
    result.error_message = "Failed while writing response body to destination path.";
    return result;
  }
  if (cancellation.stop_requested()) {
    std::filesystem::remove(request.destination);
    result.error_message = "Fetch cancelled during transfer.";
    return result;
  }
  if (response->status < 200 || response->status >= 300) {
    std::filesystem::remove(request.destination);
    result.error_message = "HTTP request returned status " + std::to_string(response->status) + ": " + parsed->origin + parsed->path;
    return result;
  }

  result.success = true;
  result.downloaded_file = request.destination;
  result.bytes_transferred = bytes_written;
  result.mime_type = response->get_header_value("Content-Type");
  if (result.mime_type.empty()) result.mime_type = "application/octet-stream";
  // A transfer-level identifier, not a cryptographic hash -- see this
  // class's own doc comment and AcquisitionResult::checksum's. ETag is
  // the closest thing HTTP offers to a server-reported content fingerprint;
  // absent one, this stays empty (the platform's real integrity guarantee
  // is the Integrity Verification stage's own SHA-256, not this field).
  result.checksum = response->get_header_value("ETag");
  return result;
}

}  // namespace oep::acquisition::connectors
