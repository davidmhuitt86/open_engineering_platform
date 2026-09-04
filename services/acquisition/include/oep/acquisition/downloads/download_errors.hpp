#pragma once

#include <stdexcept>
#include <string>

namespace oep::acquisition::downloads {

/// Thrown by `DownloadService::start_download` when the referenced job's
/// current status has no forward execution step (WORK_PACKAGE-006:
/// "Job shall be executable") -- i.e. it is Completed, Failed, or
/// Cancelled. Reuses `acquisition::next_execution_status`'s own
/// definition of "executable" rather than inventing a new one.
class JobNotExecutableError : public std::runtime_error {
 public:
  JobNotExecutableError(const std::string& job_id, const std::string& job_status)
      : std::runtime_error("Job is not executable (status '" + job_status + "'): " + job_id) {}
};

/// Thrown by `DownloadService::start_download` when `connector_id` does
/// not resolve to a registered connector (WORK_PACKAGE-006: "Connector
/// shall exist").
class UnknownConnectorError : public std::runtime_error {
 public:
  explicit UnknownConnectorError(const std::string& connector_id)
      : std::runtime_error("Connector does not exist: " + connector_id) {}
};

/// Thrown by `DownloadService::start_download` when the resolved
/// connector's health check does not report Healthy (WORK_PACKAGE-006:
/// "Connector shall be healthy").
class ConnectorUnhealthyError : public std::runtime_error {
 public:
  ConnectorUnhealthyError(const std::string& connector_id, const std::string& health_status)
      : std::runtime_error("Connector is not healthy (status '" + health_status + "'): " + connector_id) {}
};

/// Thrown by `DownloadService::start_download` when the computed local
/// storage destination is not valid (WORK_PACKAGE-006: "Download
/// destination shall validate") -- e.g. an empty/unusable file name, or
/// the configured workspace directory could not be created.
class InvalidDestinationError : public std::runtime_error {
 public:
  explicit InvalidDestinationError(const std::string& file_name)
      : std::runtime_error("Download destination did not validate for file name: " + file_name) {}
};

/// Thrown by `DownloadService::cancel` when the download's current
/// status has no valid transition to Cancelled (WORK_PACKAGE-006:
/// "Invalid transitions shall be rejected") -- only Pending and
/// Downloading can be cancelled. A separate type from
/// `acquisition::InvalidTransitionError` (rather than reusing it) so the
/// message correctly says "download," not "job."
class InvalidTransitionError : public std::runtime_error {
 public:
  explicit InvalidTransitionError(const std::string& current_status)
      : std::runtime_error("Cannot cancel a download in status '" + current_status + "'.") {}
};

}  // namespace oep::acquisition::downloads
