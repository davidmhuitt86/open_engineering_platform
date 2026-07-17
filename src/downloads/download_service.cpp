#include "oep/acquisition/downloads/download_service.hpp"

#include <filesystem>
#include <system_error>

#include "oep/acquisition/acquisition/acquisition_execution.hpp"
#include "oep/acquisition/common/time.hpp"
#include "oep/acquisition/connectors/connector.hpp"
#include "oep/acquisition/downloads/download_errors.hpp"
#include "oep/acquisition/downloads/validation.hpp"

namespace oep::acquisition::downloads {

namespace {

std::string derive_file_name(const std::string& source_uri) {
  const auto slash = source_uri.find_last_of('/');
  const std::string candidate = slash == std::string::npos ? source_uri : source_uri.substr(slash + 1);
  return candidate.empty() ? "download.bin" : candidate;
}

// Sanitizes `file_name` down to just its filename component (discarding
// any directory parts, so a maliciously- or accidentally-crafted
// "../../etc/passwd" cannot escape `workspace_root`) and ensures the
// containing directory can actually be created -- WORK_PACKAGE-006:
// "Download destination shall validate."
std::optional<std::filesystem::path> resolve_destination(const std::string& workspace_root,
                                                            const std::string& job_id,
                                                            const std::string& file_name) {
  const std::filesystem::path sanitized_name = std::filesystem::path(file_name).filename();
  if (sanitized_name.empty()) {
    return std::nullopt;
  }

  const std::filesystem::path destination = std::filesystem::path(workspace_root) / job_id / sanitized_name;

  std::error_code error;
  std::filesystem::create_directories(destination.parent_path(), error);
  if (error) {
    return std::nullopt;
  }
  return destination;
}

}  // namespace

DownloadService::DownloadService(IDownloadRepository& downloads, acquisition::IAcquisitionJobRepository& jobs,
                                   connectors::ConnectorRegistry& connector_registry,
                                   common::StorageConfig storage_config)
    : downloads_(downloads),
      jobs_(jobs),
      connector_registry_(connector_registry),
      storage_config_(std::move(storage_config)) {}

Download DownloadService::start_download(const nlohmann::json& body) {
  const StartDownloadRequest request = parse_and_validate_start(body);

  const auto job = jobs_.find_by_id(request.job_id);
  if (!job.has_value()) {
    throw UnknownJobError(request.job_id);
  }
  if (!acquisition::next_execution_status(job->status).has_value()) {
    throw JobNotExecutableError(request.job_id, acquisition::to_string(job->status));
  }

  connectors::IConnector* connector = connector_registry_.resolve(request.connector_id);
  if (connector == nullptr) {
    throw UnknownConnectorError(request.connector_id);
  }
  const auto health = connector->health_check();
  if (health.status != connectors::HealthStatus::Healthy) {
    throw ConnectorUnhealthyError(request.connector_id, connectors::to_string(health.status));
  }

  const std::string file_name =
      request.file_name.empty() ? derive_file_name(request.source_uri) : request.file_name;
  const auto destination = resolve_destination(storage_config_.workspace_path, request.job_id, file_name);
  if (!destination.has_value()) {
    throw InvalidDestinationError(file_name);
  }

  Download download;
  download.job_id = request.job_id;
  download.connector_id = request.connector_id;
  download.source_uri = request.source_uri;
  download.local_storage_path = destination->string();
  download.file_name = file_name;
  download.status = DownloadStatus::Pending;

  Download created = downloads_.create(download);

  created.status = DownloadStatus::Downloading;
  created.started_at = common::current_timestamp_utc();
  created = downloads_.update(created.id, created).value_or(created);

  connectors::AcquisitionRequest fetch_request;
  fetch_request.job_id = request.job_id;
  fetch_request.source_uri = request.source_uri;
  fetch_request.destination = *destination;
  const std::string download_id = created.id;
  fetch_request.progress = [this, download_id](std::uint64_t transferred, std::uint64_t total) {
    update_progress(download_id, transferred, total);
  };

  connectors::AcquisitionResult result;
  bool fetch_threw = false;
  std::string thrown_message;
  try {
    result = connector->fetch(fetch_request);
  } catch (const std::exception& ex) {
    fetch_threw = true;
    thrown_message = ex.what();
  }

  Download finalized = downloads_.find_by_id(download_id).value_or(created);
  finalized.completed_at = common::current_timestamp_utc();
  if (fetch_threw) {
    finalized.status = DownloadStatus::Failed;
    finalized.error_message = thrown_message;
  } else if (result.success) {
    finalized.status = DownloadStatus::Completed;
    finalized.mime_type = result.mime_type;
    finalized.file_size_bytes = result.bytes_transferred;
    finalized.local_storage_path = result.downloaded_file.string();
    finalized.progress_percentage = 100;
  } else {
    finalized.status = DownloadStatus::Failed;
    finalized.error_message = result.error_message.value_or("Fetch failed for an unspecified reason.");
  }

  return downloads_.update(download_id, finalized).value_or(finalized);
}

std::optional<Download> DownloadService::get(const std::string& id) {
  return downloads_.find_by_id(id);
}

std::vector<Download> DownloadService::list(const DownloadFilter& filter) {
  return downloads_.list(filter);
}

std::optional<Download> DownloadService::cancel(const std::string& id) {
  const auto download = downloads_.find_by_id(id);
  if (!download.has_value()) {
    return std::nullopt;
  }
  if (download->status != DownloadStatus::Pending && download->status != DownloadStatus::Downloading) {
    throw InvalidTransitionError(to_string(download->status));
  }

  Download updated = *download;
  updated.status = DownloadStatus::Cancelled;
  updated.completed_at = common::current_timestamp_utc();
  return downloads_.update(id, updated);
}

void DownloadService::update_progress(const std::string& id, std::uint64_t bytes_transferred,
                                        std::uint64_t total_bytes) {
  auto current = downloads_.find_by_id(id);
  if (!current.has_value()) {
    return;
  }
  current->progress_percentage = clamp_progress_percentage(bytes_transferred, total_bytes);
  downloads_.update(id, *current);
}

}  // namespace oep::acquisition::downloads
