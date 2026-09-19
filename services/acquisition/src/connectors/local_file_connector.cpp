#include "oep/acquisition/connectors/local_file_connector.hpp"

#include <cstdint>
#include <fstream>
#include <sstream>
#include <string_view>
#include <system_error>

#include "oep/acquisition/common/time.hpp"

namespace oep::acquisition::connectors {

namespace {

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

std::uint64_t max_file_bytes(const ConnectorConfig& config) {
  const auto it = config.settings.find("max_file_bytes");
  if (it == config.settings.end()) return 2ull * 1024 * 1024 * 1024;
  try {
    return std::stoull(it->second);
  } catch (const std::exception&) {
    return 2ull * 1024 * 1024 * 1024;
  }
}

}  // namespace

LocalFileConnector::LocalFileConnector(ConnectorConfig config) : config_(std::move(config)) {}

void LocalFileConnector::connect() { connected_ = true; }
void LocalFileConnector::disconnect() { connected_ = false; }
bool LocalFileConnector::is_connected() const { return connected_; }

HealthCheckResult LocalFileConnector::health_check() const {
  // No external system to probe -- the local filesystem is always
  // "reachable" in the sense this connector cares about; a specific
  // source file's own readability is checked per-fetch, not here.
  return HealthCheckResult{HealthStatus::Healthy, "Local file connector reports healthy (no external dependency).",
                            common::current_timestamp_utc()};
}

std::set<std::string> LocalFileConnector::capabilities() const { return parse_capabilities(config_); }

bool LocalFileConnector::validate_configuration() const {
  return !config_.connector_id.empty() && !config_.type.empty();
}

const ConnectorConfig& LocalFileConnector::config() const { return config_; }

AcquisitionResult LocalFileConnector::fetch(const AcquisitionRequest& request) {
  AcquisitionResult result;

  if (request.cancellation.stop_requested()) {
    result.error_message = "Fetch cancelled before it started.";
    return result;
  }

  // `source_uri` is interpreted as an absolute local filesystem path for
  // this connector type (see this class's own doc comment) -- reject
  // anything else outright rather than guessing at a relative path
  // against an ambiguous working directory.
  const std::filesystem::path source_path(request.source_uri);
  if (!source_path.is_absolute()) {
    result.error_message = "source_uri must be an absolute local file path for the local-file connector: " +
                            request.source_uri;
    return result;
  }

  std::error_code status_error;
  // `std::filesystem::status` (not `symlink_status`) follows symlinks --
  // a file picker's own selection may legitimately resolve through one
  // (e.g. a synced-folder shortcut); what matters is that the final
  // target is a genuine regular file, not what kind of directory entry
  // pointed at it.
  const auto file_status = std::filesystem::status(source_path, status_error);
  if (status_error || !std::filesystem::exists(file_status)) {
    result.error_message = "Local file does not exist or is not accessible: " + source_path.string();
    return result;
  }
  if (!std::filesystem::is_regular_file(file_status)) {
    result.error_message = "Local file path does not refer to a regular file: " + source_path.string();
    return result;
  }

  std::error_code size_error;
  const std::uintmax_t source_size = std::filesystem::file_size(source_path, size_error);
  if (size_error) {
    result.error_message = "Could not determine the size of the local file: " + source_path.string();
    return result;
  }
  if (source_size == 0) {
    result.error_message = "Local file is empty: " + source_path.string();
    return result;
  }
  const std::uint64_t limit = max_file_bytes(config_);
  if (source_size > limit) {
    result.error_message =
        "Local file exceeds the maximum accepted size (" + std::to_string(limit) + " bytes): " + source_path.string();
    return result;
  }

  if (!request.overwrite && !request.resume && std::filesystem::exists(request.destination)) {
    result.error_message = "Destination already exists (overwrite=false).";
    return result;
  }

  if (request.progress) {
    request.progress(0, source_size);
  }

  std::error_code copy_error;
  if (request.destination.has_parent_path()) {
    std::filesystem::create_directories(request.destination.parent_path(), copy_error);
    if (copy_error) {
      result.error_message = "Failed to create staging directory: " + copy_error.message();
      return result;
    }
    copy_error.clear();
  }
  // `copy_file` -- never `rename`/`remove` -- the engineer's original
  // file must remain completely untouched (WP-EAM-005 §4: "Do not
  // delete or modify the user's original file").
  std::filesystem::copy_file(source_path, request.destination, std::filesystem::copy_options::overwrite_existing,
                              copy_error);
  if (copy_error) {
    result.error_message = "Failed to copy local file to staging location: " + copy_error.message();
    return result;
  }

  if (request.progress) {
    request.progress(source_size, source_size);
  }

  result.success = true;
  result.downloaded_file = request.destination;
  result.bytes_transferred = static_cast<std::uint64_t>(source_size);
  // No content-type sniffing here -- the existing Metadata Extraction
  // stage (document_inspector.cpp/file_type_detector.cpp) is the
  // established place MIME type is actually determined from real
  // content; a generic default is enough for the connector's own
  // AcquisitionResult, matching StubConnector's precedent of a simple
  // default rather than duplicating that detection here.
  result.mime_type = "application/octet-stream";
  // No transfer-level checksum reported -- unlike HttpConnector's ETag,
  // a local file copy has no equivalent server-reported fingerprint;
  // the platform's real integrity guarantee remains the existing
  // Integrity Verification stage's own SHA-256, computed after this
  // connector returns, exactly as for every other connector.
  return result;
}

}  // namespace oep::acquisition::connectors
