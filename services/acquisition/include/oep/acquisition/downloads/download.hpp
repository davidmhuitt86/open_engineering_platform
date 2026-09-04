#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace oep::acquisition::downloads {

/// WORK_PACKAGE-006 "Download States". "Invalid transitions shall be
/// rejected" -- enforced by `DownloadService`, not by this enum itself.
enum class DownloadStatus {
  Pending,
  Downloading,
  Completed,
  Failed,
  Cancelled,
};

[[nodiscard]] std::string to_string(DownloadStatus status);
[[nodiscard]] std::optional<DownloadStatus> download_status_from_string(const std::string& text);

/// WORK_PACKAGE-006's "Download Model". `id` is the externally-visible
/// UUID, mirroring `registry::OfficialSource` and `acquisition::AcquisitionJob`
/// -- distinct from the database's internal surrogate primary key.
///
/// `local_storage_path`, `file_name`, `mime_type`, and `file_size_bytes`
/// are populated by `DownloadService` (from the resolved destination and
/// the connector's `AcquisitionResult`), never supplied directly by a
/// REST client.
struct Download {
  std::string id;
  std::string job_id;
  std::string connector_id;
  std::string source_uri;
  std::string local_storage_path;
  std::string file_name;
  std::string mime_type;
  std::uint64_t file_size_bytes = 0;
  DownloadStatus status = DownloadStatus::Pending;
  // 0-100 (WORK_PACKAGE-006 Validation Rules: "Progress shall remain
  // between 0 and 100").
  int progress_percentage = 0;
  std::optional<std::string> started_at;
  std::optional<std::string> completed_at;
  std::optional<std::string> error_message;
  std::string created_at;
  std::string updated_at;
};

/// Converts a byte-based progress report into a percentage clamped to
/// [0, 100] (WORK_PACKAGE-006 Validation Rules: "Progress shall remain
/// between 0 and 100"), used by `DownloadService`'s progress callback.
/// Returns 0 if `total_bytes` is 0 (unknown total).
[[nodiscard]] int clamp_progress_percentage(std::uint64_t bytes_transferred, std::uint64_t total_bytes);

}  // namespace oep::acquisition::downloads
