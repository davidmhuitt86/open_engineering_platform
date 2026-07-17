#pragma once

#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "oep/acquisition/downloads/download.hpp"

namespace oep::acquisition::downloads {

/// Optional filters for `GET /downloads`. Every field is optional; unset
/// fields impose no constraint.
struct DownloadFilter {
  std::optional<DownloadStatus> status;
  std::optional<std::string> job_id;
  std::optional<std::string> connector_id;
};

/// Thrown by `create` if `job_id` does not reference an existing
/// Acquisition Job -- defense in depth via the database's own foreign
/// key; `DownloadService` already validates job existence before
/// calling `create`, mirroring `acquisition::UnknownSourceError`.
class UnknownJobError : public std::runtime_error {
 public:
  explicit UnknownJobError(const std::string& job_id)
      : std::runtime_error("job_id does not reference an existing Acquisition Job: " + job_id) {}
};

/// Abstracts persistence for `Download` so `DownloadService` can be
/// unit-tested against a fake without a live PostgreSQL instance,
/// mirroring `acquisition::IAcquisitionJobRepository`.
class IDownloadRepository {
 public:
  virtual ~IDownloadRepository() = default;

  /// Inserts `download` and returns the stored row (`id`/`created_at`/
  /// `updated_at` populated by the database). Throws UnknownJobError if
  /// `download.job_id` does not reference an existing Acquisition Job.
  virtual Download create(const Download& download) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<Download> find_by_id(const std::string& id) = 0;

  virtual std::vector<Download> list(const DownloadFilter& filter) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<Download> update(const std::string& id, const Download& download) = 0;
};

}  // namespace oep::acquisition::downloads
