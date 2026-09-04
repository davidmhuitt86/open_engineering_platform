#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_job_repository.hpp"
#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/downloads/download_repository.hpp"

namespace oep::acquisition::downloads {

/// Orchestrates WORK_PACKAGE-006's Engineering Downloader: validates a
/// download request against the Acquisition Job Engine and the Source
/// Connector Framework, resolves and validates a local storage
/// destination, and retrieves the artifact via
/// `connectors::IConnector::fetch` (ADR-0008) -- entirely synchronously,
/// within the call to `start_download` (see README.md "Implementation
/// Decisions" for why no background thread is used).
///
/// Depends on `IDownloadRepository`, `acquisition::IAcquisitionJobRepository`,
/// and `connectors::ConnectorRegistry` so it can be unit-tested against
/// fakes/an in-memory registry without a live database or a real
/// connector, mirroring `acquisition::AcquisitionExecutionService`.
class DownloadService {
 public:
  DownloadService(IDownloadRepository& downloads, acquisition::IAcquisitionJobRepository& jobs,
                   connectors::ConnectorRegistry& connector_registry, common::StorageConfig storage_config);

  /// Throws (WORK_PACKAGE-006 "Validation Rules", checked in this order):
  /// - ValidationError if `job_id`/`connector_id`/`source_uri` are
  ///   missing.
  /// - UnknownJobError if `job_id` does not reference an existing
  ///   Acquisition Job.
  /// - JobNotExecutableError if that job's status is terminal.
  /// - UnknownConnectorError if `connector_id` is not registered.
  /// - ConnectorUnhealthyError if that connector's health check does not
  ///   report Healthy.
  /// - InvalidDestinationError if the resolved local storage destination
  ///   is not usable.
  ///
  /// On success, synchronously performs the fetch and returns the
  /// Download in its final state (Completed or Failed).
  Download start_download(const nlohmann::json& body);

  std::optional<Download> get(const std::string& id);

  std::vector<Download> list(const DownloadFilter& filter);

  /// Empty optional if `id` does not exist. Throws InvalidTransitionError
  /// if the download's current status is not Pending or Downloading.
  std::optional<Download> cancel(const std::string& id);

 private:
  IDownloadRepository& downloads_;
  acquisition::IAcquisitionJobRepository& jobs_;
  connectors::ConnectorRegistry& connector_registry_;
  common::StorageConfig storage_config_;

  void update_progress(const std::string& id, std::uint64_t bytes_transferred, std::uint64_t total_bytes);
};

}  // namespace oep::acquisition::downloads
